local opts = { noremap = true, silent = true }

local term_opts = { silent = true }

-- Shorten function name
local keymap = vim.keymap.set

--Remap space as leader key
keymap("", "<Space>", "<Nop>", opts)
vim.g.mapleader = " "
vim.g.maplocalleader = " "

-- Modes
--   normal_mode = "n",
--   insert_mode = "i",
--   visual_mode = "v",
--   visual_block_mode = "x",
--   term_mode = "t",
--   command_mode = "c",

-- Resize with arrows
-- keymap("n", "<C-Up>", ":resize -2<CR>", opts)
-- keymap("n", "<C-Down>", ":resize +2<CR>", opts)
-- keymap("n", "<C-Left>", ":vertical resize -2<CR>", opts)
-- keymap("n", "<C-Right>", ":vertical resize +2<CR>", opts)

-- Navigate buffers
-- keymap("n", "<A-l>", ":bnext<CR>", opts)
-- keymap("n", "<A-h>", ":bprevious<CR>", opts)
-- Remap Ctrl-^ to switch to last buffer
-- vim.keymap.set('n', '<A-b>', ':b#<CR>', { noremap = true, silent = true })

-- Move between buffers (shown in bufferline)
vim.keymap.set('n', '<A-Tab>', ':BufferLineCycleNext<CR>', { silent = true })
vim.keymap.set('n', '<A-S-Tab>', ':BufferLineCyclePrev<CR>', { silent = true })

-- Open / close buffers
vim.keymap.set('n', '<A-t>', ':enew<CR>', { silent = true })
vim.keymap.set('n', '<A-w>', ':bdelete<CR>', { silent = true })

-- Move text up and down
keymap("n", "<A-j>", ":m .+1<CR>==", opts)
keymap("n", "<A-k>", ":m .-2<CR>==", opts)

-- Insert --
-- Press jk fast to exit insert mode 
keymap("i", "jk", "<ESC>", opts)
keymap("i", "kj", "<ESC>", opts)

-- paste what I explicitly yanked
vim.keymap.set("n", "p", '"0p')
vim.keymap.set("n", "P", '"0P')

-- Visual --
-- Stay in indent mode
keymap("v", ">", ">gv^", opts)

-- Yank to system clipboard with Cmd+C (requires terminal to forward <D-c> to nvim)
keymap("v", "<D-c>", '"+y', opts)

-- Wrap visual selection with brackets and quotes
keymap('v', '(', 'c()<Esc>P', { desc = 'Wrap selection with ()' })
keymap('v', ')', 'c()<Esc>P', { desc = 'Wrap selection with ()' })
keymap('v', '[', 'c[]<Esc>P', { desc = 'Wrap selection with []' })
keymap('v', ']', 'c[]<Esc>P', { desc = 'Wrap selection with []' })
keymap('v', '{', 'c{}<Esc>P', { desc = 'Wrap selection with {}' })
keymap('v', '}', 'c{}<Esc>P', { desc = 'Wrap selection with {}' })
keymap('v', '"', 'c""<Esc>P', { desc = 'Wrap selection with ""' })
keymap('v', "'", "c''<Esc>P", { desc = "Wrap selection with ''" })
keymap('v', '`', 'c``<Esc>P', { desc = 'Wrap selection with ``' })
keymap('v', '<', 'c<><Esc>P', { desc = 'Wrap selection with <>' })

-- Visual Block --
-- Move text up and down
keymap("x", "J", ":m '>+1<CR>gv=gv", opts)
keymap("x", "K", ":m '<-2<CR>gv=gv", opts)

