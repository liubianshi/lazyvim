-- 键位注册，经由 which-key 的 add()。setup 前后调用都能落地：which-key 的
-- init.lua 里那个只做 table.insert(M._queue, ...) 的 add() 是引导期占位实现，
-- config.lua 在 setup 时用 `wk.add = M.add` 把它替换成真实实现（实测 setup
-- 之后 add 的映射，maparg 立即可取，队列始终为空）。
local M = {}

function M.keymap(mapping)
  local wk_ok, wk = pcall(require, "which-key")
  if wk_ok then
    wk.add({ mapping })
    return
  end

  -- Fallback to native vim.keymap.set if which-key is not found.
  local lhs = mapping[1]
  local rhs = mapping[2]
  if not lhs or not rhs then
    return
  end

  -- Prepare options for vim.keymap.set
  local opts = {}
  for k, v in pairs(mapping) do
    if type(k) == "string" then
      opts[k] = v
    end
  end

  local mode = opts.mode or "n"
  opts.mode = nil -- Mode is a separate argument for vim.keymap.set
  opts = vim.tbl_deep_extend("keep", opts, { silent = true, remap = false })
  vim.keymap.set(mode, lhs, rhs, opts)
end

function M.wk_reg(mapping, opts)
  local wk_ok, wk = pcall(require, "which-key")
  if not wk_ok then
    return
  end
  wk.add(mapping, opts)
end

return M
