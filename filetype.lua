local function cheatsheets_filetype(path, bufnr)
  local syntax_check_regex = "^syntax: (%w+)%s*$"
  local second_line = vim.api.nvim_buf_get_lines(bufnr, 1, 2, false)[1] or ""
  if string.match(second_line, syntax_check_regex) then
    return string.match(second_line, syntax_check_regex)
  end

  local filetype_map = {
    R = "r",
    perl = "perl",
    stata = "stata",
    nvim = "vim",
    vim = "vim",
    bash = "sh",
  }

  local key = string.match(path:lower(), "/cheatsheets/personal/(%w+)/")
  if key and filetype_map[key] then
    return filetype_map[key]
  end
  return "sh"
end
vim.filetype.add({
  extension = {
    sxhkdrc = "sxhkd",
    tsv = "tsv",
    sthlp = "smcl",
    ihlp = "smcl",
    newsboat = "newsboat",
  },
  filename = {
    [".gitignore"] = "gitignore",
    lfrc = "lf",
  },
  pattern = {
    ["%.[Rr]md$"] = "rmd",
    ["%.[Rr]markdown$"] = "rmd",
    [".*/newsboat-article.*"] = "newsboat",
    [".*cheatsheets/personal/.*"] = cheatsheets_filetype,
  },
})
