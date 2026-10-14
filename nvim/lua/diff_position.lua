-- Diff Position: "[2/10]" in the statusline -- which diff chunk the cursor is
-- on, out of how many the current window has. Counts the same chunks that
-- <A-[>/<A-]> step through: diff chunks in a diff window, or merge conflicts
-- in Diffview's 1-pane merge layout (which isn't in diff mode).
local M = {}

local conflict_start = [[^<<<<<<< ]]

-- Bumped on every DiffUpdated, so a cached chunk list goes stale when the
-- *other* pane changes too, not only when this buffer does.
local diff_gen = 0
local cache = {} -- winid -> { key = ..., starts = { lnum, ... } }

-- First line of every diff chunk in the current window, e.g. { 3, 40, 112 }.
-- A chunk is a run of changed lines (diff_hlID ~= 0), plus any filler lines
-- above it -- or just filler lines, when this side has the deletion. A pure
-- deletion sits above the line below it, which is where ]c lands, so that
-- line is its start (the last line, for a deletion past the end of file).
local function diff_chunk_starts()
  local last = vim.fn.line('$')
  local starts, in_chunk = {}, false
  for lnum = 1, last + 1 do
    local changed = lnum <= last and vim.fn.diff_hlID(lnum, 1) ~= 0
    -- Filler right after a changed run belongs to that run, not a new chunk.
    if not in_chunk and (changed or vim.fn.diff_filler(lnum) > 0) then
      table.insert(starts, math.min(lnum, last))
    end
    in_chunk = changed
  end
  return starts
end

local function conflict_starts()
  local starts = {}
  for lnum, line in ipairs(vim.api.nvim_buf_get_lines(0, 0, -1, false)) do
    if vim.fn.match(line, conflict_start) == 0 then table.insert(starts, lnum) end
  end
  return starts
end

-- Scanning every line on every cursor move would crawl on big files, so the
-- chunk list is cached per window until its buffer or the diff changes.
local function chunk_starts()
  local win, buf = vim.api.nvim_get_current_win(), vim.api.nvim_get_current_buf()
  local is_diff = vim.wo.diff
  local key = table.concat({ buf, vim.b.changedtick, is_diff and diff_gen or 'plain' }, ':')
  local entry = cache[win]
  if not entry or entry.key ~= key then
    entry = { key = key, starts = is_diff and diff_chunk_starts() or conflict_starts() }
    cache[win] = entry
  end
  return entry.starts
end

-- "[2/10]" when the cursor is on (or past the start of) the 2nd of 10 chunks,
-- "[-/10]" above the first one, "" outside a diff / conflicted file.
function M.label()
  local is_diff = vim.wo.diff
  -- Outside diff mode, only a Diffview tab's conflicted files are worth it.
  if not is_diff and not vim.t.diffview_view_initialized then return '' end
  local starts = chunk_starts()
  if #starts == 0 then return '' end

  local row, idx = vim.fn.line('.'), 0
  for i, lnum in ipairs(starts) do
    if lnum > row then break end
    idx = i
  end
  return string.format('[%s/%d]', idx == 0 and '-' or idx, #starts)
end

local group = vim.api.nvim_create_augroup('DiffPosition', { clear = true })

vim.api.nvim_create_autocmd('DiffUpdated', {
  group = group,
  callback = function() diff_gen = diff_gen + 1 end,
})

vim.api.nvim_create_autocmd('WinClosed', {
  group = group,
  callback = function(args) cache[tonumber(args.match)] = nil end,
})

return M
