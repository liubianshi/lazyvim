local Edit = {}
local api = vim.api
local bindings = {}
local next_id = 0
local tool_name = "chinese_polish_edit"

local function notify(message)
  vim.notify(message, vim.log.levels.WARN, { title = "中文润色" })
end

local function manual_tools(chat)
  local approvals = require("codecompanion.interactions.chat.tools.approvals")
  approvals:set_mode(chat.bufnr, { mode = "ask" })
  chat.tools.tools_config.opts.auto_submit_success = false
  chat.tools.tools_config.opts.auto_submit_errors = false
end

local function close_review(review)
  if review.group then
    pcall(api.nvim_del_augroup_by_id, review.group)
    review.group = nil
  end
  if review.ui then
    review.ui.resolved = true
    pcall(review.ui.clear, review.ui)
    pcall(review.ui.close, review.ui)
  end
end

local function settle(review, outcome, message)
  if review.done then
    return
  end
  review.done = true
  local binding = review.binding
  binding.review = nil
  close_review(review)
  if outcome == "accepted" or outcome == "rejected" or outcome == "invalid" then
    binding.candidate = nil
  end
  binding.handlers.settled(outcome, review.candidate, review.output_cb ~= nil, message)
  if review.output_cb then
    manual_tools(binding.chat)
    review.output_cb({ status = outcome == "invalid" and "error" or "success", data = message })
    review.output_cb = nil
  end
end

local function open_review(binding, candidate, output_cb)
  local review = { binding = binding, candidate = candidate, output_cb = output_cb }
  binding.review = review
  local valid, error_message = binding.handlers.validate(candidate)
  if not valid then
    settle(review, "invalid", error_message)
    return
  end
  next_id = next_id + 1
  local ok, ui = pcall(function()
    return require("codecompanion.helpers").show_diff({
      diff_id = next_id,
      chat_bufnr = binding.chat.bufnr,
      from_lines = vim.split(candidate.original, "\n", { plain = true }),
      to_lines = vim.split(candidate.text, "\n", { plain = true }),
      ft = "text",
      inline = false,
      title = "中文润色：仅当前段，不自动保存",
      banner = "g2 接受当前段全部修改 │ g3 拒绝 │ g4／q／Esc 暂停审阅 │ {／} 导航",
      skip_default_keymaps = true,
    })
  end)
  if not ok or not ui then
    settle(
      review,
      "cancelled",
      "无法打开原生 diff，原稿未修改；检查 CodeCompanion 后可重新审阅。"
    )
    return notify("无法打开原生 diff，原稿未修改；可用 <leader>aA 重试。")
  end
  review.ui = ui
  review.group = api.nvim_create_augroup("lbs_polish_diff_" .. next_id, { clear = true })
  local function cancel()
    settle(review, "cancelled", "已暂停审阅，原稿未修改；可用 <leader>aA 重新打开。")
  end
  api.nvim_create_autocmd("WinClosed", {
    group = review.group,
    pattern = tostring(ui.winnr),
    once = true,
    callback = cancel,
  })
  api.nvim_create_autocmd("BufWipeout", { group = review.group, buffer = ui.bufnr, once = true, callback = cancel })
  local maps = {
    g1 = function()
      notify("每段必须单独审阅；g2 仅接受当前段，不授权后续自动修改。")
    end,
    g2 = function()
      if review.done then
        return
      end
      local accepted, accept_error = binding.handlers.accept(candidate)
      if not accepted then
        settle(review, "invalid", accept_error)
        return notify(accept_error)
      end
      settle(review, "accepted", "用户已接受当前段修改；仅修改 buffer，尚未保存。")
    end,
    g3 = function()
      settle(review, "rejected", "用户拒绝当前候选，原稿未修改；等待用户提供新的修改要求。")
    end,
    g4 = cancel,
    q = cancel,
    ["<Esc>"] = cancel,
  }
  for lhs, callback in pairs(maps) do
    api.nvim_buf_set_keymap(
      ui.bufnr,
      "n",
      lhs,
      "",
      { callback = callback, noremap = true, silent = true, nowait = true }
    )
  end
end

