-- CLI 交互下的可视选区上下文：只发文件引用（@path + 行号），不复制选区内容。
-- Claude Code 等 CLI agent 会自己读文件，复制内容徒增 token。
-- 但 agent 读的是磁盘文件：缓冲区有未保存修改、或缓冲区没有对应文件时，
-- 引用会指向与选区不符的内容，此时回退到上游实现，完整发送选区。
-- chat 交互（chat_render）不受影响：普通 API 适配器读不了文件，仍需完整内容。
local Base = require("codecompanion.interactions.shared.editor_context.selection")

local fmt = string.format

---@class LBS.EditorContext.Selection: CodeCompanion.EditorContext.Selection
local EditorContext = setmetatable({}, { __index = Base })

---@param args CodeCompanion.EditorContextArgs
function EditorContext.new(args)
  return setmetatable(Base.new(args), { __index = EditorContext })
end

---是否存在可用 @file 引用安全指代的选区（agent 读磁盘文件即可还原选区）。
---「有可视选区」也归入判定，使调用方免于重复计算这对谓词。
---@param ctx CodeCompanion.BufferContext|nil
---@return boolean
function EditorContext.can_reference(ctx)
  return ctx ~= nil
    and ctx.is_visual == true
    and ctx.lines ~= nil
    and #ctx.lines > 0
    and ctx.path ~= nil
    and ctx.path ~= ""
    and ctx.bufnr ~= nil
    and vim.api.nvim_buf_is_valid(ctx.bufnr)
    and not vim.bo[ctx.bufnr].modified
end

---选区的 @file + 行号引用文本。引用格式的唯一归属：
---plugins/codecompanion.lua 中 resolve_editor_context 的覆写也从这里取。
---@param ctx CodeCompanion.BufferContext
---@return string
function EditorContext.reference(ctx)
  return fmt("@%s (lines %d-%d)", ctx.relative_path, ctx.start_line, ctx.end_line)
end

---@return { inline: string, block: string }|nil
function EditorContext:cli_render()
  local ctx = self.buffer_context

  if not EditorContext.can_reference(ctx) then
    return Base.cli_render(self)
  end

  return {
    inline = "the selected code in " .. EditorContext.reference(ctx),
  }
end

return EditorContext
