-- colorscheme config
local colortheme = {
    "catppuccin/nvim",
    name = "catppuccin",
    lazy = false,
    priority = 1000,
    config = function()
        require("catppuccin").setup({
            flavour = "mocha",
            transparent_background = true,
            integrations = {
                diffview = true,
                gitsigns = true,
            },
        })
        vim.cmd.colorscheme("catppuccin")
    end
}

-- The active colorscheme is set by catppuccin's config above. If catppuccin is
-- ever disabled, uncomment this to fall back to a builtin scheme.
-- vim.cmd.colorscheme("default")

-- Most colorschemes ship diff colours that are too desaturated to tell apart.
-- Vim also marks a modified line as DiffChange/DiffText on *both* sides of a
-- diff, so without the per-window overrides below a changed line renders the
-- same colour left and right instead of red-vs-green.
-- Re-applied on every ColorScheme so these survive a theme switch.
local function diff_highlights()
    local hl = {
        -- Whole-line backgrounds.
        DiffAdd    = "#1e3a2a", -- green: line exists only on the right
        DiffDelete = "#3d1f27", -- red:   line exists only on the left
        DiffChange = "#1f2b3f", -- neutral fallback (non-diffview windows)
        DiffText   = "#2f4a6b",

        -- Per-side variants used by the diffview hook. "AsDelete" = left pane,
        -- "AsAdd" = right pane. Text variants are brighter so the changed
        -- region stands out against the rest of the line.
        DiffviewDiffChangeAsDelete = "#3d1f27",
        DiffviewDiffTextAsDelete   = "#6e2a38",
        DiffviewDiffChangeAsAdd    = "#1e3a2a",
        DiffviewDiffTextAsAdd      = "#2f6b42",
    }
    for group, bg in pairs(hl) do
        vim.api.nvim_set_hl(0, group, { bg = bg })
    end
end

vim.api.nvim_create_autocmd("ColorScheme", {
    group = vim.api.nvim_create_augroup("UserDiffHighlights", { clear = true }),
    callback = diff_highlights,
})
diff_highlights()

-- Telescope config
local telescope = {
    "nvim-telescope/telescope.nvim",
    dependencies = {
        "nvim-lua/plenary.nvim",
        -- FZF native matcher for drastically faster searching and better fuzzy matching
        { "nvim-telescope/telescope-fzf-native.nvim", build = "make" },
        -- UI select extension to replace Neovim's default vim.ui.select (code actions, etc.)
        "nvim-telescope/telescope-ui-select.nvim",
    },
    config = function()
        local telescope = require("telescope")
        local actions = require("telescope.actions")
        local action_layout = require("telescope.actions.layout")

        telescope.setup {
            defaults = {
                path_display = { "smart" },
                mappings = {
                    i = {
                        -- Toggle preview window dynamically
                        ["<M-p>"] = action_layout.toggle_preview,
                        -- Move selection up/down like j/k
                        ["<C-j>"] = actions.move_selection_next,
                        ["<C-k>"] = actions.move_selection_previous,
                    },
                },

                -- Always stacked (results on top, preview below), regardless of terminal width
                layout_strategy = "vertical",
                layout_config = {
                    -- Use nearly the whole screen, VSCode-quick-open style
                    width = 0.95,
                    height = 0.90,
                    -- preview_cutoff = 0 works around the preview not showing:
                    -- https://github.com/nvim-telescope/telescope.nvim/issues/1594#issuecomment-993447528
                    vertical = { preview_cutoff = 0, preview_height = 0.3 },
                }
            },
            extensions = {
                fzf = {
                    fuzzy = true,
                    override_generic_sorter = true,
                    override_file_sorter = true,
                    case_mode = "smart_case",
                },
                ["ui-select"] = {
                    require("telescope.themes").get_dropdown({}),
                },
            },
        }

        telescope.load_extension("fzf")
        telescope.load_extension("ui-select")

        local builtin = require("telescope.builtin")

        -- Resolve to the current file's git repo root, falling back to cwd
        -- when not inside a git repo, so pickers always search from the
        -- project root regardless of which subdirectory nvim was opened in.
        local function git_root()
            local root = vim.fn.systemlist("git rev-parse --show-toplevel")[1]
            if vim.v.shell_error == 0 and root and root ~= "" then
                return root
            end
            return vim.loop.cwd()
        end

        -- Submodules are separate repos with their own (often huge) history/
        -- files; keep Telescope from descending into them by reading their
        -- paths straight out of .gitmodules, so this stays correct even as
        -- submodules are added/removed.
        local function submodule_ignore_patterns(root)
            local out = vim.fn.systemlist(
                "git -C " .. vim.fn.shellescape(root) .. " config --file .gitmodules --get-regexp path 2>/dev/null"
            )
            local patterns = {}
            for _, line in ipairs(out) do
                local path = line:match("^submodule%.%S+%.path%s+(.+)$")
                if path then
                    table.insert(patterns, "^" .. vim.pesc(path) .. "/")
                end
            end
            return patterns
        end

        -- File & text search
        vim.keymap.set("n", "<leader>ff", function()
            local root = git_root()
            builtin.find_files({ cwd = root, file_ignore_patterns = submodule_ignore_patterns(root) })
        end, { desc = "Find files" })
        vim.keymap.set("n", "<leader>fs", function()
            local root = git_root()
            builtin.live_grep({ cwd = root, file_ignore_patterns = submodule_ignore_patterns(root) })
        end, { desc = "Search text across project" })
        vim.keymap.set("n", "<leader>fb", builtin.buffers, { desc = "List open buffers" })
        vim.keymap.set("n", "<leader>fh", builtin.command_history, { desc = "Command history" })

        -- Telescope LSP symbols
        vim.keymap.set("n", "<leader>ss", builtin.lsp_document_symbols, { desc = "Document symbols" })
        vim.keymap.set("n", "<leader>sw", builtin.lsp_workspace_symbols, { desc = "Workspace symbols" })

        -- Git pickers
        vim.keymap.set("n", "<leader>pgc", builtin.git_commits, { desc = "Git commits" })
        vim.keymap.set("n", "<leader>pgs", builtin.git_status, { desc = "Git status" })
    end
}

