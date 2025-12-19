local ai_adapters = require("util.ai_adapters")

local function using_prompt(bufnr)
  bufnr = bufnr or 0
  local filetype = vim.api.nvim_get_option_value("filetype", { buf = bufnr })

  if filetype == "quarto" then
    return "apolish"
  end

  if vim.tbl_contains({ "markdown", "norg", "org", "mail" }, filetype) or filetype == "" then
    return "polish"
  end

  return "optimize"
end

local function optimize_select()
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
end

return { -- olimorris/codecompanion.nvim ------------------------------------- {{{2
  "olimorris/codecompanion.nvim",
  -- stylua: ignore start
  keys = {
    { "<leader>al", "<cmd>CodeCompanionActions<CR>",     desc = "CodeCompanion: Actions",                mode = { "n", "v", "x" } },
    { "<leader>ac", "<cmd>CodeCompanionChat Toggle<CR>", desc = "CodeCompanion: Chat Toggle",            mode = { "n", "v"      } },
    { "<A-l>",      "<cmd>CodeCompanionChat Add<CR>",    desc = "CodeCompanion: Chat Add Selection",     mode = { "v"           } },
    { "<A-o>",      function() optimize_select() end,    desc = "CodeCompanion: Optimize selected text", mode = { "n", "v"      } },
  },
  -- stylua: ignore end
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
    rules = {
      default = {
        description = "Collection of common files for all projects",
        files = {
          ".clinerules",
          ".cursorrules",
          ".goosehints",
          ".rules",
          ".windsurfrules",
          ".github/copilot-instructions.md",
          "AGENT.md",
          "AGENTS.md",
          { path = "CLAUDE.md", parser = "claude" },
          { path = "CLAUDE.local.md", parser = "claude" },
          { path = "~/.claude/CLAUDE.md", parser = "claude" },
        },
        is_preset = true,
      },
      opts = {
        chat = {
          enabled = true,
          default_rules = "default", -- The rule groups to load
        },
      },
    },
    interactions = {
      background = {
        adapter = "background",
        chat = {
          -- callbacks = {
          --   ["on_ready"] = {
          --     actions = {
          --       "interactions.background.builtin.chat_make_title",
          --     },
          --     enabled = true,
          --   },
          -- },
          opts = {
            enabled = true,
          },
        },
      },
      chat = {
        adapter = "chat",
        -- keymaps = {
        --   send = {
        --     callback = function(chat)
        --       vim.cmd("stopinsert")
        --       chat:add_buf_message({ role = "llm", content = "" })
        --       chat:submit()
        --     end,
        --     index = 1,
        --     description = "Send",
        --   },
        -- },
      },
      inline = {
        adapter = "code",
      },
      cmd = {
        adapter = "code",
      },
    },
    adapters = ai_adapters.codecompanion_adapters(),
    prompt_library = {
      markdown = {
        dirs = {
          vim.fn.stdpath("config") .. "/prompts",
        },
      },
    },
    extensions = {
      history = {
        enabled = true,
        opts = {
          auto_save = true,
          keymap = "gh",
          auto_generate_title = true,
          summary = {
            generation_opts = {
              adapter = "background",
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
    ignore_warnings = true,
    language = "Chinese",
  },
}
