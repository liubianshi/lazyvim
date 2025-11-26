-- Optimized function to get the first word from the background cache file
-- Uses more efficient file handling and error checking
local function fetch_terminal_background()
  local file_path = os.getenv("TERM_BACKGROUND_CACHE")
  if not file_path then
    return nil
  end

  local file, err = io.open(file_path, "r")
  if not file then
    -- Log error if needed: print("Error opening file: " .. err)
    return nil
  end

  -- Read the first line efficiently
  local line = file:read("*l")
  file:close()

  if not line then
    return nil
  end

  -- Extract the first word using pattern matching
  local first_word = line:match("%S+")
  return first_word
end

return {
  {
    "LazyVim/LazyVim",

    opts = function(_, opts)
      local background = vim.env.NVIM_BACKGROUND or fetch_terminal_background()
      background = (background or "dark"):lower()

      local colorschemes = vim.g.default_colorscheme
        or {
          dark = vim.env.NVIM_COLOR_SCHEME_DARK or "everforest",
          light = vim.env.NVIM_COLOR_SCHEME_LIGHT or "seoulbones",
        }

      vim.opt.background = background
      opts.colorscheme = colorschemes[background]
    end,
  },
}