-- Move cursor in insert mode with Ctrl + hjkl
vim.keymap.set('i', '<C-h>', '<Left>', { noremap = true, silent = true })
vim.keymap.set('i', '<C-j>', '<Down>', { noremap = true, silent = true })
vim.keymap.set('i', '<C-k>', '<Up>', { noremap = true, silent = true })
vim.keymap.set('i', '<C-w>', '<C-o>w', { noremap = true, silent = true })
vim.keymap.set('i', '<C-b>', '<C-o>b', { noremap = true, silent = true })
vim.keymap.set('i', '<C-e>', '<C-o>e', { noremap = true, silent = true })
vim.keymap.set('i', '<C-l>', '<Right>', { noremap = true, silent = true })
vim.keymap.set('i', '<C-u>', '<C-o>10k', { noremap = true, silent = true })
vim.keymap.set('i', '<C-d>', '<C-o>10j', { noremap = true, silent = true })
vim.keymap.set('i', '<C-S-h>', '<C-o>^', { noremap = true, silent = true, desc = 'Move to start of line' })
vim.keymap.set('i', '<C-S-l>', '<C-o>$', { noremap = true, silent = true, desc = 'Move to end of line' })

-- Move to first non-blank character (Normal + Visual)
vim.keymap.set({ "n", "v" }, "H", "^", { noremap = true, silent = true, desc = "Go to line start (non-blank)" })

-- Move to end of line (Normal + Visual)
vim.keymap.set({ "n", "v" }, "L", "$", { noremap = true, silent = true, desc = "Go to line end" })

-- Vertical and horizontal splits
vim.keymap.set("n", "<A-\\>", ":vsplit<CR>", { noremap = true, silent = true, desc = "Vertical Split" })

-- Navigate between window panes
vim.keymap.set("n", "<A-h>", "<C-w>h", { noremap = true, silent = true, desc = "Go to left window" })
vim.keymap.set("n", "<A-j>", "<C-w>j", { noremap = true, silent = true, desc = "Go to below window" })
vim.keymap.set("n", "<A-k>", "<C-w>k", { noremap = true, silent = true, desc = "Go to above window" })
vim.keymap.set("n", "<A-l>", "<C-w>l", { noremap = true, silent = true, desc = "Go to right window" })
vim.keymap.set("n", "<A-o>", "<C-w>w", { noremap = true, silent = true, desc = "Cycle to next window" })

-- Toggle wrap option
vim.keymap.set("n", "<A-x>", function()
  vim.opt.wrap = not vim.opt.wrap:get()
  print("Wrap " .. (vim.opt.wrap:get() and "enabled" or "disabled"))
end, { desc = "Toggle text wrap" })

-- Resize splits easily with arrow keys
vim.keymap.set("n", "<C-Up>",    ":resize +5<CR>",         { silent = true, desc = "Increase window height" })
vim.keymap.set("n", "<C-Down>",  ":resize -5<CR>",         { silent = true, desc = "Decrease window height" })
vim.keymap.set("n", "<C-Left>",  ":vertical resize -5<CR>", { silent = true, desc = "Decrease window width" })
vim.keymap.set("n", "<C-Right>", ":vertical resize +5<CR>", { silent = true, desc = "Increase window width" })

-- Jump to prev/next diff chunk
vim.keymap.set('n', '<A-[>', ']c', { noremap = true, silent = true, desc = 'Next diff chunk' })
vim.keymap.set('n', '<A-]>', '[c', { noremap = true, silent = true, desc = 'Previous diff chunk' })

-- Pull ("obtain") the current diff chunk from the other window, then save.
-- Skips the write when the current buffer is read-only (e.g. Diffview's
-- synthetic index/commit panes), since "do" has nothing to apply there.
vim.keymap.set('n', "<A-'>", function()
  if not vim.bo.modifiable then
    return
  end
  vim.cmd('normal! do')
  vim.cmd('silent! write')
end, { noremap = true, silent = true, desc = 'Diff obtain (pull chunk from other pane) and save' })

