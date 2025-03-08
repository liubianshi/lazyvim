return {
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
    config = function()
      ---@diagnostic disable: missing-fields
      require("everforest").setup({
        background = "hard",
        transparent_background_level = 2,
        italics = true,
        disable_italic_comments = true,
      })
    end,
  },
  {
    "rose-pine/neovim",
    name = "rose-pine",
    opts = {
      styles = {
        transparency = true,
      },
    },
  },
}
