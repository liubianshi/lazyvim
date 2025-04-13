local default_opts = {
  ns_name = "LBS_Translate",
  hl_group = "Comment",
  key = "L",
}
local function init(opts)
  return {
    opts = opts,
    extmark = require("util.extmark").new(opts.ns_name),
    ns_id = vim.api.nvim_get_namespaces()[opts.ns_name] or vim.api.nvim_create_namespace(opts.ns_name),
  }
end

local M = init(default_opts)

---@param buf integer buffer number, 0 for current buffer
---@param row integer Line where to place the mark, 0-based
---@param col integer Column where to place the mark, 0-based
---@param text string virtual text to add
local function set_text_extmark(buf, row, col, text, opts)
  opts = vim.tbl_deep_extend("keep", opts or {}, {
    virt_text_pos = "inline",
    virt_text_repeat_linebreak = true,
    hl_mode = "combine",
  })
  opts.virt_text = { { string.format("[%s]", text), M.opts.hl_group } }
  vim.api.nvim_buf_set_extmark(buf, M.ns_id, row, col, opts)
end

---@param buf integer buffer number, 0 for current buffer
---@param row integer Line where to place the mark, 0-based
---@param lines string[] virtual lines to add
---@param opts? vim.api.keyset.set_extmark
local function set_line_extmark(buf, row, lines, opts)
  opts = vim.tbl_deep_extend("keep", opts or {}, {
    virt_lines_leftcol = false,
  })
  opts.virt_lines = vim.tbl_map(function(line)
    return { { line, M.opts.hl_group } }
  end, lines)
  vim.api.nvim_buf_set_extmark(buf, M.ns_id, row, 0, opts)
end

---@param content string
---@param callback function
function M.translate_phrase(content, callback)
  if not content or #content == 0 then
    return
  end
  local cmd = { "deepl", content }
  vim.system(cmd, { text = true }, function(obj)
    if obj.code ~= 0 then
      vim.notify("Failed to translate " .. content .. "\n" .. obj.stderr, "error")
      return
    end
    local result = vim.split(vim.trim(obj.stdout), "\n")[2]
    vim.schedule(function()
      callback(result)
    end)
  end)
end

---@param content string[] Content to be translated
---@param callback function
---@return string[]|nil
function M.translate_paragraph(content, callback)
  if not content or #content == 0 then
    return
  end

  local cmd = { "fabric", "--pattern", "translate", "-m=gemini-2.0-flash-exp", "--stream" }

  local head_chars = vim.trim(content[1]):sub(1, 20)
  local is_cjk = false
  for _, char in ipairs(vim.fn.split(head_chars, "\\zs")) do
    if is_cjk_character(char) then
      is_cjk = true
      break
    end
  end
  if is_cjk then
    table.insert(cmd, "-v=lang_code:en_US")
  else
    table.insert(cmd, "-v=lang_code:zh_cn")
  end

  local ok, progress = pcall(require, "fidget.progress")
  local progress_handle
  if ok then
    progress_handle = progress.handle.create({
      title = " Requesting Fabric (Translate)",
      message = "In progress...",
      lsp_client = {
        name = "Fabric",
      },
    })
  end

  vim.system(cmd, { stdin = content }, function(obj_trans)
    if progress_handle then
      if obj_trans.code ~= 0 then
        progress_handle.message = " Faild to translate with fabric"
        progress_handle:finish()
      else
        progress_handle.message = "Translate Complete"
        progress_handle.message = "Starting formatting..."
      end
    end

    vim.system({ "mdwrap" }, { stdin = vim.split(obj_trans.stdout, "\n") }, function(obj_format)
      if progress_handle then
        progress_handle.message = obj_format.code == 0 and "Completed" or " Failed to formatting"
        progress_handle:finish()
      end
      local translated_liens = vim.split(vim.trim(obj_format.stdout), "\n")
      vim.schedule(function()
        callback(translated_liens)
      end)
    end)
  end)
end

function M.run()
  local winid = vim.api.nvim_get_current_win()
  local buf = vim.api.nvim_win_get_buf(winid)
  local visual_coordiate = require("util").get_visual_coordinate()
  local content = require("util").get_visual_selection()
  if not visual_coordiate or not content or #content == 0 then
    return
  end
  local srow, scol, erow, ecol = unpack(visual_coordiate)

  if srow == erow and (scol ~= 1 or ecol < vim.fn.getline(srow):len()) then
    M.translate_phrase(content[1], function(text)
      set_text_extmark(buf, erow - 1, ecol, text)
    end)
  else
    local grouped_content, paragraph_range = require("util").join_strings_by_paragraph(content)
    table.insert(grouped_content, "")
    local paragraph_end = vim.tbl_map(function(range)
      return range.finish + srow - 1
    end, paragraph_range or {})

    M.translate_paragraph(grouped_content, function(lines)
      local para = {}
      local para_id = 1
      for _, line in ipairs(lines) do
        local trimmed_line = vim.trim(line or "")
        if #trimmed_line > 0 then
          table.insert(para, trimmed_line)
        else
          set_line_extmark(buf, paragraph_end[para_id] - 1, para)
          para_id = para_id + 1
          para = {}
        end
      end
      if #para > 0 then
        set_line_extmark(buf, paragraph_end[para_id] - 1, para)
      end
    end)
  end
end

function M.trans_op(type)
  local commands = {
    line = "'[V']",
    char = "`[v`]",
    block = "`[\\<C-V>`]",
  }
  if not type or #type == 0 then
    vim.opt.opfunc = "v:lua.require'translate'.trans_op"
    vim.api.nvim_feedkeys("g@", "m", false)
  else
    vim.cmd.normal(commands[type])
    M.run()
  end
end

function M.toggle()
  M.extmark:toggle_extmarks()
end

return M
