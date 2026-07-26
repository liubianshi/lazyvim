-- 配色取样与高亮组调整：从当前 colorscheme 取色板，据此调整自定义高亮组。
local M = {}

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
  vim.api.nvim_set_hl(0, "Title", { fg = palette.red })
  vim.api.nvim_set_hl(0, "@markdown.strong", { bg = "NONE", fg = palette.blue, bold = true })
  vim.api.nvim_set_hl(0, "markup.strong", { bg = "NONE", fg = palette.blue, bold = true })
  vim.api.nvim_set_hl(0, "@markup.strong", { bg = "NONE", fg = palette.blue, bold = true })
  vim.api.nvim_set_hl(0, "TSStrong", { bg = "NONE", fg = palette.blue, bold = true })
  vim.api.nvim_set_hl(0, "@markup.raw.markdown_inline", { bg = "NONE", fg = palette.cyan })

  vim.api.nvim_set_hl(0, "IndentLine", { link = "LineNr" })
  vim.api.nvim_set_hl(0, "IndentLineCurrent", { fg = palette.orange })
  vim.api.nvim_set_hl(0, "Bold", { underline = true })
end

return M
