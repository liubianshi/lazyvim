return {
  name = "Source ...",
  builder = function(params)
    return {
      cmd = { "perl" },
      args = { vim.fn.expand("%") },
    }
  end,
  condition = {
    filetype = { "perl", "sh", "bash" },
  },
}
