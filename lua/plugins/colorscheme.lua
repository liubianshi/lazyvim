return {
  {
    "folke/tokyonight.nvim",
    opts = {
      transparent = false,
      styles = {
        floats = "day",
      },
    },
  },
  {
    "vague2k/vague.nvim",
    opts = {
      transparent = false,
    },
  },
  {
    "neanias/everforest-nvim",
    version = false,
    lazy = false,
    priority = 1000, -- make sure to load this before all the other start plugins
    opts = {
      background = "hard",
      transparent_background_level = 0,
      float_style = "dim",
      italics = true,
      disable_italic_comments = true,
      on_highlights = function(hl, palette)
        hl.NormalFloat = { fg = palette.fg, bg = palette.none }
        hl.FloatTitle = { bg = palette.none }
        hl.FloatBorder = { bg = palette.none }
        hl["@comment.warning"] = { bg = palette.none }
        require("util.ui").adjust_hi_group(palette)
      end,
    },
    config = function(_, opts)
      require("everforest").setup(opts)
    end,
  },
  {
    "rose-pine/neovim",
    name = "rose-pine",
    opts = {
      styles = {
        transparency = false,
      },
      palette = {
        dawn = {
          base = "#E5E5E5",
        },
      },
    },
  },
  {
    "zenbones-theme/zenbones.nvim",
    -- Optionally install Lush. Allows for more configuration or extending the colorscheme
    -- If you don't want to install lush, make sure to set g:zenbones_compat = 1
    -- In Vim, compat mode is turned on as Lush only works in Neovim.
    dependencies = "rktjmp/lush.nvim",
    lazy = false,
    priority = 1000,
    config = function()
      vim.g.seoulbones_lightness = "bright"
      vim.g.seoulbones_darken_comments = 60
    end,
  },
}
