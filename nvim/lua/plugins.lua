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

                -- Auto-adapt: side-by-side on wide terminals, stacked on narrow ones
                layout_strategy = "flex",
                layout_config = {
                    -- Use nearly the whole screen, VSCode-quick-open style
                    width = 0.95,
                    height = 0.90,
                    flex = {
                        flip_columns = 130, -- switch to vertical layout below 130 columns
                    },
                    -- preview_cutoff = 0 works around the preview not showing:
                    -- https://github.com/nvim-telescope/telescope.nvim/issues/1594#issuecomment-993447528
                    horizontal = { preview_cutoff = 0, preview_width = 0.3 },
                    vertical = { preview_cutoff = 0, preview_height = 0.3},
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

        -- File & text search
        vim.keymap.set("n", "<C-p>f", builtin.find_files, { desc = "Find files" })
        vim.keymap.set("n", "<C-p>s", builtin.live_grep, { desc = "Search text across project" })
        vim.keymap.set("n", "<C-p>w", builtin.grep_string, { desc = "Search word under cursor" })
        vim.keymap.set("n", "<C-p>b", builtin.buffers, { desc = "List open buffers" })
        vim.keymap.set("n", "<C-p>r", builtin.resume, { desc = "Resume last Telescope picker" })
        vim.keymap.set("n", "<C-p>h", builtin.command_history, { desc = "Command history" })

        -- Telescope LSP symbols
        vim.keymap.set("n", "<C-s>s", builtin.lsp_document_symbols, { desc = "Document symbols" })
        vim.keymap.set("n", "<C-s>w", builtin.lsp_workspace_symbols, { desc = "Workspace symbols" })

        -- Git pickers
        vim.keymap.set("n", "<C-p>gc", builtin.git_commits, { desc = "Git commits" })
        vim.keymap.set("n", "<C-p>gs", builtin.git_status, { desc = "Git status" })
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
            ensure_installed = { "lua", "vim", "vimdoc", "python", "c", "cpp" },
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
            },
        })
    end
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

    -- LSP client config
    {
        "neovim/nvim-lspconfig",
        lazy = false,
        config = function()
            local servers = { "lua_ls", "pyright", "clangd" }
            for _, lsp in ipairs(servers) do
                if vim.lsp.config[lsp] then
                    vim.lsp.enable(lsp)
                else
                    vim.notify(lsp .. " config not found", vim.log.levels.ERROR)
                end
            end

            -- Hover documentation
            vim.keymap.set("n", "K", vim.lsp.buf.hover, {})
            
            -- Go to definition, declaration, implementation, type definition
            -- (routed through Telescope for a multi-result picker + quickfix workflow)
            vim.keymap.set("n", "<leader>gd", function() require("telescope.builtin").lsp_definitions() end, opts)
            vim.keymap.set("n", "<leader>gD", vim.lsp.buf.declaration, opts)
            vim.keymap.set("n", "<leader>gi", function() require("telescope.builtin").lsp_implementations() end, opts)
            vim.keymap.set("n", "<leader>gt", function() require("telescope.builtin").lsp_type_definitions() end, opts)

            -- Find references
            vim.keymap.set("n", "<leader>gr", function() require("telescope.builtin").lsp_references() end, opts)

            -- Code actions
            vim.keymap.set("n", "<leader>ca", vim.lsp.buf.code_action, opts)
            vim.keymap.set("n", "<leader>rn", vim.lsp.buf.rename, opts)
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

        vim.keymap.set("n", "<leader>gp", ":Gitsigns preview_hunk<CR>")
        vim.keymap.set("n", "<leader>gb", ":Gitsigns toggle_current_line_blame<CR>")
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
  
      open_mapping = [[<C-t>]],
      hide_numbers = true,
      shade_filetypes = {},
      shade_terminals = true,
      shading_factor = 2,
      start_in_insert = true,
      insert_mappings = true,
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
    end

    vim.cmd('autocmd! TermOpen term://* lua set_terminal()')
    
  end,
}

