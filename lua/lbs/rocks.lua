-- 把 LuaRocks 的模块路径接进 package.path / package.cpath。
--
-- 优先 XDG 位置（XDG_DATA_HOME/luarocks），依次回退到 ~/.local/share/luarocks、
-- ~/.luarocks、XDG_CONFIG_HOME/luarocks；同时补 C 模块路径，扩展名由当前
-- package.cpath 推断（so / dll / dylib）。重复加载不会产生重复条目。
local M = {}

--- 取候选目录中第一个真实存在的。
local function first_existing_dir(paths)
  for _, p in ipairs(paths) do
    local stat = vim.uv.fs_stat(p)
    if stat and stat.type == "directory" then
      return p
    end
  end
end

--- 往分号分隔的路径串追加一段，已存在则原样返回。
--- 两侧都补分号再比对，避免命中子串（比如 /a/b 命中 /a/bc）。
local function append_unique(list, segment)
  local haystack = ";" .. (list or "") .. ";"
  if haystack:find(";" .. segment .. ";", 1, true) then
    return list
  end
  return (list and #list > 0) and (list .. ";" .. segment) or segment
end

function M.setup()
  local home = vim.env.HOME or ""
  local xdg_data = vim.env.XDG_DATA_HOME
  local xdg_cfg = vim.env.XDG_CONFIG_HOME

  -- 候选根目录，按优先级排列
  local candidates = {}
  if xdg_data and #xdg_data > 0 then
    candidates[#candidates + 1] = xdg_data .. "/luarocks"
  end
  if home ~= "" then
    candidates[#candidates + 1] = home .. "/.local/share/luarocks"
    candidates[#candidates + 1] = home .. "/.luarocks"
  end
  if xdg_cfg and #xdg_cfg > 0 then
    candidates[#candidates + 1] = xdg_cfg .. "/luarocks"
  end

  -- 一个都不存在时仍按 ~/.luarocks 布好路径，将来装了 rock 不必改配置
  local rocks_root = first_existing_dir(candidates) or (home ~= "" and home .. "/.luarocks")
  if not rocks_root then
    return
  end

  -- Neovim 的 LuaJIT 兼容 5.1
  local lua_version = _VERSION:match("(%d+%.%d+)")
  local ext = (package.cpath or ""):match("%?%.([%a%d]+)") or "so"

  for _, p in ipairs({
    rocks_root .. "/share/lua/" .. lua_version .. "/?.lua",
    rocks_root .. "/share/lua/" .. lua_version .. "/?/init.lua",
  }) do
    package.path = append_unique(package.path, p)
  end

  for _, p in ipairs({
    rocks_root .. "/lib/lua/" .. lua_version .. "/?." .. ext,
    rocks_root .. "/lib/lua/" .. lua_version .. "/loadall." .. ext,
  }) do
    package.cpath = append_unique(package.cpath, p)
  end
end

return M
