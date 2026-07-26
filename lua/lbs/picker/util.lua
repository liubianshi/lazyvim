-- pickers 之间共用的小工具。
local M = {}

function M.get_folders(path)
  local folders = {}
  local entries = vim.fn.readdir(path)

  for _, entry in ipairs(entries) do
    local full_path = path .. "/" .. entry
    if vim.fn.isdirectory(full_path) == 1 then
      table.insert(folders, entry)
    end
  end

  return folders
end

function M.get_reference(picker)
  local cmd = { "bibref" }
  for _, item in ipairs(picker:selected({ fallback = true })) do
    table.insert(cmd, item.key)
  end
  picker:close()
  local job = vim.system(cmd, { text = true }):wait()
  if job.code == 0 and job.stdout ~= "" then
    local ref = job.stdout:gsub("\n+$", "")
    vim.fn.setreg("+", ref)
  end
end

return M
