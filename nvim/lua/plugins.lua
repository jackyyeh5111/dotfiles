-- colorthem etheme config
local colortheme = {
    "catppuccin/nvim",
    name = "catppuccin",
    lazy = false,
    priority = 1000,
    config = function()
        require("catppuccin").setup()
        vim.cmd.colorscheme("catppuccin")
    end
}

-- Telescope config
local telescope = {
    "nvim-telescope/telescope.nvim",
    dependencies = {"nvim-lua/plenary.nvim"},
    config = function()
        require("telescope").setup {
            defaults = {
                mappings = {
                    i = {
                        ["<C-j>"] = require("telescope.actions").move_selection_next,
                        ["<C-k>"] = require("telescope.actions").move_selection_previous
                    }
                },

                -- this solve my preview no show issue
                -- https://github.com/nvim-telescope/telescope.nvim/issues/1594#issuecomment-993447528
                layout_config = {
                    horizontal = {
                        preview_cutoff = 0
                    }
                }
            }
        }
        local builtin = require("telescope.builtin")
        vim.keymap.set("n", "<leader>p", builtin.find_files)
        vim.keymap.set("n", "<leader>r", builtin.live_grep)
        vim.keymap.set("n", "<leader>b", builtin.buffers)
        vim.keymap.set('n', '<leader>h', builtin.command_history)

    end
}

-- Treesitter config
local treesitter = {
    "nvim-treesitter/nvim-treesitter",
    build = ":TSUpdate"
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
            local cfg = vim.lsp.config["lua_ls"]
            if cfg then
                vim.lsp.start(cfg)
            else
                vim.notify("lua_ls config not found", vim.log.levels.ERROR)
            end

            -- Hover documentation
            vim.keymap.set("n", "K", vim.lsp.buf.hover, {})
            
            -- Go to definition, declaration, implementation, type definition
            vim.keymap.set("n", "<leader>gd", vim.lsp.buf.definition, opts)
            vim.keymap.set("n", "<leader>gD", vim.lsp.buf.declaration, opts)
            vim.keymap.set("n", "<leader>gi", vim.lsp.buf.implementation, opts)
            vim.keymap.set("n", "<leader>gt", vim.lsp.buf.type_definition, opts)

            -- Find references
            vim.keymap.set("n", "<leader>gr", vim.lsp.buf.references, opts)

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
            return vim.o.lines * 0.3      -- 30% of total editor height
            elseif term.direction == "vertical" then
            return vim.o.columns * 0.4    -- 40% of total width
            else
            return 20                     -- default for float
            end
        end,
  
      open_mapping = [[<S-t>]],
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
      vim.api.nvim_buf_set_keymap(0, "t", "jk", [[<C-\><C-n>]], opts)
      vim.api.nvim_buf_set_keymap(0, "t", "<C-h>", [[<C-\><C-n><C-W>h]], opts)
      vim.api.nvim_buf_set_keymap(0, "t", "<C-j>", [[<C-\><C-n><C-W>j]], opts)
      vim.api.nvim_buf_set_keymap(0, "t", "<C-k>", [[<C-\><C-n><C-W>k]], opts)
      vim.api.nvim_buf_set_keymap(0, "t", "<C-l>", [[<C-\><C-n><C-W>l]], opts)

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

    size = function(term)
            if term.direction == "horizontal" then
                return vim.o.lines * 0.3      -- 30% of total editor height
            elseif term.direction == "vertical" then
                return vim.o.columns * 0.4    -- 40% of total width
            else
                return 20                     -- default for float
            end
        end,
        
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
    { "<c-h>", "<cmd><C-U>TmuxNavigateLeft<cr>" },
    { "<c-j>", "<cmd><C-U>TmuxNavigateDown<cr>" },
    { "<c-k>", "<cmd><C-U>TmuxNavigateUp<cr>" },
    { "<c-l>", "<cmd><C-U>TmuxNavigateRight<cr>" },
    { "<c-\\>", "<cmd><C-U>TmuxNavigatePrevious<cr>" },
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
        require("diffview").setup {}
        
        -- automatically close (hide) the file panel when you open Diffview, by calling
        vim.keymap.set("n", "<leader>do", function()
            vim.cmd("DiffviewOpen")
            vim.cmd("DiffviewToggleFiles") -- automatically close the file panel
        end, { desc = "Open Diffview (no file panel)" })

        vim.keymap.set('n', '<leader>dc', ':DiffviewClose<CR>', { noremap = true, silent = true, desc = "Diffview Close" })
        vim.keymap.set("n", "<leader>df", ":DiffviewToggleFiles<CR>", { desc = "Toggle Diffview file panel" })
        vim.keymap.set("n", "<leader>dh", ":DiffviewFileHistory %<CR>", { desc = "View file history of current file" })

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

return {
    commentor,
    devicons,
    colortheme,
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
