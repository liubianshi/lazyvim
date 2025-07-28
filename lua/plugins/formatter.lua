return {
  "stevearc/conform.nvim",
  opts = {
    formatters_by_ft = {
      bib = { "bibtex-tidy" },
      bash = { "shfmt" },
      json = { "jq" },
      xml = { "xmllint" },
      python = { "ruff" },
      yaml = { "yq" },
      r = { "air" },
      markdown = { "injected", "mdwrap" },
      quarto = { "injected", "mdwrap" },
      codecompanion = { "mdwrap" },
      perl = { "perltidy" },
    },
    formatters = {
      ["perltidy"] = {
        prepend_args = { "-i=2", "-l=120", "-xci", "-cti=1", "-nsfs", "-st" },
      },
      ["r-format"] = function()
        local shiftwidth = vim.opt.shiftwidth:get()
        local expandtab = vim.opt.expandtab:get()

        if not expandtab then
          shiftwidth = 0
        end

        return {
          command = "r-format",
          args = { "-i", shiftwidth },
          stdin = true,
        }
      end,
      ["mdwrap"] = {
        command = "mdwrap",
      },
      ["injected"] = {
        lang_to_ft = {
          r = { "air" },
        },
        lang_to_formatters = {
          r = { "air" },
          lua = { "stylua" },
        },
      },
    },
  },
}
