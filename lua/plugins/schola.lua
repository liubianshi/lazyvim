local filetypes = { "markdown", "quarto", "rmd", "rmarkdown", "pandoc" }

return {
  "liubianshi/schola.nvim",
  dev = true,
  ft = filetypes,
  opts = { filetypes = filetypes },
}
