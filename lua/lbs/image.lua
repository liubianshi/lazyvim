local M = {}

local records_by_win = {}
local records_by_path = {}
local records_by_buf = {}
local records_by_preview_win = {}

local methods = {
  popup = true,
  infile = true,
  current = true,
  split = true,
  vsplit = true,
}

local function normalize_method(method)
  if method == 1 or method == "1" then
    return "current"
  end
  return methods[method] and method or "popup"
end

local function normalize_path(path)
  if type(path) ~= "string" or path == "" then
    return nil
  end
  return vim.fs.normalize(vim.fn.fnamemodify(path, ":p"))
end

local function valid_win(win)
  return type(win) == "number" and vim.api.nvim_win_is_valid(win)
end

local function valid_buf(buf)
  return type(buf) == "number" and vim.api.nvim_buf_is_valid(buf)
end

local function notify(message, level)
  vim.notify(message, level or vim.log.levels.WARN, { title = "Image Preview" })
end

local function remove_from_list(list, record)
  for index = #list, 1, -1 do
    if list[index] == record then
      table.remove(list, index)
    end
  end
end

local function index_buffer(record)
  records_by_buf[record.buf] = records_by_buf[record.buf] or {}
  records_by_buf[record.buf][record.path] = record
end

local function unindex(record)
  local source_records = records_by_win[record.source_win]
  if source_records then
    remove_from_list(source_records, record)
    if #source_records == 0 then
      records_by_win[record.source_win] = nil
    end
  end
  if records_by_path[record.path] == record then
    records_by_path[record.path] = nil
  end
  if records_by_preview_win[record.win] == record then
    records_by_preview_win[record.win] = nil
  end
  local buffer_records = records_by_buf[record.buf]
  if buffer_records and buffer_records[record.path] == record then
    buffer_records[record.path] = nil
    if not next(buffer_records) then
      records_by_buf[record.buf] = nil
    end
  end
end

local close_record
local layout_popups

local function restore_source(record)
  if not valid_win(record.source_win) then
    return
  end
  vim.api.nvim_set_current_win(record.source_win)
  if record.source_cursor then
    pcall(vim.api.nvim_win_set_cursor, record.source_win, record.source_cursor)
  end
end

local function scratch_buffer()
  local buf = vim.api.nvim_create_buf(false, true)
  vim.bo[buf].bufhidden = "hide"
  vim.bo[buf].filetype = "kittypreviewimage"
  return buf
end

local function set_scratch_window_options(win)
  vim.wo[win].number = false
  vim.wo[win].relativenumber = false
  vim.wo[win].cursorline = false
  vim.wo[win].wrap = false
  vim.wo[win].winblend = 0
end

local function popup_geometry(source_win, position, initial)
  local source_width = vim.api.nvim_win_get_width(source_win)
  local source_height = vim.api.nvim_win_get_height(source_win)
  local source_pos = vim.api.nvim_win_get_position(source_win)
  local max_width = math.max(1, vim.o.columns - source_pos[2])
  local max_height = math.max(1, vim.o.lines - source_pos[1])
  local width = source_width
  local col = 0
  if position == "left" then
    width = math.ceil(source_width * (initial and 0.58 or 0.59))
  elseif position == "right" then
    width = math.ceil(source_width * 0.39)
    col = source_width - width - 1
  end
  width = math.max(1, math.min(width, max_width))
  local height = math.max(1, math.min(math.floor(source_height * 0.3), max_height))
  col = math.max(0, math.min(col, max_width - width))
  local row = math.max(0, math.min(source_height - height - 2, max_height - height))
  return { row = row, col = col, width = width, height = height }
end

local function update_popup_window(record, geometry)
  if not record.popup or not valid_win(record.win) then
    return
  end
  record.popup.opts.row = geometry.row
  record.popup.opts.col = geometry.col
  record.popup.opts.width = geometry.width
  record.popup.opts.height = geometry.height
  record.popup:update()
end

local function center_popup(record)
  local placement = record.placement
  if record.closing or record.closed or not placement or not placement:ready() or not valid_win(record.win) then
    return
  end
  if not record.slot or record.centering then
    return
  end

  local state = placement:state()
  local loc = state.loc
  local slot = record.slot
  record.centering = true
  if Snacks.image.terminal.env().placeholders then
    local col = math.max(0, math.floor((slot.width - loc.width) / 2))
    placement.opts.pos = { 1, col }
    placement.opts.max_width = math.max(1, slot.width)
    placement.opts.max_height = math.max(1, slot.height)
    update_popup_window(record, slot)
  else
    local width = math.max(1, math.min(loc.width, slot.width))
    local height = math.max(1, math.min(loc.height, slot.height))
    local geometry = {
      row = slot.row,
      col = slot.col + math.max(0, math.floor((slot.width - width) / 2)),
      width = width,
      height = height,
    }
    local geometry_changed = record.popup.opts.row ~= geometry.row
      or record.popup.opts.col ~= geometry.col
      or record.popup.opts.width ~= geometry.width
      or record.popup.opts.height ~= geometry.height
    if geometry_changed then
      update_popup_window(record, geometry)
      -- fallback 渲染直接使用窗口的绝对屏幕坐标；只在几何变化时强制重绘。
      placement._state = nil
    end
  end

  placement:update()
  record.centering = false
