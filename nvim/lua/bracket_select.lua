-- Bracket Select: like the VSCode extension of the same name. <A-a> selects
-- the contents of the nearest enclosing (), {}, [], <>, "" or '' pair around
-- the cursor; pressing it again cycles content -> content+brackets -> the
-- next enclosing pair's content -> its content+brackets -> and so on.
local M = {}

local function pos(row, col) return { row = row, col = col } end
local function pos_lt(a, b) return a.row < b.row or (a.row == b.row and a.col < b.col) end
local function pos_le(a, b) return pos_lt(a, b) or (a.row == b.row and a.col == b.col) end
local function span_size(span) return (span['end'].row - span.start.row) * 1e6 + (span['end'].col - span.start.col) end

-- '[' (and, for symmetry, ']') are regex-special in Vim's default 'magic'
-- search patterns and need escaping; '(', ')', '{', '}' are literal there.
local function pattern(char) return (char == '[' or char == ']') and ('\\' .. char) or char end

-- Position right after (row, col), stepping onto the next line when (row,
-- col) is that line's last character -- e.g. an opening brace at the end of
-- a function header, whose contents start on the following line.
local function next_pos(row, col)
  local line = vim.api.nvim_buf_get_lines(0, row, row + 1, true)[1]
  if col < #line - 1 then return pos(row, col + 1) end
  if row + 1 >= vim.api.nvim_buf_line_count(0) then return pos(row, math.max(#line - 1, 0)) end
  return pos(row + 1, 0)
end

-- Position right before (row, col), stepping onto the end of the previous
-- line when (row, col) is that line's first column -- e.g. a closing brace
-- alone on its own line, whose contents end on the line above.
local function prev_pos(row, col)
  if col > 0 then return pos(row, col - 1) end
  if row == 0 then return pos(0, 0) end
  local prev_line = vim.api.nvim_buf_get_lines(0, row - 1, row, true)[1]
  return pos(row - 1, math.max(#prev_line - 1, 0))
end

-- Find the (), {} or [] pair enclosing (row, col), returning the raw
-- searchpairpos-style {line, col} (1-indexed) for the open and close bracket,
-- or {0, 0} when not found. Handles the cursor sitting exactly on the open
-- or closing bracket itself, which plain "bcnW"/"cnW" from that position
-- can't do: searchpairpos then sees the bracket under the cursor as an
-- extra, unmatched nesting level in the direction it searches, and fails.
local function find_pair(open, close, row, col)
  local open_pat, close_pat = pattern(open), pattern(close)
  local line = vim.api.nvim_buf_get_lines(0, row, row + 1, true)[1]
  local char = line:sub(col + 1, col + 1)

  if char == open then
    vim.api.nvim_win_set_cursor(0, { row + 1, col })
    return { row + 1, col + 1 }, vim.fn.searchpairpos(open_pat, '', close_pat, 'nW')
  elseif char == close then
    vim.api.nvim_win_set_cursor(0, { row + 1, col })
    return vim.fn.searchpairpos(open_pat, '', close_pat, 'bnW'), { row + 1, col + 1 }
  end

  vim.api.nvim_win_set_cursor(0, { row + 1, col })
  local s = vim.fn.searchpairpos(open_pat, '', close_pat, 'bcnW')
  local e = vim.fn.searchpairpos(open_pat, '', close_pat, 'cnW')
  return s, e
end

-- Every (), {} or [] pair enclosing (row, col), innermost first, as far out
-- as the nesting goes -- so expanding a selection can walk outward one level
-- at a time.
local function bracket_spans(open, close, row, col)
  local spans, r, c = {}, row, col
  while true do
    local s, e = find_pair(open, close, r, c)
    if s[1] == 0 or e[1] == 0 then break end

    local outer_start, outer_end = pos(s[1] - 1, s[2] - 1), pos(e[1] - 1, e[2] - 1)
    local inner_start = next_pos(outer_start.row, outer_start.col)
    local inner_end = prev_pos(outer_end.row, outer_end.col)
    if pos_le(inner_start, inner_end) then -- skip empty pairs, e.g. "()"
      table.insert(spans, { start = inner_start, ['end'] = inner_end, outer_start = outer_start, outer_end = outer_end })
    end

    if outer_start.col == 0 then break end
    r, c = outer_start.row, outer_start.col - 1
  end
  return spans
end

-- Quotes don't nest and open == close, so searchpairpos can't track them.
-- Pair up unescaped quote chars left to right on the cursor's line and
-- return whichever pair encloses the cursor column.
local function quote_span(quote, row, col)
  local line = vim.api.nvim_buf_get_lines(0, row, row + 1, true)[1]
  local cols, i = {}, 1
  while i <= #line do
    local c = line:sub(i, i)
    if c == '\\' then
      i = i + 2
    else
      if c == quote then table.insert(cols, i - 1) end -- 0-indexed
      i = i + 1
    end
  end

  for k = 1, #cols - 1, 2 do
    local ocol, ccol = cols[k], cols[k + 1]
    if ocol <= col and col <= ccol then
      local inner_start, inner_end = pos(row, ocol + 1), pos(row, ccol - 1)
      if not pos_le(inner_start, inner_end) then return nil end -- empty pair, e.g. ""
      return { start = inner_start, ['end'] = inner_end, outer_start = pos(row, ocol), outer_end = pos(row, ccol) }
    end
  end
  return nil
end

local BRACKETS = { { '(', ')' }, { '{', '}' }, { '[', ']' }, { '<', '>' } }
local QUOTES = { '"', "'" }

local function candidate_spans(row, col)
  local spans = {}
  for _, b in ipairs(BRACKETS) do
    for _, span in ipairs(bracket_spans(b[1], b[2], row, col)) do table.insert(spans, span) end
  end
  for _, q in ipairs(QUOTES) do
    local span = quote_span(q, row, col)
    if span then table.insert(spans, span) end
  end
  return spans
end

function M.select()
  local mode = vim.fn.mode()
  local expanding = mode == 'v' or mode == 'V' or mode == '\22'

  local ref_start, ref_end, cursor_row, cursor_col
  if expanding then
    -- Leave visual mode so '< / '> reflect the selection just active (same
    -- trick as wrap_selection() in keymaps.lua), then grow from it.
    vim.cmd('normal! \27')
    local sr, sc = unpack(vim.api.nvim_buf_get_mark(0, '<'))
    local er, ec = unpack(vim.api.nvim_buf_get_mark(0, '>'))
    ref_start, ref_end = pos(sr - 1, sc), pos(er - 1, ec)
    cursor_row, cursor_col = ref_start.row, ref_start.col
  else
    local r, c = unpack(vim.api.nvim_win_get_cursor(0))
    cursor_row, cursor_col = r - 1, c
    ref_start, ref_end = pos(cursor_row, cursor_col), pos(cursor_row, cursor_col)
  end

  local best
  local enclosing = candidate_spans(cursor_row, cursor_col)

  if not expanding then
    -- First press: pick the smallest pair whose bracket/quote chars (not
    -- just its inner content) enclose the cursor, so landing on a bracket
    -- itself already selects that pair's contents. Only the inner span is
    -- offered here -- expansion (below) is what reaches the outer one.
    for _, p in ipairs(enclosing) do
      if pos_le(p.outer_start, ref_start) and pos_le(ref_end, p.outer_end) then
        local span = { start = p.start, ['end'] = p['end'] }
        if not best or span_size(span) < span_size(best) then best = span end
      end
    end
  else
    -- Later presses: cycle inner -> outer (adds the brackets/quotes
    -- themselves) -> next level's inner -> its outer -> ... by picking, out
    -- of every level's inner *and* outer span, the smallest one that
    -- strictly contains the previous selection.
    for _, p in ipairs(enclosing) do
      for _, span in ipairs({ { start = p.start, ['end'] = p['end'] }, { start = p.outer_start, ['end'] = p.outer_end } }) do
        local strictly_bigger = pos_le(span.start, ref_start) and pos_le(ref_end, span['end'])
          and not (span.start.row == ref_start.row and span.start.col == ref_start.col
            and span['end'].row == ref_end.row and span['end'].col == ref_end.col)
        if strictly_bigger and (not best or span_size(span) < span_size(best)) then
          best = span
        end
      end
    end
  end

  if not best then
    if expanding then vim.cmd('normal! gv') end -- nothing bigger; keep what we had
    return
  end

  vim.api.nvim_win_set_cursor(0, { best.start.row + 1, best.start.col })
  vim.cmd('normal! v')
  vim.api.nvim_win_set_cursor(0, { best['end'].row + 1, best['end'].col })
end

return M
