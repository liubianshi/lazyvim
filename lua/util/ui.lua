-- local Layout = require("nui.layout")
local M = {}

---@alias Sign {name:string, text:string, texthl:string, priority:number}

---@return Sign?
---@param buf number
---@param lnum number
function M.get_mark(buf, lnum)
  local marks = vim.fn.getmarklist(buf)
  vim.list_extend(marks, vim.fn.getmarklist())
  for _, mark in ipairs(marks) do
    if mark.pos[1] == buf and mark.pos[2] == lnum and mark.mark:match("[a-zA-Z]") then
      return { text = mark.mark:sub(2), texthl = "DiagnosticHint" }
    end
  end
end

---@param sign? Sign
---@param len? number
function M.icon(sign, len)
  sign = sign or {}
  len = len or 2
  local text = vim.fn.strcharpart(sign.text or "", 0, len) ---@type string
  text = text .. string.rep(" ", len - vim.fn.strchars(text))
  return sign.texthl and ("%#" .. sign.texthl .. "#" .. text .. "%*") or text
end

-- Returns a list of regular and extmark signs sorted by priority (low to high)
---@return Sign[]
---@param buf number
---@param lnum number
function M.get_signs(buf, lnum)
  -- Get regular signs
  ---@type Sign[]
  local signs = {}

  -- Get extmark signs
  local extmarks = vim.api.nvim_buf_get_extmarks(
    buf,
    -1,
    { lnum - 1, 0 },
    { lnum - 1, -1 },
    { details = true, type = "sign" }
  )
  for _, extmark in pairs(extmarks) do
    signs[#signs + 1] = {
      name = extmark[4].sign_hl_group or extmark[4].sign_name or "",
      text = extmark[4].sign_text,
      texthl = extmark[4].sign_hl_group,
      priority = extmark[4].priority,
    }
  end

  -- Sort by priority
  table.sort(signs, function(a, b)
    return (a.priority or 0) < (b.priority or 0)
  end)

  return signs
end

function M.statuscolumn()
  local win = vim.g.statusline_winid
  local buf = vim.api.nvim_win_get_buf(win)
  local is_file = vim.bo[buf].buftype == ""
  local show_signs = vim.wo[win].signcolumn ~= "no"

  local components = { "", "", "" } -- left, middle, right

  local show_open_folds = vim.g.lazyvim_statuscolumn and vim.g.lazyvim_statuscolumn.folds_open
  local use_githl = vim.g.lazyvim_statuscolumn and vim.g.lazyvim_statuscolumn.folds_githl

  if show_signs then
    local signs = M.get_signs(buf, vim.v.lnum)

    ---@type Sign?,Sign?,Sign?
    local left, right, fold, githl
    for _, s in ipairs(signs) do
      if s.name and (s.name:find("GitSign") or s.name:find("MiniDiffSign")) then
        right = s
        if use_githl then
          githl = s["texthl"]
        end
      else
        left = s
      end
    end

    vim.api.nvim_win_call(win, function()
      if vim.fn.foldclosed(vim.v.lnum) >= 0 then
        fold = {
          text = vim.opt.fillchars:get().foldclose or "",
          texthl = githl or "Folded",
        }
      elseif
        show_open_folds
        and not M.skip_foldexpr[buf]
        and tostring(vim.treesitter.foldexpr(vim.v.lnum)):sub(1, 1) == ">"
      then -- fold start
        fold = { text = vim.opt.fillchars:get().foldopen or "", texthl = githl }
      end
    end)
    -- Left: mark or non-git sign
    components[3] = M.icon(M.get_mark(buf, vim.v.lnum) or left)
    -- Right: fold icon or git sign (only if file)
    components[2] = is_file and M.icon(fold or right) or ""
  end

  -- Numbers in Neovim are weird
  -- They show when either number or relativenumber is true
  local is_num = vim.wo[win].number
  local is_relnum = vim.wo[win].relativenumber
  if (is_num or is_relnum) and vim.v.virtnum == 0 then
    if vim.fn.has("nvim-0.11") == 1 then
      components[1] = "%l" -- 0.11 handles both the current and other lines with %l
    else
      if vim.v.relnum == 0 then
        components[1] = is_num and "%l" or "%r" -- the current line
      else
        components[1] = is_relnum and "%r" or "%l" -- other lines
      end
    end
    components[1] = "%=" .. components[1] .. " " -- right align
  end

  if vim.v.virtnum ~= 0 then
    components[1] = "%= "
  end

  return table.concat(components, "")
end

M.skip_foldexpr = {} ---@type table<number,boolean>
local skip_check = assert(vim.uv.new_check())

