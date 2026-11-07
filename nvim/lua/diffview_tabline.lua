local M = {}

local function current_view()
    local lib = package.loaded["diffview.lib"]
    return lib and lib.get_current_view()
end

local function files(view)
    local entries = {}
    local function add(file)
        if file.opened or file == view.cur_entry then
            entries[#entries + 1] = file
        end
    end
    if view.files then
        for _, file in view.files:iter() do
            add(file)
        end
    else
        for _, entry in ipairs(view.panel.entries) do
            for _, file in ipairs(entry.files) do add(file) end
        end
    end
    return entries
end

function M.select(index)
    local view = current_view()
    if not view then return end
    local file = files(view)[index]
    if file then view:set_file(file, true) end
end

function M.cycle(direction)
    local view = current_view()
    if not view then
        vim.cmd(direction > 0 and "BufferLineCycleNext" or "BufferLineCyclePrev")
        return
    end
    local entries = files(view)
    if #entries == 0 then return end
    local index = 1
    for i, file in ipairs(entries) do
        if file == view.cur_entry then index = i break end
    end
    M.select((index - 1 + direction) % #entries + 1)
end

function M.render()
    local view = current_view()
    if not view then return _G.nvim_bufferline() end
    local mode = view.files and "CHANGES" or "HISTORY"
    local parts = { "%#DiffviewTabBadge#   DIFFVIEW%#DiffviewTabMode# · " .. mode .. "  %#BufferLineFill# %<" }
    local icons = require("nvim-web-devicons")
    for i, file in ipairs(files(view)) do
        local active = file == view.cur_entry
        local highlight = active and "BufferLineBufferSelected" or "BufferLineBuffer"
        local name = vim.fs.basename(file.path)
        local icon = icons.get_icon(name, vim.fn.fnamemodify(name, ":e"), { default = true })
        local label = (icon .. " " .. name):gsub("%%", "%%%%")
        if i > 1 then parts[#parts + 1] = "%#DiffviewTabSeparator#│" end
        parts[#parts + 1] = ("%%%d@v:lua.DiffviewTabClick@%%#%s#  %s  %%T")
            :format(i, highlight, label)
    end
    parts[#parts + 1] = "%#BufferLineFill#%="
    return table.concat(parts)
end

local function highlights()
    local fill = vim.api.nvim_get_hl(0, { name = "BufferLineFill", link = false })
    local colors = require("catppuccin.palettes").get_palette("mocha")
    local comment = vim.api.nvim_get_hl(0, { name = "Comment", link = false })
    vim.api.nvim_set_hl(0, "DiffviewTabBadge", { fg = colors.lavender, bg = colors.surface0, bold = true })
    vim.api.nvim_set_hl(0, "DiffviewTabMode", { fg = colors.subtext0, bg = colors.surface0 })
    vim.api.nvim_set_hl(0, "DiffviewTabSeparator", { fg = comment.fg, bg = fill.bg })
end

function M.setup()
    highlights()
    vim.api.nvim_create_autocmd("ColorScheme", {
        group = vim.api.nvim_create_augroup("DiffviewTabline", { clear = true }),
        callback = function() vim.schedule(highlights) end,
    })
    _G.DiffviewTabClick = function(index, _, button)
        if button == "l" then M.select(index) end
    end
    _G.DotfilesTabline = M.render
    vim.o.tabline = "%!v:lua.DotfilesTabline()"
end

return M
