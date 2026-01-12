-- CodeCompanion 插件配置
-- 提供 AI 辅助编程功能，包括聊天、代码优化等

local ai_adapters = require("util.ai_adapters")

-- 根据文件类型获取对应的优化提示
-- @param bufnr 缓冲区编号，默认为当前缓冲区
-- @return string 提示名称 (apolish/polish/optimize)
local function get_prompt_by_filetype(bufnr)
  bufnr = bufnr or 0
  local filetype = vim.api.nvim_get_option_value("filetype", { buf = bufnr })

  if filetype == "quarto" then
    return "apolish"
  elseif vim.tbl_contains({ "markdown", "norg", "org", "mail" }, filetype) or filetype == "" then
    return "polish"
  else
    return "optimize"
  end
end

-- 智能选择并优化文本
-- 在普通模式下自动选择当前行，在可视模式下使用已选择的文本
local function optimize_select()
  local prompt_name = get_prompt_by_filetype()
  local current_mode = vim.fn.mode()

  -- 普通模式：自动选择当前行
  if current_mode == "n" then
    vim.cmd.normal({ "V", bang = true })
  elseif not (current_mode == "v" or current_mode == "V" or current_mode == "\22") then
    vim.notify("Mapping <A-o> requires normal or visual mode.", vim.log.levels.WARN)
    return
  end

  vim.schedule(function()
    require("codecompanion").prompt(prompt_name)
  end)
end

return {
  "olimorris/codecompanion.nvim",
  -- stylua: ignore start
  -- 键位映射
  keys = {
    { "<leader>al",      "<cmd>CodeCompanionActions<CR>",     desc = "CodeCompanion: Actions",                mode = { "n", "v", "x" } },
    { "<leader><space>", "<cmd>CodeCompanionChat Toggle<CR>", desc = "CodeCompanion: Chat Toggle",            mode = { "n", "v"      } },
    { "<A-l>",           "<cmd>CodeCompanionChat Add<CR>",    desc = "CodeCompanion: Chat Add Selection",     mode = { "v"           } },
    { "<A-o>",           function() optimize_select() end,    desc = "CodeCompanion: Optimize selected text", mode = { "n", "v"      } },
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
    -- 显示设置
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
    -- 规则配置：自动加载项目中的 AI 指令文件
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
        chat = { enabled = true, default_rules = "default" },
      },
    },
    -- 交互模式配置
    interactions = {
      background = { adapter = "background", chat = { opts = { enabled = true } } },
      chat = { adapter = "chat" },
      inline = { adapter = "code" },
      cmd = { adapter = "code" },
    },
    -- AI 适配器配置（从 util.ai_adapters 加载）
    adapters = ai_adapters.codecompanion_adapters(),
    -- 提示词库配置
    prompt_library = {
      markdown = { dirs = { vim.fn.stdpath("config") .. "/prompts" } },
    },
    -- 扩展配置
    extensions = {
      -- 历史记录扩展
      history = {
        enabled = true,
        opts = {
          auto_save = true,
          keymap = "gh",
          auto_generate_title = true,
          summary = { generation_opts = { adapter = "background" } },
          continue_last_chat = false,
          delete_on_clearing_chat = false,
          picker = "snacks",
          enable_logging = false,
          dir_to_save = vim.fn.stdpath("data") .. "/codecompanion-history",
        },
      },
      -- MCP Hub 扩展（Model Context Protocol）
      mcphub = {
        callback = "mcphub.extensions.codecompanion",
        opts = {
          show_result_in_chat = true,
          make_vars = true,
          make_slash_commands = true,
        },
      },
    },
    ignore_warnings = true,
    language = "Chinese",
  },
}
