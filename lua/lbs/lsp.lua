-- LSP 相关修复。
--
-- 此处原有一个 vim.lsp._changetracking.send_changes 的 monkey-patch，绕过
-- R.nvim 的 rnvimserver 与 air 同时 attach 同一 R buffer 时 state.buffers[bufnr]
-- 为 nil 的崩溃（0.12.2 / 0.12.3 复现）。上游已在 0.12.4 的 _changetracking.lua
-- 给两处 `local buf_state = state.buffers[bufnr]` 都加了 nil-guard，删除条件满足，
-- 故整块移除——它包在每次文本变更的路径上，留着是纯开销。
local M = {}

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
    -- 下一个事件循环再 attach，避免与 detach 竞争。这一 tick 之间 buffer 可能被
    -- wipe、client 可能被 stop，届时 buf_attach_client 只会往 log 写一条 warn 就
    -- 返回 false，rime_ls 静默保持 detached；所以在闭包里复查一次。
    vim.schedule(function()
      if not vim.api.nvim_buf_is_loaded(bufnr) then
        return
      end
      if not vim.lsp.get_client_by_id(client.id) then
        vim.notify("rime_ls 已停止，未能重新 attach", vim.log.levels.WARN, { title = "LSP" })
        return
      end
      vim.lsp.buf_attach_client(bufnr, client.id)
    end)
  end
end

return M
