local M = {}

function M.setup()
  local timeout = 10000 -- Auto-save delay in milliseconds (e.g., 10000ms = 10 seconds)
  local timers = {}
  local group = vim.api.nvim_create_augroup("LBS_AutoSave", { clear = true })
  local aucmd = vim.api.nvim_create_autocmd

  -- Core save function
  local function save(buf)
    vim.api.nvim_buf_call(buf, function()
      vim.cmd("noautocmd update")
    end)
  end

  -- Autocommand: Schedule auto-save on buffer modification or leaving insert mode.
  aucmd({ "InsertLeave", "TextChanged" }, {
    group = group,
    desc = "Schedule auto-saving for modified buffers",
    callback = function(event)
      local buf = event.buf
      local bo = vim.bo[buf]

      if
        vim.api.nvim_buf_get_name(buf) == ""
        or bo.buftype ~= ""
        or bo.filetype == "gitcommit"
        or bo.readonly
        or not bo.modified
      then
        return
      end

      local timer = timers[buf]
      if timer and timer:is_active() then
        timer:stop()
      end

      if not timer then
        timer = vim.uv.new_timer()
        if not timer then
          vim.notify("AutoSave: Failed to create timer for buffer " .. buf, vim.log.levels.ERROR)
          return
        end
        timers[buf] = timer
      end

      timer:start(
        timeout,
        0,
        vim.schedule_wrap(function()
          if vim.api.nvim_buf_is_valid(buf) then
            local current_bo = vim.bo[buf]
            if current_bo and current_bo.modified and not current_bo.readonly then
              save(buf)
            end
          end
        end)
      )
    end,
  })

  -- Autocommand: Save all pending buffers immediately on specific global events.
  aucmd({ "FocusLost", "ExitPre", "TermEnter" }, {
    group = group,
    desc = "Save all modified buffers with pending auto-save timers immediately",
    callback = function()
      for buf, timer in pairs(timers) do
        if vim.api.nvim_buf_is_valid(buf) then
          if timer:is_active() then
            timer:stop()
            local bo = vim.bo[buf]
            if bo and bo.modified and not bo.readonly then
              save(buf)
            end
          end
        else
          if timer:is_active() then
            timer:stop()
          end
          timer:close()
          timers[buf] = nil
        end
      end
    end,
  })

  -- Autocommand: Cancel scheduled auto-saving on manual save or entering insert mode.
  aucmd({ "BufWritePost", "InsertEnter" }, {
    group = group,
    desc = "Cancel scheduled auto-saving for the current buffer",
    callback = function(event)
      local timer = timers[event.buf]
      if timer and timer:is_active() then
        timer:stop()
      end
    end,
  })

  -- Autocommand: Clean up timer when a buffer is deleted.
  aucmd({ "BufDelete" }, {
    group = group,
    desc = "Remove and close timer for a deleted buffer",
    callback = function(event)
      local timer = timers[event.buf]
      if timer then
        if timer:is_active() then
          timer:stop()
        end
        timer:close()
        timers[event.buf] = nil
      end
    end,
  })
end

return M
