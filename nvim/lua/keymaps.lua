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

-- Normal --
-- Better window navigation
-- keymap("n", "<C-h>", "<C-w>h", opts)
-- keymap("n", "<C-j>", "<C-w>j", opts)
-- keymap("n", "<C-k>", "<C-w>k", opts)
-- keymap("n", "<C-l>", "<C-w>l", opts)
--
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
vim.keymap.set('n', '<A-,>', ':BufferLineCycleNext<CR>', { silent = true })
vim.keymap.set('n', '<A-m>', ':BufferLineCyclePrev<CR>', { silent = true })

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
keymap("v", "<", "<gv^", opts)
keymap("v", ">", ">gv^", opts)

-- Visual Block --
-- Move text up and down
keymap("x", "J", ":m '>+1<CR>gv=gv", opts)
keymap("x", "K", ":m '<-2<CR>gv=gv", opts)

-- Move cursor in insert mode with Ctrl + hjkl
vim.keymap.set('i', '<C-h>', '<C-o>h', { noremap = true, silent = true })
vim.keymap.set('i', '<C-j>', '<C-o>j', { noremap = true, silent = true })
vim.keymap.set('i', '<C-k>', '<C-o>k', { noremap = true, silent = true })
vim.keymap.set('i', '<C-w>', '<C-o>w', { noremap = true, silent = true })
vim.keymap.set('i', '<C-b>', '<C-o>b', { noremap = true, silent = true })
vim.keymap.set('i', '<C-e>', '<C-o>e', { noremap = true, silent = true })
vim.keymap.set('i', '<C-l>', '<C-o>l', { noremap = true, silent = true })
vim.keymap.set('i', '<C-u>', '<C-o>10k', { noremap = true, silent = true })
vim.keymap.set('i', '<C-d>', '<C-o>10j', { noremap = true, silent = true })

-- Move to first non-blank character (Normal + Visual)
vim.keymap.set({ "n", "v" }, "H", "^", { noremap = true, silent = true, desc = "Go to line start (non-blank)" })

-- Move to end of line (Normal + Visual)
vim.keymap.set({ "n", "v" }, "L", "$", { noremap = true, silent = true, desc = "Go to line end" })

-- Vertical and horizontal splits
vim.keymap.set("n", "<A-\\>", ":vsplit<CR>", { noremap = true, silent = true, desc = "Vertical Split" })

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
vim.keymap.set('n', '<A-]>', ']c', { noremap = true, silent = true, desc = 'Next diff chunk' })
vim.keymap.set('n', '<A-[>', '[c', { noremap = true, silent = true, desc = 'Previous diff chunk' })

-- Exit diff view and return to single window
vim.keymap.set('n', '<leader>o', ':only<CR>', { noremap = true, silent = true })

-- Open Git diff view for current file
vim.keymap.set('n', '<leader>ds', ':Gvdiffsplit<CR>', { noremap = true, silent = true, desc = 'Open Git diff view' })

-- Quick save and quit
vim.keymap.set('n', '<leader>q', ':q!', { noremap = true })
vim.keymap.set('n', '<leader>a', ':qa!', { noremap = true })
vim.keymap.set('n', '<leader>w', ':w', { noremap = true })