function M.foldexpr()
  local buf = vim.api.nvim_get_current_buf()

  -- still in the same tick and no parser
  if M.skip_foldexpr[buf] then
    return "0"
  end

  -- don't use treesitter folds for non-file buffers
  if vim.bo[buf].buftype ~= "" then
    return "0"
  end

  -- as long as we don't have a filetype, don't bother
  -- checking if treesitter is available (it won't)
  if vim.bo[buf].filetype == "" then
    return "0"
  end

  -- Using Custom Folding Methods
  local filetype_use_custom_foldexpr = { "r", "stata", "vim" }
  if vim.tbl_contains(filetype_use_custom_foldexpr, vim.bo[buf].filetype) then
    return vim.fn["fold#GetFold"]()
  end

  local ok = pcall(vim.treesitter.get_parser, buf)
  if ok then
    return vim.treesitter.foldexpr()
  end

  -- no parser available, so mark it as skip
  -- in the next tick, all skip marks will be reset
  M.skip_foldexpr[buf] = true
  skip_check:start(function()
    M.skip_foldexpr = {}
    skip_check:stop()
  end)
  return "0"
end

-- UI components -------------------------------------------------------- {{{1
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
    local choice = vim.fn.nr2char(vim.fn.getchar())
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

function M.fetch_color_pallete()
  local background = vim.o.background
  local palette = {
    ["default"] = function()
      if background == "dark" then
        return {
          bg = "#202328",
          fg = "#bbc2cf",
          fg_float = "#D1E3FA",
          yellow = "#ECBE7B",
          cyan = "#008080",
          darkblue = "#003152",
          green = "#98be65",
          orange = "#FF8800",
          violet = "#a9a1e1",
          magenta = "#c678dd",
          blue = "#51afef",
          red = "#ec5f67",
        }
      else
        return {
          bg = "#FFFBEF",
          fg = "#5c6A72",
          fg_float = "#D1E3FA",
          bg_dim = "#F2EFDF",
          yellow = "#FBD26A",
          cyan = "#35A77C",
          darkblue = "#003152",
          green = "#8DA101",
          orange = "#F57D26",
          violet = "#DF67BA",
          magenta = "#E66868",
          blue = "#3A94C5",
          red = "#900021",
        }
      end
    end,
    ["github_theme"] = function()
      local valid, github = pcall(require, "github-theme.palette")
      if not valid then
        return
      end
      local p = background == "dark" and github.load("github_dark") or github.load("github_light")
      return {
        bg = p.canvas.defaut,
        fg = p.fg.default,
        yellow = p.yellow.base,
        cyan = p.cyan.base,
        blue = p.blue.base,
        darkblue = p.scale.blue[-1],
        green = p.green.base,
        orange = p.orange,
        violet = p.scale.purple[-3],
        magenta = p.magenta.base,
        red = p.red.base,
        pink = p.pink.base,
      }
    end,
    ["kanagawa-wave"] = function()
      local valid, kanagawa = pcall(require, "kanagawa.colors")
      if not valid then
        return
      end
      local colors = kanagawa.setup({ theme = "wave" })
      local palette = colors.palette
      local ui = colors.theme.ui
      return {
        bg = ui.bg,
        bg_float = ui.float.bg,
        bg_border = ui.float.bg_border,
        bg_pmenu = ui.pmenu.bg,
        fg = ui.fg,
        fg_float = ui.float.fg,
        fg_border = ui.float.fg_border,
        fg_pmenu = ui.pmenu.fg,
        special = ui.special,
        nontext = ui.nontext,
        aqua = palette.waveAqua1,
        yellow = palette.dragonYellow,
        cyan = palette.lotusCyan,
        blue = palette.waveBlue1,
        darkblue = palette.waveBlue2,
        green = palette.dragonGreen,
        orange = palette.surimiOrange,
        violet = palette.dragonViolet,
        magenta = palette.dragonPink,
        red = palette.waveRed,
      }
    end,
  }
  return palette[vim.g.colors_name] and palette[vim.g.colors_name]() or palette.default()
end

function M.adjust_hi_group(palette)
  palette = vim.tbl_deep_extend("keep", palette or {}, vim.g.lbs_colors)

  -- 解决 vim 帮助文件的示例代码的不够突显的问题
  vim.api.nvim_set_hl(0, "helpExample", { link = "Special", default = true })

  local normal_float_hl = vim.api.nvim_get_hl(0, { name = "NormalFloat" })
  local bg_color = normal_float_hl.bg -- If NormalFloat or its bg is not set, bg_color will be nil
  local orange_color = palette.orange

  -- Only try to set MyBorder if bg_color is available, to avoid issues if NormalFloat.bg is nil
  if bg_color then
    if vim.fn.exists("g:neovide") == 1 then
      vim.api.nvim_set_hl(0, "MyBorder", { fg = bg_color, bg = bg_color })
    else
      vim.api.nvim_set_hl(0, "MyBorder", { fg = orange_color, bg = bg_color })
    end
  end

  vim.api.nvim_set_hl(0, "DiagnosticSignInfo", { bg = "NONE" })
  -- Setting the color scheme of the Complement window
  local palette_update = vim.o.background == "dark"
      and {
        background = palette.darkblue,
        fg = palette.fg_float,
        strong = palette.red,
      }
    or {
      background = palette.yellow,
      fg = palette.darkblue,
      strong = palette.red,
    }
  palette = vim.tbl_deep_extend("keep", palette_update, palette)

  -- For "guibg=bg", use Normal group's background color
  local normal_hl_info = vim.api.nvim_get_hl(0, { name = "Normal" })
  local normal_bg_color = normal_hl_info.bg -- This will be nil if Normal.bg is not set
  vim.api.nvim_set_hl(0, "MsgSeparator", { bg = normal_bg_color, fg = palette.strong })

  vim.api.nvim_set_hl(0, "ObsidianHighlightText", { fg = palette.strong })
  vim.api.nvim_set_hl(0, "@markdown.strong", { underline = true })
  vim.api.nvim_set_hl(0, "@markup.raw.markdown_inline", { bg = "NONE" })

  vim.api.nvim_set_hl(0, "IndentLine", { link = "LineNr" })
  vim.api.nvim_set_hl(0, "IndentLineCurrent", { fg = palette.orange })
end

return M
