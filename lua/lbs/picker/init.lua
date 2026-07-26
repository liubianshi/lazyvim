-- picker 注册表。
--
-- 每个 picker 独立成文件，本模块按需加载并缓存，调用形式保持不变：
--   require("lbs.picker").fabric(opts)
-- 取到的必须是函数——config/keymaps.lua 的 safe_picker_call 会检查
-- type(fn) == "function"，返回模块表会让它当成「未找到」而静默失败。

local names = {
  "cheat",
  "citation",
  "cliphist",
  "fabric",
  "fasd",
  "mylib",
  "roam",
  "stata_doc",
}

local lookup = {}
for _, name in ipairs(names) do
  lookup[name] = true
end

local M = {}

return setmetatable(M, {
  __index = function(_, key)
    if not lookup[key] then
      return nil
    end
    local fn = require("lbs.picker." .. key)
    rawset(M, key, fn) -- 缓存，后续取值直接命中，不再走 __index
    return fn
  end,
})
