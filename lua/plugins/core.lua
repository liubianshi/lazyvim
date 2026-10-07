return {
  {
    "LazyVim/LazyVim",

    opts = function(_, opts)
      -- Preserve Neovim's startup terminal detection unless overridden.
      -- TermResponse in config/autocmds.lua handles subsequent changes.
      local background = (vim.env.NVIM_BACKGROUND or vim.o.background):lower()

      local colorschemes = vim.g.default_colorscheme
        or {
          dark = vim.env.NVIM_COLOR_SCHEME_DARK or "tokyonight-night",
          light = vim.env.NVIM_COLOR_SCHEME_LIGHT or "default",
        }

      vim.opt.background = background
      opts.colorscheme = colorschemes[background]
    end,
  },
}
