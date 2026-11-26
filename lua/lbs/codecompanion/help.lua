local M = {}
local api = vim.api
local ns = api.nvim_create_namespace("lbs_codecompanion_help")

local function sections()
  local config = require("codecompanion.config").interactions
  local triggers = require("codecompanion.triggers").mappings
  local keys, context, tools = {}, {}, {}

  for name, map in pairs(config.chat.keymaps) do
    if type(map) == "table" and not map.hide and name:sub(1, 1) ~= "_" and (not map.condition or map.condition()) then
      for mode, key in pairs(map.modes or {}) do
        local binding = type(key) == "table" and table.concat(key, "/") or key
        keys[#keys + 1] = {
          { { mode, "Type" }, { binding, "Special" } },
          map.description or name,
          index = map.index or math.huge,
          name = name,
          mode = mode,
        }
      end
    end
  end
  table.sort(keys, function(a, b)
    if a.index ~= b.index then return a.index < b.index end
    if a[2] ~= b[2] then return a[2] < b[2] end
    if a.name ~= b.name then return a.name < b.name end
    return a.mode ~= b.mode and (a.mode == "n" or (b.mode ~= "n" and a.mode < b.mode))
  end)

  local function collect(entries, source, trigger)
    for name, item in pairs(source) do
      if name ~= "opts" and name ~= "groups" and type(item) == "table" and not item.hide_in_help_window then
        entries[#entries + 1] = { { { trigger .. "{" .. name .. "}", "Identifier" } }, item.description or "", name = name }
      end
    end
  end
  collect(context, config.shared.editor_context, triggers.editor_context)
  collect(tools, config.chat.tools, triggers.tools)
  collect(tools, config.chat.tools.groups, triggers.tools)
  local function by_name(a, b)
    return a.name < b.name
  end
  table.sort(context, by_name)
  table.sort(tools, by_name)
  return { { "Keymaps", keys }, { "Context", context }, { "Tools", tools } }
end

local function geometry()
  local rows = vim.o.lines - vim.o.cmdheight
  local width = math.max(1, math.min(88, vim.o.columns - 4))
  local height = math.max(1, math.min(32, rows - 4))
  return {
    relative = "editor",
    width = width,
    height = height,
    col = math.max(0, math.floor((vim.o.columns - width - 2) / 2)),
    row = math.max(0, math.floor((rows - height - 2) / 2)),
  }
end

function M.open()
  local pages = sections()
  local buf = api.nvim_create_buf(false, true)
  vim.bo[buf].bufhidden = "wipe"
  local win = api.nvim_open_win(
    buf,
    true,
    vim.tbl_extend("force", geometry(), {
      style = "minimal",
      border = "rounded",
      title = " Chat Help ",
      footer = " Tab next · q close ",
      footer_pos = "right",
    })
  )
  vim.wo[win].wrap = false
  local page = 1
  local function render()
    local tabs = {}
    for i, section in ipairs(pages) do
      tabs[i] = { "  " .. section[1] .. "  ", i == page and "TabLineSel" or "Comment" }
    end
    local lines = { "" }
    local highlights = {}
    local entries = pages[page][2]
    local widths = {}
    for _, entry in ipairs(entries) do
      for i, chunk in ipairs(entry[1]) do
        widths[i] = math.max(widths[i] or 0, vim.fn.strdisplaywidth(chunk[1]))
      end
    end
    for _, entry in ipairs(entries) do
      local row = #lines
      local line = "  "
      for i, chunk in ipairs(entry[1]) do
        local col = #line
        line = line .. chunk[1]
        highlights[#highlights + 1] = { row = row, col = col, finish = #line, group = chunk[2] }
        line = line .. string.rep(" ", widths[i] - vim.fn.strdisplaywidth(chunk[1]) + 2)
      end
      local description = vim.trim(entry[2]:gsub("%s+", " "))
      lines[row + 1] = description == "" and line:gsub(" +$", "") or line .. description
    end
    vim.bo[buf].modifiable = true
    api.nvim_buf_set_lines(buf, 0, -1, false, lines)
    vim.bo[buf].modifiable = false
    api.nvim_buf_clear_namespace(buf, ns, 0, -1)
    api.nvim_buf_set_extmark(buf, ns, 0, 0, { virt_text = tabs, virt_text_pos = "inline" })
    for _, mark in ipairs(highlights) do
      api.nvim_buf_set_extmark(buf, ns, mark.row, mark.col, { end_col = mark.finish, hl_group = mark.group })
    end
    api.nvim_win_set_cursor(win, { 1, 0 })
  end
  render()
  local function bind(key, callback)
    vim.keymap.set("n", key, callback, { buffer = buf, silent = true, nowait = true })
  end
  bind("<Tab>", function()
    page = page % #pages + 1
    render()
  end)
  bind("<S-Tab>", function()
    page = (page - 2) % #pages + 1
    render()
  end)
  local function close()
    api.nvim_win_close(win, true)
  end
  bind("q", close)
  bind("<Esc>", close)
  api.nvim_create_autocmd("VimResized", {
    buffer = buf,
    callback = function()
      if api.nvim_win_is_valid(win) then
        api.nvim_win_set_config(win, geometry())
      end
    end,
  })
end

return M
