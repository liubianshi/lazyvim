local ADAPTER = {
  code = {
    name = "xai",
    model = "grok-code-fast-1",
  },
  advanced_code = {
    name = "aihubmix-claude",
    mode = "claude-sonnet-4-5",
  },
  chat = {
    name = "xai",
    model = "grok-4-fast-reasoning",
  },
  write = {
    name = "aihubmix-openai",
    model = "gpt-5-mini",
  },
  academic = {
    name = "aihubmix-openai",
    model = "gpt-5",
  },
}

local codecampanion_utils = {
  handlers = {
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
  },
}
local PROMPTS = require("llm_prompts")
local function using_prompt(bufnr)
  bufnr = bufnr or 0
  local filetype = vim.api.nvim_get_option_value("filetype", { buf = bufnr })

  if filetype == "quarto" then
    return "apolish"
  end

  if vim.tbl_contains({ "markdown", "norg", "org", "mail" }, filetype) then
    return "polish"
  end

  return "optimize"
end

return { -- olimorris/codecompanion.nvim ------------------------------------- {{{2
  "olimorris/codecompanion.nvim",
  -- version = "v15.8.0",
  keys = {
    -- CodeCompanion keymaps: optimized descriptions and consistent options
    -- Open the CodeCompanion actions menu (normal/visual)
    {
      "<leader>al",
      "<cmd>CodeCompanionActions<CR>",
      desc = "CodeCompanion: Actions",
      mode = { "n", "v", "x" },
      silent = true,
    },

    -- Toggle the CodeCompanion chat panel (normal/visual)
    {
      "<leader>ac",
      "<cmd>CodeCompanionChat Toggle<CR>",
      desc = "CodeCompanion: Chat Toggle",
      mode = { "n", "v" },
      silent = true,
    },

    -- Add the current visual selection to the CodeCompanion chat (visual only)
    {
      "<A-l>",
      "<cmd>CodeCompanionChat Add<CR>",
      desc = "CodeCompanion: Chat Add Selection",
      mode = "v",
      silent = true,
    },
    {
      "<A-o>",
      function()
        -- Determine the appropriate polish prompt based on the filetype.
        local prompt_name = using_prompt()

        -- Get the current mode.
        local current_mode = vim.fn.mode() -- Use vim.fn.mode() for simplicity

        -- If in normal mode, visually select the current line before proceeding.
        if current_mode == "n" then
          vim.cmd.normal({ "V", bang = true }) -- Select current line visually
        -- Ensure we are in some form of visual mode (visual, visual line, visual block)
        elseif not (current_mode == "v" or current_mode == "V" or current_mode == "\22") then -- \22 is Ctrl-V/blockwise
          vim.notify("Mapping <A-o> requires normal or visual mode.", vim.log.levels.WARN)
          return
        end

        -- Construct and execute the CodeCompanion command for the visual selection.
        vim.schedule(function()
          require("codecompanion").prompt(prompt_name)
        end)
      end,
      desc = "CodeCompanion: Optimize selected text", -- Updated description
      mode = { "n", "v" }, -- Retain original modes
    },
  },
  cmd = { "CodeCompanion", "CodeCompanionChat", "CodeCompanionActions", "CodeCompanionHistory" },
  dependencies = {
    "nvim-lua/plenary.nvim",
    "nvim-treesitter/nvim-treesitter",
    "ravitemer/codecompanion-history.nvim",
  },
  init = function()
    vim.cmd([[cabbrev cc CodeCompanion]])
    require("util.spinner"):init()
    local has_fidget, _ = pcall(require, "fidget")
    if has_fidget then
      require("util.fidget"):init()
    end
  end,
  opts = {
    display = {
      chat = {
        show_settings = false,
        auto_scroll = true,
        window = {
          width = 0.375,
          opts = {
            number = false,
            relativenumber = false,
            signcolumn = "yes:1",
          },
        },
      },
      action_palette = {
        provider = "default",
      },
    },
    strategies = {
      chat = {
        adapter = ADAPTER.chat,
        keymaps = {
          send = {
            callback = function(chat)
              vim.cmd("stopinsert")
              chat:add_buf_message({ role = "llm", content = "" })
              chat:submit()
            end,
            index = 1,
            description = "Send",
          },
        },
      },
      inline = {
        adapter = ADAPTER.code,
      },
      cmd = {
        adapter = ADAPTER.code,
      },
    },
    adapters = {
      ["acp"] = {
        gemini_cli = function()
          return require("codecompanion.adapters").extend("gemini_cli", {
            defaults = {
              auth_method = "gemini-api-key", -- "oauth-personal"|"gemini-api-key"|"vertex-ai"
            },
            env = {
              GEMINI_API_KEY = "cmd:" .. os.getenv("HOME") .. "/.private_info.sh gemini",
            },
          })
        end,
      },
      ["aihubmix-gemini"] = function()
        return require("codecompanion.adapters").extend("openai_compatible", {
          roles = {
            llm = "model",
          },
          env = {
            url = "https://aihubmix.com",
            api_key = "cmd:" .. os.getenv("HOME") .. "/.private_info.sh aihubmix",
          },
          handlers = {
            chat_output = codecampanion_utils.handlers.gemini.chat_output,
          },
          schema = {
            model = {
              default = "gemini-2.5-pro-search",
              choices = {
                ["gemini-2.5-pro-search"] = { opts = { can_reason = true, has_vision = true } },
                ["gemini-2.5-pro"] = { opts = { can_reason = true, has_vision = true } },
                ["gemini-2.5-flash"] = { opts = { can_reason = true, has_vision = true } },
                ["gemini-2.5-flash-search"] = { opts = { can_reason = true, has_vision = true } },
                ["gemini-2.5-flash-lite"] = { opts = { can_reason = true, has_vision = true } },
                ["gemini-2.5-flash-nothink"] = { opts = { can_reason = false, has_vision = true } },
              },
            },
            temperature = {
              default = 0.4,
            },
          },
        })
      end,
      ["gemini"] = function()
        return require("codecompanion.adapters").extend("gemini", {
          env = {
            api_key = "cmd:" .. os.getenv("HOME") .. "/.private_info.sh gemini",
          },
        })
      end,
      ["xai"] = function()
        return require("codecompanion.adapters").extend("xai", {
          env = {
            api_key = "cmd:" .. os.getenv("HOME") .. "/.private_info.sh xai",
          },
          schema = {
            model = {
              default = "grok-4",
              choices = {
                "grok-4",
                "grok-4-fast-reasoning",
                "grok-4-fast-non-reasoning",
                "grok-code-fast-1",
              },
            },
          },
        })
      end,
      ["aihubmix-openai"] = function()
        return require("codecompanion.adapters").extend("openai", {
          url = "https://aihubmix.com/v1/chat/completions",
          env = {
            api_key = "cmd:" .. os.getenv("HOME") .. "/.private_info.sh aihubmix",
          },
          schema = {
            model = {
              default = "gpt-5.1",
              choices = {
                ["gpt-5.1"] = { opts = { has_vision = true, can_reason = true, can_use_tools = true } },
                ["gpt-5"] = { opts = { has_vision = true, can_reason = false, can_use_tools = true } },
                ["gpt-5-mini"] = { opts = { has_vision = true, can_reason = false, can_use_tools = true } },
                ["gpt-5-nano"] = { opts = { has_vision = true, can_reason = false, can_use_tools = true } },
                ["aihubmix-router"] = { opts = { has_vision = true, can_reason = false, can_use_tools = true } },
                ["o3"] = { opts = { can_reason = true, can_use_tools = true } },
                ["o4-mini"] = { opts = { can_reason = true, can_use_tools = true } },
              },
            },
            temperature = {
              default = 0.4,
            },
          },
        })
      end,
      ["aihubmix-xai"] = function()
        return require("codecompanion.adapters").extend("openai_compatible", {
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
        })
      end,
      ["aihubmix-claude"] = function()
        return require("codecompanion.adapters").extend("anthropic", {
          env = {
            api_key = "cmd:" .. os.getenv("HOME") .. "/.private_info.sh aihubmix",
          },
          url = "https://aihubmix.com/v1/messages",
          schema = {
            model = {
              default = "claude-haiku-4-5",
            },
          },
        })
      end,
      ["deepseek"] = function()
        return require("codecompanion.adapters").extend("deepseek", {
          env = {
            api_key = "cmd:" .. os.getenv("HOME") .. "/.private_info.sh deepseek",
          },
          schema = {
            model = {
              default = "deepseek-reasoner",
            },
          },
        })
      end,
    },
    prompt_library = {
      ["Text Polish"] = {
        strategy = "inline",
        description = "Polish the selected text",
        opts = {
          index = 13,
          adapter = ADAPTER.write,
          is_slash_cmd = true,
          modes = { "v" },
          short_name = "polish",
          auto_submit = true,
          user_prompt = false,
          stop_context_insertion = true,
          ignore_system_prompt = true,
          placement = "replace",
        },
        prompts = {
          {
            role = "system",
            content = PROMPTS.improve_writing,
            opts = {
              visible = false,
            },
          },
          {
            role = "user",
            content = function(context)
              local code = require("codecompanion.helpers.actions").get_code(context.start_line, context.end_line)
              return string.format("Please polish the text from buffer %d:\n\n```\n%s\n```\n\n", context.bufnr, code)
            end,
            opts = {
              contains_code = true,
            },
          },
        },
      },
      ["Optimize and Comment"] = {
        strategy = "inline",
        description = "Optimize and add necessary comments",
        opts = {
          index = 14,
          short_name = "optimize",
          adapter = ADAPTER.code,
          is_slash_cmd = true,
          modes = { "v" },
          auto_submit = true,
          user_prompt = false,
          stop_context_insertion = true,
          placement = "replace",
        },
        prompts = {
          {
            role = "system",
            content = PROMPTS.optimize_with_comment,
            opts = {
              visible = false,
            },
          },
          {
            role = "user",
            content = function(context)
              local code = require("codecompanion.helpers.actions").get_code(context.start_line, context.end_line)
              return string.format(
                "Please optimize the text from buffer %d:\n\n```%s\n%s\n```\n\n",
                context.bufnr,
                context.filetype,
                code
              )
            end,
            opts = {
              contains_code = true,
            },
          },
        },
      },
      ["Translate and Polish"] = {
        strategy = "inline",
        description = "Translate then Polish the selected text",
        opts = {
          index = 15,
          adapter = ADAPTER.write,
          is_slash_cmd = true,
          modes = { "v" },
          short_name = "trans",
          auto_submit = true,
          user_prompt = false,
          stop_context_insertion = true,
          placement = "replace",
          ignore_system_prompt = true,
        },
        prompts = {
          {
            role = "system",
            content = PROMPTS.translate_then_improve_academic_writing,
            opts = {
              visible = false,
            },
          },
          {
            role = "user",
            content = function(context)
              local lines = vim.api.nvim_buf_get_lines(context.bufnr, context.start_line - 1, context.end_line, false)
              local grouped_strings = table.concat(require("util").join_strings_by_paragraph(lines), "\n")

              local head_chars = vim.trim(grouped_strings):sub(1, 20)
              local is_cjk = false
              for _, char in ipairs(vim.fn.split(head_chars, "\\zs")) do
                if is_cjk_character(char) then
                  is_cjk = true
                  break
                end
              end

              return string.format("%s\n\n%s", (is_cjk and "en_US" or "zh_CN"), grouped_strings)
            end,
            opts = {
              contains_code = true,
            },
          },
        },
      },
      ["Academic Polish"] = {
        strategy = "inline",
        description = "Polish the selected text",
        opts = {
          index = 16,
          adapter = ADAPTER.academic,
          is_slash_cmd = true,
          modes = { "v" },
          short_name = "apolish",
          auto_submit = true,
          user_prompt = false,
          stop_context_insertion = true,
          placement = "replace",
        },
        prompts = {
          {
            role = "system",
            content = PROMPTS.improve_academic_writing,
            opts = {
              visible = false,
            },
          },
          {
            role = "user",
            content = function(context)
              local code = require("codecompanion.helpers.actions").get_code(context.start_line, context.end_line)
              return string.format("Please polish the text from buffer %d:\n\n```\n%s\n```\n\n", context.bufnr, code)
            end,
            opts = {
              contains_code = true,
            },
          },
        },
      },
    },
    extensions = {
      history = {
        enabled = true,
        opts = {
          auto_save = true,
          -- Keymap to open history from chat buffer (default: gh)
          keymap = "gh",
          -- Automatically generate titles for new chats
          auto_generate_title = true,
          -- On exiting and entering neovim, loads the last chat on opening chat
          title_generation_opts = {
            adapter = "aihubmix-openai",
            model = "gpt-5-nano",
            refresh_every_n_prompts = 2,
          },
          summary = {
            generation_opts = {
              adapter = "aihubmix-openai",
              model = "gpt-5-mini",
            },
          },
          continue_last_chat = false,
          -- When chat is cleared with `gx` delete the chat from history
          delete_on_clearing_chat = false,
          -- Picker interface ("telescope" or "default")
          picker = "snacks",
          -- Enable detailed logging for history extension
          enable_logging = false,
          -- Directory path to save the chats
          dir_to_save = vim.fn.stdpath("data") .. "/codecompanion-history",
        },
      },
      mcphub = {
        callback = "mcphub.extensions.codecompanion",
        opts = {
          show_result_in_chat = true, -- Show mcp tool results in chat
          make_vars = true, -- Convert resources to #variables
          make_slash_commands = true, -- Add prompts as /slash commands
        },
      },
    },
  },
  config = function(_, opts)
    local codecompanion = require("codecompanion")
    codecompanion.setup(opts)
  end,
}
