-- pickers 之间共用的小工具。
local M = {}

--- 列出 path 下的一级子目录名。
--- 用 fs_scandir 一次遍历同时拿到名字与类型，避免 readdir 之后再逐项 isdirectory
--- ——fabric 的 pattern 目录有一两百项，那样每次开 picker 就多出同样多次 stat。
function M.get_folders(path)
  local folders = {}
  local dir = vim.uv.fs_scandir(path)
  if not dir then
    return folders
  end
  while true do
    local name, entry_type = vim.uv.fs_scandir_next(dir)
    if not name then
      return folders
    end
    if entry_type == "directory" then
      folders[#folders + 1] = name
    end
  end
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
