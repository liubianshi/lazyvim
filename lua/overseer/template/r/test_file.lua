return {
  name = "test current file",
  builder = function()
    local test_file = require("rlib.test").source_to_test_filepath(vim.fn.expand("%"))
    return {
      cmd = { "Rscript" },
      args = {
        "--no-init-file",
        "--no-save",
        "--no-restore",
        "-e",
        string.format([[testthat::test_file("%s")]], test_file),
      },
      name = "R: test current file",
      cwd = vim.uv.cwd(),
      components = {
        { "open_output", on_complete = "always", focus = true },
        "default",
      },
      tags = { require("overseer").TAG.TEST },
    }
  end,
  condition = {
    callback = function()
      if not vim.fn.isdirectory("R") then
        return false
      end
      local fname = vim.fn.expand("%")
      if fname:lower():match("^r/.+%.r$") and not vim.fn.fnamemodify(fname, ":t"):match("^test[-_]") then
        return true
      end
      return false
    end,
  },
}
