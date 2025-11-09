return {
  {
    "LazyVim/LazyVim",

    opts = function(_, opts)
      -- Determine and apply background and colorscheme based on environment variables
      -- and time-of-day, with sensible fallbacks.

      -- Normalize environment-provided background preference ("dark", "light", or custom)
      local env_bg = (vim.env.NVIM_BACKGROUND or ""):lower()

      -- Default colorschemes can be overridden via environment variables
      local DEFAULTS = {
        dark = vim.env.NVIM_COLOR_SCHEME_DARK or "rose-pine",
        light = vim.env.NVIM_COLOR_SCHEME_LIGHT or "rose-pine",
      }

      local background, colorscheme
      if vim.env.TERM == "xterm-ghostty" then
        env_bg = "dark"
        DEFAULTS.dark = "everforest"
      end

      if env_bg == "dark" or env_bg == "light" then
        -- Respect explicit background preference
        background = env_bg
        colorscheme = DEFAULTS[background]
      elseif env_bg == "writeroom" then
        -- Special preset: writing mode (force dark + specific scheme)
        background = "dark"
        colorscheme = "everforest"
      else
        -- No explicit preference: choose by local time
        -- Dark from 18:00-23:59 and 00:00-06:59, light otherwise
        local hour = tonumber(os.date("%H")) or 12
        background = (hour >= 18 or hour <= 6) and "dark" or "light"
        colorscheme = DEFAULTS[background]
      end

      -- Safety: ensure background is valid and colorscheme has a fallback
      if background ~= "dark" and background ~= "light" then
        background = "dark"
      end
      colorscheme = colorscheme or DEFAULTS[background] or "rose-pine"

      -- Apply settings to Neovim and LazyVim
      vim.opt.background = background
      opts.colorscheme = colorscheme

    end,
  },
}
