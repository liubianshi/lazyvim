local M = {}

-- Sets NVIM_BACKGROUND to "writeroom" when opening writing-focused filetypes.
-- This is done early to influence downstream plugin/theme configuration.
function M.launch_writing_room()
  if vim.env.NVIM_BACKGROUND and vim.env.NVIM_BACKGROUND ~= "" then
    return
  end

  local argv = vim.fn.argv()
  if type(argv) ~= "table" or #argv == 0 then
    return
  end

  -- Use a set for O(1) membership checks
  local writing_ft = {
    quarto = true,
    markdown = true,
    latex = true,
    norg = true,
    org = true,
    rmarkdown = true,
    pandoc = true,
  }

  -- Attempt to infer filetype from each provided file path
  for _, path in ipairs(argv) do
    local ft = nil

    -- Prefer Neovim's filetype matcher when available
    if vim.filetype and vim.filetype.match then
      ft = vim.filetype.match({ filename = path })
    end

    -- Fallback: basic extension-based mapping
    if not ft and type(path) == "string" then
      local ext = path:match("%.([%w]+)$")
      if ext then
        local ext_map = {
          md = "markdown",
          markdown = "markdown",
          qmd = "quarto",
          org = "org",
          norg = "norg",
          rmd = "rmarkdown",
          tex = "latex",
          pandoc = "pandoc",
          pdc = "pandoc",
          html = "html",
        }
        ft = ext_map[ext]
      end
    end

    if ft and writing_ft[ft] then
      vim.env.NVIM_BACKGROUND = "writeroom"
      return
    end
  end
end

return M
