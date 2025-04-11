local M = {}

---@class Term.PipeHandle
---@field name string
---@field handle any
---@field on_exit? function|nil

---@class Term.PipeWinOpts
---
---@field id? integer ID of the output window
---@field line1? integer  Start line number
---@field line2? integer  End line number
---@field opts? snacks.win.Config

---@class Term.PipeOpts
---
---@field buf? integer|nil  Buffer number
---@field line1? integer|nil  Start line number
---@field line2? integer|nil  End line number
---@field file? string|nil  File path
---@field win? Term.PipeWinOpts
---@field stdin? string[]|nil
---@field handle? Term.PipeHandle
---@field cmd? string[]

---@class Term.PipeStdinOpts
---
---@field buf? integer|nil  Buffer number
---@field mode? string      Vim mode
---@field line1? integer|nil  Start line number
---@field line2? integer|nil  End line number

---@param opts Term.PipeStdinOpts
---@return string[]|nil
function M.get_pipe_stdin(opts)
  opts = opts or {}

  -- 1. Explicit buffer range
  if opts.buf and opts.line1 and opts.line2 then
    return vim.api.nvim_buf_get_lines(opts.buf, opts.line1 - 1, opts.line2, false)
  end

  -- 2. Whole buffer content
  if opts.buf then
    return vim.api.nvim_buf_get_lines(opts.buf, 0, -1, false)
  end

  -- 3. Visual selection (if no buffer specified)
  --    Determine mode only if needed
  local mode = opts.mode or vim.api.nvim_get_mode().mode
  if mode == "v" or mode == "V" or mode == "\22" then -- \22 is Ctrl-V (blockwise visual)
    return require("util").get_visual_selection()
  end

  -- 4. Default to system clipboard content
  --    vim.split handles nil input gracefully, returning an empty table.
  --    Explicit options ensure consistent behavior.
  return vim.split(vim.fn.getreg("+") or "", "\n", { plain = true, trimempty = false })
end

---@param opts snacks.win.Config
---@return snacks.win
local function create_window(opts)
  local default_win_opts = {
    width = 0.35,
    height = 0.99,
    border = "rounded",
    row = 0,
    col = 0.75,
    backdrop = 100,
    bo = {},
    wo = {
      signcolumn = "yes:1",
      wrap = true,
    },
  }
  local win_opts = vim.tbl_deep_extend("force", default_win_opts, opts or {})
  if not win_opts.file then
    win_opts.bo =
      vim.tbl_deep_extend("force", win_opts.bo, { buftype = "nofile", filetype = "markdown", formatexpr = nil })
  else
    win_opts.bo.modifiable = true
  end
  return require("snacks").win.new(win_opts)
end

---@param stdout string[]
---@param opts Term.PipeOpts
local function write_stdout(stdout, opts)
  local buf
  if opts.win.id then
    buf = vim.api.nvim_win_get_buf(opts.win.id)
  else
    if opts.file then
      opts.win.opts = vim.tbl_extend("keep", opts.win.opts or {}, { file = opts.file })
    end
    local win = create_window(opts.win.opts)
    buf = win.buf
  end

  if buf and type(buf) == "number" then
    local line1 = opts.win.line1 or (vim.api.nvim_buf_line_count(buf) + 1)
    local line2 = opts.win.line2 or -1
    vim.api.nvim_buf_set_lines(buf, line1 - 1, line2, false, stdout)
  end
end

---@param obj vim.SystemCompleted
---@param opts Term.PipeOpts
local function process_fabric_translate(obj, opts)
  local stdout_lines = vim.split(obj.stdout, "\n")
  local processed_output = {}
  local stdin_len = (opts.stdin and #opts.stdin) or 0

  -- Iterate only up to the number of lines in the output (matches original logic)
  for i = 1, #stdout_lines do
    local out_line = stdout_lines[i]
    -- Check corresponding input line safely
    local in_line = (opts.stdin and i <= stdin_len) and opts.stdin[i] or nil

    -- If output line exists, is non-blank, and corresponding input exists, interleave
    if out_line and out_line:match("%S") and in_line then
      -- Use vim.list_extend as in original code
      vim.list_extend(processed_output, { in_line, "", out_line })
    elseif out_line then
      -- Otherwise (output is blank, or no input, or output is nil), just add the output line
      table.insert(processed_output, out_line)
    end
  end

  vim.schedule(function()
    write_stdout(processed_output, opts)
  end)
end

---@param obj vim.SystemCompleted
---@param opts Term.PipeOpts
function M.handle_stdout(obj, opts)
  opts = opts or {}
  local status = obj.code == 0 and "success" or "error"

  if opts.handle and opts.handle.on_exit then
    opts.handle.on_exit(opts.handle.handle, status)
  end

  if status == "error" then
    vim.notify("Error: " .. obj.code, vim.log.levels.ERROR)
    return
  end

  if not obj.stdout then
    return
  end

  local cmd_string = table.concat(opts.cmd, " ")
  local is_fabric_translate = cmd_string:match("fabric %-%-pattern translate")
  if is_fabric_translate then
    return process_fabric_translate(obj, opts)
  end
end

---@param cmd string|string[]
---@param opts? Term.PipeOpts
function M.pipe(cmd, opts)
  if not cmd then
    return
  end

  if type(cmd) == "string" then
    cmd = vim.split(cmd, "%s+")
  end
  opts.cmd = cmd

  -- Default options
  opts = vim.tbl_deep_extend("force", { buf = nil, line1 = nil, line2 = nil, win = {} }, opts or {})

  -- Determine stdin data
  opts.stdin = opts.stdin or M.get_pipe_stdin({
    buf = opts.buf,
    line1 = opts.line1,
    line2 = opts.line2,
  })

  -- Execute the command
  vim.system(cmd, { stdin = opts.stdin }, function(obj)
    M.handle_stdout(obj, opts)
  end)
end

return M
