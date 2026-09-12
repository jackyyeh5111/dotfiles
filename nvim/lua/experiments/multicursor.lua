-- Multi-cursor prototype.
--
-- Idea: Neovim only has one real cursor per window. "Secondary" cursors here
-- are just extmarks (which auto-track their position through edits, even
-- edits made elsewhere in the buffer -- that's the whole trick). Every
-- keystroke applied to the real cursor gets replayed at each extmark
-- position too, in a loop, via :normal!/feedkeys. mode() stays "n" (or "i")
-- the entire time -- same as vim-visual-multi (see plugins.lua's VM_maps /
-- lualine block), just a much smaller, from-scratch version of the same idea.
--
-- Try it (without touching your real config):
--   :lua package.loaded["experiments.multicursor"] = nil
--   :lua require("experiments.multicursor").setup()
--
-- Then in some scratch text:
--   <leader>mm   add a secondary cursor at the current position
--   <leader>md   add a secondary cursor at the next occurrence of <cword>
--                (repeat to grow the set, VSCode Ctrl+D / Sublime Cmd+D style)
--   h j k l w b e 0 $   move every cursor together
--   x X D C ~ p P dd dw cc   edit at every cursor
--   i a I A o O <text> <Esc>   type at every cursor (see caveat below)
--   <Esc>        clear all secondary cursors, back to plain Neovim
--
-- Scope: this is a prototype, not vim-visual-multi. No counts (3j), no
-- arbitrary operator+motion (d3w), no visual-mode selections as cursors, no
-- undo-join across cursors (each cursor's edit is its own undo step). Enough
-- is here to prove the architecture; extending SIMPLE_KEYS below is how you'd
-- grow it.

local M = {}

local ns = vim.api.nvim_create_namespace("mc_prototype")
local group = vim.api.nvim_create_augroup("MCPrototype", { clear = true })

-- states[bufnr] = { active = bool, cursors = { extmark_id, ... }, pending_entry = "i"|nil }
local states = {}

local function state(buf)
  states[buf] = states[buf] or { active = false, cursors = {} }
  return states[buf]
end

local function char_at(buf, row, col)
  local line = vim.api.nvim_buf_get_lines(buf, row, row + 1, false)[1] or ""
  if col >= #line then
    return " " -- past end of line: nothing to overlay, show a blank cursor block
  end
  return line:sub(col + 1, col + 1)
end

-- (Re)draw the fake cursor at `id`'s current tracked position: overlay the
-- character that's actually there with a reverse-video highlight, so it
-- reads as a block cursor instead of hiding the buffer's content.
local function redraw(buf, id, row, col)
  vim.api.nvim_buf_set_extmark(buf, ns, row, col, {
    id = id,
    virt_text = { { char_at(buf, row, col), "MCCursor" } },
    virt_text_pos = "overlay",
  })
end

vim.api.nvim_set_hl(0, "MCCursor", { reverse = true })

-- Replay `keys` (a plain :normal!-safe string, no free text) at the real
-- cursor first (the primary), then at every secondary cursor's tracked
-- position. Order doesn't matter for correctness: extmarks auto-adjust for
-- *any* buffer edit, including ones made while the real cursor is sitting
-- somewhere else entirely.
local function apply(buf, keys)
  vim.cmd("normal! " .. keys)
  local primary = vim.api.nvim_win_get_cursor(0)

  for _, id in ipairs(state(buf).cursors) do
    local pos = vim.api.nvim_buf_get_extmark_by_id(buf, ns, id, {})
    if pos and #pos > 0 then
      vim.api.nvim_win_set_cursor(0, { pos[1] + 1, pos[2] })
      vim.cmd("normal! " .. keys)
      local np = vim.api.nvim_win_get_cursor(0)
      redraw(buf, id, np[1] - 1, np[2])
    end
  end

  vim.api.nvim_win_set_cursor(0, primary)
end

-- Motions and single-shot edits: safe to replay verbatim with :normal!.
-- x/X/D/C/dd/dw/cc go through the black-hole register to match the global
-- remap in keymaps.lua (otherwise they'd behave differently here than
-- everywhere else in this config while multicursor is active).
local SIMPLE_KEYS = {
  h = "h", j = "j", k = "k", l = "l",
  w = "w", b = "b", e = "e",
  ["0"] = "0", ["$"] = "$",
  ["~"] = "~", p = "p", P = "P",
  x = '"_x', X = '"_X', D = '"_D', C = '"_C',
  dd = '"_dd', dw = '"_dw', cc = '"_cc',
}

-- i/a/I/A/o/O can't be replayed live like the above -- :normal! "i" alone
-- enters and immediately auto-exits insert mode with nothing typed, since
-- there's no more input in the command string (see :h :normal). So instead:
-- let the *primary* enter real, native Insert mode (real blinking cursor,
-- completion, autopairs, everything works normally); on InsertLeave, read
-- back what was actually typed from the "." register (Vim always keeps the
-- last inserted text there) and replay `entry .. text .. <Esc>` -- now fully
-- known up front -- at every secondary cursor with one feedkeys("x") call.
local INSERT_ENTRIES = { "i", "a", "I", "A", "o", "O" }

local function bind_insert_entry(buf, lhs)
  vim.keymap.set("n", lhs, function()
    state(buf).pending_entry = lhs
    -- 'i' prepends instead of appending: without it, any keys already queued
    -- ahead of this one (a macro, dot-repeat, fast typing) would run before
    -- the real entry command instead of after it.
    vim.api.nvim_feedkeys(lhs, "ni", false)
  end, { buffer = buf })
end

vim.api.nvim_create_autocmd("InsertLeave", {
  group = group,
  callback = function(ev)
    local st = states[ev.buf]
    if not st or not st.active or not st.pending_entry then
      return
    end
    local entry = st.pending_entry
    st.pending_entry = nil

    local text = vim.fn.getreg(".")
    if text == "" then
      return
    end

    local esc = vim.api.nvim_replace_termcodes("<Esc>", true, false, true)
    local keys = entry .. text .. esc
    local primary = vim.api.nvim_win_get_cursor(0)

    for _, id in ipairs(st.cursors) do
      local pos = vim.api.nvim_buf_get_extmark_by_id(ev.buf, ns, id, {})
      if pos and #pos > 0 then
        vim.api.nvim_win_set_cursor(0, { pos[1] + 1, pos[2] })
        -- Bang bypasses mappings entirely -- including our own buffer-local
        -- <Esc> (which clears multicursor state). Without the bang, the
        -- literal Esc byte at the end of `keys` re-triggers that mapping
        -- mid-loop and wipes the remaining cursors before they're replayed.
        vim.cmd("normal! " .. keys)
        local np = vim.api.nvim_win_get_cursor(0)
        redraw(ev.buf, id, np[1] - 1, np[2])
      end
    end

    vim.api.nvim_win_set_cursor(0, primary)
  end,
})

local function deactivate(buf)
  local st = states[buf]
  if not st or not st.active then
    return
  end
  for lhs in pairs(SIMPLE_KEYS) do
    pcall(vim.keymap.del, "n", lhs, { buffer = buf })
  end
  for _, lhs in ipairs(INSERT_ENTRIES) do
    pcall(vim.keymap.del, "n", lhs, { buffer = buf })
  end
  pcall(vim.keymap.del, "n", "<Esc>", { buffer = buf })
  for _, id in ipairs(st.cursors) do
    pcall(vim.api.nvim_buf_del_extmark, buf, ns, id)
  end
  states[buf] = nil
  vim.notify("multicursor: cleared")
end

local function activate(buf)
  local st = state(buf)
  if st.active then
    return
  end
  st.active = true

  for lhs, keys in pairs(SIMPLE_KEYS) do
    vim.keymap.set("n", lhs, function() apply(buf, keys) end, { buffer = buf })
  end
  for _, lhs in ipairs(INSERT_ENTRIES) do
    bind_insert_entry(buf, lhs)
  end
  vim.keymap.set("n", "<Esc>", function() deactivate(buf) end, { buffer = buf, desc = "Clear multicursor" })
end

local function add_cursor_at(buf, row, col)
  local st = state(buf)
  local id = vim.api.nvim_buf_set_extmark(buf, ns, row, col, {
    virt_text = { { char_at(buf, row, col), "MCCursor" } },
    virt_text_pos = "overlay",
  })
  table.insert(st.cursors, id)
  activate(buf)
  vim.notify(("multicursor: %d secondary cursor(s)"):format(#st.cursors))
end

-- Drop a secondary cursor exactly where the real cursor is right now.
function M.add_cursor()
  local buf = vim.api.nvim_get_current_buf()
  local row, col = unpack(vim.api.nvim_win_get_cursor(0))
  add_cursor_at(buf, row - 1, col)
end

-- VSCode Ctrl+D / Sublime Cmd+D: turn the current position into a secondary
-- cursor, then jump the real cursor to the next occurrence of <cword>.
-- Repeat to keep growing the set.
function M.add_cursor_next_match()
  local buf = vim.api.nvim_get_current_buf()
  local word = vim.fn.expand("<cword>")
  if word == "" then
    return
  end

  local row, col = unpack(vim.api.nvim_win_get_cursor(0))
  add_cursor_at(buf, row - 1, col)

  local pat = "\\<" .. vim.fn.escape(word, "\\") .. "\\>"
  local found = vim.fn.searchpos(pat, "w")
  if found[1] == 0 then
    vim.notify("multicursor: no more matches for " .. word, vim.log.levels.WARN)
  end
end

function M.setup()
  vim.keymap.set("n", "<leader>mm", M.add_cursor, { desc = "Multicursor: add at cursor" })
  vim.keymap.set("n", "<leader>md", M.add_cursor_next_match, { desc = "Multicursor: add at next <cword> match" })
end

return M
