-- CodeCompanion 插件配置
-- 提供 AI 辅助编程功能，包括聊天、代码优化等

local ai_adapters = require("util.ai_adapters")

-- CLI 窗口固定列数：既用于窗口配置，也作为 resize 时判断是否压缩到不可读的阈值
local CLI_WIDTH = 80

-- 根据文件类型获取对应的代码优化提示词
-- @param bufnr number 缓冲区编号，默认为当前缓冲区 (可选)
-- @return string 提示词名称，可能的值: 'apolish' | 'polish' | 'optimize'
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

-- 生成一个调用 CodeCompanion CLI 的闭包，便于在 keymap 表里复用
-- @param prompt string|nil 上下文模板（如 "#{this}"），传 nil 仅传 opts
-- @param opts   table|nil  CLI 调用选项: agent / focus / submit / prompt / width / height
-- @return fun() 可直接挂在 keymap 上的函数
local function cli_send(prompt, opts)
  opts = opts or {}
  return function()
    if prompt == nil then
      require("codecompanion").cli(opts)
    else
      require("codecompanion").cli(prompt, opts)
    end
  end
end

-- 用户预定义的快捷提示词模板
-- key 为菜单标签，value 为发送到 CLI 的文本，#{this} 会被 CodeCompanion 展开为当前缓冲区/选区
local user_prompts = {
  comment = "Add comments to #{this}",
  explain = "Explain the following code: #{this}",
  refactor = "Refactor this code for better readability: #{this}",
  debug = "Debug and suggest fixes for this code: #{this}",
  test = "Generate unit tests for #{this}",
  polish = "/lbs:polish #{this}",
}

