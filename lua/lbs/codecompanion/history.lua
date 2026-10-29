local M = {}

local function truncate_content(content)
  local suffix = " [truncated]"
  local boundary = 1000 - #suffix + 1
  while content:byte(boundary) >= 128 and content:byte(boundary) < 192 do
    boundary = boundary - 1
  end
  return content:sub(1, boundary - 1) .. suffix
end

local function describe_error(error)
  if type(error) ~= "table" then
    return tostring(error or "标题生成请求失败。")
  end
  if type(error.stderr) == "string" and error.stderr ~= "" then
    return error.stderr
  end
  if type(error.stderr) == "table" and error.stderr.status then
    return string.format("HTTP %s：标题生成请求失败。", tostring(error.stderr.status))
  end
  return type(error.message) == "string" and error.message or "标题生成请求失败。"
end

function M.setup()
  ---@class LBS.History.TitleGenerator: CodeCompanion.History.TitleGenerator
  ---@field _lbs_compatible? boolean
  local Generator = require("codecompanion._extensions.history.title_generator") --[[@as LBS.History.TitleGenerator]]
  if Generator._lbs_compatible then
    return
  end

  local generate = Generator.generate
  function Generator:generate(chat, callback, is_refresh)
    local messages = vim.deepcopy(chat.messages or {})
    for _, message in ipairs(messages) do
      if type(message.content) == "string" then
        local content = vim.trim(message.content)
        if #content > 1000 then
          message.content = truncate_content(content)
        end
      end
    end
    local snapshot = vim.tbl_extend("force", {}, chat, { messages = messages })
    return generate(self, snapshot, callback, is_refresh)
  end

  function Generator:_make_adapter_request(chat, prompt, callback)
    local opts = self.opts.title_generation_opts or {}
    local settings = vim.deepcopy(opts.adapter and {} or chat.settings or {})
    if opts.model then
      settings.model = opts.model
    end
    local Background = require("codecompanion.interactions.background")
    local adapter = opts.adapter or chat.adapter
    if type(adapter) == "table" and adapter.type == "acp" then
      return callback(nil, "无法初始化标题生成所需的 HTTP 适配器。")
    end
    ---@cast adapter string|CodeCompanion.HTTPAdapter
    local ok, background = pcall(Background.new, { adapter = adapter, settings = settings })
    if not ok or not background then
      return callback(nil, "无法初始化标题生成所需的 HTTP 适配器。")
    end

    local completed = false
    local function finish(title, error_message)
      if completed then
        return
      end
      completed = true
      return callback(title, error_message)
    end

    local sent, request = pcall(background.ask, background, { { role = "user", content = prompt } }, {
      method = "async",
      silent = true,
      on_done = function(result)
        if result and result.status == "success" then
          local content = result.output and result.output.content
          if type(content) == "string" and vim.trim(content) ~= "" then
            return finish(vim.trim(content))
          end
        end
        return finish(nil, "标题响应为空或无法解析。")
      end,
      on_error = function(error)
        return finish(nil, describe_error(error))
      end,
    })
    if not sent then
      return finish(nil, "无法发送标题生成请求。")
    end
    return request
  end

  Generator._lbs_compatible = true
end

return M
