-- 浮窗与选择器：prompt / popup / select，以及 mylib 相关的两个特化弹窗。
local M = {}

M.prompt = function(top, callback, default)
  local Input = require("nui.input")
  local event = require("nui.utils.autocmd").event
  top = top or "Input"
  default = default or ""
  callback = callback or function(value)
    print(value)
  end

  local input = Input({
    position = "50%",
    size = { width = 40 },
    border = {
      style = "single",
      text = {
        top = "[" .. top .. "]",
        top_align = "center",
      },
    },
    win_options = {
      winhighlight = "Normal:Normal,FloatBorder:Normal",
    },
  }, {
    prompt = "> ",
    default_value = default,
    on_close = function()
      print("Input Closed!")
    end,
    on_submit = callback,
  })

  input:on(event.BufLeave, function()
    input:unmount()
  end)

  input:map("n", "<Esc>", function()
    input:unmount()
  end, { noremap = true })

  return input
end

M.mylib_tag = function()
  local input = M.prompt("Tags", function(value)
    vim.cmd("Mylib tag " .. value)
  end)
  input:mount()
end

M.popup = function(opts)
  local Popup = require("nui.popup")
  opts = vim.tbl_extend("keep", opts or {}, {
    enter = true,
    focusable = true,
    border = {
      style = "rounded",
    },
    position = "50%",
    size = {
      width = "80%",
      height = "40%",
    },
    buf_options = {
      modifiable = true,
      readonly = false,
    },
    win_options = {
      winblend = 10,
      winhighlight = "Normal:Normal,FloatBorder:Normal",
    },
  })

  local popup = Popup(opts)
  return popup
end

M.mylib_popup = function(bufnr)
  local Popup = require("nui.popup")
  local opts = {
    bufnr = bufnr,
    enter = true,
    focusable = true,
    border = {
      style = "rounded",
    },
    position = {
      row = "75%",
      col = "50%",
    },
    size = {
      width = "80%",
      height = "50%",
    },
    buf_options = {
      modifiable = true,
      readonly = false,
    },
    win_options = {
      winblend = 2,
      winhighlight = "Normal:TelescopeNormal,FloatBorder:TelescopeBorder",
    },
  }

  local popup = Popup(opts)
  -- popup:on(event.BufLeave, function() popup:unmount() end)
  popup:map("n", "<leader><leader>", function()
    popup:unmount()
  end, { noremap = true })
  popup:mount()
  return popup
end

--- @class select_item
--- @field key? string
--- @field text string
--- @field callback? function
--- @param items  select_item[]
--- @param opts? {title: string, callback?: function}
M.select = function(items, opts)
  opts = opts or {}
  local command, prompt, texts = {}, {}, {}
  for _, item in ipairs(items) do
    if not item.key or item.key == "" then
      table.insert(prompt, item.text)
    else
      table.insert(prompt, string.format("(%s) %s", item.key, item.text))
      command[item.key] = item.callback or (opts.callback and opts.callback(item.key))
      texts[item.key] = item.text
    end
  end

  vim.notify(table.concat(prompt, "\n"), vim.log.levels.INFO, {
    title = opts.title or "Choose an item:",
  })

  vim.schedule(function()
    local choice = vim.fn.getchar()
    vim.cmd("redraw!")
    require("notify").dismiss({ silent = true, pending = true })
    if command[choice] then
      command[choice](texts[choice])
    end
  end)
end

M.get_highest_zindex_win = function(tab)
  local wins = vim.tbl_filter(function(win)
    local bufnr = vim.api.nvim_win_get_buf(win)
    return vim.bo[bufnr].filetype ~= "notify"
  end, vim.api.nvim_tabpage_list_wins(tab or 0))

  local highest_zindex = -1
  local highest_win = nil
  for _, win in ipairs(wins) do
    local config = vim.api.nvim_win_get_config(win)
    if config and config.zindex and config.zindex > highest_zindex then
      highest_zindex = config.zindex
      highest_win = win
    end
  end

  return highest_win
end

return M