-- 弹出选择器，让用户从 user_prompts 中挑一条发送到 CLI
-- 使用 snacks.picker 渲染：编号 | preset key（等宽对齐）| prompt
-- 其中 #{...} 占位符以 SnacksPickerDirectory 高亮，
-- /cmd 形式的 CodeCompanion slash 命令以 SnacksPickerKeyword 高亮
local function select_user_prompt()
  local keys = vim.tbl_keys(user_prompts)
  table.sort(keys)

  local key_width = 0
  for _, key in ipairs(keys) do
    key_width = math.max(key_width, #key)
  end

  local items = {}
  for i, key in ipairs(keys) do
    table.insert(items, { idx = i, text = key, key = key, prompt = user_prompts[key] })
  end

  require("snacks.picker").pick({
    items = items,
    title = "CodeCompanion Preset",
    layout = {
      preset = "select",
      -- snacks 注解把 preview 标为 "main"?，但运行时支持 false 以禁用预览窗口
      ---@diagnostic disable-next-line: assign-type-mismatch
      preview = false,
      layout = { height = #items + 2 },
    },
    format = function(item)
      local ret = {}
      local sep = { " ", virtual = true }
      table.insert(ret, { string.format("%2d.", item.idx), "SnacksPickerIndex" })
      table.insert(ret, sep)
      table.insert(ret, { string.format("%-" .. key_width .. "s", item.key), "SnacksPickerSpecial" })
      table.insert(ret, sep)
      local prompt, pos = item.prompt, 1
      while pos <= #prompt do
        local ps, pe = prompt:find("#%b{}", pos)
        local cs, ce = prompt:find("/[%w][%w:%-]*", pos)
        local s, e, hl
        if ps and (not cs or ps <= cs) then
          s, e, hl = ps, pe, "SnacksPickerDirectory"
        elseif cs then
          s, e, hl = cs, ce, "SnacksPickerKeyword"
        end
        if not s then
          table.insert(ret, { prompt:sub(pos), "SnacksPickerComment" })
          break
        end
        if s > pos then
          table.insert(ret, { prompt:sub(pos, s - 1), "SnacksPickerComment" })
        end
        table.insert(ret, { prompt:sub(s, e), hl })
        pos = e + 1
      end
      return ret
    end,
    confirm = function(picker, item)
      picker:close()
      if item and item.prompt then
        require("codecompanion").cli(item.prompt, { focus = false })
      end
    end,
  })
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
  keys = {
    { "<leader>al",      "<cmd>CodeCompanionActions<CR>",                      desc = "CodeCompanion: Actions",                mode = { "n",                       "v",          "x" } },
    { "<leader><space>", "<cmd>CodeCompanionChat Toggle<CR>",                  desc = "CodeCompanion: Chat Toggle",            mode = { "n",                       "v"      } },
    { "<A-l>",           "<cmd>CodeCompanionChat Add<CR>",                     desc = "CodeCompanion: Chat Add Selection",     mode = { "v"           } },
    { "<A-o>",           function() optimize_select() end,                     desc = "CodeCompanion: Optimize selected text", mode = { "n",                       "v"      } },
    { "<leader>ac",      function() require("codecompanion").toggle_cli() end, desc = "CLI: Toggle agent window",              mode = { "n"      } },
    { "<leader>ap",      cli_send(nil,  { prompt = true }),                    desc = "CLI: Open prompt buffer",   mode = { "n", "v" } },
    { "<leader>at",      cli_send("#{this}",  { focus = false }),              desc = "CLI: Add buffer/selection", mode = { "n", "v" } },
    { "<leader>as",      select_user_prompt,                                   desc = "CLI: Select preset prompt",             mode = { "n",                       "v" } },

  },
  -- stylua: ignore end
  cmd = {
    "CodeCompanion",
    "CodeCompanionCLI",
    "CodeCompanionChat",
    "CodeCompanionActions",
    "CodeCompanionHistory",
  },
  dependencies = {
    "nvim-lua/plenary.nvim",
    "nvim-treesitter/nvim-treesitter",
    "ravitemer/codecompanion-history.nvim",
  },
  init = function()
    vim.keymap.set("ca", "cc", "CodeCompanion")
    require("util.spinner"):init()
    local has_fidget, _ = pcall(require, "fidget")
    if has_fidget then
      require("util.fidget"):init()
    end

    -- nvim 外层尺寸变化时，nvim 会按比例压缩各窗口；CLI 历史记录按固定列宽渲染，
    -- 一旦被压到 CLI_WIDTH 以下就会折行错乱、不再可读。此时直接隐藏窗口（终端进程保留），
    -- 用户可用 <leader>ac 在尺寸恢复后重新唤出。
    vim.api.nvim_create_autocmd("VimResized", {
      group = vim.api.nvim_create_augroup("lbs_codecompanion_cli_resize", { clear = true }),
      desc = "Hide CodeCompanion CLI window when compressed below CLI_WIDTH",
      callback = function()
        -- 仅在插件已加载时处理，避免在启动期意外触发 require
        if not package.loaded["codecompanion"] then
          return
        end
        local ok, cli = pcall(require, "codecompanion.interactions.cli")
        if not ok or not cli.is_visible() then
          return
        end
        local instance = cli.get_visible()
        if not instance or not instance.ui then
          return
        end
        -- 时序说明：resize 是原子的——SIGWINCH 一次性到达，nvim 在同一轮主循环里
        -- 先重排窗口、再触发 VimResized，所以此处 win_get_width 拿到的已是压缩后的最终宽度。
        -- 看似「窗口已被挤窄、再 hide 没意义」，但用户真正看到乱码取决于更晚的屏幕重绘：
        -- nvim 把重绘 flush 推迟到 autocmd 执行完之后，CLI 子进程对 SIGWINCH 的重渲染更是异步。
        -- 因此在 callback 里同步 hide()，会先于这次 flush 生效——折叠后的乱码根本没被画出来。
        -- 这条竞速与 resize 幅度无关，再大的突变也成立，故无需拦截「resize 之前」的中间态。
        local winnr = instance.ui.winnr
        if winnr and vim.api.nvim_win_is_valid(winnr) and vim.api.nvim_win_get_width(winnr) < CLI_WIDTH then
          instance.ui:hide()
        end
      end,
    })
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
      cli = {
        window = {
          layout = "vertical", -- 垂直分屏（继承自 chat，此处显式声明便于阅读）
          position = "left", -- 默认在左侧打开，避免 nvim resize 时优先压缩右侧窗口
          full_height = true, -- 占满整列高度（topleft vsplit）
          width = CLI_WIDTH, -- 固定列数：>= 1 为绝对列数；< 1 为编辑器宽度比例
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
          ".rules",
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
      cli = {
        -- 默认 agent：可通过 :CodeCompanionCLI agent=codex 临时切换
        agent = "claude_code",
        agents = {
          claude_code = {
            cmd = "claude",
            args = {},
            description = "Claude Code CLI",
            provider = "terminal",
          },
          codex = {
            cmd = "codex",
            args = {},
            description = "OpenAI Codex CLI",
            provider = "terminal",
          },
          gemini = {
            cmd = "gemini",
            args = {},
            description = "Gemini CLI",
            provider = "terminal",
          },
        },
        opts = {
          auto_insert = false, -- 切回 CLI 窗口时不自动进 insert
          reload = true, -- 文件被 agent 改动后自动 :checktime
        },
      },
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
    },
    ignore_warnings = true,
    language = "Chinese",
  },
}
