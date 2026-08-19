-- blink.cmp source for Claude Code prompt buffers (/tmp/claude-<uid>/claude-prompt-<hash>.md)
-- 提供两类补全：`@` 文件引用（fd 异步枚举项目文件）与行首 `/` 命令（内置命令 + commands + skills）。
-- 依赖 project.nvim 对 /tmp/* 的排除：cwd 保持为 claude 继承来的项目根。

local CompletionItemKind = vim.lsp.protocol.CompletionItemKind

-- Claude Code 内置斜杠命令（无官方导出接口，静态维护）
local BUILTIN_COMMANDS = {
  "clear",
  "compact",
  "config",
  "cost",
  "doctor",
  "help",
  "init",
  "memory",
  "model",
  "permissions",
  "resume",
  "review",
  "status",
}

--- 枚举 <dir>/**/*.md 为命令名，子目录映射为 a:b 命名空间
local function scan_commands(dir)
  local names = {}
  if vim.fn.isdirectory(dir) == 0 then
    return names
  end
  for _, f in ipairs(vim.fn.globpath(dir, "**/*.md", false, true)) do
    local rel = f:sub(#dir + 2):gsub("%.md$", ""):gsub("/", ":")
    names[#names + 1] = rel
  end
  return names
end

--- 枚举 <dir>/*/SKILL.md，取技能目录名
local function scan_skills(dir)
  local names = {}
  if vim.fn.isdirectory(dir) == 0 then
    return names
  end
  for _, f in ipairs(vim.fn.globpath(dir, "*/SKILL.md", false, true)) do
    names[#names + 1] = vim.fn.fnamemodify(f, ":h:t")
  end
  return names
end

local function collect_commands()
  local home = vim.env.HOME
  local cwd = vim.uv.cwd()
  local seen, names = {}, {}
  local function add(list)
    for _, name in ipairs(list) do
      if not seen[name] then
        seen[name] = true
        names[#names + 1] = name
      end
    end
  end
  add(BUILTIN_COMMANDS)
  add(scan_commands(home .. "/.claude/commands"))
  add(scan_skills(home .. "/.claude/skills"))
  if cwd then
    add(scan_commands(cwd .. "/.claude/commands"))
    add(scan_skills(cwd .. "/.claude/skills"))
  end
  return names
end

--- 异步枚举项目文件；返回可 kill 的进程句柄
local function list_files(cb)
  local cmd
  if vim.fn.executable("fd") == 1 then
    cmd = { "fd", "--type", "f", "--hidden", "--exclude", ".git", "--max-results", "3000" }
  else
    cmd = { "git", "ls-files", "--cached", "--others", "--exclude-standard" }
  end
  return vim.system(
    cmd,
    { cwd = vim.uv.cwd(), text = true },
    vim.schedule_wrap(function(out)
      if out.code ~= 0 or not out.stdout then
        return cb({})
      end
      cb(vim.split(out.stdout, "\n", { trimempty = true }))
    end)
  )
end

--- @class blink.cmp.Source
local source = {}

function source.new(opts)
  return setmetatable({ opts = opts or {} }, { __index = source })
end

function source:enabled()
  return vim.api.nvim_buf_get_name(0):match("/claude%-prompt%-[%w%-]+%.md$") ~= nil
end

function source:get_trigger_characters()
  return { "@", "/" }
end

function source:get_completions(context, callback)
  callback = vim.schedule_wrap(callback)
  local row, col = context.pos.row, context.pos.col
  local before = context.line:sub(1, col)

  -- `@` 文件分支：取光标前最后一个 @，其后不能有空白（已进入下一个词则不触发）
  local at_idx = before:match(".*()@") -- 1-based 位置
  if at_idx and not before:sub(at_idx + 1):find("%s") then
    -- @ 的 LSP character 为 at_idx-1，从其后一位（= at_idx）替换到光标
    local range = {
      start = { line = row, character = at_idx },
      ["end"] = { line = row, character = col },
    }
    local proc = list_files(function(files)
      local items = {}
      for _, f in ipairs(files) do
        items[#items + 1] = {
          label = f,
          kind = CompletionItemKind.File,
          filterText = f,
          textEdit = { newText = f, range = range },
        }
      end
      callback({ is_incomplete_forward = false, is_incomplete_backward = false, items = items })
    end)
    return function()
      pcall(function()
        proc:kill(9)
      end)
    end
  end

  -- `/` 命令分支：仅行首（前面全空白），连同 / 一起替换
  local slash_idx = before:match("^%s*()/")
  if slash_idx and not before:sub(slash_idx + 1):find("%s") then
    local range = {
      start = { line = row, character = slash_idx - 1 },
      ["end"] = { line = row, character = col },
    }
    local items = {}
    for _, name in ipairs(collect_commands()) do
      items[#items + 1] = {
        label = "/" .. name,
        kind = CompletionItemKind.Function,
        -- blink 的 keyword 不含 `/`，filterText 须为裸命令名才能匹配
        filterText = name,
        textEdit = { newText = "/" .. name, range = range },
      }
    end
    callback({ is_incomplete_forward = false, is_incomplete_backward = false, items = items })
    return
  end

  callback({ is_incomplete_forward = false, is_incomplete_backward = false, items = {} })
end

return source
