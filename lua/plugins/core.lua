return {
  {
    "LazyVim/LazyVim",
    opts = function(_, opts)
      local background
      local env_bg = vim.env.NVIM_BACKGROUND and vim.env.NVIM_BACKGROUND:lower()

      if env_bg == "dark" or env_bg == "light" then
        background = env_bg
      else
        background = tonumber(os.date("%H")) >= 18 and "dark" or "light"
      end

      vim.opt.background = background

      local colorschemes = {
        dark = vim.env.NVIM_COLOR_SCHEME_DARK or "rose-pine",
        light = vim.env.NVIM_COLOR_SCHEME_LIGHT or "rose-pine",
      }

      opts.colorscheme = colorschemes[background]
    end,
  },
}