-- Treesitter config
local treesitter = {
    "nvim-treesitter/nvim-treesitter",
    build = ":TSUpdate",
    dependencies = {
        { "nvim-treesitter/nvim-treesitter-textobjects", branch = "master" },
    },
    config = function()
        require("nvim-treesitter.configs").setup({
            ensure_installed = { "lua", "vim", "vimdoc", "python", "c", "cpp", "markdown", "markdown_inline" },
            highlight = { enable = true },
            indent = { enable = true },
            textobjects = {
                select = {
                    enable = true,
                    lookahead = true, -- Automatically jump forward to textobj
                    keymaps = {
                        ["af"] = "@function.outer",
                        ["if"] = "@function.inner",
                        ["ac"] = "@class.outer",
                        ["ic"] = "@class.inner",
                    },
                },
                move = {
                    enable = true,
                    set_jumps = true, -- so <C-o>/<C-i> can jump back/forward through these too
                    goto_next_start = {
                        ["<A-m>"] = "@function.outer",
                        ["<A-c>"] = "@class.outer",
                    },
                    goto_previous_start = {
                        ["<A-M>"] = "@function.outer",
                        ["<A-C>"] = "@class.outer",
                    },
                },
            },
        })
    end
}

-- Completion engine. Draws its own popup (doesn't rely on the built-in
-- ins-complete menu), pulls suggestions from LSP/path/snippets/buffer, and
-- exposes get_lsp_capabilities() so lspconfig can tell each server what the
-- client supports (snippet completions, etc). version = "1.*" pins to a
-- tagged release so lazy.nvim fetches the prebuilt Rust fuzzy-matcher binary
-- instead of requiring a local cargo/rustup toolchain to build it.
local blink_cmp = {
    "saghen/blink.cmp",
    version = "1.*",
    dependencies = { "rafamadriz/friendly-snippets" },
    opts = {
        keymap = { preset = "default" },
        appearance = {
            nerd_font_variant = "mono",
        },
        completion = {
            documentation = { auto_show = true, auto_show_delay_ms = 200 },
            list = { selection = { preselect = false } },
        },
        signature = { enabled = true },
        sources = {
            default = { "lsp", "path", "snippets", "buffer" },
        },
    },
    opts_extend = { "sources.default" },
}

