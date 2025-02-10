return {
  "stevearc/conform.nvim",
  opts = {
    formatters_by_ft = {
      bib = { "bibtex-tidy" },
      json = { "jq" },
      xml = { "xmllint" },
      yaml = { "yq" },
      r = { "r-format" },
      markdown = { "mdwrap" },
      codecompanion = { "mdwrap" },
      quarto = { "mdwrap" },
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
    },
  },
}
