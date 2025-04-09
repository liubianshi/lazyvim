local M = {}

M.root_patterns = { ".git", "lua", ".obsidian", ".vim", ".exercism" }

---@param plugin string
function M.has(plugin)
  return require("lazy.core.config").plugins[plugin] ~= nil
end

function M.fg(name)
  ---@type {foreground?:number}?
  local hl = vim.api.nvim_get_hl and vim.api.nvim_get_hl(0, { name = name })
  local fg = hl and (hl["fg"] or hl.foreground)
  return fg and { fg = string.format("#%06x", fg) }
end

---@param name string
function M.opts(name)
  local plugin = require("lazy.core.config").plugins[name]
  if not plugin then
    return {}
  end
  local Plugin = require("lazy.core.plugin")
  return Plugin.values(plugin, "opts", false)
end

--- Gets the git root for a buffer or path.
--- Defaults to the current buffer.
--- Based on function from:
--- https://github.com/folke/snacks.nvim/blob/main/lua/snacks/git.lua
function M.get_git_root(path)
  path = path or 0
  path = type(path) == "number" and vim.api.nvim_buf_get_name(path) or path --[[@as string]]
  path = vim.fs.normalize(path)
  path = path == "" and (vim.uv or vim.loop).cwd() or path
  if vim.fn.isdirectory(path .. "/.git") == 1 then
    return path
  end
  local git_root ---@type string?
  for dir in vim.fs.parents(path) do
    if vim.fn.isdirectory(dir .. "/.git") == 1 then
      git_root = dir
      break
    end
  end
  return git_root and vim.fs.normalize(git_root) or nil
end

