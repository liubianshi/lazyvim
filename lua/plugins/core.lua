return {
  {
    "LazyVim/LazyVim",
    opts = function()
      local background = string.lower(vim.env.NVIM_BACKGROUND or "dark")
      vim.opt.background = string.lower(background)

      local night = tonumber(os.date("%H")) > 17
      local colorscheme = {
        dark = vim.env.NVIM_COLOR_SCHEME_DARK or (night and "vague" or "everforest"),
        light = vim.env.NVIM_COLOR_SCHEME_LIGHT or "rose-pine",
      }

      return {
        colorscheme = colorscheme[background],
      }
    end,
  },
}
