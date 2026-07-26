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
    -- 契约靠断言守住：某个 picker 若改成返回模块表，调用方只会在按键那一刻
    -- 得到一句「未找到」，指不到真正的原因。
    assert(type(fn) == "function", "lbs.picker." .. key .. " 必须返回函数")
    rawset(M, key, fn) -- 缓存，后续取值直接命中，不再走 __index
    return fn
  end,
})
