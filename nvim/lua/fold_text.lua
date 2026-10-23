-- How a closed fold looks: the fold's first line kept exactly as it reads in
-- the buffer (indent + treesitter colors), then the closing bracket and how
-- many lines are hidden, e.g.
--     void DFPExecutor::start_hw_monitor() { ⋯ }   14 lines
-- The default foldtext ("+-- 14 lines: void ...----") drops both the indent
-- and the colors, so a folded function no longer looks like code.
local M = {}

-- Split `line` (row `lnum`, 1-indexed) into { text, hl_group } chunks using
-- the buffer's treesitter highlight captures. Falls back to one plain chunk
-- when the buffer has no parser or highlight query.
local function highlighted_chunks(lnum, line)
  local ok, parser = pcall(vim.treesitter.get_parser, 0)
  if not ok or not parser then return { { line, 'Folded' } } end
  local query = vim.treesitter.query.get(parser:lang(), 'highlights')
  local tree = parser:trees()[1]
  if not query or not tree then return { { line, 'Folded' } } end

  -- Later captures are more specific, so letting them overwrite per column
  -- matches what the highlighter itself draws.
  local row, hl_at = lnum - 1, {}
  for id, node in query:iter_captures(tree:root(), 0, row, row + 1) do
    local name = query.captures[id]
    if not name:find('^_') and name ~= 'spell' and name ~= 'nospell' then
      local sr, sc, er, ec = node:range()
      if sr < row then sc = 0 end
      if er > row then ec = #line end
      for col = sc, ec - 1 do hl_at[col] = '@' .. name .. '.' .. parser:lang() end
    end
  end

  -- Merge runs of bytes with the same group into one chunk.
  local chunks = {}
  for col = 0, #line - 1 do
    local hl, prev = hl_at[col] or 'Folded', chunks[#chunks]
    if prev and prev[2] == hl then
      prev[1] = prev[1] .. line:sub(col + 1, col + 1)
    else
      table.insert(chunks, { line:sub(col + 1, col + 1), hl })
    end
  end
  return chunks
end

function M.render()
  local first, last = vim.v.foldstart, vim.v.foldend
  local chunks = highlighted_chunks(first, vim.fn.getline(first))
  -- Tabs aren't expanded in a chunk list. Expand them only after colouring,
  -- since treesitter's columns count each tab as one byte.
  for _, chunk in ipairs(chunks) do
    chunk[1] = chunk[1]:gsub('\t', string.rep(' ', vim.bo.tabstop))
  end

  table.insert(chunks, { ' ⋯ ', 'Comment' })
  -- Show the block's closing bracket ("}", "});", "]") so the fold reads as
  -- a whole block; skip it when the last line is real code.
  local closing = vim.trim(vim.fn.getline(last))
  if closing:match('^[%)%]}]+[;,]?$') then
    table.insert(chunks, { closing, 'Delimiter' })
  end
  table.insert(chunks, { '   ' .. (last - first + 1) .. ' lines', 'Comment' })
  return chunks
end

return M
