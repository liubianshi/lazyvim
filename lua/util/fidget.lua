local progress = require("fidget.progress")

local M = {}

function M:init()
  local group = vim.api.nvim_create_augroup("CodeCompanionFidgetHooks", {})
  vim.api.nvim_create_autocmd({ "User" }, {
    pattern = "CodeCompanionRequest*",
    group = group,
    callback = function(request)
      if request.data.strategy == "chat" then
        return
      end
      if request.match == "CodeCompanionRequestStarted" then
        local handle = M:create_progress_handle(request)
        M:store_progress_handle(request.data.id, handle)
      elseif request.match == "CodeCompanionRequestFinished" then
        local handle_data_id = M:pop_progress_handle(request.data.id)
        if handle_data_id then
          M:report_exit_status(handle_data_id, request)
          handle_data_id:finish()
        end
      end
    end,
  })
end

M.handles = {}

function M:store_progress_handle(id, handle)
  M.handles[id] = handle
end

function M:pop_progress_handle(id)
  local handle = M.handles[id]
  M.handles[id] = nil
  return handle
end

function M:create_progress_handle(request)
  return progress.handle.create({
    title = " Requesting assistance (" .. request.data.strategy .. ")",
    message = "In progress...",
    lsp_client = {
      name = M:llm_role_title(request.data.adapter),
    },
  })
end

function M:llm_role_title(adapter)
  local parts = {}
  table.insert(parts, adapter.formatted_name)
  if adapter.model and adapter.model ~= "" then
    table.insert(parts, "(" .. adapter.model .. ")")
  end
  return table.concat(parts, " ")
end

function M:report_exit_status(handle, request)
  if request.data.status == "success" then
    handle.message = "Completed"
  elseif request.data.status == "error" then
    handle.message = " Error"
  else
    handle.message = "󰜺 Cancelled"
  end
end

return M
