return {
  {
    "LazyVim/LazyVim",
    opts = function(_, opts)
      local background
      local env_bg = vim.env.NVIM_BACKGROUND and vim.env.NVIM_BACKGROUND:lower()
      local current_time = tonumber(os.date("%H"))

      if env_bg == "dark" or env_bg == "light" then
        background = env_bg
      else
        background = (current_time >= 18 or current_time <= 6) and "dark" or "light"
      end

      vim.opt.background = background

      local colorschemes = {
        dark = vim.env.NVIM_COLOR_SCHEME_DARK or "rose-pine",
        light = vim.env.NVIM_COLOR_SCHEME_LIGHT or "everforest",
      }

      opts.colorscheme = colorschemes[background]
    end,
  },
}