-- Same, but for every chunk in the file at once: makes this file identical to
-- the other pane, then saves. ":%diffget" is deliberately not used -- its range
-- can't reach a hunk that sits *above* line 1 (lines the other side adds at the
-- top), so it silently leaves that one behind. Copying the other buffer wholesale
-- has no such blind spot.
local function diff_obtain_all()
  if not vim.wo.diff then
    vim.notify('Not in diff mode', vim.log.levels.WARN)
    return
  end
  if not vim.bo.modifiable then
    return
  end

  local cur = vim.api.nvim_get_current_win()
  local others = {}
  for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
    if win ~= cur and vim.wo[win].diff then
      table.insert(others, win)
    end
  end
  -- A 3-way diff (merge conflict) is ambiguous: no single "other side" to pull.
  if #others ~= 1 then
    vim.notify(
      #others == 0 and 'No other diff window' or 'More than two diff windows',
      vim.log.levels.WARN
    )
    return
  end

  local lines = vim.api.nvim_buf_get_lines(vim.api.nvim_win_get_buf(others[1]), 0, -1, false)
  local row = vim.api.nvim_win_get_cursor(0)[1]
  vim.api.nvim_buf_set_lines(0, 0, -1, false, lines)
  vim.api.nvim_win_set_cursor(0, { math.min(row, math.max(#lines, 1)), 0 })
  vim.cmd('silent! write')
  vim.cmd('diffupdate')

  -- Saving makes the file identical to the other side, so Diffview drops the
  -- entry and swaps this window to the next file -- which would hide the buffer
  -- (and its undo history) right after the edit. Hold this file in place so "u"
  -- still undoes the pull (":w" then re-applies it). Diffview swaps more than
  -- once, hence a standing autocmd rather than a one-shot; it lifts after 1.5s
  -- so deliberate navigation is only ever fought for that instant.
  local buf, win = vim.api.nvim_get_current_buf(), cur
  local group = vim.api.nvim_create_augroup('DiffObtainAllKeepBuf', { clear = true })

  vim.api.nvim_create_autocmd({ 'BufWinEnter', 'WinEnter' }, {
    group = group,
    callback = function()
      vim.schedule(function()
        if vim.api.nvim_win_is_valid(win) and vim.api.nvim_buf_is_valid(buf)
          and vim.api.nvim_win_get_buf(win) ~= buf then
          pcall(vim.api.nvim_win_set_buf, win, buf)
        end
      end)
    end,
  })
  vim.defer_fn(function() pcall(vim.api.nvim_del_augroup_by_id, group) end, 1500)
end

vim.keymap.set('n', '<A-">', diff_obtain_all,
  { noremap = true, silent = true, desc = 'Diff obtain all chunks in file and save' })
vim.keymap.set('n', "<A-S-'>", diff_obtain_all,
  { noremap = true, silent = true, desc = 'Diff obtain all chunks in file and save' })

-- Quick save and quit
vim.keymap.set('n', '<leader>q', ':q!', { noremap = true })
vim.keymap.set('n', '<leader>a', ':qa!', { noremap = true })
vim.keymap.set('n', '<leader>w', ':wq', { noremap = true })

-- Copy absolute file path (system clipboard + yank register, for the p/P remap above)
vim.keymap.set('n', '<leader>yp', function()
  local path = vim.fn.expand('%:p')
  vim.fn.setreg('+', path)
  vim.fn.setreg('0', path)
  vim.notify('Copied: ' .. path)
end, { noremap = true, silent = true, desc = 'Copy absolute file path' })

-- Copy absolute file path with line number, e.g. /abs/path/file.lua:42
vim.keymap.set('n', '<leader>yl', function()
  local path = vim.fn.expand('%:p') .. ':' .. vim.fn.line('.')
  vim.fn.setreg('+', path)
  vim.fn.setreg('0', path)
  vim.notify('Copied: ' .. path)
end, { noremap = true, silent = true, desc = 'Copy absolute file path with line number' })

-- Copy file path relative to the current git repo root, e.g. nvim/lua/keymaps.lua
vim.keymap.set('n', '<leader>yr', function()
  local abs_path = vim.fn.expand('%:p')
  local dir = vim.fn.expand('%:p:h')
  local root = vim.fn.systemlist('git -C ' .. vim.fn.shellescape(dir) .. ' rev-parse --show-toplevel')[1]
  if vim.v.shell_error ~= 0 or not root then
    vim.notify('Not inside a git repo', vim.log.levels.WARN)
    return
  end
  local rel_path = abs_path:sub(#root + 2)
  vim.fn.setreg('+', rel_path)
  vim.fn.setreg('0', rel_path)
  vim.notify('Copied: ' .. rel_path)
end, { noremap = true, silent = true, desc = 'Copy file path relative to repo root' })

