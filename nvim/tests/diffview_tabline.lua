local function check()
  local root = vim.fn.stdpath('data') .. '/lazy/'
  for _, plugin in ipairs({'diffview.nvim', 'plenary.nvim', 'bufferline.nvim', 'nvim-web-devicons', 'catppuccin'}) do
    vim.opt.rtp:prepend(root .. plugin)
  end
  vim.opt.rtp:prepend(vim.fn.fnamemodify(debug.getinfo(1, 'S').source:sub(2), ':p:h:h'))
  require('bufferline').setup({})
  local opened = 0
  for _, plugin in ipairs(require('plugins')) do
    if plugin[1] == 'sindrets/diffview.nvim' then plugin.config() end
  end
  vim.cmd('runtime plugin/diffview.lua')
  local bar = require('diffview_tabline')
  bar.setup()
  local repo = vim.fn.tempname()
  vim.fn.mkdir(repo .. '/src', 'p')
  local function git(args)
    local command = {'git', '-C', repo}
    vim.list_extend(command, args)
    local out = vim.fn.system(command)
    assert(vim.v.shell_error == 0, out)
  end
  git({'init', '-q'})
  vim.fn.writefile({'before'}, repo .. '/src/one.txt')
  vim.fn.writefile({'before'}, repo .. '/src/two.txt')
  git({'add', '.'})
  git({'-c', 'user.name=Test', '-c', 'user.email=test@example.com', 'commit', '-qm', 'before'})
  vim.fn.writefile({'after'}, repo .. '/src/one.txt')
  vim.fn.writefile({'after'}, repo .. '/src/two.txt')
  git({'add', '.'})
  git({'-c', 'user.name=Test', '-c', 'user.email=test@example.com', 'commit', '-qm', 'after'})
  vim.cmd.cd(repo)
  vim.fn.writefile({'latest'}, repo .. '/src/one.txt')
  vim.fn.writefile({'latest'}, repo .. '/src/two.txt')
  git({'add', '.'})
  git({'-c', 'user.name=Test', '-c', 'user.email=test@example.com', 'commit', '-qm', 'latest'})
  local normal_tab = vim.api.nvim_get_current_tabpage()
  vim.cmd('DiffviewFileHistory --max-count=2')
  local lib = require('diffview.lib')
  assert(vim.wait(10000, function()
    local v = lib.get_current_view()
    return v and v.cur_entry and v.cur_entry.opened
  end), 'history failed to load')
  local rendered = bar.render()
  assert(rendered:find('one.txt', 1, true), 'opened file is missing')
  assert(not rendered:find('two.txt', 1, true), 'unopened file leaked into bar')
  assert(not rendered:find('No Name', 1, true), 'normal buffer leaked into history')
  local evaluated = vim.api.nvim_eval_statusline(rendered, {use_tabline = true, maxwidth = 120})
  assert(evaluated.str:find('DIFFVIEW · HISTORY', 1, true), evaluated.str)
  assert(not evaluated.str:find('src/', 1, true), 'bar shows paths instead of filenames')
  lib.get_current_view().emitter:on('file_open_post', function() opened = opened + 1 end)
  local view = lib.get_current_view()
  local before = opened
  bar.cycle(1)
  assert(view.cur_entry.path == 'src/one.txt', 'cycling opened an unvisited file')
  assert(vim.wait(5000, function() return opened > before end), 'cycle did not finish')
  before = opened
  view:set_file(view.panel.entries[1].files[2], true)
  assert(vim.wait(5000, function() return opened > before end), 'second file did not finish opening')
  rendered = bar.render()
  assert(rendered:find('one.txt', 1, true) and rendered:find('two.txt', 1, true), 'opened files did not stay in bar')
  before = opened
  bar.cycle(-1)
  assert(vim.wait(5000, function() return opened > before and view.cur_entry.path == 'src/one.txt' end), 'cycle did not return to first opened diff')
  before = opened
  _G.DiffviewTabClick(2, 1, 'l')
  assert(vim.wait(5000, function() return opened > before and view.cur_entry.path == 'src/two.txt' end), 'click did not select second opened diff')
  before = opened
  view:set_file(view.panel.entries[2].files[1], true)
  assert(vim.wait(5000, function() return opened > before end), 'older revision did not open')
  before = opened
  _G.DiffviewTabClick(1, 1, 'l')
  assert(vim.wait(5000, function() return opened > before and view.cur_entry == view.panel.entries[1].files[1] end), 'tab switched to wrong commit')
  before = opened
  _G.DiffviewTabClick(3, 1, 'l')
  assert(vim.wait(5000, function() return opened > before and view.cur_entry == view.panel.entries[2].files[1] end), 'older revision disappeared from tabs')

  -- Closing history used to lose the visited files and selected revision.
  local toggle_history = vim.fn.maparg('<A-F>', 'n', false, true).callback
  local selected = view.cur_entry
  local history_bar = bar.render()
  local tab_count = #vim.api.nvim_list_tabpages()
  toggle_history()
  assert(vim.api.nvim_get_current_tabpage() == normal_tab, 'toggle did not return to normal editing')
  assert(bar.render() == _G.nvim_bufferline(), 'history tabs leaked into normal editing')
  before = opened
  toggle_history()
  assert(vim.wait(5000, function() return opened > before end), 'restored history did not finish opening')
  assert(lib.get_current_view() == view, 'toggle recreated history instead of restoring it')
  assert(view.cur_entry == selected, 'toggle lost the selected commit and file')
  assert(view.panel.entries[1].files[1].opened and view.panel.entries[1].files[2].opened,
    'toggle lost previously opened files')
  assert(not view.panel.entries[2].files[2].opened, 'toggle opened an unvisited file')
  assert(bar.render() == history_bar, 'toggle lost an opened revision from the tabs')
  toggle_history()
  before = opened
  toggle_history()
  assert(vim.wait(5000, function() return opened > before end), 'second toggle did not finish opening')
  assert(#vim.api.nvim_list_tabpages() == tab_count, 'repeated toggles created duplicate history tabs')
  vim.cmd('DiffviewClose')
  assert(bar.render() == _G.nvim_bufferline(), 'normal buffer bar did not return')

  -- An explicitly closed history must not leave a dead toggle target.
  toggle_history()
  assert(vim.wait(10000, function()
    local v = lib.get_current_view()
    return v and v.cur_entry and v.cur_entry.opened
  end), 'toggle could not open history after an explicit close')
  assert(lib.get_current_view() ~= view, 'explicitly closed history was reused')
  vim.cmd('DiffviewClose')
  vim.fn.writefile({'uncommitted'}, repo .. '/src/two.txt')
  vim.cmd('DiffviewOpen')
  assert(vim.wait(10000, function()
    local v = lib.get_current_view()
    return v and v.cur_entry and v.cur_entry.opened
  end), 'working diff failed to load')
  assert(bar.render():find('two.txt', 1, true), 'working diff missing from bar')
  assert(not bar.render():find('one.txt', 1, true), 'previous history session leaked into working diff')
  vim.cmd('DiffviewClose')

  -- Every shortcut must keep its own opened files instead of recreating a view.
  vim.fn.writefile({'uncommitted'}, repo .. '/src/one.txt')
  local cases = {
    {key = '<A-d>', file = 'one.txt', left = 'latest'},
    {key = '<A-D>', file = 'one.txt', left = 'after'},
    {key = '<A-f>', file = 'one.txt'},
    {key = '<A-f>', file = 'two.txt'},
  }
  local function wait_for_view()
    assert(vim.wait(10000, function()
      local v = lib.get_current_view()
      return v and v.cur_entry and v.cur_entry.opened
    end), 'toggled view failed to load')
    return lib.get_current_view()
  end
  for _, case in ipairs(cases) do
    vim.cmd.edit(repo .. '/src/' .. case.file)
    case.toggle = vim.fn.maparg(case.key, 'n', false, true).callback
    case.toggle()
    local v = wait_for_view()
    if case.left then
      local buf = v.cur_entry.layout.a.file.bufnr
      assert(vim.api.nvim_buf_get_lines(buf, 0, 1, false)[1] == case.left,
        case.key .. ' opened the wrong base revision')
    else
      assert(v.cur_entry.path == 'src/' .. case.file, 'file history opened the wrong file')
    end
    local target = v.files and v.panel:ordered_file_list()[2] or v.panel.entries[2].files[1]
    local completed = 0
    v.emitter:on('file_open_post', function() completed = completed + 1 end)
    v:set_file(target, true)
    assert(vim.wait(5000, function() return completed > 0 end), 'second diff did not open')
    case.view, case.selected, case.bar = v, target, bar.render()
    case.toggle()
    assert(vim.api.nvim_get_current_tabpage() == normal_tab, case.key .. ' did not return to normal editing')
    assert(vim.api.nvim_tabpage_is_valid(v.tabpage), case.key .. ' destroyed its view')
    assert(bar.render() == _G.nvim_bufferline(), case.key .. ' left diff tabs in normal editing')
  end

  -- Switching modes or current files must not overwrite another saved session.
  local saved_tab_count = #vim.api.nvim_list_tabpages()
  for _, case in ipairs(cases) do
    vim.cmd.edit(repo .. '/src/' .. case.file)
    case.toggle()
    local v = wait_for_view()
    assert(v == case.view, case.key .. ' restored the wrong session')
    assert(v.cur_entry == case.selected, case.key .. ' lost the selected diff')
    assert(bar.render() == case.bar, case.key .. ' lost previously opened files')
    case.toggle()
  end
  assert(#vim.api.nvim_list_tabpages() == saved_tab_count, 'toggles created duplicate tabs')

  -- Leaving through a different shortcut must not replace its saved view.
  vim.cmd.edit(repo .. '/src/one.txt')
  cases[1].toggle()
  wait_for_view()
  cases[3].toggle()
  assert(vim.api.nvim_get_current_tabpage() == normal_tab, 'different shortcut did not leave Diffview')
  cases[3].toggle()
  assert(wait_for_view() == cases[3].view, 'leaving working changes overwrote file history')
  cases[3].toggle()

  -- Explicitly closing a saved view must allow that shortcut to open it again.
  for _, case in ipairs(cases) do
    vim.cmd.edit(repo .. '/src/' .. case.file)
    case.toggle()
    wait_for_view()
    vim.cmd('DiffviewClose')
    vim.api.nvim_set_current_tabpage(normal_tab)
    case.toggle()
    assert(wait_for_view() ~= case.view, case.key .. ' reused an explicitly closed view')
    vim.cmd('DiffviewClose')
    vim.api.nvim_set_current_tabpage(normal_tab)
  end
  vim.fn.delete(repo, 'rf')
  print('PASS: tabline, all Diffview toggles preserve opened files and selected revisions, separate modes and file histories, reopening closed views')
end
local ok, err = xpcall(check, debug.traceback)
if not ok then print(err); vim.cmd('cquit 1') end
vim.cmd('qa!')
