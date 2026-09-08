local options = {
  backup = false,                          -- creates a backup file
  clipboard = "unnamedplus",               -- allows neovim to access the system clipboard
  -- cmdheight = 2,                           -- more space in the neovim command line for displaying messages
  completeopt = { "menuone", "noselect" }, -- used by blink.cmp
  conceallevel = 0,                        -- so that `` is visible in markdown files
  fileencoding = "utf-8",                  -- the encoding written to a file
  hlsearch = true,                         -- highlight all matches on previous search pattern
  ignorecase = true,                       -- ignore case in search patterns
  mouse = "a",                             -- allow the mouse to be used in neovim
  pumheight = 10,                          -- pop up menu height
  -- showmode = false,                        -- we don't need to see things like -- INSERT -- anymore
  showtabline = 2,                         -- always show tabs
  smartcase = true,                        -- smart case
  smartindent = true,                      -- make indenting smarter again
  splitbelow = true,                       -- force all horizontal splits to go below current window
  splitright = true,                       -- force all vertical splits to go to the right of current window
  swapfile = false,                        -- creates a swapfile
  termguicolors = true,                    -- set term gui colors (most terminals support this)
  timeout = false,                         -- wait forever for a mapped sequence to complete; <Esc> still cancels it
  undofile = true,                         -- enable persistent undo
  updatetime = 300,                        -- faster completion (4000ms default)
  writebackup = false,                     -- if a file is being edited by another program (or was written to file while editing with another program), it is not allowed to be edited
  expandtab = true,                        -- convert tabs to spaces
  shiftwidth = 4,                          -- the number of spaces inserted for each indentation
  tabstop = 4,                             -- insert X spaces for a tab
  cursorline = true,                       -- highlight the current line
  number = true,                           -- set numbered lines
  relativenumber = false,                 -- absolute line numbers
  numberwidth = 4,                         -- set number column width to 2 {default 4}

  signcolumn = "yes",                      -- always show the sign column, otherwise it would shift the text each time
  wrap = false,                             -- display lines as one long line
  linebreak = true,                        -- companion to wrap, don't split words
  scrolloff = 8,                           -- minimal number of screen lines to keep above and below the cursor
  sidescrolloff = 8,                       -- minimal number of screen columns either side of cursor if wrap is `false`
  guifont = "monospace:h17",               -- the font used in graphical neovim applications
  whichwrap = "bs<>[]hl",                  -- which "horizontal" keys are allowed to travel to prev/next line
  signcolumn = "no",

}

for k, v in pairs(options) do
  vim.opt[k] = v
end

-- vim.opt.shortmess = "ilmnrx"                        -- flags to shorten vim messages, see :help 'shortmess'
vim.opt.shortmess:append "c"                           -- don't give |ins-completion-menu| messages
vim.opt.iskeyword:append "-"                           -- hyphenated words recognized by searches
vim.opt.formatoptions:remove({ "c", "r", "o" })        -- don't insert the current comment leader automatically for auto-wrapping comments using 'textwidth', hitting <Enter> in insert mode, or hitting 'o' or 'O' in normal mode.
vim.opt.runtimepath:remove("/usr/share/vim/vimfiles")  -- separate vim plugins from neovim in case vim still in use

-- Send the system clipboard through OSC 52 instead of the default xclip
-- provider. nvim runs on a remote Linux box reached over SSH from Ghostty on
-- the Mac, and the xclip path only reaches the Mac pasteboard via ssh -X ->
-- XQuartz: it needs X forwarding to be up, it dies whenever a reconnect
-- hands out a new display number (long-lived shells keep pointing at the old,
-- now-dead localhost:10.0), and a stale selection owner can wedge a read
-- until it's killed. OSC 52 is just an escape sequence written to the
-- terminal, so it rides the same connection nvim is already drawing on:
-- no X server, nothing to go stale, nothing that can block the editor.
-- Reading back (for p) needs Ghostty's `clipboard-read = allow`.
local osc52 = require("vim.ui.clipboard.osc52")
vim.g.clipboard = {
  name = "osc52",
  copy = { ["+"] = osc52.copy("+"), ["*"] = osc52.copy("+") },
  paste = { ["+"] = osc52.paste("+"), ["*"] = osc52.paste("+") },
}

-- clipboard=unnamedplus only mirrors "" into "+ for Vim's own yank/delete/put
-- dispatch. vim-visual-multi's multi-cursor yank joins per-cursor text and
-- calls setreg() directly on "", bypassing that dispatch, so it never
-- reaches the system clipboard on its own. Mirror it by hand on SafeState,
-- but only while VM is actually active (tracked via the same VM autocmd
-- events plugins.lua uses for its <C-c> exit binding) -- this used to run
-- unconditionally on every SafeState tick, so a plain yank paid for a
-- second, redundant clipboard-provider round trip on top of the one
-- unnamedplus already does natively. That matters here because the
-- underlying xclip/X11-forwarding link (SSH to a remote box) has been
-- observed to wedge: a stale clipboard-owner process can leave a later
-- read hanging indefinitely. Scoping this to VM-only cuts the extra round
-- trips back down to the case that actually needs them, and pcall keeps a
-- wedged provider call from raising into SafeState and breaking other
-- autocmds on it.
local vm_active = false
vim.api.nvim_create_autocmd("User", {
  pattern = "visual_multi_mappings",
  callback = function() vm_active = true end,
})
vim.api.nvim_create_autocmd("User", {
  pattern = "visual_multi_exit",
  callback = function() vm_active = false end,
})

local last_unnamed_reg
vim.api.nvim_create_autocmd("SafeState", {
  callback = function()
    if not vm_active or not vim.o.clipboard:find("unnamedplus") then
      return
    end
    local reg = vim.fn.getreg('"')
    if reg ~= last_unnamed_reg then
      last_unnamed_reg = reg
      pcall(vim.fn.setreg, "+", reg, vim.fn.getregtype('"'))
    end
  end,
})

