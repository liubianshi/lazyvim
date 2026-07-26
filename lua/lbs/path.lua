-- 路径与项目定位：项目根、日记文件路径、Obsidian vault 判定。
local M = {}

M.root_patterns = { ".git", "lua", ".obsidian", ".vim", ".exercism" }

-- returns the root directory based on:
-- * lsp workspace folders
-- * lsp rootdir
-- * root pattern of filename of the current buffer
-- * root pattern of cwd
---@return string
function M.get_root(path, root_patterns)
  root_patterns = root_patterns or M.root_patterns
  if type(root_patterns) ~= "table" then
    root_patterns = { root_patterns }
  end
  ---@type string?
  path = path or vim.api.nvim_buf_get_name(0)
  path = path ~= "" and vim.uv.fs_realpath(path) or nil
  ---@type string[]
  local roots = {}
  if path then
    for _, client in pairs(vim.lsp.get_clients({ bufnr = 0 })) do
      local workspace = client.config.workspace_folders
      -- Use the resolved `client.root_dir` (a string|nil), not
      -- `client.config.root_dir` which may still hold a function for clients
      -- started via `vim.lsp.start`; guard the type so a function never reaches
      -- `vim.loop.fs_realpath` / `vim.fs.normalize`.
      local paths = workspace
          and vim.tbl_map(function(ws)
            return vim.uri_to_fname(ws.uri)
          end, workspace)
        or (type(client.root_dir) == "string" and { client.root_dir })
        or {}
      for _, p in ipairs(paths) do
        local r = vim.loop.fs_realpath(p) or ""
        if path:find(r, 1, true) then
          roots[#roots + 1] = r
        end
      end
    end
  end
  table.sort(roots, function(a, b)
    return #a > #b
  end)
  ---@type string?
  local root = roots[1]
  if not root then
    path = path and vim.fs.dirname(path) or vim.uv.cwd()
    ---@type string?
    root = vim.fs.find(root_patterns, { path = path, upward = true })[1]
    root = root and vim.fs.dirname(root) or vim.loop.cwd()
  end
  ---@cast root string
  return root
end

--- Generate file paths that meet a specific format based on today's date
---@param ext? string
---@param base? string|string[]
---@param pre? string
---@return string
M.get_daily_filepath = function(ext, base, pre)
  ext = ext and ("." .. ext) or ""
  pre = pre and (pre .. "-") or ""
  if not base then
    base = "/"
  elseif type(base) == "table" then
    base = "/" .. table.concat(base, "/") .. "/"
  else
    base = "/" .. base .. "/"
  end
  local writing_room = vim.env.WRITING_LIB or vim.env.HOME .. "/Documents/writing"
  local basename = os.date("%Y%m%d")
  return writing_room .. base .. pre .. basename .. ext
end

function M.in_obsidian_vault(buf)
  if not buf or (type(buf) == "table" and #buf == 0) then
    buf = 0
  end
  local root_dir = M.get_root(vim.api.nvim_buf_get_name(buf))

  if root_dir and root_dir:match("/vaults/") then
    return root_dir
  end
end

return M
