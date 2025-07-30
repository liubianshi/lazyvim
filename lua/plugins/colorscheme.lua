return {
  {
    "folke/tokyonight.nvim",
    opts = {
      transparent = false,
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
    },
  },
}
