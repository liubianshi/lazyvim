local M = {}
local api = vim.api
local namespace = api.nvim_create_namespace("lbs_chinese_polish")
local segments = require("lbs.codecompanion.polish_segments")
local editing = require("lbs.codecompanion.polish_edit")
local max_repairs = 2
local stage_names =
  { "原文分析", "多视角润色方向", "参考书与方向词汇", "确认润色方案", "润色定稿" }
local scheme_fields = { "核心目标", "输出字数", "润色视角", "参考书籍／方法" }
local confirmations = {
  ["无"] = true,
  ["没有"] = true,
  ["无补充"] = true,
  ["没有补充"] = true,
  ["继续"] = true,
  ["确认"] = true,
}

local function notify(message)
  vim.notify(message, vim.log.levels.WARN, { title = "中文润色" })
end

local function cleanup(state)
  state.candidate = nil
  state.active = false
  if state.chat_bufnr then
    editing.release({ bufnr = state.chat_bufnr })
  end
  state.generation = (state.generation or 0) + 1
  state.request = nil
  state.repair_queued = false
  state.phase = "closed"
  if state.source_autocmd then
    pcall(api.nvim_del_autocmd, state.source_autocmd)
    state.source_autocmd = nil
  end
  if state.mark and api.nvim_buf_is_valid(state.bufnr) then
    pcall(api.nvim_buf_del_extmark, state.bufnr, namespace, state.mark)
  end
  state.mark = nil
end