-- returns the root directory based on:
-- * lsp workspace folders
-- * lsp rootdir
-- * root pattern of filename of the current buffer
-- * root pattern of cwd
---@return string
function M.get_root(path, root_patterns)
  root_patterns = root_patterns or M.root_patterns
  if type(root_patterns) ~= "table" then
    root_patterns = { root_patterns }
  end
  ---@type string?
  path = path or vim.api.nvim_buf_get_name(0)
  path = path ~= "" and vim.uv.fs_realpath(path) or nil
  ---@type string[]
  local roots = {}
  if path then
    for _, client in pairs(vim.lsp.get_clients({ bufnr = 0 })) do
      local workspace = client.config.workspace_folders
      local paths = workspace
          and vim.tbl_map(function(ws)
            return vim.uri_to_fname(ws.uri)
          end, workspace)
        or client.config.root_dir and { client.config.root_dir }
        or {}
      for _, p in ipairs(paths) do
        local r = vim.loop.fs_realpath(p) or ""
        if path:find(r, 1, true) then
          roots[#roots + 1] = r
        end
      end
    end
  end
  table.sort(roots, function(a, b)
    return #a > #b
  end)
  ---@type string?
  local root = roots[1]
  if not root then
    path = path and vim.fs.dirname(path) or vim.uv.cwd()
    ---@type string?
    root = vim.fs.find(root_patterns, { path = path, upward = true })[1]
    root = root and vim.fs.dirname(root) or vim.loop.cwd()
  end
  ---@cast root string
  return root
end

-- this will return a function that calls telescope.
-- cwd will default to lazyvim.util.get_root
-- for `files`, git_files or find_files will be chosen depending on .git
function M.telescope(builtin, opts)
  local params = { builtin = builtin, opts = opts }
  return function()
    builtin = params.builtin
    opts = params.opts
    opts = vim.tbl_deep_extend("force", { cwd = M.get_root() }, opts or {})
    if builtin == "files" then
      if vim.loop.fs_stat((opts.cwd or vim.loop.cwd()) .. "/.git") then
        opts.show_untracked = true
        builtin = "git_files"
      else
        builtin = "find_files"
      end
    end
    if opts.cwd and opts.cwd ~= vim.loop.cwd() then
      opts.attach_mappings = function(_, map)
        map("i", "<a-c>", function()
          local action_state = require("telescope.actions.state")
          local line = action_state.get_current_line()
          M.telescope(
            params.builtin,
            vim.tbl_deep_extend("force", {}, params.opts or {}, { cwd = false, default_text = line })
          )()
        end)
        return true
      end
    end

    require("telescope.builtin")[builtin](opts)
  end
end

-- Clearing images previewed with image.nvim
function M.clear_previewed_images(win)
  win = win or 0
  local is_ok, api = pcall(require, "image")
  if not is_ok then
    return
  end

  local images = api.get_images()
  if not next(images) then
    return
  end

  local windows_in_current_tab = vim.api.nvim_tabpage_list_wins(win)
  local windows_in_current_tab_map = {}
  for _, current_window in ipairs(windows_in_current_tab) do
    windows_in_current_tab_map[current_window] = true
  end

  for _, current_image in ipairs(images) do
    if not current_image.window or not current_image.buffer then
      goto continue
    end

    local window_ok, is_valid_window = pcall(vim.api.nvim_win_is_valid, current_image.window)
    if not (window_ok and is_valid_window) then
      goto continue
    end

    local buf_ok, is_valid_buffer = pcall(vim.api.nvim_buf_is_valid, current_image.buffer)
    if not buf_ok or not is_valid_buffer then
      goto continue
    end

    local is_window_in_current_tab = windows_in_current_tab_map[current_image.window]
    if not is_window_in_current_tab then
      goto continue
    end

    local is_buffer_in_window = vim.api.nvim_win_get_buf(current_image.window) == current_image.buffer
    if not is_buffer_in_window then
      goto continue
    end

    current_image:clear()
  end
  ::continue::
end

local get_item_info = function(b, field, command)
  field = field or "note"
  local valid_items = { "note", "pdf", "bib", "newsboat", "html", "md", "path", "title", "url" }
  local item_path
  if field == "note" then
    item_path = vim.fn.trim(vim.fn.system("mylib note @" .. b))
  elseif vim.tbl_contains(valid_items, field) then
    item_path = vim.fn.trim(vim.fn.system("mylib get " .. field .. " -- @" .. b))
  end
  if command then
    if vim.fn.filewritable(item_path) == 0 then
      return
    end
    vim.cmd(command .. " " .. vim.fn.fnameescape(item_path))
  else
    return item_path
  end
end

function M.bibkey_action(bibkey)
  if not bibkey then
    return
  end
  bibkey = "@" .. bibkey
  local bibkey_action = function(key)
    local command = {
      ["e"] = function()
        get_item_info(bibkey, "note", "edit ")
      end,
      ["v"] = function()
        get_item_info(bibkey, "note", "vsplit ")
      end,
      ["t"] = function()
        get_item_info(bibkey, "note", "tabnew ")
      end,
      ["s"] = function()
        get_item_info(bibkey, "note", "split ")
      end,
      ["o"] = function()
        get_item_info(bibkey, "path", "Lf ")
      end,
      ["n"] = function()
        get_item_info(bibkey, "newsboat", "edit ")
      end,
      ["p"] = function()
        local pdf_file = get_item_info(bibkey, "pdf")
        if not pdf_file or vim.fn.filereadable(pdf_file) == 0 then
          return
        end
        vim.ui.open(pdf_file)
      end,
      ["u"] = function()
        local url = get_item_info(bibkey, "url")
        if not url then
          return
        end
        vim.ui.open(url)
      end,
    }
    return command[key]
  end
  local items = {
    { key = "e", text = "edit note" },
    { key = "n", text = "newsboat" },
    { key = "o", text = "open dir" },
    { key = "p", text = "open pdf file" },
    { key = "s", text = "split note" },
    { key = "t", text = "tabnew note" },
    { key = "u", text = "open url" },
    { key = "v", text = "vsplite note" },
    { key = "", text = "---------------" },
    { key = "q", text = "Quit" },
  }
  local select = require("util.ui").select
  select(items, { title = "Choose an action:", callback = bibkey_action })
end

function M.execute_async(command, callback_funs)
  callback_funs = callback_funs or {}
  callback_funs = vim.tbl_extend("keep", callback_funs, {
    on_stdout = function(_, data, _)
      if type(data) ~= "table" then
        data = { data }
      end
      print(vim.fn.join(data, ""))
    end,
    on_error = function(_, data, _)
      if type(data) ~= "table" then
        data = { data }
      end
      print(vim.fn.join(data, ""))
    end,
    on_exit = function(_, data, _)
      if type(data) ~= "table" then
        data = { data }
      end
      print(vim.fn.join(data, ""))
    end,
  })

  local job_id = vim.fn.jobstart(command, {
    on_stdout = callback_funs.on_stdout,
    on_stderr = callback_funs.on_stderr,
    on_exit = callback_funs.on_exit,
  })

  return job_id
end

function M.in_project()
  local cwd = vim.fn.getcwd()
  local ok, project = pcall(require, "project_nvim")
  if not ok then
    return
  end
  local projects = project.get_recent_projects()
  for _, proj in ipairs(projects) do
    if cwd == proj then
      return true
    end
  end
  return false
end

function M.wk_reg(mapping, opts)
  local wk_ok, wk = pcall(require, "which-key")
  if not wk_ok then
    return
  end
  wk.add(mapping, opts)
end

function M.border(symbol, type, neovide, highlight)
  symbol = symbol or "═"
  type = type or "top"
  neovide = neovide or false
  highlight = "MyBorder"

  if vim.fn.exists("g:neovide") == 1 and not neovide then
    return "none"
  end

  if type == "top" then
    return { "", { symbol, highlight }, "", "", "", "", "", "" }
  elseif type == "bottom" then
    return { "", "", "", "", "", { symbol, highlight }, "", "" }
  end
end

---@class VisualCoordinate
---@field start_line number Start line number (1-based)
---@field start_col number Start column number (1-based)
---@field end_line number End line number (1-based)
---@field end_col number End column number (1-based)

--- Gets the start and end coordinates (line and column) of the last visual selection.
--- Ensures that the start position always comes before the end position,
--- regardless of the direction the visual selection was made.
---@return VisualCoordinate|nil A table containing the start and end coordinates: { start_line, start_col, end_line, end_col }
function M.get_visual_coordinate()
  -- Get the start and end positions of the last visual selection
  -- getpos("'<") returns the start marker
  -- getpos("'>") returns the end marker
  -- The format is [bufnum, lnum, col, off]
  local start_pos, end_pos
  local mode = vim.api.nvim_get_mode().mode
  if mode ~= "v" and mode ~= "V" and mode ~= "\22" then
    start_pos = vim.fn.getpos("'<")
    end_pos = vim.fn.getpos("'>")
  else
    start_pos = vim.fn.getpos(".")
    end_pos = vim.fn.getpos("v")
  end
  if not start_pos or not end_pos then
    return
  end

  -- Ensure start_pos represents the position that comes first in the buffer
  -- Compare line numbers first, then column numbers if lines are the same
  if start_pos[2] > end_pos[2] or (start_pos[2] == end_pos[2] and start_pos[3] > end_pos[3]) then
    start_pos, end_pos = end_pos, start_pos -- Swap if start_pos is after end_pos
  end

  -- Return the relevant coordinates: start line, start col, end line, end col
  return { start_pos[2], start_pos[3], end_pos[2], end_pos[3] }
end

-- https://github.com/ibhagwan/nvim-lua/blob/main/lua/utils.lua
---@return string[]|nil A table containing the start and end coordinates: { start_line, start_col, end_line, end_col }
function M.get_visual_selection()
  -- this will exit visual mode
  -- use 'gv' to reselect the text
  local visual_coordiate = M.get_visual_coordinate()
  if not visual_coordiate then
    return
  end
  local csrow, cscol, cerow, cecol = unpack(visual_coordiate)
  local lines = vim.api.nvim_buf_get_lines(0, csrow - 1, cerow, false)
  local n = #lines
  if n <= 0 then
    return
  end
  if not cecol then
    lines[n] = string.sub(lines[n], 1, cecol)
  end
  if not cscol then
    lines[1] = string.sub(lines[1], cscol)
  end

  return lines
end

-- https://github.com/ibhagwan/nvim-lua/blob/main/lua/utils.lua
M.win_is_float = function(winnr)
  local wincfg = vim.api.nvim_win_get_config(winnr)
  if wincfg and (wincfg.external or wincfg.relative and #wincfg.relative > 0) then
    return true
  end
  return false
end

--- Generate file paths that meet a specific format based on today's date
---@param ext? string
---@param base? string|string[]
---@param pre? string
---@return string
M.get_daily_filepath = function(ext, base, pre)
  ext = ext and ("." .. ext) or ""
  pre = pre and (pre .. "-") or ""
  if not base then
    base = "/"
  elseif type(base) == "table" then
    base = "/" .. table.concat(base, "/") .. "/"
  else
    base = "/" .. base .. "/"
  end
  local writing_room = vim.env.WRITING_LIB or vim.env.HOME .. "/Documents/writing"
  local basename = os.date("%Y%m%d")
  return writing_room .. base .. pre .. basename .. ext
end

function M.in_obsidian_vault(buf)
  if not buf or (type(buf) == "table" and #buf == 0) then
    buf = 0
  end
  local root_dir = M.get_root(vim.api.nvim_buf_get_name(buf))

  if root_dir and root_dir:match("/vaults/") then
    return root_dir
  end
end

function M.get_selected_lines()
  local mode = vim.api.nvim_get_mode().mode
  if mode ~= "v" and mode ~= "V" and mode ~= "\22" then
    return
  end

  local buf = vim.api.nvim_get_current_buf()
  local start_line = vim.fn.line("v") - 1
  local end_line = vim.fn.line(".")
  local lines = vim.api.nvim_buf_get_lines(buf, start_line, end_line, false)
  return lines
end

function M.is_process_running(pid)
  local success = pcall(function()
    vim.uv.kill(pid, 0)
  end)
  return success
end

function M.md_preview(input)
  if not input then
    input = M.get_selected_lines()
  end
  if not input or #input == 0 then
    return
  end

  local outfile = vim.fn.stdpath("cache") .. "/vim_markdown_preview.html"
  vim.system({ "mdviewer", "--to", "html", "--outfile", outfile }, { text = true, stdin = input }, function() end)
end

function M.keymap(mapping)
  local wk_ok, wk = pcall(require, "which-key")
  if wk_ok then
    wk.add(mapping)
    return
  end
  local mode = mapping.mode or "n"
  local lhs = mapping:remove(1)
  local rhs = mapping:remove(1)
  mapping.mode = nil
  mapping.icon = nil
  vim.keymap.set(mode, lhs, rhs, mapping)
end

-- 执行外部命令，并将标准输出写入窗口 ----------------------------------- {{{1

---@class PipeWinOpts
---
---@field id? integer ID of the output window
---@field line1? integer  Start line number
---@field line2? integer  End line number
---@field opts? snacks.win.Config

---@class PipeOpts
---
---@field buf? integer|nil  Buffer number
---@field line1? integer|nil  Start line number
---@field line2? integer|nil  End line number
---@field file? string|nil  File path
---@field win? PipeWinOpts
---@field stdin? string[]|nil

---@class PipeStdinOpts
---
---@field buf? integer|nil  Buffer number
---@field line1? integer|nil  Start line number
---@field line2? integer|nil  End line number

---@param opts PipeStdinOpts
---@return string[]|nil
local function get_stdin_data(opts)
  if opts.buf and opts.line1 and opts.line2 then
    return vim.api.nvim_buf_get_lines(opts.buf, opts.line1 - 1, opts.line2, false)
  elseif opts.buf then
    return vim.api.nvim_buf_get_lines(opts.buf, 0, -1, false)
  else
    local mode = vim.api.nvim_get_mode().mode
    if mode == "v" or mode == "V" or mode == "\22" then
      return M.get_visual_selection()
    end
  end
  return vim.split(vim.fn.getreg("+"), "\n")
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
    win_opts.bo = vim.tbl_deep_extend("force", win_opts.bo, { buftype = "nofile", filetype = "markdown" })
  else
    win_opts.bo.modifiable = true
  end
  return require("snacks").win.new(win_opts)
end

---@param obj vim.SystemCompleted
---@param opts PipeOpts
local function handle_output(obj, opts)
  if obj.code ~= 0 then
    vim.notify("Error: " .. obj.code, vim.log.levels.ERROR)
    return
  end

  if not obj.stdout then
    return
  end

  vim.schedule(function()
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
      vim.api.nvim_buf_set_lines(buf, line1 - 1, line2, false, vim.split(obj.stdout, "\n"))
    end
  end)
end

---@param cmd string|string[]
---@param opts? PipeOpts
function M.pipe(cmd, opts)
  if not cmd then
    return
  end
  if type(cmd) == "string" then
    cmd = vim.split(cmd, "%s+")
  end
  opts = vim.tbl_extend("force", { buf = nil, line1 = nil, line2 = nil, win = {} }, opts or {})

  local stdin_data = opts.stdin
    or get_stdin_data({
      buf = opts.buf,
      line1 = opts.line1,
      line2 = opts.line2,
    })

  vim.system(cmd, {
    stdin = stdin_data,
    text = true,
  }, function(obj)
    handle_output(obj, opts)
  end)
end

return M
