local M = {}

--- Replace English punctuation with Chinese punctuation equivalents
---
--- This function replaces paired English punctuation marks (quotes and parentheses)
--- with their Chinese equivalents on the current line based on cursor position.
function M.replace_en_with_cn_punctuation()
  -- Mapping of English punctuation to Chinese equivalents
  local punctuation_map = {
    ["'"] = {
      pattern = "%s*%\\?%'(.-)%\\?%'%s*",
      replacement = function(content)
        return "‘" .. content .. "’"
      end,
    },
    [">"] = {
      pattern = "%s*%\\?%<(.-)%\\?%>%s*",
      replacement = function(content)
        return "《" .. content .. "》"
      end,
    },
    ["]"] = {
      pattern = "%s*%\\?%[(.-)%\\?%]%s*",
      replacement = function(content)
        return "【" .. content .. "】"
      end,
    },
    ['"'] = {
      pattern = '%s*%\\?%"(.-)%\\?%"%s*',
      replacement = function(content)
        return "「" .. content .. "」"
      end,
    },
    [")"] = {
      pattern = "%s*%((.-)%)%s*",
      replacement = function(content)
        return "（" .. content .. "）"
      end,
    },
    [","] = {
      pattern = "%,()%s*",
      replacement = function(_)
        return "，"
      end,
    },
    ["."] = {
      pattern = "%.()%s*",
      replacement = function(_)
        return "。"
      end,
    },
    ["\\"] = {
      pattern = "%\\()%s*",
      replacement = function(_)
        return "、"
      end,
    },
    [":"] = {
      pattern = "%:()%s*",
      replacement = function(_)
        return "："
      end,
    },
    [";"] = {
      pattern = "%;()%s*",
      replacement = function(_)
        return "；"
      end,
    },
    ["-"] = {
      pattern = "%-()%s*",
      replacement = function(_)
        return "—"
      end,
    },
    ["_"] = {
      pattern = "%_()%s*",
      replacement = function(_)
        return "——"
      end,
    },
    ["^"] = {
      pattern = "%^()%s*",
      replacement = function(_)
        return "……"
      end,
    },
    ["!"] = {
      pattern = "%!()%s*",
      replacement = function(_)
        return "！"
      end,
    },
    ["?"] = {
      pattern = "%?()%s*",
      replacement = function(_)
        return "？"
      end,
    },
  }

  local cursor_row, cursor_col = unpack(vim.api.nvim_win_get_cursor(0))
  local current_line = vim.api.nvim_get_current_line()

  -- Early return if line is empty
  if current_line == "" then
    vim.notify("Current line is empty", vim.log.levels.INFO)
    return
  end

  -- Skip whitespace after cursor
  while cursor_col < #current_line and current_line:sub(cursor_col + 1, cursor_col + 1) == " " do
    cursor_col = cursor_col + 1
  end

  local line_before_cursor = current_line:sub(1, cursor_col)
  local line_after_cursor = current_line:sub(cursor_col + 1)

  -- Find the last non-whitespace character before cursor
  local trigger_char = line_before_cursor:match("([^%s])%s*$")
  local punctuation_info = punctuation_map[trigger_char]

  if not punctuation_info then
    vim.notify("No supported punctuation found before cursor", vim.log.levels.WARN)
    return
  end

  -- Search for paired punctuation in the line before cursor
  local start_pos, content, end_pos = line_before_cursor:match("()" .. punctuation_info.pattern .. "()$")

  if not start_pos or not content then
    vim.notify("No paired punctuation found on current line", vim.log.levels.WARN)
    return
  end

  -- Create the replacement with Chinese punctuation
  local trimmed_content = vim.fn.trim(content)
  local chinese_replacement = punctuation_info.replacement(trimmed_content)

  -- Construct the updated line
  local line_prefix = line_before_cursor:sub(1, start_pos - 1)
  local line_suffix = line_before_cursor:sub(end_pos + 1)
  local updated_line = line_prefix .. chinese_replacement .. line_suffix .. line_after_cursor

  -- Apply changes to buffer
  vim.api.nvim_set_current_line(updated_line)

  -- Position cursor after the Chinese punctuation
  local new_cursor_col = start_pos - 1 + #chinese_replacement
  vim.api.nvim_win_set_cursor(0, { cursor_row, new_cursor_col })
end

return M
