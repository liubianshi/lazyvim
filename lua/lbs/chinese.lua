local M = {}

-- Mapping from English to Chinese punctuation and the detection patterns.
-- stylua: ignore start
local PUNCTUATION_MAP = {
  ["'"]  = { is_pair = true,  pattern = "%s*'(.-)'%s*",   replacement = "‘%s’"   },
  ['"']  = { is_pair = true,  pattern = '%s*"(.-)"%s*',   replacement = "「%s」" },
  [")"]  = { is_pair = true,  pattern = "%s*%((.-)%)%s*", replacement = "（%s）" },
  ["]"]  = { is_pair = true,  pattern = "%s*%[(.-)%]%s*", replacement = "【%s】" },
  [">"]  = { is_pair = true,  pattern = "%s*<(.-)>%s*",   replacement = "《%s》" },

  [","]  = { is_pair = false, pattern = "%s*,%s*",        replacement = "，"     },
  ["."]  = { is_pair = false, pattern = "%s*%.%s*",       replacement = "。"     },
  ["\\"] = { is_pair = false, pattern = "%s*\\%s*",       replacement = "、"     },
  [":"]  = { is_pair = false, pattern = "%s*:%s*",        replacement = "："     },
  [";"]  = { is_pair = false, pattern = "%s*;%s*",        replacement = "；"     },
  ["-"]  = { is_pair = false, pattern = "%s*%-%s*",       replacement = "—"      },
  ["_"]  = { is_pair = false, pattern = "%s*_%s*",        replacement = "——"     },
  ["^"]  = { is_pair = false, pattern = "%s*%^%s*",       replacement = "……"     },
  ["!"]  = { is_pair = false, pattern = "%s*%!%s*",       replacement = "！"     },
  ["?"]  = { is_pair = false, pattern = "%s*%?%s*",       replacement = "？"     },
}
-- stylua: ignore end

-- Helper to skip spaces after a given 0-based column index
local function skip_spaces(line, col0)
  local idx = (line:find("%S", col0 + 1) or (#line + 1)) - 1
  return idx
end

--- Replace English punctuation with Chinese punctuation equivalents on the current line.
---
--- Behavior:
--- - If the last non-space character before the cursor is a supported punctuation mark,
---   this function attempts to replace the matched punctuation sequence ending at the cursor
---   with the corresponding Chinese punctuation. For paired punctuation (quotes, brackets),
---   the inner text is preserved and trimmed.
function M.replace_en_with_cn_punctuation()
  -- Get cursor row (1-based) and column (0-based), and the current line text
  local cursor_row, cursor_col = unpack(vim.api.nvim_win_get_cursor(0))
  local current_line = vim.api.nvim_get_current_line()

  if current_line == "" then
    vim.notify("Current line is empty", vim.log.levels.INFO)
    return
  end

  -- Advance cursor_col past any spaces so we operate on the next non-space region
  cursor_col = skip_spaces(current_line, cursor_col)

  local line_before_cursor = current_line:sub(1, cursor_col)
  local line_after_cursor = current_line:sub(cursor_col + 1)

  -- Determine the punctuation that triggers replacement: the last non-space char before cursor
  local trigger_char = line_before_cursor:match("([^%s])%s*$")
  if not trigger_char then
    return
  end

  local info = PUNCTUATION_MAP[trigger_char]
  if not info then
    return
  end

  -- Try to match a replaceable segment that ends at the cursor position
  local start_pos, end_pos, inner = line_before_cursor:find(info.pattern .. "$")
  if not start_pos or not end_pos then
    return
  end

  -- Build replacement text
  local replacement
  if info.is_pair then
    local content = vim.trim(inner or "")
    replacement = string.format(info.replacement, content)
  else
    replacement = info.replacement
  end

  -- Reconstruct the new line
  local updated_line = table.concat({
    line_before_cursor:sub(1, start_pos - 1),
    replacement,
    line_before_cursor:sub(end_pos + 1),
    line_after_cursor,
  })

  -- Apply update
  vim.api.nvim_set_current_line(updated_line)

  -- Place cursor just after the inserted Chinese punctuation
  local new_cursor_col = (start_pos - 1) + #replacement
  vim.api.nvim_win_set_cursor(0, { cursor_row, new_cursor_col })
end

return M