local function capture(context, whole_buffer)
  local bufnr = context.bufnr
  if not api.nvim_buf_is_loaded(bufnr) or vim.bo[bufnr].buftype ~= "" then
    return nil, "请从原稿的普通文本缓冲区启动。"
  end

  local mode = context.mode
  if mode == "\22" or mode == "^V" then
    return nil, "块选区不支持安全写回，请改用字符或整行选区。"
  end

  local start_row, start_col, end_row, end_col
  if mode == "v" then
    local first = { bufnr, context.start_line, context.start_col, 0 }
    local last = { bufnr, context.end_line, context.end_col, 0 }
    local opts = { type = "v", exclusive = vim.o.selection == "exclusive", eol = true }
    local segments = vim.fn.getregionpos(first, last, opts)
    if #segments == 0 or segments[1][1][4] ~= 0 or segments[#segments][2][4] ~= 0 then
      return nil, "无法定位选区，请避免虚拟列并重新选择正文。"
    end
    local first_pos, last_pos = segments[1][1], segments[#segments][2]
    start_row, start_col = first_pos[2] - 1, math.max(first_pos[3] - 1, 0)
    end_row, end_col = last_pos[2] - 1, math.max(last_pos[3] - 1, 0)
    local last_line = api.nvim_buf_get_lines(bufnr, end_row, end_row + 1, false)[1]
    end_col = math.min(end_col, #last_line)
    if end_col < #last_line then
      end_col = end_col + #vim.fn.strcharpart(last_line:sub(end_col + 1), 0, 1)
    end
    local selected = table.concat(vim.fn.getregion(first, last, opts), "\n")
    local extracted = table.concat(api.nvim_buf_get_text(bufnr, start_row, start_col, end_row, end_col, {}), "\n")
    if extracted ~= selected then
      return nil, "选区包含无法精确替换的虚拟文本，请重新选择。"
    end
  elseif mode == "V" then
    start_row, start_col = context.start_line - 1, 0
    end_row = context.end_line - 1
    end_col = #api.nvim_buf_get_lines(bufnr, end_row, end_row + 1, false)[1]
  elseif whole_buffer then
    start_row, start_col, end_row = 0, 0, api.nvim_buf_line_count(bufnr) - 1
    end_col = #api.nvim_buf_get_lines(bufnr, end_row, end_row + 1, false)[1]
  else
    local lines = api.nvim_buf_get_lines(bufnr, 0, -1, false)
    local first_line = context.cursor_pos[1]
    if vim.trim(lines[first_line]) == "" then
      return nil, "光标位于空白行，请移动到要润色的段落。"
    end
    local last_line = first_line
    while first_line > 1 and vim.trim(lines[first_line - 1]) ~= "" do
      first_line = first_line - 1
    end
    while last_line < #lines and vim.trim(lines[last_line + 1]) ~= "" do
      last_line = last_line + 1
    end
    start_row, start_col, end_row, end_col = first_line - 1, 0, last_line - 1, #lines[last_line]
  end

  local original = table.concat(api.nvim_buf_get_text(bufnr, start_row, start_col, end_row, end_col, {}), "\n")
  if vim.trim(original) == "" then
    return nil, "选中的正文为空，请重新选择。"
  end

  return {
    bufnr = bufnr,
    original = original,
    active = true,
    stage = 1,
    phase = "initial",
    generation = 0,
    repairs = 0,
    mark = api.nvim_buf_set_extmark(bufnr, namespace, start_row, start_col, {
      end_row = end_row,
      end_col = end_col,
      right_gravity = true,
      end_right_gravity = false,
      invalidate = true,
    }),
  }
end

local function fenced(text)
  local fence = "````"
  for run in text:gmatch("`+") do
    if #run >= #fence then
      fence = string.rep("`", #run + 1)
    end
  end
  return fence .. "text\n" .. text .. "\n" .. fence
end

function M.source(args)
  local context = args.context
  local state, error_message
  local batch = args.session
  if not batch then
    state, error_message = capture(context, args.segmented)
    if state and args.segmented then
      local position = api.nvim_buf_get_extmark_by_id(state.bufnr, namespace, state.mark, { details = true })
      batch, error_message = segments.create(state.bufnr, {
        position[1],
        position[2],
        position[3].end_row,
        position[3].end_col,
      })
      cleanup(state)
      state = nil
    end
  end
  if batch then
    local current
    current, error_message = segments.current(batch)
    if current then
      state = {
        bufnr = current.bufnr,
        original = current.original,
        active = true,
        stage = current.selection and 5 or 1,
        phase = args.prepared and "awaiting_start" or "initial",
        generation = 0,
        repairs = 0,
        batch = batch,
        segment = current.index,
        selection = current.selection,
      }
    end
  end
  context.lbs_chinese_polish = setmetatable(state or { error = error_message }, {})
  context.is_visual = false
  context.lines = {}
  context.code = nil
  if not state then
    return "（没有可用原稿，编辑器将阻止发送。）"
  end
  return (state.batch and segments.progress(state.batch) .. "\n\n" or "") .. fenced(state.original)
end

local function citations(text)
  local result = {}
  local function add(token)
    result[token] = (result[token] or 0) + 1
  end
  for bracket in text:gmatch("%b[]") do
    if bracket:match("@[%w_]") then
      add("bracket:" .. bracket)
    end
  end
  for key in text:gmatch("@[%w_][%w_:./%-]*") do
    add("key:" .. key)
  end
  return result
end

local function target_range(state)
  if state.batch then
    if
      not state.active
      or not api.nvim_buf_is_loaded(state.bufnr)
      or not vim.bo[state.bufnr].modifiable
      or vim.bo[state.bufnr].readonly
    then
      return nil, "本段已结束或原稿不可修改。"
    end
    local range, error_message = segments.check(state.batch, state.segment)
    if range and not segments.context_valid(state.batch, state.neighbors) then
      return nil,
        "已发送的相邻上下文发生变化；为保留消息历史，请跳过本段或停止后重新启动。"
    end
    return range, error_message
  end
  if not state.active or not state.mark or not api.nvim_buf_is_loaded(state.bufnr) then
    return nil, "原稿已关闭或本轮已结束，请从原稿重新启动。"
  end
  if not vim.bo[state.bufnr].modifiable or vim.bo[state.bufnr].readonly then
    return nil, "原稿不可修改，请先解除只读状态。"
  end
  local mark = api.nvim_buf_get_extmark_by_id(state.bufnr, namespace, state.mark, { details = true })
  if #mark == 0 or mark[3].invalid or not mark[3].end_row then
    return nil, "原稿范围已失效，请从原稿重新启动。"
  end
  local range = { mark[1], mark[2], mark[3].end_row, mark[3].end_col }
  local text = table.concat(api.nvim_buf_get_text(state.bufnr, range[1], range[2], range[3], range[4], {}), "\n")
  if text ~= state.original then
    return nil, "原稿范围内已有修改，拒绝覆盖；请重新启动润色。"
  end
  return range
end

local function finish_segment(chat, state, status, replacement, range)
  local summary = segments.finish(state.batch, chat.bufnr, status, replacement, range)
  cleanup(state)
  if summary and api.nvim_buf_is_valid(chat.bufnr) then
    chat.ui:unlock_buf()
    api.nvim_buf_set_lines(
      chat.bufnr,
      math.min(chat.header_line or 0, api.nvim_buf_line_count(chat.bufnr)),
      -1,
      false,
      {
        summary,
        "",
        "",
      }
    )
    vim.notify(summary, vim.log.levels.INFO, { title = "中文润色" })
  end
end

local function validate_candidate(state, candidate)
  if candidate ~= state.candidate or candidate.generation ~= state.generation then
    return nil, "会话或候选已变化，请重新生成后审阅。"
  end
  if state.batch and not segments.owns(state.batch, state.chat_bufnr) then
    return nil, "此聊天不拥有当前分段批次。"
  end
  if not vim.deep_equal(citations(state.original), citations(candidate.text)) then
    return nil, "定稿改变了引文标记或其数量，拒绝写回；请让模型修正后重新提交。"
  end
  return target_range(state)
end

local function write_candidate(state, candidate)
  local range, error_message = validate_candidate(state, candidate)
  if not range then
    return nil, error_message
  end
  vim.bo[state.bufnr].undolevels = vim.bo[state.bufnr].undolevels
  local ok, write_error = pcall(
    api.nvim_buf_set_text,
    state.bufnr,
    range[1],
    range[2],
    range[3],
    range[4],
    vim.split(candidate.text, "\n", { plain = true })
  )
  if not ok then
    return nil, "无法替换原稿：" .. tostring(write_error)
  end
  vim.bo[state.bufnr].undolevels = vim.bo[state.bufnr].undolevels
  candidate.range = range
  return true
end

local function finish_review(chat, state, result)
  state.review_result = nil
  if result.outcome == "accepted" then
    if state.batch then
      finish_segment(chat, state, "applied", result.candidate.text, result.candidate.range)
    else
      cleanup(state)
    end
    vim.notify("已替换原稿，尚未保存；可用 u 撤销。", vim.log.levels.INFO, { title = "中文润色" })
  else
    state.phase = result.outcome == "invalid" and "blocked" or "awaiting"
    state.candidate = result.outcome == "cancelled" and result.candidate or nil
    notify(result.message)
  end
end

local function apply(chat)
  editing.reopen(chat)
end

local function prepare_input(chat, state)
  local lines = api.nvim_buf_get_lines(chat.bufnr, 0, -1, false)
  local last_content = #lines
  while last_content > 0 and lines[last_content] == "" do
    last_content = last_content - 1
  end
  state.input_label = lines[last_content]
  local padding = {}
  for _ = #lines - last_content + 1, 2 do
    table.insert(padding, "")
  end
  if #padding > 0 then
    api.nvim_buf_set_lines(chat.bufnr, -1, -1, false, padding)
  end
  if api.nvim_get_current_buf() == chat.bufnr then
    api.nvim_win_set_cursor(0, { api.nvim_buf_line_count(chat.bufnr), 0 })
  end
end

local function get_state(chat)
  local state = chat.buffer_context and chat.buffer_context.lbs_chinese_polish
  if state and getmetatable(state) then
    return state
  end
end

local function read_input(chat, state)
  local lines = api.nvim_buf_get_lines(chat.bufnr, chat.header_line or 0, -1, false)
  local input = vim.trim(table.concat(lines, "\n"))
  if state.input_label and input:sub(1, #state.input_label) == state.input_label then
    input = vim.trim(input:sub(#state.input_label + 1))
  end
  return input
end

local function command(input)
  input = vim.trim(input)
  local previous
  repeat
    previous = input
    input = vim.trim(input:gsub("[.!?]+$", ""):gsub("。$", ""):gsub("！$", ""):gsub("？$", ""))
  until previous == input
  return input
end

local function extract_scheme(content, heading)
  local fields, inside, fence = {}, false, nil
  for _, line in ipairs(vim.split(content, "\n", { plain = true })) do
    local delimiter, suffix = line:match("^%s*(```+)(.-)%s*$")
    if delimiter then
      if not fence then
        fence = delimiter
      elseif #delimiter >= #fence and vim.trim(suffix) == "" then
        fence = nil
      end
    elseif not fence then
      local hashes, title = line:match("^(#+)%s+(.+)$")
      if hashes and #hashes <= 3 then
        if inside then
          break
        end
        inside = #hashes == 3 and vim.trim(title) == heading
      elseif inside then
        local plain = line:gsub("%*%*", "")
        for _, field in ipairs(scheme_fields) do
          local value = plain:match("^%s*%- " .. field .. "：%s*(.-)%s*$")
          if value and value ~= "" then
            if fields[field] then
              return nil
            end
            fields[field] = value
          end
        end
      end
    end
  end
  for _, field in ipairs(scheme_fields) do
    local value = fields[field]
    if not value then
      return nil
    end
    for _, placeholder in ipairs({ "待补充", "未确定", "待选择", "未选择", "xxx" }) do
      if value:find(placeholder, 1, true) then
        return nil
      end
    end
  end
  return fields
end

local function scheme_text(scheme)
  local lines = {}
  for _, field in ipairs(scheme_fields) do
    table.insert(lines, "- " .. field .. "：" .. scheme[field])
  end
  return table.concat(lines, "\n")
end

local function citation_error(original, final)
  local expected, actual = citations(original), citations(final)
  if vim.deep_equal(expected, actual) then
    return nil
  end
  local differences = {}
  for token in pairs(vim.tbl_extend("force", expected, actual)) do
    if expected[token] ~= actual[token] then
      table.insert(
        differences,
        string.format("%s：原稿 %d 次，定稿 %d 次", token, expected[token] or 0, actual[token] or 0)
      )
    end
  end
  table.sort(differences)
  return "引文标记、引用键或数量不同，须恢复原样：\n" .. table.concat(differences, "\n")
end

local function control(chat, stage, detail)
  chat:add_message({
    role = "user",
    content = string.format(
      "【编辑器工作流控制】本轮仅执行第 %d 步「%s」。这是阶段控制，不是原稿。\n%s\n不要提前进入其他步骤，也不要显示本条控制信息。",
      stage,
      stage_names[stage],
      detail
    ),
  }, { visible = false })
end

local function before_submit(chat)
  local state = get_state(chat)
  if not state or state.error or not state.active then
    notify(state and state.error or "本轮已结束或来自历史记录，请从原稿重新启动五步润色。")
    return false
  end
  if editing.pending(chat) then
    notify("请先接受、拒绝或关闭当前 diff，再发送新的修改要求。")
    return false
  end
  if state.last_cycle and chat.cycle < state.last_cycle then
    if state.batch and segments.owns(state.batch, chat.bufnr) then
      segments.stop(state.batch)
    end
    cleanup(state)
    notify("本轮聊天已清空，请从原稿重新启动。")
    return false
  end
  local range, range_error = target_range(state)
  if not range then
    state.candidate = nil
    state.generation = state.generation + 1
    state.phase = "blocked"
    notify(range_error)
    return false
  end
  local input = read_input(chat, state)
  if state.phase ~= "initial" and input == "" then
    notify("请在输入栏下方填写补充或确认；第四步须先填写方案，再单独确认。")
    return false
  end
  local stage = state.retry_target or state.stage
  local selection = state.selection
  local normalized = command(input)
  if not state.retry_target and state.phase ~= "initial" and state.phase ~= "awaiting_start" then
    if stage < 4 and confirmations[normalized] then
      stage = stage + 1
    elseif stage == 4 then
      if normalized == "确认" or normalized == "采用默认方案" then
        if normalized == "确认" then
          selection = state.plan
        else
          selection = state.default_plan
        end
        if not selection then
          notify(
            "还没有完整的可确认方案，请先填写核心目标、输出字数、润色视角和参考书籍／方法。"
          )
          return false
        end
        stage = 5
      end
    end
  end
  if not state.credentials_checked then
    local ok, result = pcall(function()
      return vim.system({ vim.fn.expand("~/.private_info.sh"), "deepseek" }, { text = true, timeout = 5000 }):wait()
    end)
    if not ok or type(result) ~= "table" or result.code ~= 0 or vim.trim(result.stdout or "") == "" then
      notify("DeepSeek 密钥查询失败或返回空值，请检查私密查询工具的 deepseek 项。")
      return false
    end
    state.credentials_checked = true
  end
  if state.batch then
    if not segments.owns(state.batch, chat.bufnr) or not target_range(state) then
      notify("分段状态或原稿已变化，未发送请求。")
      return false
    end
    if not state.neighbors then
      local omitted
      state.neighbors, omitted = segments.neighbors(state.batch)
      local context = {
        "以下是相邻正文，只读，仅用于衔接与术语一致；不得混入当前段定稿或复制其中引文。",
      }
      for _, neighbor in ipairs(state.neighbors) do
        table.insert(context, "### 只读" .. neighbor.label .. "\n\n" .. fenced(neighbor.text))
      end
      if #state.neighbors > 0 then
        chat:add_message({ role = "user", content = table.concat(context, "\n\n") }, { visible = false })
      end
      if omitted then
        notify("部分相邻段落已变化，已省略该只读上下文。")
      end
    end
    if stage == 5 then
      segments.confirm(state.batch, selection)
    end
  end
  editing.cancel(chat, true)
  state.candidate, state.review_result, state.validation_error = nil, nil, nil
  state.generation = state.generation + 1
  state.repairs = 0
  state.repair_queued = false
  state.selection = selection
  if stage == 4 then
    state.plan = nil
  end
  local detail =
    "回答用户对当前步骤的补充或问题，完成后等待明确确认；不要因收到一条补充就进入下一步。"
  if stage == 4 then
    detail = detail
      .. "\n只收集与回显方案，不输出定稿。四项明确后用「### 待确认方案」及约定的四个项目字段回显；否则只追问缺项。"
    if state.batch and selection then
      detail = detail
        .. "\n此前确认的共用方案如下，仅供修改时参考，不代表确认本次修改：\n"
        .. scheme_text(selection)
    end
  elseif stage == 5 then
    detail = "用户已确认以下方案，按此润色；必须调用 chinese_polish_edit 提交完整替换正文，保留引文，不输出 polished 围栏，不声称已写回：\n"
      .. scheme_text(selection)
  end
  if state.batch then
    detail = detail
      .. "\n这是连续分段模式，仅处理本次绑定的当前段。输出字数是每段目标，不是全篇总字数；相邻段只读。临时改稿要求只用于本段。"
  end
  control(chat, stage, detail)
  state.phase = "running"
  state.request = { stage = stage, message_count = #chat.messages, generation = state.generation }
  chat.subscribers.stopped = false
end

local function fail_request(state)
  state.retry_target = state.request.stage
  state.request = nil
  state.candidate = nil
  state.phase = "failed"
  state.repair_queued = false
  notify("本轮请求未完成，没有推进步骤；可输入「重试」，或补充要求后手动重试。")
end

local function on_ready(chat)
  local state = get_state(chat)
  if not state or not state.active or not state.request then
    return
  end
  local request = state.request
  if state.review_result then
    state.stage, state.last_cycle, state.request, state.retry_target = request.stage, chat.cycle, nil, nil
    state.input_label = nil
    return finish_review(chat, state, state.review_result)
  end
  if state.phase ~= "running" then
    return
  end
  if chat.status ~= "success" then
    return fail_request(state)
  end
  local content = ""
  for index = #chat.messages, request.message_count + 1, -1 do
    local message = chat.messages[index]
    if message.role == "llm" and type(message.content) == "string" and message.content ~= "" then
      content = message.content
      break
    end
  end
  if content == "" and request.stage ~= 5 then
    return fail_request(state)
  end
  state.stage = request.stage
  state.last_cycle = chat.cycle
  state.request = nil
  state.retry_target = nil
  state.input_label = nil
  state.phase = "awaiting"
  if state.stage == 4 then
    state.plan = extract_scheme(content, "待确认方案")
    state.default_plan = extract_scheme(content, "默认方案") or state.default_plan
  elseif state.stage == 5 then
    local range, range_error = target_range(state)
    if not range then
      state.phase = "blocked"
      return notify(range_error)
    end
    local validation_error = state.validation_error
      or "第五步必须调用 chinese_polish_edit 提交正文，不能只输出聊天定稿。"
    if state.repairs < max_repairs then
      state.phase = "repair_pending"
      state.validation_error = validation_error
    else
      state.phase = "failed_validation"
      notify("自动修复已达两次上限，尚不可采用：" .. validation_error)
    end
  end
end

local function queue_repair(chat, state)
  state.repair_queued = true
  local generation = state.generation
  local cycle = chat.cycle
  vim.notify(
    string.format("定稿检查未通过，准备自动修复（%d/%d）。", state.repairs + 1, max_repairs),
    vim.log.levels.INFO
  )
  vim.defer_fn(function()
    if
      not state.active
      or not api.nvim_buf_is_valid(chat.bufnr)
      or state.generation ~= generation
      or state.phase ~= "repair_pending"
      or chat.cycle ~= cycle
      or chat.current_request
      or chat.subscribers.stopped
    then
      return
    end
    state.repair_queued = false
    if read_input(chat, state) ~= "" then
      state.phase = "failed_validation"
      return notify("检测到新的输入，已暂停自动修复；请手动发送你的修改要求。")
    end
    local range, range_error = target_range(state)
    if not range then
      state.phase = "blocked"
      return notify(range_error)
    end
    state.repairs = state.repairs + 1
    state.generation = state.generation + 1
    control(
      chat,
      5,
      "仅修复本次工具提交或引文问题，调用 chinese_polish_edit 提交正文，保持已确认方案与原意。\n"
        .. state.validation_error
        .. "\n已确认方案：\n"
        .. scheme_text(state.selection)
    )
    state.phase = "running"
    state.request = { stage = 5, message_count = #chat.messages, generation = state.generation }
    chat:submit({ auto_submit = true })
  end, require("codecompanion.config").opts.submit_delay)
end

local function show_input(chat, state)
  local label
  if state.phase == "awaiting_start" then
    label = segments.progress(state.batch)
      .. (
        state.selection and "沿用已确认方案；填写「开始」或本段要求后手动发送："
        or "尚未确认共享方案；填写「开始」进入五步流程："
      )
  elseif state.phase == "failed" or state.phase == "cancelled" then
    label = "本轮未完成；输入「重试」或补充要求后，手动重试当前步骤："
  elseif state.phase == "failed_validation" then
    label = "定稿检查未通过，请填写修正要求后手动重试："
  elseif state.stage < 4 then
    label = "对第"
      .. state.stage
      .. "步的补充或问题（留在本步）；无补充填「无」，或填「继续／确认」推进："
  elseif state.stage == 4 then
    label =
      "填写或修改润色方案；完整方案回显后单独填「确认」，或填「采用默认方案」出稿："
  else
    label =
      "可按 <leader>aA 重开暂停的 diff，或在下方填写新的修改要求；接受后仍需手动保存："
  end
  chat:add_buf_message({ role = "user", content = label })
  prepare_input(chat, state)
end
local function close_workflow(chat, state)
  if state.batch and segments.owns(state.batch, chat.bufnr) then
    segments.stop(state.batch)
  end
  cleanup(state)
end

local function local_input(chat, state, content)
  chat:add_buf_message({ role = "llm", content = content })
  chat:add_buf_message({ role = "user", content = "" })
  chat.header_line = (chat.builder.state.current_header_line or 0) + 1
  state.input_cycle = chat.cycle
  show_input(chat, state)
end

local function next_segment(chat, state)
  local current, error_message = segments.next(state.batch, chat.bufnr)
  if not current then
    return notify(error_message)
  end
  local context = vim.tbl_extend("force", chat.buffer_context, {
    bufnr = current.bufnr,
    mode = "n",
    lines = {},
    is_visual = false,
  })
  context.lbs_chinese_polish = nil
  local ok, next_chat = pcall(function()
    local workflow = M.workflow({ session = state.batch, prepared = true })
    if workflow then
      return require("codecompanion.action_palette").resolve(workflow, context)
    end
  end)
  if not ok or not next_chat then
    segments.rollback(state.batch, chat.bufnr)
    notify("无法打开下一段，进度未推进；请检查提示词与 CodeCompanion 后重试。")
  else
    segments.commit(state.batch, next_chat.bufnr)
  end
end

local function skip_segment(chat, state)
  if not state.active or not segments.owns(state.batch, chat.bufnr) then
    return notify("此聊天不是当前待处理段落。")
  end
  if chat.current_request then
    return notify("请先取消当前请求，再跳过本段。")
  end
  if editing.pending(chat) then
    state.stage, state.phase = state.request and state.request.stage or state.stage, "awaiting"
    state.request = nil
    editing.cancel(chat, true)
    state.candidate = nil
  end
  local generation = state.generation
  vim.ui.select({ "取消", "跳过本段，保留原文" }, { prompt = "确认跳过当前段？" }, function(choice)
    if choice ~= "跳过本段，保留原文" then
      return
    end
    if
      not state.active
      or generation ~= state.generation
      or chat.current_request
      or not segments.owns(state.batch, chat.bufnr)
    then
      return notify("当前段或会话已变化，未跳过。")
    end
    finish_segment(chat, state, "skipped")
  end)
end

local function change_plan(chat, state)
  if not state.active or not segments.owns(state.batch, chat.bufnr) then
    return notify("请在当前待处理段落修改共享方案。")
  end
  if chat.current_request then
    return notify("请先取消当前请求，再修改方案。")
  end
  state.request = nil
  editing.cancel(chat, true)
  state.generation = state.generation + 1
  state.candidate, state.request, state.retry_target, state.plan, state.default_plan = nil, nil, nil, nil, nil
  state.repair_queued = false
  state.phase, state.stage = "awaiting", 4
  chat.ui:unlock_buf()
  api.nvim_buf_set_lines(
    chat.bufnr,
    math.min(chat.header_line or 0, api.nvim_buf_line_count(chat.bufnr)),
    -1,
    false,
    { "" }
  )
  local_input(
    chat,
    state,
    "### 修改共享方案\n\n"
      .. (state.selection and scheme_text(state.selection) or "尚未确认共享方案。")
      .. "\n\n字数为每段目标。填写四项选择，完整回显后另行确认；新方案用于本段及后续段落。"
  )
end

local function attach(chat)
  local state = get_state(chat)
  if not state or state.attached then
    return
  end
  state.attached = true
  state.chat_bufnr = chat.bufnr
  if state.batch then
    local claimed = segments.claim(state.batch, state.segment, chat.bufnr, function()
      cleanup(state)
      if chat.current_request or chat.tool_orchestrator then
        chat:stop()
      end
    end)
    if not claimed then
      cleanup(state)
      return notify("分段批次已变化，未绑定此聊天。")
    end
  end
  chat.opts.ignore_system_prompt = true
  local tags = require("codecompanion.interactions.shared.tags")
  for _, tag in ipairs({ tags.SYSTEM_PROMPT_FROM_CONFIG, tags.TOOL_SYSTEM_PROMPT, tags.TOOL }) do
    chat:remove_tagged_message(tag)
  end
  chat.tool_registry:clear()
  chat.tool_registry.flags.ignore_tool_system_prompt = true
  editing.bind(chat, {
    propose = function(args)
      if not state.active or not state.request or state.request.stage ~= 5 or not state.selection then
        return nil, "仅在已确认方案的第五步允许提交当前段修改。"
      end
      if state.request.proposed then
        return nil, "每次第五步请求只能提交一个候选，拒绝重复调用。"
      end
      state.request.proposed = true
      local range, range_error = target_range(state)
      if not range then
        state.review_result = { outcome = "invalid", message = range_error }
        return nil, range_error
      end
      local validation_error
      if type(args) ~= "table" then
        state.validation_error = "工具参数必须是包含 replacement 正文的对象。"
        return nil, state.validation_error
      end
      for key in pairs(args) do
        if key ~= "replacement" and key ~= "summary" then
          validation_error = "仅允许 replacement 正文和可选 summary，不得指定路径或范围。"
        end
      end
      if type(args.replacement) ~= "string" or vim.trim(args.replacement) == "" then
        validation_error = "replacement 必须是当前段完整、非空的正文。"
      elseif args.replacement:match("^%s*```+polished") or args.replacement:match("^%s*~~~+polished") then
        validation_error = "replacement 只放正文，不要添加 polished 围栏。"
      elseif args.summary ~= nil and type(args.summary) ~= "string" then
        validation_error = "summary 必须是字符串。"
      else
        validation_error = validation_error or citation_error(state.original, args.replacement)
      end
      if validation_error then
        state.validation_error = validation_error
        return nil, validation_error
      end
      local candidate = {
        text = args.replacement,
        original = state.original,
        summary = args.summary,
        generation = state.generation,
      }
      state.candidate, state.phase = candidate, "reviewing"
      return candidate
    end,
    validate = function(candidate)
      return validate_candidate(state, candidate)
    end,
    accept = function(candidate)
      return write_candidate(state, candidate)
    end,
    settled = function(outcome, candidate, pending_tool, message)
      if not state.active or state.candidate ~= candidate then
        return
      end
      local result = { outcome = outcome, candidate = candidate, message = message }
      if pending_tool then
        if state.request then
          state.review_result = result
        end
      else
        finish_review(chat, state, result)
      end
    end,
  })
  chat.tool_registry:add_single_tool("chinese_polish_edit", { visible = false })
  chat.context:remove_items({ ["<tool>chinese_polish_edit</tool>"] = true })
  for _, branch in ipairs({
    {
      name = "chinese_polish_input",
      condition = function()
        return state.active
          and state.input_cycle ~= chat.cycle
          and (
            state.phase == "awaiting_start"
            or state.phase == "awaiting"
            or state.phase == "failed"
            or state.phase == "failed_validation"
            or state.phase == "cancelled"
          )
      end,
      callback = function()
        state.input_cycle = chat.cycle
        show_input(chat, state)
      end,
    },
    {
      name = "chinese_polish_repair",
      condition = function()
        return state.active and state.phase == "repair_pending" and not state.repair_queued
      end,
      callback = function()
        queue_repair(chat, state)
      end,
    },
  }) do
    chat.subscribers:subscribe({
      data = { name = branch.name, type = "repeat", condition = branch.condition, opts = { auto_submit = false } },
      reuse = function()
        return state.active
      end,
      callback = branch.callback,
    })
  end
  api.nvim_create_autocmd("BufWipeout", {
    buffer = chat.bufnr,
    once = true,
    callback = function()
      close_workflow(chat, state)
    end,
  })
  if not state.batch then
    state.source_autocmd = api.nvim_create_autocmd({ "BufUnload", "BufWipeout" }, {
      buffer = state.bufnr,
      once = true,
      callback = function()
        close_workflow(chat, state)
        if chat.current_request or chat.tool_orchestrator then
          chat:stop()
        end
      end,
    })
  end
  vim.keymap.set("n", "<leader>aA", function()
    apply(chat, state)
  end, { buffer = chat.bufnr, desc = "中文润色：重开当前段 diff" })
  api.nvim_buf_create_user_command(chat.bufnr, "ChinesePolishApply", function()
    apply(chat, state)
  end, { desc = "重开暂停的中文润色 diff" })
  if state.batch then
    for name, callback in pairs({
      ChinesePolishNext = next_segment,
      ChinesePolishSkip = skip_segment,
      ChinesePolishPlan = change_plan,
      ChinesePolishStop = function(current_chat, current_state)
        if not segments.owns(current_state.batch, current_chat.bufnr) then
          return notify("此聊天不拥有当前分段批次。")
        end
        segments.stop(current_state.batch)
        notify("分段批次已停止；已采用的修改保留，文件未保存。")
      end,
    }) do
      api.nvim_buf_create_user_command(chat.bufnr, name, function()
        callback(chat, state)
      end, { desc = "中文连续分段润色" })
    end
    if state.phase == "awaiting_start" then
      local_input(chat, state, "编辑器预览：" .. segments.progress(state.batch) .. "尚未发送请求。")
    end
  end
end

function M.workflow(options)
  options = options or {}
  local path = vim.fn.stdpath("config") .. "/prompts/chinese_polish.md"
  local ok, prompt = pcall(require("codecompanion.prompt_library.markdown").parse_file, path, {})
  if not ok or not prompt or not prompt.prompts or not prompt.prompts[1] then
    notify("无法解析中文润色提示词，未注册本工作流；请检查 " .. path .. " 和 YAML parser。")
    return nil
  end
  local initial = prompt.prompts[1]
  local source_prompt = initial[#initial].content
  if type(source_prompt) ~= "string" or not source_prompt:find("${chinese_polish.source}", 1, true) then
    notify("中文润色提示词缺少原稿占位符，未注册本工作流。")
    return nil
  end
  initial[#initial].content = function(context)
    local content = (
      source_prompt:gsub("%${chinese_polish%.source}", function()
        return M.source({
          context = context,
          segmented = options.segmented,
          session = options.session,
          prepared = options.prepared,
        })
      end)
    )
    if options.prepared then
      content = content:gsub(
        "请先完成第一步原文分析。",
        "本段已准备好，等待用户手动发送；执行阶段以编辑器控制信息为准。"
      )
    end
    return content
  end
  if options.segmented then
    prompt.name = "中文连续分段润色"
    prompt.description = "正文按空行分段，确认方案后逐段复用并手动采用"
    prompt.opts.alias = "zh_polish_segments"
    prompt.opts.index = 19
  end
  if options.prepared then
    initial[#initial].opts = vim.tbl_extend("force", initial[#initial].opts or {}, { auto_submit = false })
  end
  prompt.prompts = { initial }
  prompt.opts.enabled = true
  prompt.opts.callbacks = {
    on_created = attach,
    on_before_submit = before_submit,
    on_ready = on_ready,
    on_completed = function(chat)
      local state = get_state(chat)
      if not state or not state.active or chat.current_request then
        return
      end
      local needs_input = false
      if state.phase == "running" and state.request then
        fail_request(state)
        needs_input = true
      elseif state.phase == "cancelled" and chat.header_line > api.nvim_buf_line_count(chat.bufnr) then
        needs_input = true
      end
      if needs_input then
        chat:add_buf_message({ role = "llm", content = "编辑器提示：本轮请求未完成，未推进步骤。" })
        chat:ready_for_input()
      end
    end,
    on_cancelled = function(chat)
      local state = get_state(chat)
      if state and state.active then
        state.retry_target = state.request and state.request.stage or state.stage
        state.request = nil
        editing.cancel(chat, true)
        state.candidate = nil
        state.review_result = nil
        state.generation = state.generation + 1
        state.repair_queued = false
        state.phase = "cancelled"
      end
    end,
    on_closed = function(chat)
      local state = get_state(chat)
      if state then
        close_workflow(chat, state)
      end
    end,
  }
  return prompt
end

function M.setup()
  api.nvim_create_autocmd("User", {
    group = api.nvim_create_augroup("lbs_chinese_polish", { clear = true }),
    pattern = "CodeCompanionChatCleared",
    callback = function(event)
      local chat = require("codecompanion").buf_get_chat(event.data.bufnr)
      if chat then
        local state = get_state(chat)
        if state then
          close_workflow(chat, state)
        end
      end
    end,
  })
end

return M