local multicursor = {
    "jake-stewart/multicursor.nvim",
    branch = "1.0",
    config = function()
        local mc = require("multicursor-nvim")
        mc.setup()

        local set = vim.keymap.set

        -- Add or skip cursor above/below the main cursor.
        set({"n", "x"}, "<leader>k", function()
            mc.lineAddCursor(-1)
        end)
        set({"n", "x"}, "<leader>j", function()
            mc.lineAddCursor(1)
        end)

        -- Add or skip adding a new cursor by matching word/selection
        set({"n", "x"}, "<leader>n", function() mc.matchAddCursor(1) end)
        set({"n", "x"}, "<leader>s", function() mc.matchSkipCursor(1) end)
        set({"n", "x"}, "<leader>N", function() mc.matchAddCursor(-1) end)
        set({"n", "x"}, "<leader>S", function() mc.matchSkipCursor(-1) end)
        
        -- Mappings defined in a keymap layer only apply when there are
        -- multiple cursors. This lets you have overlapping mappings.
        mc.addKeymapLayer(function(layerSet)
            layerSet("n", "j", function()
                mc.lineAddCursor(1)
            end)
            layerSet("n", "k", function()
                mc.lineAddCursor(-1)
            end)
            
            -- Enable and clear cursors using escape.
            layerSet("n", "<C-c>", function()
                if not mc.cursorsEnabled() then
                    mc.enableCursors()
                else
                    mc.clearCursors()
                end
            end)
            layerSet("n", "<esc>", function()
                if not mc.cursorsEnabled() then
                    mc.enableCursors()
                else
                    mc.clearCursors()
                end
            end)

        end)

    end
}

local neo_tree = {
    "nvim-neo-tree/neo-tree.nvim",
    branch = "v3.x",
    dependencies = {"nvim-lua/plenary.nvim", "nvim-tree/nvim-web-devicons", "MunifTanjim/nui.nvim"},

    config = function()
        require("neo-tree").setup {}

        vim.keymap.set('n', '<leader>e', ':Neotree filesystem toggle left<CR>')
    end
}

local tmux_navigator = {
  "christoomey/vim-tmux-navigator",
  cmd = {
    "TmuxNavigateLeft",
    "TmuxNavigateDown",
    "TmuxNavigateUp",
    "TmuxNavigateRight",
    "TmuxNavigatePrevious",
    "TmuxNavigatorProcessList",
  },
  keys = {
    { "<c-h>", "<cmd>TmuxNavigateLeft<cr>" },
    { "<c-j>", "<cmd>TmuxNavigateDown<cr>" },
    { "<c-k>", "<cmd>TmuxNavigateUp<cr>" },
    { "<c-l>", "<cmd>TmuxNavigateRight<cr>" },
    { "<c-p>", "<cmd>TmuxNavigatePrevious<cr>" },
  },
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
        require("diffview").setup {
            enhanced_diff_hl = true,
            hooks = {
                -- Vim highlights a modified line as DiffChange/DiffText on both
                -- sides, so it reads the same colour left and right. Repaint the
                -- left pane ("a") in reds and the right pane ("b") in greens.
                diff_buf_win_enter = function(_, winid, ctx)
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

        vim.keymap.set('n', '<A-d>', ':DiffviewOpen -uno<CR>', { noremap = true, silent = true, desc = "Diffview Open" })
        -- vim.keymap.set('n', '<leader>do', ':Diffview<CR>', { noremap = true, silent = true, desc = "Diffview " })
        -- vim.keymap.set('n', '<leader>dc', ':DiffviewClose<CR>', { noremap = true, silent = true, desc = "Diffview Close" })
        -- vim.keymap.set("n", "<leader>df", ":DiffviewToggleFiles<CR>", { desc = "Toggle Diffview file panel" })
        vim.keymap.set("n", "<A-f>", ":DiffviewFileHistory %<CR>", { desc = "View file history of current file" })

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

return {
    commentor,
    devicons,
    colortheme,
    lualine,
    bufferline,
    telescope,
    treesitter,
    lspconfig,
    gitsigns,
    git_fugitive,
    lazygit,
    copilot,
    toggleterm,
    multicursor,
    neo_tree,
    tmux_navigator,
    treesitter_context,
    diffview,
    nvim_autopairs,
}
