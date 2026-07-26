-- GNU GLOBAL (gtags) 查询，结果送入 quickfix。
--
-- Neovim 移除了内置 cscope（没有 :cscope / cscopeprg），所以这里直接调用
-- `global` 而不再走 cscope 桥接。GTAGSLABEL=native-pygments 在
-- config/options.lua 设置；数据库需先用 :GtagsUpdate 生成（在 cwd 跑 `gtags`）。
local M = {}

--- `global` 是否可用。不可用时调用方应整组跳过，不注册命令与键位。
function M.available()
  return vim.fn.executable("global") == 1
end

-- Run `global <flag> <pattern>` and populate the quickfix list.
-- flag: "-d" definitions, "-r" references, "-s" other symbols.
function M.query(flag, label, pattern)
  pattern = (pattern ~= nil and pattern ~= "") and pattern or vim.fn.expand("<cword>")
  if pattern == "" then
    vim.notify("gtags: no symbol under cursor", vim.log.levels.WARN)
    return
  end
  -- `--result=grep` prints `file:lineno:source line`, parsed below.
  local out = vim.fn.systemlist({ "global", "--result=grep", flag, pattern })
  if vim.v.shell_error ~= 0 then
    vim.notify("gtags: " .. table.concat(out, "\n"), vim.log.levels.ERROR)
    return
  end
  if vim.tbl_isempty(out) then
    vim.notify(string.format("gtags: no %s for '%s'", label, pattern), vim.log.levels.INFO)
    return
  end
  local items = {}
  for _, line in ipairs(out) do
    local file, lnum, text = line:match("^(.-):(%d+):(.*)$")
    if file then
      items[#items + 1] = { filename = file, lnum = tonumber(lnum), text = text }
    end
  end
  vim.fn.setqflist({}, " ", { title = string.format("gtags %s: %s", label, pattern), items = items })
  -- Jump straight to the sole match, otherwise open the quickfix list.
  if #items == 1 then
    vim.cmd("cfirst")
  else
    vim.cmd("botright copen")
  end
end

-- (Re)build the gtags database in the current working directory.
function M.update()
  vim.notify("gtags: building database ...", vim.log.levels.INFO)
  local out = vim.fn.system({ "gtags" })
  if vim.v.shell_error ~= 0 then
    vim.notify("gtags update failed: " .. out, vim.log.levels.ERROR)
  else
    vim.notify("gtags: database updated", vim.log.levels.INFO)
  end
end

-- 由 config/keymaps.lua 在确认 `global` 可用后调用；require 本模块不产生副作用。
function M.setup_commands()
  vim.api.nvim_create_user_command("GtagsUpdate", M.update, { desc = "gtags: build/refresh database" })
  vim.api.nvim_create_user_command("Gtags", function(o)
    M.query("-d", "definitions", o.args)
  end, { nargs = "?", desc = "gtags: definitions" })
  vim.api.nvim_create_user_command("GtagsRef", function(o)
    M.query("-r", "references", o.args)
  end, { nargs = "?", desc = "gtags: references" })
  vim.api.nvim_create_user_command("GtagsSym", function(o)
    M.query("-s", "symbols", o.args)
  end, { nargs = "?", desc = "gtags: other symbols" })
end

return M
