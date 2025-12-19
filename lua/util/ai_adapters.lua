local M = {}

M.use_models = {
  background = {
    name = "xai",
    model = "grok-4-1-fast-non-reasoning",
  },
  code = {
    name = "xai",
    model = "grok-code-fast-1",
  },
  advanced_code = {
    -- name = "aihubmix-claude",
    -- mode = "claude-sonnet-4-5",
    name = "aihubmix-gemini",
    model = "gemini-3-pro-preview-search",
  },
  chat = {
    name = "aihubmix-gemini",
    model = "gemini-3-pro-preview-search",
  },
  write = {
    name = "aihubmix-gemini",
    model = "gemini-3-flash-preview",
  },
  academic = {
    name = "aihubmix-gemini",
    model = "gemini-3-pro-preview",
  },
}

M.handlers = {
  gemini = {
    chat_output = function(self, data)
      local output = {}
      local utils = require("codecompanion.utils.adapters")
      if data and data ~= "" then
        local data_mod = utils.clean_streamed_data(data)
        local ok, json = pcall(vim.json.decode, data_mod, { luanil = { object = true } })

        if ok and json.choices and #json.choices > 0 then
          local choice = json.choices[1]

          if choice.finish_reason then
            local reason = choice.finish_reason
            if reason ~= "stop" and reason ~= "" then
              return {
                status = "error",
                output = "The stream was stopped with the a finish_reason of '" .. reason .. "'",
              }
            end
          end

          local delta = (self.opts and self.opts.stream) and choice.delta or choice.message

          if delta then
            if delta.role then
              output.role = delta.role
            else
              output.role = "llm"
            end

            -- Some providers may return empty content
            if delta.content then
              output.content = delta.content
            else
              output.content = ""
            end

            return {
              status = "success",
              output = output,
            }
          end
        end
      end
    end,
  },
}

-- Definitions of base adapters (configuration only, no implementation logic)
M.adapter_definitions = {
  acp = {
    ["gemini_cli"] = {
      base = "gemini_cli",
      opts = {
        defaults = {
          auth_method = "gemini-api-key",
        },
        env = {
          GEMINI_API_KEY = "cmd:" .. os.getenv("HOME") .. "/.private_info.sh gemini",
        },
      },
    },
  },
  http = {
    ["aihubmix-gemini"] = {
      base = "openai_compatible",
      opts = {
        roles = {
          llm = "model",
        },
        env = {
          url = "https://aihubmix.com",
          api_key = "cmd:" .. os.getenv("HOME") .. "/.private_info.sh aihubmix",
          chat_url = "/v1/chat/completions",
        },
        handlers = {
          chat_output = "M.handlers.gemini.chat_output", -- Placeholder, resolved in runtime for cleaner data
        },
        schema = {
          model = {
            default = "gemini-2.0-flash-exp",
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
          temperature = {
            default = 0.4,
          },
        },
      },
    },
    ["gemini"] = {
      base = "gemini",
      opts = {
        env = {
          api_key = "cmd:" .. os.getenv("HOME") .. "/.private_info.sh gemini",
        },
      },
    },
    ["xai"] = {
      base = "xai",
      opts = {
        env = {
          api_key = "cmd:" .. os.getenv("HOME") .. "/.private_info.sh xai",
        },
        schema = {
          model = {
            default = "grok-4-1-fast-reasoning",
            choices = {
              "grok-4-1-fast-non-reasoning",
              "grok-4-1-fast-reasoning",
              "grok-4",
              "grok-code-fast-1",
            },
          },
        },
      },
    },
    ["aihubmix-openai"] = {
      base = "openai",
      opts = {
        url = "https://aihubmix.com/v1/chat/completions",
        env = {
          api_key = "cmd:" .. os.getenv("HOME") .. "/.private_info.sh aihubmix",
        },
        schema = {
          model = {
            default = "gpt-5.1",
            choices = {
              ["gpt-5.1"] = { opts = { has_vision = true, can_reason = true, can_use_tools = true } },
              ["qwen3-max"] = { opts = { has_vision = true, can_reason = true, can_use_tools = true } },
            },
          },
          temperature = {
            default = 0.4,
          },
        },
      },
    },
    ["aihubmix-xai"] = {
      base = "openai_compatible",
      opts = {
        env = {
          url = "https://aihubmix.com",
          api_key = "cmd:" .. os.getenv("HOME") .. "/.private_info.sh aihubmix",
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
          temperature = {
            default = 0.4,
          },
        },
      },
    },
    ["aihubmix-claude"] = {
      base = "anthropic",
      opts = {
        env = {
          api_key = "cmd:" .. os.getenv("HOME") .. "/.private_info.sh aihubmix",
        },
        url = "https://aihubmix.com/v1/messages",
        schema = {
          model = {
            default = "claude-sonnet-4-5",
          },
        },
      },
    },
    ["deepseek"] = {
      base = "deepseek",
      opts = {
        env = {
          api_key = "cmd:" .. os.getenv("HOME") .. "/.private_info.sh deepseek",
        },
        schema = {
          model = {
            default = "deepseek-reasoner",
          },
        },
      },
    },
  },
}

-- Private helper to resolve handlers references in definition
local function resolve_handlers(opts)
  if opts.handlers and opts.handlers.chat_output == "M.handlers.gemini.chat_output" then
    opts.handlers.chat_output = M.handlers.gemini.chat_output
  end
  return opts
end

function M.codecompanion_adapters()
  local adapters = {
    acp = {},
    http = {},
  }

  -- 1. Register Base Adapters
  for section, definitions in pairs(M.adapter_definitions) do
    for name, def in pairs(definitions) do
      adapters[section][name] = function()
        local extend_adapter = require("codecompanion.adapters").extend
        local opts = vim.deepcopy(def.opts)
        opts = resolve_handlers(opts)
        return extend_adapter(def.base, opts)
      end
    end
  end

  -- Helper to find factory function (now constructed from definition)
  local function get_factory(name)
    if adapters.http[name] then return adapters.http[name] end
    if adapters.acp[name] then return adapters.acp[name] end
    return nil
  end

  -- 2. Register Dynamic Adapters (chat, code, etc.)
  for name, config in pairs(M.use_models) do
    local factory = get_factory(config.name)

    if factory then
      -- Define the adapter function which inherits from the base factory but overrides the model
      local adapter_func = function()
        local adapter = factory() -- Instantiate the base adapter
        if adapter.schema and adapter.schema.model then
          adapter.schema.model.default = config.model
        end
        return adapter
      end

      -- Assign to appropriate category (same as the factory's category)
      if M.adapter_definitions.acp[config.name] then
        adapters.acp[name] = adapter_func
      else
        adapters.http[name] = adapter_func
      end
    end
  end

  return adapters
end

return M