-- LSP configs
local lspconfig = {

    -- Mason manages external tooling like LSP servers, DAP servers, linters, and formatters
    {
        "williamboman/mason.nvim",
        lazy = false,
        config = function()
            require("mason").setup()
        end,
    },

    -- Mason LSPconfig bridges mason.nvim with the lspconfig plugin
    {
        "williamboman/mason-lspconfig.nvim",
        lazy = false,
        opts = {
            ensure_installed = { "lua_ls", "pyright", "clangd" },
            automatic_installation = true,
        },
    },

    -- Mason only auto-installs LSP servers on its own; this extension covers
    -- the non-LSP CLI tools (formatters, linters, DAP servers) mason.nvim
    -- also knows how to fetch -- here, the formatters conform.nvim shells
    -- out to.
    {
        "WhoIsSethDaniel/mason-tool-installer.nvim",
        lazy = false,
        opts = {
            ensure_installed = { "stylua", "black", "isort", "clang-format" },
        },
    },

    -- LSP client config
    {
        "neovim/nvim-lspconfig",
        lazy = false,
        dependencies = { "saghen/blink.cmp" },
        config = function()
            -- Tell every LSP server that this client can render completion
            -- items with snippet expansion, resolve documentation lazily,
            -- etc -- without this, completion still works but falls back to
            -- plain-text/less capable results from the server.
            local capabilities = require("blink.cmp").get_lsp_capabilities()
            vim.lsp.config("*", { capabilities = capabilities })

            local servers = { "lua_ls", "pyright", "clangd" }
            for _, lsp in ipairs(servers) do
                if vim.lsp.config[lsp] then
                    vim.lsp.enable(lsp)
                else
                    vim.notify(lsp .. " config not found", vim.log.levels.ERROR)
                end
            end

            -- Hover documentation
            vim.keymap.set("n", "K", vim.lsp.buf.hover, { desc = "Hover documentation" })
            
            -- Go to definition, declaration, implementation, type definition
            -- (routed through Telescope for a multi-result picker + quickfix workflow)
            vim.keymap.set("n", "<leader>gd", function() require("telescope.builtin").lsp_definitions() end,
                { noremap = true, silent = true, desc = "Go to definition (Telescope)" })
            vim.keymap.set("n", "<leader>gD", vim.lsp.buf.declaration,
                { noremap = true, silent = true, desc = "Go to declaration" })
            vim.keymap.set("n", "<leader>gi", function() require("telescope.builtin").lsp_implementations() end,
                { noremap = true, silent = true, desc = "Go to implementations (Telescope)" })
            vim.keymap.set("n", "<leader>gt", function() require("telescope.builtin").lsp_type_definitions() end,
                { noremap = true, silent = true, desc = "Go to type definition (Telescope)" })

            -- Find references
            vim.keymap.set("n", "<leader>gr", function() require("telescope.builtin").lsp_references() end,
                { noremap = true, silent = true, desc = "Find references (Telescope)" })

            -- Code actions
            vim.keymap.set("n", "<leader>ca", vim.lsp.buf.code_action,
                { noremap = true, silent = true, desc = "Code action" })
            vim.keymap.set("n", "<leader>rn", vim.lsp.buf.rename,
                { noremap = true, silent = true, desc = "Rename symbol" })
        end,
    }
}

local git_fugitive = {
    "tpope/vim-fugitive",
    cmd = { "Git", "Gdiff", "Gvdiffsplit", "Gread", "Gwrite" },
}
local gitsigns = {
    "lewis6991/gitsigns.nvim",
    event = "BufReadPre",  -- load on buffer read
    config = function()
        require("gitsigns").setup({
            current_line_blame = true,  -- optional: show git blame for current line
            watch_gitdir = {
                interval = 1000,
                follow_files = true
            },
        })

        vim.keymap.set("n", "<leader>gp", ":Gitsigns preview_hunk<CR>", { desc = "Preview git hunk" })
        vim.keymap.set("n", "<leader>gb", ":Gitsigns toggle_current_line_blame<CR>", { desc = "Toggle line blame" })

        vim.keymap.set("n", "<A-s>", ":Gitsigns stage_hunk<CR>", { desc = "Stage current hunk" })
        vim.keymap.set("n", "<A-u>", ":Gitsigns undo_stage_hunk<CR>", { desc = "Undo stage hunk" })
        vim.keymap.set("n", "<A-r>", ":Gitsigns reset_hunk<CR>", { desc = "Reset (discard) current hunk" })
    end,
    dependencies = { "nvim-lua/plenary.nvim" },  -- gitsigns depends on plenary
}