function Edit.bind(chat, handlers)
  bindings[chat.bufnr] = { chat = chat, handlers = handlers }
  local refresh = chat.tools.refresh
  chat.tools.refresh = function(tools, opts)
    refresh(tools, opts)
    tools.tools_config = { opts = tools.tools_config.opts, groups = {}, [tool_name] = tools.tools_config[tool_name] }
    manual_tools(chat)
    return tools
  end
  local execute = chat.tools.execute
  chat.tools.execute = function(tools, current_chat, calls)
    tools:refresh({ adapter = current_chat.adapter })
    return execute(tools, current_chat, calls)
  end
  chat.tools:refresh({ adapter = chat.adapter })
end

function Edit.pending(chat)
  local binding = bindings[chat.bufnr]
  return binding and binding.review ~= nil or false
end

function Edit.cancel(chat, drop_candidate)
  local binding = bindings[chat.bufnr]
  if not binding then
    return
  end
  if binding.review then
    if binding.chat.tool_orchestrator then
      binding.chat.tool_orchestrator:cancel()
      binding.chat.tool_orchestrator = nil
    end
    settle(binding.review, "cancelled", "本次审阅已取消，原稿未修改。")
  end
  if drop_candidate then
    binding.candidate = nil
  end
end

function Edit.release(chat)
  local binding = bindings[chat.bufnr]
  if binding then
    binding.closing = true
  end
  Edit.cancel(chat, true)
  bindings[chat.bufnr] = nil
end

function Edit.reopen(chat)
  local binding = bindings[chat.bufnr]
  if not binding or not binding.candidate then
    return notify("没有待审阅候选，请先完成第五步。")
  end
  if binding.review then
    if binding.review.ui and api.nvim_win_is_valid(binding.review.ui.winnr) then
      api.nvim_set_current_win(binding.review.ui.winnr)
    end
    return
  end
  if chat.current_request then
    return notify("请先等待当前请求完成。")
  end
  open_review(binding, binding.candidate)
end

Edit.tool = {
  name = tool_name,
  cmds = {
    function(tools, args, opts)
      local binding = bindings[tools.chat.bufnr]
      if not binding then
        return opts.output_cb({
          status = "error",
          data = "此聊天没有活动的中文润色原稿，拒绝编辑。",
        })
      end
      manual_tools(binding.chat)
      if binding.review then
        return opts.output_cb({ status = "error", data = "当前候选尚未处理，拒绝并行提交。" })
      end
      local candidate, error_message = binding.handlers.propose(args)
      if not candidate then
        return opts.output_cb({ status = "error", data = error_message })
      end
      if candidate.text == candidate.original then
        binding.handlers.settled(
          "unchanged",
          candidate,
          true,
          "原文无需修改；留在当前段，由用户决定下一步。"
        )
        return opts.output_cb({
          status = "success",
          data = "原文无需修改，未写回；等待用户决定下一步。",
        })
      end
      binding.candidate = candidate
      open_review(binding, candidate, opts.output_cb)
    end,
  },
  schema = {
    type = "function",
    ["function"] = {
      name = tool_name,
      description = "仅在第五步提交当前绑定段落的润色正文供用户审阅。用户接受前不修改原稿，不保存文件。不得指定文件或越出当前段。",
      parameters = {
        type = "object",
        additionalProperties = false,
        properties = {
          replacement = {
            type = "string",
            description = "当前段完整替换正文，原样保留引文；不添加围栏或改动说明。",
          },
          summary = { type = "string", description = "可选的简短修改说明。" },
        },
        required = { "replacement" },
      },
    },
  },
  output = {
    cancelled = function(self, meta)
      local chat = meta.tools.chat
      local binding = bindings[chat.bufnr]
      local message = "中文润色审阅已取消，原稿未修改。"
      chat:add_tool_output(self, message, binding and binding.closing and "" or message)
    end,
    success = function(self, stdout, meta)
      meta.tools.chat:add_tool_output(self, table.concat(stdout or {}, "\n"), table.concat(stdout or {}, "\n"))
    end,
    error = function(self, stderr, meta)
      meta.tools.chat:add_tool_output(self, table.concat(stderr or {}, "\n"), table.concat(stderr or {}, "\n"))
    end,
  },
}

function Edit.config()
  return {
    callback = function()
      return Edit.tool
    end,
    description = "中文润色：仅提交当前段修改供人工审阅",
    visible = false,
    opts = { require_approval_before = false, require_confirmation_after = false, protect = true, judge = false },
  }
end

return Edit
