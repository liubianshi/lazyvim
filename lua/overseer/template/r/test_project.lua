return {
  name = "R: test current project",
  builder = function()
    local args
    if vim.uv.fs_access("NAMESPACE", "R") then
      args = { "-e", "devtools::test()" }
    else
      args = { "tests/testthat.R" }
    end
    return {
      cmd = { "Rscript" },
      args = args,
      name = "R: test current project",
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
      if vim.fn.isdirectory("R") and vim.uv.fs_access("tests/testthat.R", "R") then
        return true
      end
      return false
    end,
  },
}
