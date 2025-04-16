local PROMPTS = require("llm_prompts")

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

return {
  { -- jackMort/ChatGPT.nvim: Effortless Natural Language Generation ---- {{{2
    "jackMort/ChatGPT.nvim",
    enabled = false,
    event = "VeryLazy",
    cmd = { "ChatGPT" },
    opts = {
      api_key_cmd = vim.env.HOME .. "/.private_info.sh openai",
      yank_register = "+",
      edit_with_instructions = {
        diff = false,
        keymaps = {
          close = "<C-c>",
          accept = "<C-y>",
          toggle_diff = "<C-d>",
          toggle_settings = "<C-o>",
          toggle_help = "<C-h>",
          cycle_windows = "<Tab>",
          use_output_as_input = "<C-i>",
        },
      },
      chat = {
        -- welcome_message = WELCOME_MESSAGE,
        loading_text = "Loading, please wait ...",
        question_sign = "", -- 🙂
        answer_sign = "ﮧ", -- 🤖
        border_left_sign = "<",
        border_right_sign = ">",
        max_line_length = 120,
        sessions_window = {
          active_sign = " 󰄲",
          inactive_sign = " 󰄱 ",
          current_line_sign = "",
          border = {
            style = require("util").border("═", "top", true),
            text = {
              top = " Sessions ",
            },
          },
          win_options = {
            winhighlight = "Normal:NormalFloat,FloatBorder:FloatBorder",
          },
        },
        keymaps = {
          close = "<C-c>",
          yank_last = "<C-y>",
          yank_last_code = "<C-k>",
          scroll_up = "<C-u>",
          scroll_down = "<C-d>",
          new_session = "<C-n>",
          cycle_windows = "<Tab>",
          cycle_modes = "<C-f>",
          next_message = "<C-j>",
          prev_message = "<C-k>",
          select_session = "<Space>",
          rename_session = "r",
          delete_session = "d",
          draft_message = "<C-r>",
          edit_message = "e",
          delete_message = "d",
          toggle_settings = "<C-o>",
          toggle_sessions = "<C-p>",
          toggle_help = "<C-h>",
          toggle_message_role = "<C-r>",
          toggle_system_role_open = "<C-s>",
          stop_generating = "<C-x>",
        },
      },
      popup_layout = {
        default = "center",
        center = {
          width = "80%",
          height = "80%",
        },
        right = {
          width = "30%",
          width_settings_open = "50%",
        },
      },
      popup_window = {
        border = {
          style = require("util").border("═", "top", true),
          text = {
            top = " ChatGPT ",
          },
        },
        win_options = {
          wrap = true,
          linebreak = true,
          foldcolumn = "0",
          winhighlight = "Normal:NormalFloat,FloatBorder:FloatBorder",
        },
        buf_options = {
          filetype = "markdown",
        },
      },
      system_window = {
        border = {
          style = require("util").border("═", "top", true),
          text = {
            top = " SYSTEM ",
          },
        },
        win_options = {
          wrap = true,
          linebreak = true,
          foldcolumn = "0",
          winhighlight = "Normal:NormalFloat,FloatBorder:FloatBorder",
        },
      },
      popup_input = {
        prompt = "  ",
        border = {
          style = vim.fn.exists("g:neovide") == 1 and { "", "─", "", "", "", "", "", "" }
            or { "", "─", "", "", "", { "═", "MyBorder" }, "", "" },
          text = {
            top_align = "center",
            top = " Prompt ",
          },
        },
        zindex = 100,
        win_options = {
          winhighlight = "Normal:NormalFloat,FloatBorder:FloatBorder",
        },
        submit = ";<Enter",
        submit_n = "<Enter>",
        max_visible_lines = 20,
      },
      settings_window = {
        setting_sign = "  ",
        border = {
          style = require("util").border("═", "top", true),
          text = {
            top = " Settings ",
          },
        },
        win_options = {
          winhighlight = "Normal:NormalFloat,FloatBorder:FloatBorder",
        },
      },
      help_window = {
        setting_sign = "  ",
        border = require("util").border("═", "top", true),
        win_options = {
          winhighlight = "Normal:NormalFloat,FloatBorder:FloatBorder",
        },
      },
      openai_params = {
        model = "gpt-4o",
        frequency_penalty = 0,
        presence_penalty = 0,
        max_tokens = 3000,
        temperature = 0,
        top_p = 1,
        n = 1,
      },
      openai_edit_params = {
        model = "gpt-4o",
        frequency_penalty = 0,
        presence_penalty = 0,
        temperature = 0,
        top_p = 1,
        n = 1,
      },
      use_openai_functions_for_edits = false,
      actions_paths = {},
      show_quickfixes_cmd = "Trouble quickfix",
      predefined_chat_gpt_prompts = "file:///Users/luowei/useScript/chatgpt_prompt.csv",
      highlights = {
        help_key = "@symbol",
        help_description = "@comment",
      },
    },
    config = function(_, opts)
      require("chatgpt").setup(opts)

      vim.cmd([[ hi ChatGPTTotalTokens guibg=NONE]])
      local status_ok, wk = pcall(require, "which-key")
      if status_ok then
        wk.add({
          { ",", group = "ChatGPT" },
          { ",c", "<cmd>ChatGPT<CR>", desc = "ChatGPT" },
          {
            mode = { "n", "v" },
            { ",a", "<cmd>ChatGPTRun add_tests<CR>", desc = "Add Tests" },
            { ",d", "<cmd>ChatGPTRun docstring<CR>", desc = "Docstring" },
            {
              ",e",
              "<cmd>ChatGPTEditWithInstruction<CR>",
              desc = "Edit with instruction",
            },
            { ",f", "<cmd>ChatGPTRun fix_bugs<CR>", desc = "Fix Bugs" },
            {
              ",g",
              "<cmd>ChatGPTRun grammar_correction<CR>",
              desc = "Grammar Correction",
            },
            { ",k", "<cmd>ChatGPTRun keywords<CR>", desc = "Keywords" },
            {
              ",l",
              "<cmd>ChatGPTRun code_readability_analysis<CR>",
              desc = "Code Readability Analysis",
            },
            { ",o", "<cmd>ChatGPTRun optimize_code<CR>", desc = "Optimize Code" },
            { ",r", "<cmd>ChatGPTRun roxygen_edit<CR>", desc = "Roxygen Edit" },
            { ",s", "<cmd>ChatGPTRun summarize<CR>", desc = "Summarize" },
            { ",t", "<cmd>ChatGPTRun translate<CR>", desc = "Translate" },
            { ",x", "<cmd>ChatGPTRun explain_code<CR>", desc = "Explain Code" },
          },
        })
      end
    end,
  },
  { -- robitx/gp.nvim: (GPT prompt) Neovim AI plugin -------------------- {{{2
    "robitx/gp.nvim",
    cmd = {
      "GpAgent",
      "GpChatNew",
      "GpChatFinder",
      "GpRewrite",
      "GpAppend",
      "GpPopup",
      "GpContext",
      "GpTextOptimize",
      "GpTranslator",
    },
    keys = {
      {
        "<M-o>",
        ":<C-u>'<,'>GpTextOptimize<cr>",
        desc = "Optimize Text",
        nowait = true,
        mode = { "v" },
      },
      {
        "<C-g>c",
        "<cmd>GpChatNew vsplit<cr>",
        desc = "GPT prompt New Chat",
        nowait = true,
      },
      {
        "<C-g>t",
        "<cmd>GpChatToggle vsplit<cr>",
        desc = "GPT prompt Toggle Chat",
        nowait = true,
      },
      {
        "<C-g>f",
        "<cmd>GpChatFinder<cr>",
        desc = "GPT prompt Chat Finder",
        nowait = true,
      },
      {
        "<leader>sc",
        "<cmd>GpChatFinder<cr>",
        desc = "GPT prompt Chat Finder",
        nowait = true,
      },
      {
        "<C-g>c",
        ":<C-u>'<,'>GpChatNew<cr>",
        desc = "GPT prompt Visual Chat New",
        nowait = true,
        mode = "v",
      },
      {
        "<C-g>p",
        ":<C-u>'<,'>GpChatPaste<cr>",
        desc = "GPT prompt Visual Chat Paste",
        nowait = true,
        mode = "v",
      },
      {
        "<C-g>t",
        ":<C-u>'<,'>GpChatToggle<cr>",
        desc = "GPT prompt Visual Toggle Chat",
        nowait = true,
        mode = "v",
      },
      {
        "<C-g><C-x>",
        "<cmd>GpChatNew split<cr>",
        desc = "GPT prompt New Chat split",
        nowait = true,
      },
      {
        "<C-g><C-v>",
        "<cmd>GpChatNew vsplit<cr>",
        desc = "GPT prompt New Chat vsplit",
        nowait = true,
      },
      {
        "<C-g><C-t>",
        "<cmd>GpChatNew tabnew<cr>",
        desc = "GPT prompt New Chat tabnew",
        nowait = true,
      },
      {
        "<C-g><C-x>",
        ":<C-u>'<,'>GpChatNew split<cr>",
        desc = "GPT prompt Visual Chat New split",
        nowait = true,
        mode = "v",
      },
      {
        "<C-g><C-v>",
        ":<C-u>'<,'>GpChatNew vsplit<cr>",
        desc = "GPT prompt Visual Chat New vsplit",
        nowait = true,
        mode = "v",
      },
      {
        "<C-g><C-t>",
        ":<C-u>'<,'>GpChatNew tabnew<cr>",
        desc = "GPT prompt Visual Chat New tabnew",
        nowait = true,
        mode = "v",
      },
      -- Prompt commands
      {
        "<C-g>r",
        "<cmd>GpRewrite<cr>",
        desc = "GPT prompt Inline Rewrite",
        nowait = true,
      },
      {
        "<C-g>a",
        "<cmd>GpAppend<cr>",
        desc = "GPT prompt Append (after)",
        nowait = true,
      },
      {
        "<C-g>b",
        "<cmd>GpPrepend<cr>",
        desc = "GPT prompt Prepend (before)",
        nowait = true,
      },
      {
        "<C-g>r",
        ":<C-u>'<,'>GpRewrite<cr>",
        desc = "GPT prompt Visual Rewrite",
        nowait = true,
        mode = "v",
      },
      {
        "<C-g>a",
        ":<C-u>'<,'>GpAppend<cr>",
        desc = "GPT prompt Visual Append (after)",
        nowait = true,
        mode = "v",
      },
      {
        "<C-g>b",
        ":<C-u>'<,'>GpPrepend<cr>",
        desc = "GPT prompt Visual Prepend (before)",
        nowait = true,
        mode = "v",
      },
      {
        "<C-g>i",
        ":<C-u>'<,'>GpImplement<cr>",
        desc = "GPT prompt Implement selection",
        nowait = true,
        mode = "v",
      },
      {
        "<C-g>gp",
        "<cmd>GpPopup<cr>",
        desc = "GPT prompt Popup",
        nowait = true,
      },
      {
        "<C-g>ge",
        "<cmd>GpEnew<cr>",
        desc = "GPT prompt GpEnew",
        nowait = true,
      },
      {
        "<C-g>gn",
        "<cmd>GpNew<cr>",
        desc = "GPT prompt GpNew",
        nowait = true,
      },
      {
        "<C-g>gv",
        "<cmd>GpVnew<cr>",
        desc = "GPT prompt GpVnew",
        nowait = true,
      },
      {
        "<C-g>gt",
        "<cmd>GpTabnew<cr>",
        desc = "GPT prompt GpTabnew",
        nowait = true,
      },
      {
        "<C-g>gp",
        ":<C-u>'<,'>GpPopup<cr>",
        desc = "GPT prompt Visual Popup",
        nowait = true,
        mode = "v",
      },
      {
        "<C-g>ge",
        ":<C-u>'<,'>GpEnew<cr>",
        desc = "GPT prompt Visual GpEnew",
        nowait = true,
        mode = "v",
      },
      {
        "<C-g>gn",
        ":<C-u>'<,'>GpNew<cr>",
        desc = "GPT prompt Visual GpNew",
        nowait = true,
        mode = "v",
      },
      {
        "<C-g>gv",
        ":<C-u>'<,'>GpVnew<cr>",
        desc = "GPT prompt Visual GpVnew",
        nowait = true,
        mode = "v",
      },
      {
        "<C-g>gt",
        ":<C-u>'<,'>GpTabnew<cr>",
        desc = "GPT prompt Visual GpTabnew",
        nowait = true,
        mode = "v",
      },
      {
        "<C-g>x",
        "<cmd>GpContext<cr>",
        desc = "GPT prompt Toggle Context",
        nowait = true,
      },
      {
        "<C-g>x",
        ":<C-u>'<,'>GpContext<cr>",
        desc = "GPT prompt Visual Toggle Context",
        nowait = true,
        mode = "v",
      },
      {
        "<C-g>s",
        "<cmd>GpStop<cr>",
        desc = "GPT prompt Stop",
        nowait = true,
        mode = { "n", "v", "x" },
      },
      {
        "<C-g>n",
        "<cmd>GpNextAgent<cr>",
        desc = "GPT prompt Next Agent",
        nowait = true,
        mode = { "n", "v", "x" },
      },
    },
    opts = {
      openai_api_key = { vim.env.HOME .. "/.private_info.sh", "aihubmix" },
      providers = {
        openai = {
          endpoint = "https://aihubmix.com/v1/chat/completions",
        },
        ollama = {
          endpoint = "http://localhost:11434/v1/chat/completions",
          secret = "",
        },
        deepseek = {
          endpoint = "https://api.deepseek.com/v1/chat/completions",
          secret = { os.getenv("HOME") .. "/.private_info.sh", "deepseek" },
        },
      },
      hooks = {
        Translator = function(gp, params)
          local agent = gp.agents["DeepSeek-Chat"]
          local chat_system_prompt = "请你担任一名将英文翻译成简体中文的翻译者。请帮我把英文翻译成简体中文。"
            .. "我会输入英文内容，内容可能是一个句子、或一个单字，请先理解内容后再将我提供的内容翻译成简体中文。"
            .. "回答内容请尽量口语化且符合语境，但仍保留意思。回答内容包含翻译后的简体中文文本，不需要额外的解释。"
          gp.cmd.ChatNew(params, agent.model, chat_system_prompt)
        end,
        TextOptimize = function(gp, params)
          local template = "Please polish the text from {{filename}}:\n\n" .. "```{{filetype}}\n{{selection}}\n```\n\n"
          local agent = gp.agents["Writing_Optimizer"]
          if vim.bo.filetype == "quarto" then
            agent.model.model = "gpt-4.1"
            agent.system_prompt = PROMPTS.improve_academic_writing
          end
          gp.logger.info("Implementing selection with agent: " .. agent.name)
          gp.Prompt(
            params,
            gp.Target.rewrite,
            agent,
            template,
            nil, -- command will run directly without any prompting for user input
            nil -- no predefined instructions (e.g. speech-to-text from Whisper)
          )
        end,
      },
      whisper = { disable = true },
      image = { disable = true },
      default_chat_agent = "Gemini-Pro",
      default_command_agent = "Gemini-Flash",
      chat_shortcut_respond = { modes = { "n", "i", "v", "x" }, shortcut = "<c-s>" },
      chat_user_prefix = "| []:",
      chat_assistant_prefix = { "|: ", "[{{agent}}]" },
      chat_dir = (os.getenv("WRITING_LIB") or os.getenv("HOME") .. "/Documents/Writing"):gsub("/$", "") .. "/gp_chats",
    },
    config = function(_, opts)
      opts.agents = vim.tbl_deep_extend("force", opts.agents or {}, {
        {
          name = "DeepSeek7B",
          provider = "ollama",
          chat = false,
          command = true,
          model = "deepseek-r1:7b",
          system_prompt = require("gp.defaults").chat_system_prompt,
        },
        {
          name = "DeepSeek8B",
          provider = "ollama",
          chat = false,
          command = true,
          model = "deepseek-r1:8b",
          system_prompt = require("gp.defaults").chat_system_prompt,
        },
        {
          name = "DeepSeek-Chat",
          provider = "openai",
          chat = true,
          command = true,
          model = { model = "deepseek-chat", temperature = 1.1, top_p = 1 },
          system_prompt = require("gp.defaults").chat_system_prompt,
        },
        {
          name = "DeepSeek-Reasoner",
          provider = "openai",
          chat = true,
          command = true,
          model = { model = "DeepSeek-R1", temperature = 0.7, top_p = 1 },
          system_prompt = require("gp.defaults").chat_system_prompt,
        },
        {
          name = "Gemini-Pro",
          provider = "openai",
          chat = true,
          command = true,
          model = { model = "gemini-2.0-pro-exp-02-05-search", temperature = 1.1, top_p = 1 },
          system_prompt = require("gp.defaults").chat_system_prompt,
        },
        {
          name = "Gemini-Flash",
          provider = "openai",
          chat = true,
          command = true,
          model = { model = "gemini-2.0-flash", temperature = 1.1, top_p = 1 },
          system_prompt = require("gp.defaults").chat_system_prompt,
        },
        {
          name = "Writing_Optimizer",
          provider = "openai",
          chat = false,
          command = true,
          model = { model = "gemini-2.0-flash", temperature = 0, top_p = 1 },
          system_prompt = PROMPTS.improve_writing,
        },
      })
      require("gp").setup(opts)
      local gp_group = vim.api.nvim_create_augroup("GpAuto", { clear = true })
      vim.api.nvim_create_autocmd({ "FileType" }, {
        group = gp_group,
        pattern = "markdown",
        callback = function(ev)
          local lines = vim.api.nvim_buf_get_lines(ev.buf, 0, 1, true)
          if lines and lines[1] and string.match(lines[1], "^# topic: %?$") then
            return true
          end
          vim.keymap.set("n", "<localleader><leader>", function()
            local row = vim.fn.line(".") - 2
            if row <= 1 then
              return
            end

            local chat_assistant_prefix = require("gp").config.chat_assistant_prefix[1]
            for i = row, 1, -1 do
              local line = vim.api.nvim_buf_get_lines(0, i - 1, i, true)[1] or ""
              if line:find("^" .. chat_assistant_prefix) then
                vim.api.nvim_win_set_cursor(0, { i + 1, 0 })
                return
              end
            end
          end, {
            buffer = ev.buf,
            desc = "GPT goto previous assistant",
            noremap = true,
            silent = true,
            nowait = true,
          })
        end,
      })
    end,
  },
  { -- yetone/avante.nvim ----------------------------------------------- {{{2
    "yetone/avante.nvim",
    event = "VeryLazy",
    cmd = {
      "AvanteChat",
    },
    -- lazy = false,
    version = "*", -- Set this to "*" to always pull the latest release version, or set it to false to update to the latest code changes.
    opts = {
      provider = "openai",
      vendors = {
        ["deepseek"] = {
          __inherited_from = "openai",
          model = "DeepSeek-R1",
          endpoint = "https://aihubmix.com/v1",
          api_key_name = "cmd:" .. os.getenv("HOME") .. "/.private_info.sh aihubmix",
        },
      },
      ["openai"] = {
        endpoint = "https://aihubmix.com/v1",
        api_key_name = "cmd:" .. os.getenv("HOME") .. "/.private_info.sh aihubmix",
        -- model = "claude-3-7-sonnet-20250219",
        model = "gemini-2.5-pro-exp-03-25",
        temperature = 0,
      },
      hints = {
        enabled = false,
      },
    },
    -- if you want to build from source then do `make BUILD_FROM_SOURCE=true`
    build = "make",
    -- build = "powershell -ExecutionPolicy Bypass -File Build.ps1 -BuildFromSource false" -- for windows
    dependencies = {
      "nvim-lua/plenary.nvim",
      "MunifTanjim/nui.nvim",
    },
    config = function(_, opts)
      require("avante").setup(opts)

      local prefill_edit_window = function(request)
        if not request then
          return
        end
        request = vim.split(request, "\n")
        require("avante.api").edit()
        local code_bufnr = vim.api.nvim_get_current_buf()
        local code_winid = vim.api.nvim_get_current_win()
        if code_bufnr == nil or code_winid == nil then
          return
        end
        vim.api.nvim_buf_set_lines(code_bufnr, 0, -1, false, request)
        -- Optionally set the cursor position to the end of the input
        vim.api.nvim_win_set_cursor(code_winid, { 1, #request + 1 })
        -- Simulate Ctrl+S keypress to submit
        vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<C-s>", true, true, true), "v", true)
      end
      require("which-key").add({
        { "<leader>a", group = "Avante" },
        {
          mode = "v",
          {
            "<leader>ap",
            function()
              prefill_edit_window(PROMPTS.improve_academic_writing)
            end,
            desc = "Paper Polish",
          },
        },
      })
    end,
  },
  { -- olimorris/codecompanion.nvim ------------------------------------- {{{2
    "olimorris/codecompanion.nvim",
    keys = {
      { "<c-a>l", "<cmd>CodeCompanionActions<cr>", desc = "CodeCompanion Actions", mode = { "n", "v" } },
      { "<leader>ac", "<cmd>CodeCompanionChat Toggle<cr>", desc = "CodeCompanion Toggle", mode = { "n", "v" } },
      { "<c-a>a", "<cmd>CodeCompanionChat Add<cr>", desc = "CodeCompanion Toggle", mode = { "v" } },
      {
        "<localleader>cp",
        function()
          require("codecompanion").prompt("polish")
        end,
        mode = { "v" },
      },
    },
    cmd = { "CodeCompanion", "CodeCompanionChat", "CodeCompanionActions" },
    dependencies = {
      "nvim-lua/plenary.nvim",
      "nvim-treesitter/nvim-treesitter",
    },
    init = function()
      vim.cmd([[cabbrev cc CodeCompanion]])
      local has_fidget, _ = pcall(require, "fidget")
      if has_fidget then
        require("util.fidget"):init()
      end
    end,
    opts = {
      display = {
        chat = {
          show_settings = true,
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
      },
      strategies = {
        chat = {
          adapter = "gemini-thinking",
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
            },
            schema = {
              model = {
                default = "gemini-2.0-pro-exp-02-05-search",
              },
              temperature = {
                default = 0,
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
                default = "gemini-2.0-flash-search",
              },
              temperature = {
                default = 0,
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
                default = "gemini-2.5-pro-preview-03-25",
              },
              temperature = {
                default = 0,
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
                default = 0,
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
              name = "aihubmix-opeanai",
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
  },
}