local copilot = {
    "github/copilot.vim"
}

-- File: lua/plugins/toggleterm.lua
local toggleterm = {
  "akinsho/toggleterm.nvim",

  config = function()
    -- Colored top border for the toggleterm window.
    --
    -- Note: WinSeparator is NOT usable here. With laststatus=2 (the default,
    -- and what lualine leaves it at since globalstatus is off) Neovim draws no
    -- horizontal separator between stacked windows at all -- the boundary is
    -- just the upper window's statusline. WinSeparator's horizontal variant
    -- only renders under laststatus=3. So the border is drawn as a winbar on
    -- the terminal window instead, which always renders and stays scoped to
    -- that window.
    local function toggleterm_border_highlights()
      vim.api.nvim_set_hl(0, "ToggleTermBorder", { fg = "#cba6f7", bold = true }) -- catppuccin mauve
    end
    vim.api.nvim_create_autocmd("ColorScheme", {
      group = vim.api.nvim_create_augroup("UserToggleTermBorder", { clear = true }),
      callback = toggleterm_border_highlights,
    })
    toggleterm_border_highlights()

    require("toggleterm").setup({

    -- size
        size = function(term)
            if term.direction == "horizontal" then
                return vim.o.lines * 0.5      -- 30% of total editor height
            elseif term.direction == "vertical" then
                return vim.o.columns * 0.5    -- 40% of total width
            else
                return 20                     -- default for float
            end
        end,
  
      open_mapping = [[<leader>t]],
      hide_numbers = true,
      shade_filetypes = {},
      shade_terminals = true,
      shading_factor = 2,
      start_in_insert = true,
      insert_mappings = false, -- only toggle from normal mode, not insert
      persist_size = true,
      direction = "horizontal",
      close_on_exit = true,
      shell = vim.o.shell,
      float_opts = {
        border = "curved",
        winblend = 0,
        highlights = {
          border = "Normal",
          background = "Normal",
        },
      },
    })

    -- Terminal settings
    function _G.set_terminal()
      local opts = { noremap = true }
      vim.api.nvim_buf_set_keymap(0, "t", "<esc>", [[<C-\><C-n>]], opts)
      vim.api.nvim_buf_set_keymap(0, "t", "<C-[>", [[<C-\><C-n>]], opts)
      vim.api.nvim_buf_set_keymap(0, "t", "<C-h>", [[<C-\><C-n><C-W>h]], opts)
      vim.api.nvim_buf_set_keymap(0, "t", "<C-j>", [[<C-\><C-n><C-W>j]], opts)
      vim.api.nvim_buf_set_keymap(0, "t", "<C-k>", [[<C-\><C-n><C-W>k]], opts)
      vim.api.nvim_buf_set_keymap(0, "t", "<C-l>", [[<C-\><C-n><C-W>l]], opts)


      vim.api.nvim_buf_set_keymap(0, "t", '<C-g>', "", {
          noremap = true,
          silent = true,
          callback = function()
              -- Exit terminal mode
              vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<C-\\><C-n>", true, false, true), 'n', true)

              -- Get terminal buffer's current working directory
              local cwd = vim.fn.getcwd()  -- or vim.fn.expand('%:p:h') if you want buffer dir

              -- Get filename under cursor
              local file = vim.fn.expand('<cword>')

              -- Combine cwd + filename and get absolute path
              local absolute_path = vim.fn.fnamemodify(cwd .. '/' .. file, ':p')

              -- Open file in current buffer
              vim.cmd('edit ' .. absolute_path)
          end,
      })

      -- enable numbers and relative numbers on this terminal buffer
      vim.api.nvim_buf_set_option(0, "number", true)
      vim.api.nvim_buf_set_option(0, "relativenumber", true)

      -- Draw the top border as a full-width rule across this window only.
      -- %{repeat()} re-evaluates on every redraw, so it tracks window resizes.
      vim.wo.winbar = "%#ToggleTermBorder#%{repeat('━', winwidth(0))}"
    end

    vim.cmd('autocmd! TermOpen term://* lua set_terminal()')
    
  end,
}

