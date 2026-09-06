local M = {}
local PackageName = "Undo"

--- Maximum number of undoable operations kept in the history file.
local DEFAULT_LIMIT = 200

local home = os.getenv("HOME") or ""

--- Kept in `$HOME` rather than under `$XDG_STATE_HOME` because the history is
--- appended from `ps.sub()`, which runs in a sync context where neither `fs`
--- nor `Command` is available to create a missing directory.
local HISTORY_FILE = home .. "/.yazi_history"

---@enum STATE
local STATE = {
	POSITION = "position",
	SHOW_CONFIRM = "show_confirm",
	SUPPRESS_SUCCESS_NOTIFICATION = "suppress_success_notification",
	LIMIT = "limit",
	INITIALIZED = "initialized",
}

--- Whether `ps.sub()` already ran in this Lua VM. Re-subscribing the same kind
--- throws, so `setup()` has to be idempotent.
local subscribed = false

--- A line of `trash-restore` output: index, deletion date, original path.
--- The path is kept whole, so paths containing spaces survive.
local ENTRY_PATTERN = "^%s*(%d+)%s+%d%d%d%d%-%d%d%-%d%d%s+%d%d:%d%d:%d%d%s+(.*)$"

--- Both scripts are constant text: every value reaches the shell as a
--- positional argument, so paths can never be parsed as shell syntax.
local LIST_SCRIPT = 'printf "\\n" | trash-restore --sort=date -- "$1"'
local RESTORE_SCRIPT = 'printf "%s\\n" "$1" | trash-restore --sort=date -- "$2"'

local set_state = ya.sync(function(state, key, value)
	state[key] = value
end)

local get_state = ya.sync(function(state, key)
	return state[key]
end)

local function notify_error(s, ...)
	ya.notify({ title = PackageName, content = string.format(s, ...), timeout = 5, level = "error" })
end

local function notify_info(s, ...)
	ya.notify({ title = PackageName, content = string.format(s, ...), timeout = 5, level = "info" })
end

--- Escape the characters that would otherwise break the line-based, tab
--- separated history format.
---@param s string
---@return string
local function encode(s)
	return (s:gsub("[%%\t\r\n]", function(c)
		return string.format("%%%02X", string.byte(c))
	end))
end

---@param s string
---@return string
local function decode(s)
	return (s:gsub("%%(%x%x)", function(hex)
		return string.char(tonumber(hex, 16))
	end))
end

