return {
  {
    "LazyVim/LazyVim",

    opts = function(_, opts)
      -- $NVIM_BACKGROUND is the shell-side override; TermResponse in
      -- config/autocmds.lua corrects this after OSC 11 / DEC 2031 arrives.
      local background = (vim.env.NVIM_BACKGROUND or "dark"):lower()

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
