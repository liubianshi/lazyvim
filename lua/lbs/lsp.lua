-- LSP 相关的补丁与修复。两处都是绕过外部缺陷的临时措施，
-- 上游修好后应当删除，因此集中放在一起便于将来清理。
local M = {}

-- Workaround for Neovim _changetracking.lua:352 (实测 0.12.2 与 0.12.3 均未修复)
-- 当 R.nvim 的 rnvimserver (r_ls) 与 air language server 同时 attach 同一个 R buffer
-- 时,两者 sync_kind 不同导致落入不同 group;其中一个 group 未走过 init()
-- 路径,state.buffers[bufnr] 为 nil,进入插入模式首次按键即崩。
-- 这里只吞带 "buf_state" 字样的错误,其它 LSP 异常照常抛出。
-- 上游若在 _changetracking.lua 给 `local buf_state = state.buffers[bufnr]` 加
-- nil-guard 后,本块可删除(可搜 _buf_state_guard 定位)。
function M.patch_changetracking()
  local ok, ct = pcall(require, "vim.lsp._changetracking")
  if ok and ct and ct.send_changes and not ct._buf_state_guard then
    local orig = ct.send_changes
    ct.send_changes = function(bufnr, firstline, lastline, new_lastline)
      local ok2, err = pcall(orig, bufnr, firstline, lastline, new_lastline)
      if not ok2 and type(err) == "string" and err:find("buf_state", 1, true) then
        return
      elseif not ok2 then
        error(err)
      end
    end
    ct._buf_state_guard = true
  end
end

-- Lsp ------------------------------------------------------------------ {{{1
--- Restarts LSP clients for a buffer after it has been renamed.
-- This is useful after commands like `:saveas` or `:file new_name`, which
-- can confuse LSP servers that track files by their path.
function M.restart_on_rename(args)
  local bufnr = args.buf

  -- Ensure the buffer is still valid before proceeding.
  if not vim.api.nvim_buf_is_valid(bufnr) then
    return
  end

  -- codecompanion-history 自动设置标题时调用 `nvim_buf_set_name()` 会让 rime_ls 失效，
  -- 需要 detach 再 attach。其他 LSP 同样受影响，但 codecompanion 下通常只有 rime_ls，
  -- 故只处理它，避免影响扩散。
  for _, client in ipairs(vim.lsp.get_clients({ bufnr = bufnr, name = "rime_ls" })) do
    vim.notify("Buffer renamed, restarting rime_ls ...", vim.log.levels.INFO, { title = "LSP" })
    vim.lsp.buf_detach_client(bufnr, client.id)
    -- 下一个事件循环再 attach，避免与 detach 竞争。
    vim.schedule(function()
      vim.lsp.buf_attach_client(bufnr, client.id)
    end)
  end
end

return M
