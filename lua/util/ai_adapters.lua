-- Base Adapter Definitions
-- Separated configuration from logic. Uses cached 'secret_cmd' for cleanliness.

---@class LazyVim.AI.Adapter.Schema
---@field default any
---@field choices? table<string, any>|string[]

---@class LazyVim.AI.Adapter.Opts
---@field env? table<string, string>
---@field roles? table<string, string>
---@field handlers? table<string, string|function>
---@field schema? table<string, LazyVim.AI.Adapter.Schema>
---@field url? string

---@class LazyVim.AI.Adapter
---@field base string
---@field opts? LazyVim.AI.Adapter.Opts

---@class LazyVim.AI.Adapters
---@field acp? table<string, LazyVim.AI.Adapter>
---@field http? table<string, LazyVim.AI.Adapter>

local M = {}

-- Pre-calculate common paths to avoid repeated system calls during adapter construction
local home = os.getenv("HOME") or ""
local secret_cmd = "cmd:" .. home .. "/.private_info.sh "

-- User configuration: Mapping intents (e.g., 'code', 'chat') to specific provider/model pairs
-- stylua: ignore start
M.use_models = {
  background    = { name = "xai",             model = "grok-4-1-fast-non-reasoning" },
  code          = { name = "xai",             model = "grok-code-fast-1"            },
  advanced_code = { name = "aihubmix_claude", model = "claude-sonnet-4-5"           },
  chat          = { name = "aihubmix_gemini", model = "gemini-3-pro-preview"        },
  write         = { name = "aihubmix_gemini", model = "gemini-3-flash-preview"      },
  academic      = { name = "aihubmix_gemini", model = "gemini-3-pro-preview"        },
}
-- stylua: ignore end

-- Custom Handlers
M.handlers = {
  gemini = {
    ---Parse Gemini output for CodeCompanion
    ---@param self table The adapter instance
    ---@param data string The raw data chunk
    ---@return table|nil
    chat_output = function(self, data)
      if not data or data == "" then
        return
      end

      local utils = require("codecompanion.utils.adapters")
      -- Optimization: Flattened logic and reduced nesting for readability
      local ok, json = pcall(vim.json.decode, utils.clean_streamed_data(data), { luanil = { object = true } })

      if not ok or not json.choices or #json.choices == 0 then
        return
      end

      local choice = json.choices[1]
      local reason = choice.finish_reason

      -- Check for error stops
      if reason and reason ~= "stop" and reason ~= "" then
        return {
          status = "error",
          output = string.format("Stream stopped. Finish reason: '%s'", reason),
        }
      end

      -- Handle both streaming (delta) and standard (message) responses
      local delta = (self.opts and self.opts.stream) and choice.delta or choice.message

      if delta then
        return {
          status = "success",
          output = {
            role = delta.role or "llm",
            content = delta.content or "",
          },
        }
      end
    end,
  },
}

---@type LazyVim.AI.Adapters
M.adapter_definitions = {
  acp = {
    gemini_cli = {
      base = "gemini_cli",
      opts = {
        env = { GEMINI_API_KEY = secret_cmd .. "gemini" },
      },
    },
  },
  http = {
    ["aihubmix_gemini"] = {
      base = "openai_compatible",
      opts = {
        roles = { llm = "model" },
        env = {
          url = "https://aihubmix.com",
          api_key = secret_cmd .. "aihubmix",
          chat_url = "/v1/chat/completions",
        },
        handlers = {
          -- Reference resolved at runtime to avoid definition order issues
          chat_output = "M.handlers.gemini.chat_output",
        },
        schema = {
          model = {
            default = "gemini-3.0-flash-exp",
            choices = {
              ["gemini-3-pro-preview"] = {
                formatted_name = "Gemini 3 Pro",
                opts = { can_reason = true, has_vision = true },
              },
              ["gemini-3-flash-preview"] = {
                formatted_name = "Gemini 3 Flash",
                opts = { can_reason = true, has_vision = true },
              },
            },
          },
          temperature = { default = 0.4 },
        },
      },
    },
    gemini = {
      base = "gemini",
      opts = {
        env = { api_key = secret_cmd .. "gemini" },
      },
    },
    xai = {
      base = "xai",
      opts = {
        env = { api_key = secret_cmd .. "xai" },
        schema = {
          model = {
            default = "grok-4-1-fast-reasoning",
            choices = { "grok-4-1-fast-non-reasoning", "grok-4-1-fast-reasoning", "grok-4", "grok-code-fast-1" },
          },
        },
      },
    },
    ["aihubmix_openai"] = {
      base = "openai",
      opts = {
        url = "https://aihubmix.com/v1/chat/completions",
        env = { api_key = secret_cmd .. "aihubmix" },
        schema = {
          model = {
            default = "gpt-5.1",
            choices = {
              ["gpt-5.2"] = { opts = { has_vision = true, can_reason = true, can_use_tools = true } },
              ["qwen3-max"] = { opts = { has_vision = true, can_reason = true, can_use_tools = true } },
            },
          },
          temperature = { default = 0.4 },
        },
      },
    },
    ["aihubmix_xai"] = {
      base = "openai_compatible",
      opts = {
        env = {
          url = "https://aihubmix.com",
          api_key = secret_cmd .. "aihubmix",
          chat_url = "/v1/chat/completions",
        },
        schema = {
          model = {
            default = "grok-4",
            choices = {
              ["grok-4"] = { opts = { has_vision = false, can_reason = true, can_use_tools = true } },
              ["grok-3"] = { opts = { has_vision = false, can_reason = false, can_use_tools = true } },
              ["grok-3-mini"] = { opts = { has_vision = false, can_reason = false, can_use_tools = true } },
            },
          },
          temperature = { default = 0.4 },
        },
      },
    },
    ["aihubmix_claude"] = {
      base = "anthropic",
      opts = {
        env = { api_key = secret_cmd .. "aihubmix" },
        url = "https://aihubmix.com/v1/messages",
        schema = {
          model = { default = "claude-sonnet-4-5" },
        },
      },
    },
  },
}

---Resolves string references to functions in handler options
---@param opts table The options table to resolve
---@return table opts The resolved options
local function resolve_handlers(opts)
  if opts.handlers and opts.handlers.chat_output == "M.handlers.gemini.chat_output" then
    opts.handlers.chat_output = M.handlers.gemini.chat_output
  end
  return opts
end

---Main entry point: Generates and registers all CodeCompanion adapters
---@return table adapters The final table of configured adapters
function M.codecompanion_adapters()
  local adapters = { acp = {}, http = {} }
  -- 1. Register Base Adapters from definitions
  for section, definitions in pairs(M.adapter_definitions) do
    for name, def in pairs(definitions) do
      adapters[section][name] = function()
        local opts = resolve_handlers(vim.deepcopy(def.opts))
        return require("codecompanion.adapters").extend(def.base, opts)
      end
    end
  end

  -- 2. Register Dynamic Adapters (Aliases defined in M.use_models)
  for name, config in pairs(M.use_models) do
    -- Locate the base factory function (check both sections)
    local base_factory = adapters.http[config.name] or adapters.acp[config.name]

    if base_factory then
      local section = adapters.acp[config.name] and "acp" or "http"

      -- Create a wrapper that inherits from base but overrides the model
      adapters[section][name] = function()
        local adapter = base_factory()
        if adapter.schema and adapter.schema.model then
          adapter.schema.model.default = config.model
        end
        return adapter
      end
    end
  end

  return adapters
end

return M