--- Split on single tabs, preserving empty fields.
---@param s string
---@return string[]
local function split_tabs(s)
	local fields = {}
	for field in (s .. "\t"):gmatch("([^\t]*)\t") do
		fields[#fields + 1] = field
	end
	return fields
end

---@return string[]
local function hist_read()
	local file = io.open(HISTORY_FILE, "r")
	if not file then
		return {}
	end

	local lines = {}
	for line in file:lines() do
		if line ~= "" then
			lines[#lines + 1] = line
		end
	end

	file:close()
	return lines
end

--- Rewrite the history through a temporary file, so an interrupted write can't
--- truncate the existing history.
---@param lines string[]
local function hist_write(lines)
	local limit = get_state(STATE.LIMIT) or DEFAULT_LIMIT
	while #lines > limit do
		table.remove(lines, 1)
	end

	local temp = HISTORY_FILE .. ".tmp"
	local file, err = io.open(temp, "w")
	if not file then
		notify_error("Cannot write the history file: %s", tostring(err))
		return
	end

	for _, line in ipairs(lines) do
		file:write(line, "\n")
	end
	file:close()

	local ok, rename_err = os.rename(temp, HISTORY_FILE)
	if not ok then
		notify_error("Cannot replace the history file: %s", tostring(rename_err))
		os.remove(temp)
	end
end

--- Append one operation. Runs in a sync context, so it stays a single append
--- rather than a read-modify-write of the whole file.
---@param op string
---@param paths string[]
local function hist_push(op, paths)
	if #paths == 0 then
		return
	end

	local fields = { op }
	for _, path in ipairs(paths) do
		fields[#fields + 1] = encode(path)
	end

	local file = io.open(HISTORY_FILE, "a")
	if not file then
		return
	end

	file:write(table.concat(fields, "\t"), "\n")
	file:close()
end

--- Most recent operation, left in place until it has actually been undone.
---@return string?, string[]?
local function hist_peek()
	local lines = hist_read()
	if #lines == 0 then
		return
	end

	local line = lines[#lines]

	-- Entries written before the tab separated format was introduced are space
	-- separated and unescaped. They only ever held paths without spaces, so
	-- reading them back that way loses nothing.
	if not line:find("\t") then
		local fields = {}
		for field in line:gmatch("%S+") do
			fields[#fields + 1] = field
		end
		return table.remove(fields, 1), fields
	end

	local fields = split_tabs(line)
	local op = table.remove(fields, 1)

	local paths = {}
	for _, field in ipairs(fields) do
		paths[#paths + 1] = decode(field)
	end

	return op, paths
end

--- Remove the most recent operation, once it has been undone.
local function hist_drop()
	local lines = hist_read()
	if #lines == 0 then
		return
	end

	table.remove(lines)
	hist_write(lines)
end

--- Run a constant script with the given positional arguments.
---@param script string
---@param args string[]
---@return Output?
local function sh(script, args)
	local argv = { "-c", script, "sh" }
	for _, arg in ipairs(args) do
		argv[#argv + 1] = arg
	end

	local output, err = Command("sh"):arg(argv):stdout(Command.PIPED):stderr(Command.PIPED):output()
	if not output then
		notify_error("Cannot run trash-restore: %s", tostring(err))
		return
	end

	return output
end

--- Index of the most recently trashed entry whose original path is exactly
--- `path`. `trash-restore` sorts by date, so the last match is the newest.
---@param path string
---@return string?
local function latest_index(path)
	local output = sh(LIST_SCRIPT, { path })
	if not output or not output.status.success then
		return
	end

	local index
	for line in output.stdout:gmatch("[^\n]+") do
		local candidate, candidate_path = line:match(ENTRY_PATTERN)
		if candidate and candidate_path == path then
			index = candidate
		end
	end

	return index
end

--- Restore a single path from the trash, returning whether it is back on disk.
---@param path string
---@return boolean
local function restore(path)
	local index = latest_index(path)
	if not index then
		return false
	end

	-- Deliberately no `--overwrite`: an undo should never clobber a file that
	-- has taken the original's place.
	local output = sh(RESTORE_SCRIPT, { index, path })
	if not output or not output.status.success then
		return false
	end

	-- `trash-restore` reports some failures on stdout while still exiting 0,
	-- so confirm against the filesystem.
	return fs.cha(Url(path)) ~= nil
end

---@param paths string[]
---@return boolean
local function undo_trash(paths)
	if #paths == 0 then
		notify_error("No items to restore from trash.")
		return false
	end

	if get_state(STATE.SHOW_CONFIRM) then
		local body = #paths == 1 and paths[1] or string.format("%d items:\n%s", #paths, table.concat(paths, "\n"))
		local confirmed = ya.confirm({
			pos = get_state(STATE.POSITION) or { "center", w = 70, h = 40 },
			title = "Restore from trash?",
			body = body,
		})

		if not confirmed then
			return false
		end
	end

	local restored, failed = 0, {}
	for _, path in ipairs(paths) do
		if restore(path) then
			restored = restored + 1
		else
			failed[#failed + 1] = path
		end
	end

	if #failed > 0 then
		notify_error("Could not restore %d of %d item(s):\n%s", #failed, #paths, table.concat(failed, "\n"))
	end

	if restored == 0 then
		return false
	end

	if not get_state(STATE.SUPPRESS_SUCCESS_NOTIFICATION) then
		notify_info("Restored %d item%s from trash.", restored, restored > 1 and "s" or "")
	end

	-- Only drop the history entry once nothing is left to retry.
	return #failed == 0
end

---@class SetupOptions
---@field position? AsPos Position of the confirmation dialog.
---@field show_confirm? boolean Ask before restoring. Defaults to true.
---@field suppress_success_notification? boolean Stay quiet on success. Defaults to false.
---@field limit? integer Operations kept in the history file. Defaults to 200.

--- Setup plugin, add it to yazi/init.lua file
---@param opts? SetupOptions
function M:setup(opts)
	if opts ~= nil and type(opts) ~= "table" then
		notify_error("setup() expects a table of options, got %s.", type(opts))
		return
	end

	local limit = opts and opts.limit or DEFAULT_LIMIT
	if type(limit) ~= "number" or limit < 1 then
		notify_error("`limit` must be a positive number, got %s.", tostring(limit))
		limit = DEFAULT_LIMIT
	end

	set_state(STATE.POSITION, (opts and type(opts.position) == "table") and opts.position or { "center", w = 70, h = 40 })
	set_state(STATE.SHOW_CONFIRM, opts == nil or opts.show_confirm ~= false)
	set_state(STATE.SUPPRESS_SUCCESS_NOTIFICATION, (opts and opts.suppress_success_notification) == true)
	set_state(STATE.LIMIT, limit)
	set_state(STATE.INITIALIZED, true)

	if not subscribed then
		-- Record the paths only. Looking them up in the trash is deferred to
		-- undo time, to keep this handler off the shell entirely.
		ps.sub("trash", function(body)
			local paths = {}
			for _, url in ipairs(body.urls) do
				paths[#paths + 1] = tostring(url)
			end
			hist_push("trash", paths)
		end)
		subscribed = true
	end
end

function M:entry()
	if not get_state(STATE.INITIALIZED) then
		notify_error('Not set up. Add `require("undo"):setup()` to your init.lua.')
		return
	end

	local op, paths = hist_peek()
	if not op then
		notify_info("No more undo entries.")
		return
	end

	if op ~= "trash" then
		-- Nothing can ever undo it, so drop it instead of letting it block
		-- every later entry.
		notify_error("Discarding an unknown undo operation: %s", op)
		hist_drop()
		return
	end

	if undo_trash(paths) then
		hist_drop()
	end
end

return M
