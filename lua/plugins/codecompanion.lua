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

return { -- olimorris/codecompanion.nvim ------------------------------------- {{{2
  "olimorris/codecompanion.nvim",
  keys = {
    { "<leader>al", "<cmd>CodeCompanionActions<cr>", desc = "CodeCompanion Actions", mode = { "n", "v" } },
    { "<leader>ac", "<cmd>CodeCompanionChat Toggle<cr>", desc = "CodeCompanion Toggle", mode = { "n", "v" } },
    { "<leader>ap", "<cmd>CodeCompanionChat Add<cr>", desc = "CodeCompanion Toggle", mode = { "v" } },
    {
      "<A-o>",
      function()
        -- Determine the appropriate polish prompt based on the filetype.
        local filetype = vim.bo.filetype
        local prompt_name = (filetype == "quarto") and "apolish" or "polish"

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
      desc = "CodeCompanion: Polish selected text (Academic for Quarto)", -- Updated description
      mode = { "n", "v" }, -- Retain original modes
    },
  },
  cmd = { "CodeCompanion", "CodeCompanionChat", "CodeCompanionActions" },
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
      diff = {
        provider = "default",
      },
      action_palette = {
        provider = "default",
      },
    },
    strategies = {
      chat = {
        adapter = "gemini-search",
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
        adapter = "gemini-thinking",
      },
      cmd = {
        adapter = "gemini-flash",
      },
    },
    adapters = {
      ["gemini-search"] = function()
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
            inline_output = codecampanion_utils.handlers.gemini.inline_output,
          },
          schema = {
            model = {
              default = "gemini-2.5-pro-preview-05-06-search",
            },
            temperature = {
              default = 1,
            },
          },
        })
      end,
      ["gemini-flash"] = function()
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
              default = "gemini-2.5-flash-preview-04-17",
            },
            temperature = {
              default = 0.4,
            },
          },
        })
      end,
      ["gemini-thinking"] = function()
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
              default = "gemini-2.5-pro-preview-05-06",
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
              default = "grok-3",
            },
          },
        })
      end,
      ["aihubmix-opeanai"] = function()
        return require("codecompanion.adapters").extend("openai_compatible", {
          env = {
            url = "https://aihubmix.com",
            api_key = "cmd:" .. os.getenv("HOME") .. "/.private_info.sh aihubmix",
          },
          schema = {
            model = {
              default = "gpt-4.1",
            },
            temperature = {
              default = 0.4,
            },
          },
        })
      end,
      ["deepseek-r1"] = function()
        return require("codecompanion.adapters").extend("openai_compatible", {
          env = {
            url = "https://aihubmix.com",
            api_key = "cmd:" .. os.getenv("HOME") .. "/.private_info.sh aihubmix",
          },
          schema = {
            model = {
              default = "DeepSeek-R1",
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
          adapter = {
            name = "gemini-flash",
          },
          is_slash_cmd = true,
          modes = { "v" },
          short_name = "polish",
          auto_submit = true,
          user_prompt = false,
          stop_context_insertion = true,
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
          adapter = {
            name = "gemini-thinking",
          },
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
          adapter = {
            name = "aihubmix-opeanai",
          },
          is_slash_cmd = true,
          modes = { "v" },
          short_name = "trans",
          auto_submit = true,
          user_prompt = false,
          stop_context_insertion = true,
          placement = "replace",
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
          adapter = {
            name = "gemini-thinking",
          },
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
          -- Keymap to open history from chat buffer (default: gh)
          keymap = "gh",
          -- Automatically generate titles for new chats
          auto_generate_title = false,
          -- On exiting and entering neovim, loads the last chat on opening chat
          continue_last_chat = false,
          -- When chat is cleared with `gx` delete the chat from history
          delete_on_clearing_chat = false,
          -- Picker interface ("telescope" or "default")
          picker = "default",
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
    require("codecompanion").setup(opts)
    local function chat_save(buf, opt)
      buf = buf or 0
      opt = opt or { fargs = {} }
      -- 获取当前缓冲区的聊天内容
      local success, chat = pcall(function()
        local codecompanion = require("codecompanion")
        return codecompanion.buf_get_chat(buf)
      end)

      -- 检查是否在CodeCompanion聊天缓冲区
      if not success or chat == nil then
        vim.notify("CodeCompanionSave should only be called from CodeCompanion chat buffers", vim.log.levels.ERROR)
        return
      end

      -- 生成文件名
      local save_name
      if #opt.fargs == 0 then
        -- 如果没有提供文件名参数，则从第一条用户消息生成文件名
        for _, output in ipairs(chat.messages) do
          if output.role == "user" and output.content then
            -- 清理内容中的特殊字符和空格
            save_name = output
              .content
              :gsub("[?？%p%s]*$", "") -- 去除末尾的标点和空格
              :gsub("[?/%\\%s]", "-") -- 替换路径分隔符和空格为-
              :gsub("？", "-") -- 替换路径分隔符和空格为-
              :sub(1, 100) -- 限制最大长度
              .. ".md"
            break
          end
        end
        if not save_name then
          return
        end
      else
        -- 如果提供了文件名参数，则直接使用
        save_name = table.concat(opt.fargs, "-") .. ".md"
      end

      -- 设置保存路径
      local Path = require("plenary.path")
      local data_path = os.getenv("WRITING_LIB") or vim.fn.getcwd()
      local save_folder = Path:new(data_path, "cc_saves")

      -- 创建保存目录（如果不存在）
      if not save_folder:exists() then
        local success_mkdir, err = pcall(save_folder.mkdir, save_folder, { parents = true })
        if not success_mkdir then
          vim.notify("Failed to create save directory: " .. err, vim.log.levels.ERROR)
          return
        end
      end

      -- 保存文件
      local save_path = Path:new(save_folder, save_name)
      local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
      local success_write, err = pcall(save_path.write, save_path, table.concat(lines, "\n"), "w")

      -- 显示保存结果
      if success_write then
        vim.notify(string.format("Chat saved to: %s", save_path:absolute()), vim.log.levels.INFO)
      else
        vim.notify("Failed to save chat: " .. err, vim.log.levels.ERROR)
      end
    end
    vim.api.nvim_create_user_command("CodeCompanionSave", function(opt)
      chat_save(0, opt)
    end, {
      nargs = "*",
      desc = "Save CodeCompanion chat to markdown file",
    })
    vim.api.nvim_create_autocmd({ "FileType" }, {
      group = vim.api.nvim_create_augroup("LBS_CC", { clear = true }),
      callback = function()
        require("util").keymap({
          "<leader>fs",
          chat_save,
          desc = "CodeCompanion: Save current chat buffer",
          buffer = true,
          silent = true,
          noremap = true,
        })
      end,
    })
  end,
}
