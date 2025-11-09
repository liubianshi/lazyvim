return {
  {
    "jghauser/papis.nvim",
    dependencies = {
      "kkharji/sqlite.lua",
      "MunifTanjim/nui.nvim",
    },
    opts = {
      enable_keymaps = true,
      cite_formats = {
        quarto = {
          ref_prefix = "@",
          separator_str = "; ",
        },
      },
      -- Filetypes that start papis.nvim.
      init_filetypes = { "markdown", "norg", "yaml", "typst", "quarto", "rmarkdown", "rmd" },
      -- The sqlite schema of the main `data` table. Only the "text" and "luatable"
      -- types are allowed.
      data_tbl_schema = {
        ref = { "text", required = false, unique = false },
      },
      ["debug"] = {
        enable = false,
      },
    },
    config = function(_, opts)
      require("papis").setup(opts)
    end,
  },
}
