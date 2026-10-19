local M = {}
local api = vim.api
local namespace = api.nvim_create_namespace("lbs_chinese_polish_segments")
local sessions, sources = {}, {}
local parse_cache = {}
local next_id = 0
local markdown_types = { markdown = true, quarto = true, rmd = true, rmarkdown = true, pandoc = true }
local text_types = { [""] = true, text = true, txt = true }

local function before(first, last)
  return first[1] < last[1] or first[1] == last[1] and first[2] < last[2]
end

local function contains(outer, inner)
  return not before({ inner[1], inner[2] }, { outer[1], outer[2] })
    and not before({ outer[3], outer[4] }, { inner[3], inner[4] })
end

local function parse_paragraphs(bufnr)
  local lines = api.nvim_buf_get_lines(bufnr, 0, -1, false)
  local filetype = vim.bo[bufnr].filetype
  local ranges = {}
  if text_types[filetype] then
    local first
    for index = 1, #lines + 1 do
      if index <= #lines and vim.trim(lines[index]) ~= "" then
        first = first or index
      elseif first then
        table.insert(ranges, { first - 1, 0, index - 2, #lines[index - 1] })
        first = nil
      end
    end
    return ranges
  end
  if not markdown_types[filetype] then
    return nil,
      "分段模式仅支持纯文本、Markdown 和 Quarto；此格式请使用 <leader>aw 选择正文润色。"
  end
  local ok, tree = pcall(function()
    return vim.treesitter.get_string_parser(table.concat(lines, "\n") .. "\n", "markdown"):parse()[1]
  end)
  if not ok or not tree or tree:root():has_error() then
    return nil, "无法安全解析 Markdown 正文，请检查 markdown Tree-sitter parser；未启动分段。"
  end
  local eligible_rows = {}
  local function visit(node)
    local kind = node:type()
    if kind == "document" or kind == "section" then
      for child in node:iter_children() do
        visit(child)
      end
    elseif kind == "paragraph" then
      local first_row, first_col, last_row, last_col = node:range()
      if last_col == 0 then
        last_row = last_row - 1
        last_col = #(lines[last_row + 1] or "")
      end
      for index = first_row + 1, last_row + 1 do
        eligible_rows[index] = true
      end
      table.insert(ranges, { first_row, first_col, last_row, last_col })
    end
  end
  visit(tree:root())
  local protected, math_end = {}, nil
  for index, line in ipairs(lines) do
    local stripped = vim.trim(line)
    if math_end then
      protected[index] = true
      if stripped == math_end then
        math_end = nil
      end
    elseif eligible_rows[index] and (stripped == "$$" or stripped == "\\[") then
      math_end = stripped == "$$" and "$$" or "\\]"
      protected[index] = true
    elseif
      stripped:match("^%$%$")
      or stripped:match("^\\%[")
      or stripped:match("^:::")
      or stripped:match("^{{[<%%]")
      or stripped:match("^%[%^.-%]:")
      or stripped:match("^!%[")
      or stripped:match("^%b{}$")
    then
      protected[index] = true
    end
  end
  return vim.tbl_filter(function(range)
    for index = range[1] + 1, range[3] + 1 do
      if protected[index] then
        return false
      end
    end
    return true
  end, ranges)
end

local function paragraphs(bufnr)
  local tick, filetype = api.nvim_buf_get_changedtick(bufnr), vim.bo[bufnr].filetype
  local cached = parse_cache[bufnr]
  if cached and cached.tick == tick and cached.filetype == filetype then
    return cached.ranges
  end
  local ranges, error_message = parse_paragraphs(bufnr)
  if ranges then
    parse_cache[bufnr] = { tick = tick, filetype = filetype, ranges = ranges }
  end
  return ranges, error_message
end

local function mark(bufnr, range)
  return api.nvim_buf_set_extmark(bufnr, namespace, range[1], range[2], {
    end_row = range[3],
    end_col = range[4],
    right_gravity = true,
    end_right_gravity = false,
    invalidate = true,
  })
end

function M.stop(id)
  local session = sessions[id]
  if not session then
    return
  end
  sessions[id], sources[session.bufnr] = nil, nil
  parse_cache[session.bufnr] = nil
  if session.autocmd then
    pcall(api.nvim_del_autocmd, session.autocmd)
  end
  if api.nvim_buf_is_valid(session.bufnr) then
    for _, item in ipairs(session.items) do
      pcall(api.nvim_buf_del_extmark, session.bufnr, namespace, item.mark)
    end
  end
  if session.on_stop then
    session.on_stop()
  end
end

function M.create(bufnr, scope)
  if sources[bufnr] then
    return nil, "此原稿已有分段批次，请先在活动聊天执行 :ChinesePolishStop。"
  end
  local ranges, error_message = paragraphs(bufnr)
  if not ranges then
    return nil, error_message
  end
  local items = {}
  for _, range in ipairs(ranges) do
    local first, last = { range[1], range[2] }, { range[3], range[4] }
    if before(first, { scope[1], scope[2] }) then
      first = { scope[1], scope[2] }
    end
    if before({ scope[3], scope[4] }, last) then
      last = { scope[3], scope[4] }
    end
    if before(first, last) then
      local clipped = { first[1], first[2], last[1], last[2] }
      local text = table.concat(api.nvim_buf_get_text(bufnr, clipped[1], clipped[2], clipped[3], clipped[4], {}), "\n")
      if vim.trim(text) ~= "" then
        table.insert(items, { text = text, mark = mark(bufnr, clipped), status = "pending" })
      end
    end
  end
  if #items == 0 then
    parse_cache[bufnr] = nil
    return nil, "所选范围没有可安全处理的普通正文段落。"
  end
  next_id = next_id + 1
  local session = { bufnr = bufnr, items = items, index = 1, applied = 0, skipped = 0, phase = "opening" }
  sessions[next_id], sources[bufnr] = session, next_id
  local id = next_id
  session.autocmd = api.nvim_create_autocmd({ "BufUnload", "BufWipeout" }, {
    buffer = bufnr,
    once = true,
    callback = function()
      M.stop(id)
    end,
  })
  vim.schedule(function()
    if sessions[id] and not sessions[id].owner then
      M.stop(id)
    end
  end)
  return id
end

function M.current(id)
  local session = sessions[id]
  if not session then
    return nil, "分段批次已结束，请从原稿重新启动。"
  end
  local item = session.items[session.index]
  return {
    bufnr = session.bufnr,
    index = session.index,
    total = #session.items,
    original = item.text,
    selection = session.selection and vim.deepcopy(session.selection),
  }
end

function M.owns(id, bufnr)
  local session = sessions[id]
  return session ~= nil and session.owner == bufnr
end

function M.claim(id, index, bufnr, on_stop)
  local session = sessions[id]
  if not session or session.phase ~= "opening" or session.index ~= index then
    return false
  end
  session.owner, session.on_stop, session.phase = bufnr, on_stop, "active"
  return true
end

function M.check(id, index)
  local session = sessions[id]
  local item = session and session.items[index]
  if not item or not api.nvim_buf_is_loaded(session.bufnr) then
    return nil, "原稿或分段批次已关闭。"
  end
  local position = api.nvim_buf_get_extmark_by_id(session.bufnr, namespace, item.mark, { details = true })
  if #position == 0 or position[3].invalid or not position[3].end_row then
    return nil, "本段范围已失效，请跳过本段或停止后重新启动。"
  end
  local range = { position[1], position[2], position[3].end_row, position[3].end_col }
  local text = table.concat(api.nvim_buf_get_text(session.bufnr, range[1], range[2], range[3], range[4], {}), "\n")
  if text ~= item.text then
    return nil, "本段原稿已有修改，拒绝接管或覆盖；请跳过本段或重新启动。"
  end
  local ranges, error_message = paragraphs(session.bufnr)
  if not ranges then
    return nil, error_message
  end
  for _, eligible in ipairs(ranges) do
    if contains(eligible, range) then
      return range
    end
  end
  return nil, "本段已不属于可处理的普通正文，请跳过本段或重新启动。"
end

function M.neighbors(id)
  local session = sessions[id]
  local neighbors, omitted = {}, false
  for _, index in ipairs({ session.index - 1, session.index + 1 }) do
    local item = session.items[index]
    if item then
      if M.check(id, index) then
        table.insert(
          neighbors,
          { index = index, text = item.text, label = index < session.index and "前段" or "后段" }
        )
      else
        omitted = true
      end
    end
  end
  return neighbors, omitted
end

function M.context_valid(id, neighbors)
  for _, neighbor in ipairs(neighbors or {}) do
    local session = sessions[id]
    if not M.check(id, neighbor.index) or session.items[neighbor.index].text ~= neighbor.text then
      return false
    end
  end
  return true
end

function M.confirm(id, selection)
  sessions[id].selection = vim.deepcopy(selection)
end

function M.progress(id)
  local session = sessions[id]
  local position =
    api.nvim_buf_get_extmark_by_id(session.bufnr, namespace, session.items[session.index].mark, { details = true })
  local location = #position > 0
      and not position[3].invalid
      and string.format("（原稿第 %d—%d 行）", position[1] + 1, position[3].end_row + 1)
    or "（原稿范围已变化）"
  return string.format(
    "第 %d／%d 段%s；已采用 %d 段，已跳过 %d 段。",
    session.index,
    #session.items,
    location,
    session.applied,
    session.skipped
  )
end

function M.finish(id, owner, status, replacement, range)
  local session = sessions[id]
  if not M.owns(id, owner) or session.phase ~= "active" then
    return nil
  end
  local item = session.items[session.index]
  if replacement then
    pcall(api.nvim_buf_del_extmark, session.bufnr, namespace, item.mark)
    local lines = vim.split(replacement, "\n", { plain = true })
    item.text = replacement
    item.mark = mark(session.bufnr, {
      range[1],
      range[2],
      range[1] + #lines - 1,
      #lines == 1 and range[2] + #lines[1] or #lines[#lines],
    })
  end
  item.status = status
  session[status] = session[status] + 1
  session.phase = "between"
  local summary = M.progress(id)
  if session.index == #session.items then
    summary = "分段润色已完成。" .. summary
    M.stop(id)
  else
    summary = summary .. "执行 :ChinesePolishNext 预览下一段，再手动发送。"
  end
  return summary
end

function M.next(id, owner)
  local session = sessions[id]
  if not M.owns(id, owner) or session.phase ~= "between" then
    return nil, "请先采用或跳过当前段；旧聊天不能推进正在处理的段落。"
  end
  session.handoff = { owner = session.owner, on_stop = session.on_stop }
  session.index = session.index + 1
  session.phase = "opening"
  return M.current(id)
end

function M.commit(id, owner)
  if M.owns(id, owner) then
    sessions[id].handoff = nil
  end
end

function M.rollback(id, owner)
  local session = sessions[id]
  if session and session.handoff and session.handoff.owner == owner then
    if session.owner ~= owner and session.on_stop then
      session.on_stop()
    end
    session.index = session.index - 1
    session.owner, session.on_stop = session.handoff.owner, session.handoff.on_stop
    session.handoff = nil
    session.phase = "between"
  end
end

return M
