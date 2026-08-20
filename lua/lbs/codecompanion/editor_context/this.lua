-- 覆盖内置 #{this}：上游 this.lua 硬编码 require 内置 selection 模块，
-- 仅在配置里替换 selection.path 影响不到它，故继承上游、只重写 cli_render——
-- 可视分支改指向本地 selection（引用式），其余（nil 警告、buffer 分支）原样回落上游。
local Base = require("codecompanion.interactions.shared.editor_context.this")

---@class LBS.EditorContext.This: CodeCompanion.EditorContext.This
local EditorContext = setmetatable({}, { __index = Base })

---@param args CodeCompanion.EditorContextArgs
function EditorContext.new(args)
  return setmetatable(Base.new(args), { __index = EditorContext })
end

---@return { inline: string, block: string }|nil
function EditorContext:cli_render()
  local ctx = self.buffer_context

  if ctx and ctx.is_visual and ctx.lines and #ctx.lines > 0 then
    return require("lbs.codecompanion.editor_context.selection")
      .new({ buffer_context = ctx, config = self.config, params = self.params })
      :cli_render()
  end

  return Base.cli_render(self)
end

return EditorContext
