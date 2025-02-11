local gpt4 = "gpt-4o"
local gpt35 = "gpt-3.5-turbo"
local prompt_polish_system = [[
**Paper Polishing Request**

You are an economics paper editing assistant with 10 years experience. Your
expertise includes econometric analysis formatting and academic style
maintenance.


Please refine the following academic paragraph by:

1. Correcting grammatical errors and typos
2. Improving sentence structure for better readability
3. Enhancing academic tone while maintaining original meaning
4. Ensuring technical terminology accuracy
5. Optimizing transition between ideas
6. Ensure that the language is the same as the original language
7. Applying proper academic formatting conventions
8. Maintain original citation/reference format

Respond exclusively with:
1. full polished version (no markdown codeblocks) and
2. Brief technical justification, as markdown comment, like:

   ```
   <!-- EXPLANATION
   - ...
   - ...
   -->
   ```
]]

return {
  { -- jackMort/ChatGPT.nvim: Effortless Natural Language Generation ---- {{{3
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
        "<cmd>GpTextOptimize<cr>",
        desc = "Optimize Text",
        nowait = true,
        mode = { "n" },
      },
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
      openai_api_key = { vim.env.HOME .. "/.private_info.sh", "openai" },
      providers = {
        deepseek = {
          endpoint = "https://api.deepseek.com/v1/chat/completions",
          secret = { os.getenv("HOME") .. "/.private_info.sh", "deepseek" },
        },
      },
      hooks = {
        Translator = function(gp, params)
          local agent = gp.agents["DeepSeek-Chat"]
          local chat_system_prompt =
            "请你担任一名将英文翻译成简体中文的翻译者。请帮我把英文翻译成简体中文。我会输入英文内容，内容可能是一个句子、或一个单字，请先理解内容后再将我提供的内容翻译成简体中文。回答内容请尽量口语化且符合语境，但仍保留意思。回答内容包含翻译后的简体中文文本，不需要额外的解释。"
          gp.cmd.ChatNew(params, agent.model, chat_system_prompt)
        end,
        TextOptimize = function(gp, params)
          local template = "Having following from {{filename}}:\n\n"
            .. "```{{filetype}}\n{{selection}}\n```\n\n"
            .. "Please act as an economics professor."
            .. " Correct any spelling mistakes and improve the expression to enhance clarity and coherence."
            .. " Additionally, optimize the text to align with the style and tone of an academic paper in the field of economics."
            .. " Please ensure that the language is the same as the original language."
            .. "\n\nRespond exclusively with the snippet that should replace the selection above."
          local agent = gp.agents["CodeGPT4o-mini"]
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
      default_chat_agent = "DeepSeek-Chat",
      default_command_agent = "DeepSeek-Reasoner",
      chat_user_prefix = "# 💬: ",
      chat_assistant_prefix = { "🤖: ", "[{{agent}}]" },
    },
    config = function(_, opts)
      opts.agents = vim.tbl_deep_extend("force", opts.agents or {}, {
        {
          name = "DeepSeek-Chat",
          provider = "deepseek",
          chat = true,
          command = true,
          model = { model = "deepseek-chat", temperature = 1.1, top_p = 1 },
          system_prompt = require("gp.defaults").chat_system_prompt,
        },
        {
          name = "DeepSeek-Reasoner",
          provider = "deepseek",
          chat = false,
          command = true,
          model = { model = "deepseek-reasoner", temperature = 0.7, top_p = 1 },
          system_prompt = require("gp.defaults").chat_system_prompt,
        },
        {
          name = "ChatGPT4",
          chat = true,
          command = false,
          -- string with model name or table with model name and parameters
          model = { model = gpt4, temperature = 1.1, top_p = 1 },
          -- system prompt (use this to specify the persona/role of the AI)
          system_prompt = require("gp.defaults").chat_system_prompt,
        },
        {
          name = "ChatGPT3-5",
          chat = true,
          command = false,
          -- string with model name or table with model name and parameters
          model = { model = gpt35, temperature = 1.1, top_p = 1 },
          -- system prompt (use this to specify the persona/role of the AI)
          system_prompt = require("gp.defaults").chat_system_prompt,
        },
        {
          name = "CodeGPT4",
          chat = false,
          command = true,
          -- string with model name or table with model name and parameters
          model = { model = gpt4, temperature = 0.8, top_p = 1 },
          -- system prompt (use this to specify the persona/role of the AI)
          system_prompt = "You are an AI working as a code editor.\n\n"
            .. "Please AVOID COMMENTARY OUTSIDE OF THE SNIPPET RESPONSE.\n"
            .. "START AND END YOUR ANSWER WITH:\n\n```",
        },
        {
          name = "ChatGPT4o-mini",
          provider = "openai",
          chat = true,
          command = false,
          -- string with model name or table with model name and parameters
          model = { model = "gpt-4o-mini", temperature = 1.1, top_p = 1 },
          -- system prompt (use this to specify the persona/role of the AI)
          system_prompt = require("gp.defaults").chat_system_prompt,
        },
        {
          provider = "openai",
          name = "CodeGPT4o-mini",
          chat = false,
          command = true,
          -- string with model name or table with model name and parameters
          model = { model = "gpt-4o-mini", temperature = 0.7, top_p = 1 },
          -- system prompt (use this to specify the persona/role of the AI)
          system_prompt = "Please return ONLY code snippets.\nSTART AND END YOUR ANSWER WITH:\n\n```",
        },
        {
          name = "CodeGPT3-5",
          chat = false,
          command = true,
          -- string with model name or table with model name and parameters
          model = { model = gpt35, temperature = 0.8, top_p = 1 },
          -- system prompt (use this to specify the persona/role of the AI)
          system_prompt = "You are an AI working as a code editor.\n\n"
            .. "Please AVOID COMMENTARY OUTSIDE OF THE SNIPPET RESPONSE.\n"
            .. "START AND END YOUR ANSWER WITH:\n\n```",
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
      -- add any opts here
      -- for example
      provider = "deepseek",
      vendors = {
        ["deepseek"] = {
          __inherited_from = "openai",
          model = "deepseek-coder",
          endpoint = "https://api.deepseek.com",
          api_key_name = "cmd:" .. os.getenv("HOME") .. "/.private_info.sh deepseek",
        },
      },
      openai = {
        api_key_name = "cmd:" .. os.getenv("HOME") .. "/.private_info.sh openai",
      },
    },
    -- if you want to build from source then do `make BUILD_FROM_SOURCE=true`
    build = "make",
    -- build = "powershell -ExecutionPolicy Bypass -File Build.ps1 -BuildFromSource false" -- for windows
    dependencies = {
      "stevearc/dressing.nvim",
      "nvim-lua/plenary.nvim",
      "MunifTanjim/nui.nvim",
    },
  },
  { -- olimorris/codecompanion.nvim ------------------------------------- {{{2
    "olimorris/codecompanion.nvim",
    keys = {
      { "<c-a>", "<cmd>CodeCompanionActions<cr>", desc = "CodeCompanion Actions", mode = { "n", "v" } },
      { "<leader>ac", "<cmd>CodeCompanionChat Toggle<cr>", desc = "CodeCompanion Toggle", mode = { "n", "v" } },
      { "ga", "<cmd>CodeCompanionChat Add<cr>", desc = "CodeCompanion Toggle", mode = { "v" } },
    },
    cmd = { "CodeCompanion" },
    dependencies = {
      "nvim-lua/plenary.nvim",
      "nvim-treesitter/nvim-treesitter",
    },
    init = function()
      vim.cmd([[cabbrev cc CodeCompanion]])
      local has_fidget, _ = pcall(require, "fidget")
      if has_fidget then
        require("util.codecompanion.fidget-spinner"):init()
      end
    end,
    opts = {
      display = {
        chat = {
          show_settings = true,
        },
      },
      strategies = {
        chat = {
          adapter = "deepseek",
        },
        inline = {
          adapter = "deepseek",
        },
        cmd = {
          adapter = "deepseek",
        },
      },
      adapters = {
        openai = function()
          return require("codecompanion.adapters").extend("openai", {
            env = {
              api_key = "cmd:" .. os.getenv("HOME") .. "/.private_info.sh openai",
            },
          })
        end,
        deepseek = function()
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
            mapping = "<LocalLeader>cp",
            is_slash_cmd = false,
            modes = { "v" },
            short_name = "polish",
            auto_submit = true,
            user_prompt = false,
            stop_context_insertion = true,
            -- placement = "replace",
          },
          prompts = {
            {
              role = "system",
              content = prompt_polish_system,
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
    },
    config = function(_, opts)
      require("codecompanion").setup(opts)
      local cc_group = vim.api.nvim_create_augroup("LBS_CC", { clear = true })
      vim.api.nvim_create_autocmd({ "FileType" }, {
        group = cc_group,
        pattern = { "codecompanion" },
        callback = function()
          vim.opt_local.formatexpr = "v:lua.require'conform'.formatexpr()"
          vim.opt_local.number = false
          vim.opt_local.relativenumber = false
        end,
      })
    end,
  },
}