-- Yazi terminal file manager, opened as a floating window inside nvim.
-- <leader>- opens it scoped to the current file's directory (cursor lands on
-- that file); picking a different file there opens it as the current nvim
-- buffer. <A-y> reopens the same session (cwd, cursor position, selection)
-- instead of starting fresh -- handy for "hop into yazi, create a file,
-- come back" without losing your place.
local yazi = {
    "mikavilpas/yazi.nvim",
    version = "*",
    event = "VeryLazy",
    dependencies = {
        { "nvim-lua/plenary.nvim", lazy = true },
    },
    keys = {
        {
            "<leader>-",
            mode = { "n", "v" },
            "<cmd>Yazi<cr>",
            desc = "Open yazi at the current file",
        },
        {
            "<A-y>",
            "<cmd>Yazi toggle<cr>",
            desc = "Resume the last yazi session",
        },
    },
    opts = {
        open_for_directories = false,
        keymaps = {
            show_help = "<f1>",
        },
    },
}

local neo_tree = {
    "nvim-neo-tree/neo-tree.nvim",
    branch = "v3.x",
    dependencies = {"nvim-lua/plenary.nvim", "nvim-tree/nvim-web-devicons", "MunifTanjim/nui.nvim"},

    config = function()
        require("neo-tree").setup {}

        vim.keymap.set('n', '<leader>e', ':Neotree filesystem toggle left<CR>', { desc = 'Toggle file explorer' })
    end
}

local treesitter_context = {
    "nvim-treesitter/nvim-treesitter-context",
    config = function()
        require("treesitter-context").setup{
            enable = true, -- Enable this plugin (Can be enabled/disabled later via commands)
            max_lines = 0, -- How many lines the window should span. Values <= 0 mean no limit.
            trim_scope = 'outer', -- Which context lines to discard if `max_lines` is exceeded. Choices: 'inner', 'outer'
            patterns = { -- Match patterns for TS nodes. These get wrapped to match at word boundaries.
                default = {
                    'class',
                    'function',
                    'method',
                    'for',
                    'while',
                    'if',
                    'switch',
                    'case',
                },
            },
        }
    end
}

local lazygit = {
    "kdheepak/lazygit.nvim",
    lazy = true,
    cmd = {
        "LazyGit",
        "LazyGitConfig",
        "LazyGitCurrentFile",
        "LazyGitFilter",
        "LazyGitFilterCurrentFile",
    },
    -- optional for floating window border decoration
    dependencies = {
        "nvim-lua/plenary.nvim",
    },
    -- setting the keybinding for LazyGit with 'keys' is recommended in
    -- order to load the plugin when the command is run for the first time
    keys = {
        { "<leader>lg", "<cmd>LazyGit<cr>", desc = "LazyGit" }
    }
}    

