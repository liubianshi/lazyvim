-- 外部进程：异步执行命令并回调。
local M = {}

function M.execute_async(command, callback_funs)
  callback_funs = callback_funs or {}
  callback_funs = vim.tbl_extend("keep", callback_funs, {
    on_stdout = function(_, data, _)
      if type(data) ~= "table" then
        data = { data }
      end
      print(vim.fn.join(data, ""))
    end,
    on_error = function(_, data, _)
      if type(data) ~= "table" then
        data = { data }
      end
      print(vim.fn.join(data, ""))
    end,
    on_exit = function(_, data, _)
      if type(data) ~= "table" then
        data = { data }
      end
      print(vim.fn.join(data, ""))
    end,
  })

  local job_id = vim.fn.jobstart(command, {
    on_stdout = callback_funs.on_stdout,
    on_stderr = callback_funs.on_stderr,
    on_exit = callback_funs.on_exit,
  })

  return job_id
end

return M
