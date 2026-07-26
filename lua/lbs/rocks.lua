-- 把 LuaRocks 的模块路径接进 package.path / package.cpath。
--
-- 优先 XDG 位置（XDG_DATA_HOME/luarocks），依次回退到 ~/.local/share/luarocks、
-- ~/.luarocks、XDG_CONFIG_HOME/luarocks；同时补 C 模块路径，扩展名由当前
-- package.cpath 推断（so / dll / dylib）。重复加载不会产生重复条目。
local M = {}

function M.setup()
  -- Resolve LuaRocks paths and add them to Lua's package.path and package.cpath
  -- This version prefers XDG-compliant locations when available, falls back to ~/.luarocks,
  -- and avoids adding duplicate entries. It also augments package.cpath for compiled modules.
  
  -- Pick libuv handle compatible with multiple Neovim versions
  local uv = vim and (vim.uv or vim.loop)
  
  -- Helper: return first existing directory from a list of candidates
  local function first_existing_dir(paths)
    if not uv then
      return nil
    end
    for _, p in ipairs(paths) do
      local stat = uv.fs_stat(p)
      if stat and stat.type == "directory" then
        return p
      end
    end
    return nil
  end
  
  -- Helper: append a path segment to a list string if not already present
  local function append_unique(list, segment)
    -- Ensure both sides are semicolon-delimited to avoid substring matches
    local haystack = ";" .. (list or "") .. ";"
    local needle = ";" .. segment .. ";"
    if not haystack:find(needle, 1, true) then
      if list and #list > 0 then
        return list .. ";" .. segment
      else
        return segment
      end
    end
    return list
  end
  
  -- Derive candidate LuaRocks roots (most-preferred first)
  local home = (vim and vim.env and vim.env.HOME) or os.getenv("HOME") or ""
  local xdg_data = (vim and vim.env and vim.env.XDG_DATA_HOME) or os.getenv("XDG_DATA_HOME")
  local xdg_cfg = (vim and vim.env and vim.env.XDG_CONFIG_HOME) or os.getenv("XDG_CONFIG_HOME")
  
  local candidates = {}
  if xdg_data and #xdg_data > 0 then
    table.insert(candidates, xdg_data .. "/luarocks")
  end
  if home ~= "" then
    table.insert(candidates, home .. "/.local/share/luarocks")
    table.insert(candidates, home .. "/.luarocks")
  end
  if xdg_cfg and #xdg_cfg > 0 then
    table.insert(candidates, xdg_cfg .. "/luarocks")
  end
  
  local rocks_root = first_existing_dir(candidates)
  -- Fallback if we couldn't stat anything (e.g., older Neovim without uv): use ~/.luarocks
  if not rocks_root and home ~= "" then
    rocks_root = home .. "/.luarocks"
  end
  
  -- Determine Lua version directory (e.g., "5.1"). Neovim uses LuaJIT compatible with 5.1.
  local lua_version = (_VERSION and _VERSION:match("(%d+%.%d+)")) or "5.1"
  
  -- Infer shared library extension from current package.cpath (so, dll, dylib)
  local inferred_ext = (package.cpath or ""):match("%?%.([%a%d]+)") or "so"
  
  -- Build LuaRocks search patterns
  local lua_paths = {
    rocks_root .. "/share/lua/" .. lua_version .. "/?.lua",
    rocks_root .. "/share/lua/" .. lua_version .. "/?/init.lua",
  }
  
  local c_paths = {
    rocks_root .. "/lib/lua/" .. lua_version .. "/?." .. inferred_ext,
    rocks_root .. "/lib/lua/" .. lua_version .. "/loadall." .. inferred_ext,
  }
  
  -- Apply to package.path and package.cpath without duplicates
  for _, p in ipairs(lua_paths) do
    package.path = append_unique(package.path, p)
  end
  
  for _, p in ipairs(c_paths) do
    package.cpath = append_unique(package.cpath, p)
  end
  
  --[[
  Summary:
  - Prefers XDG_DATA_HOME/luarocks, then ~/.local/share/luarocks, ~/.luarocks, and XDG_CONFIG_HOME/luarocks.
  - Adds both Lua module paths (?.lua, ?/init.lua) and C module paths (?.<ext>, loadall.<ext>).
  - Avoids duplicating entries across repeated loads.
  - Keeps compatibility with various Neovim versions by using vim.uv or vim.loop when available.
  ]]
end

return M
