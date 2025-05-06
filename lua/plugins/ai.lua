local PROMPTS = require("llm_prompts")

return {
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
      -- {
      --   "<M-o>",
      --   ":<C-u>'<,'>GpTextOptimize<cr>",
      --   desc = "Optimize Text",
      --   nowait = true,
      --   mode = { "v" },
      -- },
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
          model = { model = "gemini-2.0-flash", temperature = 0.4, top_p = 1 },
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
        model = "gemini-2.5-pro-preview-03-25",
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
          -- {
          --   "<leader>ap",
          --   function()
          --     prefill_edit_window(PROMPTS.improve_academic_writing)
          --   end,
          --   desc = "Paper Polish",
          -- },
        },
      })
    end,
  },
  { -- ravitemer/mcphub.nvim -------------------------------------------- {{{2
    "ravitemer/mcphub.nvim",
    dependencies = {
      "nvim-lua/plenary.nvim", -- Required for Job and HTTP requests
    },
    cmd = "MCPHub", -- lazy load
    build = "npm install -g mcp-hub@latest", -- Installs required mcp-hub npm module
    opts = {
      auto_approve = false,
    },
  },
}
