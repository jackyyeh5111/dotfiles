local M = {}

-- Space (or any leader that isn't Ctrl/Alt/Shift) can't be "held" the way a
-- real modifier can: terminals only combine an actual modifier bit with a
-- key into one chord, so holding Ctrl and tapping j resends "<C-j>" on every
-- tap, but holding Space just repeats Space -- there's no "<leader>+j held"
-- chord to send. This fakes the same practical effect in software: run
-- `action` once, then keep re-running it for every further bare press of
-- `trigger`, until a different key arrives -- which is fed back so it runs
-- normally instead of being swallowed.
--
-- Usage: vim.keymap.set("n", "<leader>j", utils.sticky("j", my_action))
function M.sticky(trigger, action)
  return function()
    action()
    while true do
      local ok, ch = pcall(vim.fn.getcharstr)
      if not ok or ch == "" then
        return
      end
      if ch == trigger then
        action()
      else
        vim.api.nvim_feedkeys(ch, "n", false)
        return
      end
    end
  end
end

return M