end

local function active_popups(records, excluded)
  return vim.tbl_filter(function(record)
    return record ~= excluded and record.method == "popup" and not record.closed and not record.closing
  end, records)
end

layout_popups = function(source_win, initial)
  local records = records_by_win[source_win]
  if not records or not valid_win(source_win) then
    return
  end
  local popups = active_popups(records)
  if #popups == 0 then
    return
  end
  if #popups == 1 then
    local record = popups[1]
    record.slot = popup_geometry(source_win, "single", initial)
    update_popup_window(record, record.slot)
    center_popup(record)
    return
  end

  local right = popups[#popups - 1]
  local left = popups[#popups]
  right.slot = popup_geometry(source_win, "right", initial)
  left.slot = popup_geometry(source_win, "left", initial)
  update_popup_window(right, right.slot)
  update_popup_window(left, left.slot)
  center_popup(right)
  center_popup(left)
end

local function delete_owned_buffer(record)
  if record.owns_buf and valid_buf(record.buf) then
    pcall(vim.api.nvim_buf_delete, record.buf, { force = true })
  end
end

close_record = function(record, opts)
  opts = opts or {}
  if not record or record.closed or record.closing then
    return
  end
  record.closing = true
  unindex(record)

  if record.placement and not record.placement.closed then
    pcall(record.placement.close, record.placement)
  end

  if record.method == "current" and opts.close_win ~= false and valid_win(record.win) then
    local restored = valid_buf(record.original_buf) and vim.api.nvim_win_get_buf(record.win) == record.buf
    if restored then
      pcall(vim.api.nvim_win_set_buf, record.win, record.original_buf)
    end
    for option, value in pairs(record.original_window_options or {}) do
      vim.wo[record.win][option] = value
    end
    if restored and record.original_view then
      pcall(vim.api.nvim_win_call, record.win, function()
        vim.fn.winrestview(record.original_view)
      end)
    end
  end

  if record.popup then
    pcall(record.popup.close, record.popup)
  elseif
    record.owns_win
    and opts.close_win ~= false
    and valid_win(record.win)
    and vim.api.nvim_win_get_buf(record.win) == record.buf
  then
    pcall(vim.api.nvim_win_close, record.win, true)
  end
  if opts.close_buf ~= false then
    delete_owned_buffer(record)
  end

  if record.temp_file then
    pcall(vim.uv.fs_unlink, record.temp_file)
    record.temp_file = nil
  end
  record.closed = true
  record.closing = false

  if opts.relayout ~= false then
    layout_popups(record.source_win, false)
  end
end

local function new_record(path, method, source_win)
  local record = {
    path = path,
    src = path,
    method = method,
    source_win = source_win,
    source_cursor = valid_win(source_win) and vim.api.nvim_win_get_cursor(source_win) or nil,
  }
  records_by_win[source_win] = records_by_win[source_win] or {}
  table.insert(records_by_win[source_win], record)
  records_by_path[path] = record
  return record
end

local function make_temp_copy(record)
  local extension = vim.fn.fnamemodify(record.path, ":e")
  local temp_file = vim.fn.tempname() .. "." .. extension
  local ok, err = vim.uv.fs_copyfile(record.path, temp_file)
  if not ok then
    notify(string.format("无法创建强制更新副本：%s", err or "unknown error"), vim.log.levels.ERROR)
    return false
  end
  record.temp_file = temp_file
  record.src = temp_file
  return true
end

local function create_placement(record, opts)
  opts = opts or {}
  local placement_opts = {
    pos = { opts.line or 1, 0 },
    inline = record.method == "infile",
    auto_resize = true,
  }
  if record.method == "popup" then
    placement_opts.on_update = function()
      center_popup(record)
    end
  end
  record.placement = Snacks.image.placement.new(record.buf, record.src, placement_opts)
end

local function open_popup(record)
  local records = records_by_win[record.source_win] or {}
  local popups = active_popups(records, record)
  local keep = popups[#popups]
  for _, item in ipairs(popups) do
    if item ~= keep then
      close_record(item, { relayout = false })
    end
  end

  record.slot = popup_geometry(record.source_win, keep and "left" or "single", true)
  record.popup = Snacks.win({
    relative = "win",
    win = record.source_win,
    position = "float",
    row = record.slot.row,
    col = record.slot.col,
    width = record.slot.width,
    height = record.slot.height,
    border = "single",
    backdrop = false,
    enter = false,
    focusable = true,
    zindex = 99,
    minimal = true,
    resize = false,
    bo = { filetype = "kittypreviewimage" },
    wo = { winblend = 0 },
    keys = {
      q = function()
        close_record(record)
      end,
    },
  })
  record.buf = record.popup.buf
  record.win = record.popup.win
  record.owns_buf = true
  records_by_preview_win[record.win] = record
  index_buffer(record)
  create_placement(record)
  layout_popups(record.source_win, true)
end

local function open_split(record, method)
  record.buf = scratch_buffer()
  vim.cmd(method)
  record.win = vim.api.nvim_get_current_win()
  vim.api.nvim_win_set_buf(record.win, record.buf)
  record.owns_buf = true
  record.owns_win = true
  records_by_preview_win[record.win] = record
  index_buffer(record)
  set_scratch_window_options(record.win)
  if method == "split" then
    vim.api.nvim_win_set_height(record.win, 12)
  else
    vim.api.nvim_win_set_width(record.win, 70)
  end
  create_placement(record)
  restore_source(record)
end

local function open_current(record)
  record.win = record.source_win
  record.original_buf = vim.api.nvim_win_get_buf(record.win)
  record.original_window_options = {
    number = vim.wo[record.win].number,
    relativenumber = vim.wo[record.win].relativenumber,
    cursorline = vim.wo[record.win].cursorline,
    wrap = vim.wo[record.win].wrap,
    winblend = vim.wo[record.win].winblend,
  }
  record.original_view = vim.api.nvim_win_call(record.win, vim.fn.winsaveview)
  record.buf = scratch_buffer()
  vim.api.nvim_win_set_buf(record.win, record.buf)
  record.owns_buf = true
  record.owns_win = false
  records_by_preview_win[record.win] = record
  index_buffer(record)
  set_scratch_window_options(record.win)
  create_placement(record)
end

local function nearest_empty_line(buf, win, requested)
  if requested then
    return math.max(1, math.min(requested, vim.api.nvim_buf_line_count(buf)))
  end
  local cursor_line = vim.api.nvim_win_get_cursor(win)[1]
  local line_count = vim.api.nvim_buf_line_count(buf)
  local chunk_start = cursor_line
  while chunk_start < line_count do
    local chunk_end = math.min(chunk_start + 128, line_count)
    local lines = vim.api.nvim_buf_get_lines(buf, chunk_start, chunk_end, false)
    for offset, line in ipairs(lines) do
      if line:match("^%s*$") then
        return chunk_start + offset
      end
    end
    chunk_start = chunk_end
  end
  return math.min(cursor_line + 1, line_count)
end

local function open_infile(record, opts)
  record.win = record.source_win
  record.buf = vim.api.nvim_win_get_buf(record.source_win)
  record.owns_buf = false
  record.owns_win = false
  index_buffer(record)
  local line = nearest_empty_line(record.buf, record.source_win, opts.line)
  create_placement(record, { line = line })
end

function M.preview(path, opts)
  opts = opts or {}
  path = normalize_path(path)
  if not path or vim.fn.filereadable(path) == 0 then
    return nil
  end
  if not Snacks.image.supports_file(path) then
    return nil
  end
  if not Snacks.image.supports_terminal() then
    notify("当前终端不支持 Snacks.image 所需的 Kitty Graphics Protocol")
    return nil
  end

  local method = normalize_method(opts.method)
  if method == "infile" and not Snacks.image.terminal.env().placeholders then
    notify("当前终端不支持 unicode placeholders；infile 已安全降级为 scratch popup")
    method = "popup"
  end

  local existing = records_by_path[path]
  if existing and not opts.update then
    return existing
  elseif existing then
    close_record(existing)
  end

  local source_win = opts.win or vim.api.nvim_get_current_win()
  if not valid_win(source_win) then
    return nil
  end
  local record = new_record(path, method, source_win)
  if opts.update and not make_temp_copy(record) then
    close_record(record)
    return nil
  end

  local ok, err = pcall(function()
    if method == "popup" then
      open_popup(record)
    elseif method == "infile" then
      open_infile(record, opts)
    elseif method == "current" then
      open_current(record)
    else
      open_split(record, method)
    end
  end)
  if not ok then
    close_record(record)
    notify(string.format("图片预览失败：%s", err), vim.log.levels.ERROR)
    return nil
  end
  return record
end

function M.clear(opts)
  if type(opts) == "string" then
    opts = { file = opts }
  else
    opts = opts or {}
  end
  local path = normalize_path(opts.file or opts.path)
  if path then
    close_record(records_by_path[path])
    return
  end

  local records = {}
  local seen = {}
  local function add(record)
    if record and not seen[record] then
      seen[record] = true
      table.insert(records, record)
    end
  end
  local layout_win = opts.win or vim.api.nvim_get_current_win()
  if opts.all then
    for _, record in pairs(records_by_path) do
      add(record)
    end
  else
    local win = layout_win
    local preview = records_by_preview_win[win]
    if preview then
      add(preview)
      layout_win = preview.source_win
    end
    for _, record in ipairs(vim.list_slice(records_by_win[win] or {})) do
      add(record)
    end
    local buf = opts.buf or (valid_win(win) and vim.api.nvim_win_get_buf(win) or nil)
    for _, record in pairs(records_by_buf[buf] or {}) do
      add(record)
    end
  end
  for _, record in ipairs(records) do
    close_record(record, { relayout = false })
  end
  if valid_win(layout_win) then
    layout_popups(layout_win, false)
  end
end

function M.toggle(path, opts)
  opts = opts or {}
  path = path or vim.fn.expand("<cfile>")
  local normalized = normalize_path(path)
  local existing = normalized and records_by_path[normalized]
  if existing then
    close_record(existing)
    return nil
  end
  opts.method = opts.method or (opts.bang and "infile" or "popup")
  return M.preview(path, opts)
end

local function image_under_cursor(buf)
  local file = vim.fn.expand("<cfile>")
  local ok, in_obsidian = pcall(function()
    return require("lbs.path").in_obsidian_vault()
  end)
  if ok and in_obsidian then
    local relative = vim.fs.dirname(vim.api.nvim_buf_get_name(buf)) .. "/" .. file
    if vim.uv.fs_stat(relative) then
      file = relative
    end
  end
  file = normalize_path(file)
  if file and (records_by_path[file] or (vim.fn.filereadable(file) == 1 and Snacks.image.supports_file(file))) then
    M.toggle(file)
  else
    M.clear({ win = vim.api.nvim_get_current_win() })
  end
end

function M.setup()
  vim.api.nvim_create_user_command("PreviewImage", function(args)
    local file = args.fargs[#args.fargs]
    local method = #args.fargs > 1 and args.fargs[1] or "popup"
    M.preview(file, { method = method, update = args.bang })
  end, { bang = true, nargs = "+", complete = "file", desc = "Preview image" })

  vim.api.nvim_create_user_command("ImageToggle", function(args)
    M.toggle(args.fargs[1], { bang = args.bang })
  end, { bang = true, nargs = "?", complete = "file", desc = "Toggle image preview" })

  vim.api.nvim_create_user_command("ImageClear", function(args)
    M.clear({ file = args.fargs[1] })
  end, { nargs = "?", complete = "file", desc = "Clear image preview" })

  local group = vim.api.nvim_create_augroup("LBS_Image_Adjust", { clear = true })
  vim.api.nvim_create_autocmd("WinResized", {
    group = group,
    callback = function()
      for _, win in ipairs(vim.v.event.windows or {}) do
        if valid_win(win) and vim.api.nvim_win_get_config(win).relative == "" then
          layout_popups(win, false)
        end
      end
    end,
  })

  vim.api.nvim_create_autocmd("WinClosed", {
    group = group,
    callback = function(event)
      local win = tonumber(event.match)
      local preview = records_by_preview_win[win]
      if preview then
        close_record(preview, { close_win = false })
      elseif records_by_win[win] then
        local records = vim.list_slice(records_by_win[win])
        for _, record in ipairs(records) do
          close_record(record, { relayout = false })
        end
      end
    end,
  })

  vim.api.nvim_create_autocmd({ "BufWinLeave", "BufWipeout", "BufDelete" }, {
    group = group,
    callback = function(event)
      local records = vim.tbl_values(records_by_buf[event.buf] or {})
      for _, record in ipairs(records) do
        if event.event ~= "BufWinLeave" or record.owns_buf then
          vim.schedule(function()
            close_record(record)
          end)
        end
      end
    end,
  })

  vim.api.nvim_create_autocmd("FileType", {
    group = group,
    pattern = { "rmd", "rmarkdown", "norg", "org" },
    callback = function(event)
      vim.keymap.set("n", "<S-CR>", function()
        image_under_cursor(event.buf)
      end, {
        buffer = event.buf,
        desc = "Display image file under cursor",
        noremap = true,
        silent = true,
      })
    end,
  })
end

return M