local diffview = {
    "sindrets/diffview.nvim",

    config = function()
        local actions = require("diffview.actions")

        -- "X" only restores the entry under the cursor. This is the bulk
        -- version: reset every tracked file (staged and unstaged) back to HEAD.
        -- Untracked files are left alone -- add a "git clean" if you ever want
        -- those gone too. There is no undo, hence the confirm prompt.
        local function discard_all()
            local view = require("diffview.lib").get_current_view()
            if not view then return end
            if vim.fn.confirm("Discard ALL working-tree changes?", "&Yes\n&No", 2) ~= 1 then
                return
            end

            vim.system(
                { "git", "-C", view.adapter.ctx.toplevel,
                    "restore", "--source=HEAD", "--staged", "--worktree", "--", "." },
                {},
                vim.schedule_wrap(function(res)
                    if res.code ~= 0 then
                        vim.notify(res.stderr, vim.log.levels.ERROR)
                        return
                    end
                    vim.cmd("DiffviewRefresh")
                end)
            )
        end

        require("diffview").setup {
            enhanced_diff_hl = true,
            keymaps = {
                -- Toggle the file panel (sidebar) with opt+b instead of the
                -- default <leader>b, in every context that has that mapping.
                view = {
                    { "n", "<leader>b", false },
                    { "n", "<A-b>", actions.toggle_files, { desc = "Toggle the file panel" } },
                    { "n", "<leader>X", discard_all, { desc = "Discard all changes" } },
                },
                file_panel = {
                    { "n", "<leader>b", false },
                    { "n", "<A-b>", actions.toggle_files, { desc = "Toggle the file panel" } },
                    { "n", "<leader>X", discard_all, { desc = "Discard all changes" } },
                },
                file_history_panel = {
                    { "n", "<leader>b", false },
                    { "n", "<A-b>", actions.toggle_files, { desc = "Toggle the file panel" } },
                },
            },
            hooks = {
                -- Vim highlights a modified line as DiffChange/DiffText on both
                -- sides, so it reads the same colour left and right. Repaint the
                -- left pane ("a") in reds and the right pane ("b") in greens.
                diff_buf_win_enter = function(_, winid, ctx)
                    -- Diff-mode folds unchanged regions by default (e.g. "+--384
                    -- lines: ..."). Open every fold so all lines show by default.
                    vim.wo[winid].foldlevel = 99

                    if not ctx.layout_name:match("^diff2") then return end

                    if ctx.symbol == "a" then
                        vim.wo[winid].winhl = table.concat({
                            "DiffAdd:DiffviewDiffAddAsDelete",
                            "DiffDelete:DiffviewDiffDeleteDim",
                            "DiffChange:DiffviewDiffChangeAsDelete",
                            "DiffText:DiffviewDiffTextAsDelete",
                        }, ",")
                    elseif ctx.symbol == "b" then
                        vim.wo[winid].winhl = table.concat({
                            "DiffDelete:DiffviewDiffDeleteDim",
                            "DiffAdd:DiffAdd",
                            "DiffChange:DiffviewDiffChangeAsAdd",
                            "DiffText:DiffviewDiffTextAsAdd",
                        }, ",")
                    end
                end,
            },
        }
        
        -- automatically close (hide) the file panel when you open Diffview, by calling
        -- vim.keymap.set("n", "<leader>do", function()
        --     vim.cmd("DiffviewOpen")
        --     vim.cmd("DiffviewToggleFiles") -- automatically close the file panel
        -- end, { desc = "Open Diffview (no file panel)" })

        vim.keymap.set('n', '<A-d>', function()
            local ok, lib = pcall(require, "diffview.lib")
            if ok and lib.get_current_view() then
                vim.cmd("DiffviewClose")
            else
                vim.cmd("DiffviewOpen -uno")
            end
        end, { noremap = true, silent = true, desc = "Diffview Toggle" })
        -- vim.keymap.set('n', '<leader>do', ':Diffview<CR>', { noremap = true, silent = true, desc = "Diffview " })
        -- vim.keymap.set('n', '<leader>dc', ':DiffviewClose<CR>', { noremap = true, silent = true, desc = "Diffview Close" })
        -- vim.keymap.set("n", "<leader>df", ":DiffviewToggleFiles<CR>", { desc = "Toggle Diffview file panel" })
        vim.keymap.set("n", "<A-f>", function()
            local ok, lib = pcall(require, "diffview.lib")
            if ok and lib.get_current_view() then
                vim.cmd("DiffviewClose")
            else
                vim.cmd("DiffviewFileHistory %")
            end
        end, { noremap = true, silent = true, desc = "Toggle file history of current file" })

    end,
}

local visual_multi = {
    "mg979/vim-visual-multi",
    branch = "master",
    event = "VeryLazy",
    init = function()
        vim.g.VM_maps = {
            ["Add Cursor Down"] = "<D-A-j>",
            ["Add Cursor Up"] = "<D-A-k>",
        }

        -- VM_maps only accepts one key per action, and "Exit" already owns <Esc>.
        -- Add <C-c> as a second exit key by hooking the autocmd VM fires right
        -- after it sets up its buffer-local mappings, and remove it again on
        -- exit -- VM only unmaps its own buffer-local keys, not ours, so
        -- leaving this mapped after exit calls <Plug>(VM-Exit) against a
        -- buffer whose VM state has already been torn down (E716: Key not
        -- present in Dictionary: "Vars").
        local buf
        vim.api.nvim_create_autocmd("User", {
            pattern = "visual_multi_mappings",
            callback = function()
                buf = vim.api.nvim_get_current_buf()
                vim.keymap.set("n", "<C-c>", "<Plug>(VM-Exit)",
                    { buffer = buf, desc = "Exit visual-multi" })
            end,
        })
        vim.api.nvim_create_autocmd("User", {
            pattern = "visual_multi_exit",
            callback = function()
                if buf and vim.api.nvim_buf_is_valid(buf) then
                    pcall(vim.keymap.del, "n", "<C-c>", { buffer = buf })
                end
            end,
        })
    end,
}

local nvim_autopairs = {
    "windwp/nvim-autopairs",
    event = "InsertEnter",
    config = function()
        require("nvim-autopairs").setup {}
    end,
}

local devicons = {
    "nvim-tree/nvim-web-devicons",
}

local commentor =
{
    'numToStr/Comment.nvim',
    config = function()
        require('Comment').setup(
            {
                toggler = {
                    line = '<leader>/',  -- line comment toggle
                    block = '<leader>.', -- block comment toggle
                },
                opleader = {
                    line = '<leader>/',  -- visual mode line comment
                    block = '<leader>.', -- visual mode block comment
                },
            }
        )
    end
}

local bufferline = {
    "akinsho/bufferline.nvim",
    dependencies = { "nvim-tree/nvim-web-devicons" },
    config = function()
        require("bufferline").setup({
            options = {
                mode = "buffers",
                numbers = "none",
                diagnostics = "nvim_lsp",
                show_buffer_close_icons = false,
                show_close_icon = false,
                separator_style = "slant",
            },
            highlights = {
                separator = { fg = "#292c33" },
                separator_visible = { fg = "#292c33" },
                separator_selected = { fg = "#292c33" },
                buffer_selected = { bg = "#31323c", bold = true },
            },
        })
    end,
}

local render_markdown = {
    "MeanderingProgrammer/render-markdown.nvim",
    dependencies = { "nvim-treesitter/nvim-treesitter", "nvim-tree/nvim-web-devicons" },
    ft = { "markdown" },
    config = function()
        require("render-markdown").setup({})
    end,
}

local lualine = {
    "nvim-lualine/lualine.nvim",
    dependencies = { "nvim-tree/nvim-web-devicons" },
    config = function()
        require("lualine").setup({
            options = {
                theme = "catppuccin-mocha",
            },
            sections = {
                lualine_a = { "mode" },
                lualine_b = {},
                lualine_c = {},
                lualine_x = {},
                lualine_y = {},
                lualine_z = {},
            },
            inactive_sections = {
                lualine_a = {},
                lualine_b = {},
                lualine_c = {},
                lualine_x = {},
                lualine_y = {},
                lualine_z = {},
            },
        })
    end,
}

local which_key = {
    "folke/which-key.nvim",
    event = "VeryLazy",
    opts = {},
}

-- Formatting. Shells out to each filetype's standalone formatter (not the
-- LSP server) so formatting is decoupled from whichever LSP happens to be
-- attached and deterministic. Manual-only: no format_on_save, so ":w" never
-- touches the buffer -- format explicitly with <leader>cf.
local conform = {
    "stevearc/conform.nvim",
    cmd = { "ConformInfo" },
    keys = {
        {
            "<leader>cf",
            function()
                require("conform").format({ async = true, lsp_format = "fallback" })
            end,
            mode = { "n", "v" },
            desc = "Format buffer/selection",
        },
    },
    opts = {
        formatters_by_ft = {
            lua = { "stylua" },
            python = { "isort", "black" },
            c = { "clang_format" },
            cpp = { "clang_format" },
        },
    },
}

return {
    commentor,
    devicons,
    colortheme,
    lualine,
    bufferline,
    telescope,
    treesitter,
    blink_cmp,
    lspconfig,
    which_key,
    conform,
    gitsigns,
    git_fugitive,
    lazygit,
    copilot,
    toggleterm,
    yazi,
    neo_tree,
    treesitter_context,
    diffview,
    nvim_autopairs,
    visual_multi,
    render_markdown,
}
