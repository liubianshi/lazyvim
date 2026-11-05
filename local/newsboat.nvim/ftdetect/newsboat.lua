vim.filetype.add({
  extension = {
    newsboat = "newsboat",
  },
  pattern = {
    [".*/newsboat%-article.*"] = "newsboat",
  },
})
