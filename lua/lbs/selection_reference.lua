-- Copy a Visual selection as a file location for CLI coding agents.
local M = {}

local function selection_bounds()
  local mode = vim.api.nvim_get_mode().mode
  if mode ~= "v" and mode ~= "V" and mode ~= "\22" then
    return nil
  end

  local anchor = vim.fn.getpos("v")
  local cursor = vim.fn.getpos(".")
  local first_line = math.min(anchor[2], cursor[2])
  local last_line = math.max(anchor[2], cursor[2])

  if mode == "V" then
    return { mode = mode, first_line = first_line, last_line = last_line }
  end

  -- With `list = true`, virtcol returns both edges of a Tab or wide character.
  local anchor_cols = vim.fn.virtcol("v", true)
  local cursor_cols = vim.fn.virtcol(".", true)
  if mode == "\22" then
    return {
      mode = mode,
      first_line = first_line,
      last_line = last_line,
      first_col = math.min(anchor_cols[1], cursor_cols[1]),
      last_col = math.max(anchor_cols[2], cursor_cols[2]),
    }
  end

  -- Characterwise selection has a start and end, unlike a rectangular block.
  if anchor[2] > cursor[2] or (anchor[2] == cursor[2] and anchor[3] > cursor[3]) then
    anchor_cols, cursor_cols = cursor_cols, anchor_cols
  end
  return {
    mode = mode,
    first_line = first_line,
    last_line = last_line,
    first_col = anchor_cols[1],
    last_col = cursor_cols[2],
  }
end

function M.reference()
  local filename = vim.api.nvim_buf_get_name(0)
  if filename == "" then
    return nil, "Cannot copy a location from an unnamed buffer"
  end

  local bounds = selection_bounds()
  if not bounds then
    return nil, "Select text first"
  end

  local absolute = vim.uv.fs_realpath(filename) or vim.fs.normalize(filename)
  local root = require("lbs.path").get_root(filename)
  local path = vim.fs.relpath(root, absolute) or absolute
  local prefix = "@" .. path

  if bounds.mode == "V" then
    return string.format("%s#L%d-%d", prefix, bounds.first_line, bounds.last_line)
  end
  if bounds.mode == "\22" then
    return string.format(
      "%s :L%d:C%d-L%d:C%d (block)",
      prefix,
      bounds.first_line,
      bounds.first_col,
      bounds.last_line,
      bounds.last_col
    )
  end
  if bounds.first_line == bounds.last_line then
    return string.format("%s :L%d:C%d-C%d", prefix, bounds.first_line, bounds.first_col, bounds.last_col)
  end
  return string.format(
    "%s :L%d:C%d-L%d:C%d",
    prefix,
    bounds.first_line,
    bounds.first_col,
    bounds.last_line,
    bounds.last_col
  )
end

function M.copy()
  local reference, err = M.reference()
  if not reference then
    vim.notify(err, vim.log.levels.WARN)
    return
  end

  local ok, result = pcall(vim.fn.setreg, "+", reference, "v")
  if not ok or result ~= 0 then
    vim.notify("Could not copy location: " .. tostring(result), vim.log.levels.ERROR)
    return
  end

  vim.notify("Copied " .. reference, vim.log.levels.INFO)
  local filename = vim.api.nvim_buf_get_name(0)
  if vim.bo.modified or not vim.uv.fs_stat(filename) then
    vim.notify("Buffer is not saved; the file reference may show different content", vim.log.levels.WARN)
  end
end

return M
