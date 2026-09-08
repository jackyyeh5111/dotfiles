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
--
-- herdr is the exception. It runs each pane in its own terminal emulator and
-- relays OSC 52 clipboard *writes* outward, but it has no code path at all for
-- answering the read query -- so asking it for the clipboard hangs nvim on
-- "waiting for OSC response from the terminal" until you press Ctrl-C. Inside
-- herdr, serve paste out of what we last copied instead of asking the
-- terminal; outside it, query for real so a Cmd+C made outside nvim is
-- reachable with p. Copy stays OSC 52 in both cases, so a yank always makes it
-- to the Mac pasteboard.
local osc52 = require("vim.ui.clipboard.osc52")
local in_herdr = vim.env.HERDR_ENV ~= nil

local osc52_copy = osc52.copy("+")
local last_copy = { { "" }, "v" }
local function copy(lines, regtype)
  last_copy = { lines, regtype }
  osc52_copy(lines, regtype)
end
local function paste_last_copy()
  return last_copy
end

vim.g.clipboard = {
  name = in_herdr and "osc52-herdr" or "osc52",
  copy = { ["+"] = copy, ["*"] = copy },
  paste = {
    ["+"] = in_herdr and paste_last_copy or osc52.paste("+"),
    ["*"] = in_herdr and paste_last_copy or osc52.paste("+"),
  },
}

-- clipboard=unnamedplus only mirrors "" into "+ for Vim's own yank/delete/put
-- dispatch. vim-visual-multi writes "" with a raw setreg() instead -- a
-- multi-cursor yank joins the per-cursor text and fills the register by hand
-- (Edit.fill_register) -- so it bypasses that dispatch and never reaches the
-- system clipboard on its own. Mirror it here, but only around VM: outside
-- VM an ordinary yank already reaches "+ natively, and mirroring on every
-- SafeState tick would buy a second, redundant clipboard-provider round trip
-- per idle.
--
-- Three details in VM's own bookkeeping decide whether this works, and
-- getting any of them wrong means a VM yank silently never reaches Cmd+V:
--
--   * 'clipboard' cannot be tested while VM is running. VM does
--     `set clipboard=` on entry ("force default register",
--     vm/variables.vim) and restores it only in vm#variables#reset() on the
--     way out -- so "VM is active" and "'clipboard' contains unnamedplus"
--     are mutually exclusive, and requiring both is a gate that never opens.
--   * The session has to be tracked with visual_multi_start, not
--     visual_multi_mappings. VM re-applies its mappings (and re-fires that
--     event) on every mode change *within* a session, and change_mode() is
--     part of the yank-at-cursors path itself -- so anything that resets
--     per-session state on visual_multi_mappings gets reset again in the
--     middle of `y$`, after the register was already written. Only
--     visual_multi_start fires once per session (vm#comp#init, reached from
--     vm#init_buffer, which returns early once b:visual_multi is set).
--   * SafeState alone is not enough. VM's exit sequence rewrites "" from its
--     own backup (Funcs.restore_regs) after the last yank, and the exit can
--     land in the same input batch as the yank, so nothing guarantees an
--     idle tick in between. Mirror once more on visual_multi_exit, which VM
--     fires last (vm#comp#exit), by which point 'clipboard' is back and ""
--     holds the yanked text.
--
-- pcall keeps a wedged provider call from raising into SafeState and
-- breaking other autocmds on it.
local last_unnamed_reg
local function mirror_unnamed_reg()
  local reg = vim.fn.getreg('"')
  if reg == last_unnamed_reg then
    return
  end
  last_unnamed_reg = reg
  pcall(vim.fn.setreg, "+", reg, vim.fn.getregtype('"'))
end

local vm_active = false
vim.api.nvim_create_autocmd("User", {
  pattern = "visual_multi_start",
  callback = function()
    vm_active = true
    -- Baseline the change check against "" as it is on entry, so only what
    -- this VM session writes gets mirrored. Carrying the previous session's
    -- value over instead would misread "same text as last time" as "nothing
    -- to do" and leave a Cmd+C made in between sitting on the pasteboard.
    last_unnamed_reg = vim.fn.getreg('"')
  end,
})
vim.api.nvim_create_autocmd("User", {
  pattern = "visual_multi_exit",
  callback = function()
    vm_active = false
    mirror_unnamed_reg()
  end,
})

vim.api.nvim_create_autocmd("SafeState", {
  callback = function()
    if vm_active then
      mirror_unnamed_reg()
    end
  end,
})
