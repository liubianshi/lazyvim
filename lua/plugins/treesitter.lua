local function disable_treesitter(lang, buf)
  local disable_lang_list = { "tsv", "perl", "quarto" }
  local disable_filetype_list = { "tsv", "perl", "quarto" }
  if vim.tbl_contains(disable_lang_list, lang) then
    return true
  end
  if vim.tbl_contains(disable_filetype_list, vim.bo[buf].filetype) then
    return true
  end

  local lines = vim.api.nvim_buf_get_lines(buf, 0, 1, true)
  if lines and lines[1] and string.match(lines[1], "^# topic: %?$") then
    return true
  end

  local max_filesize = 100 * 1024 -- 100 KB
  local ok, stats = pcall(vim.uv.fs_stat, vim.api.nvim_buf_get_name(buf))
  if ok and stats and stats.size > max_filesize then
    return true
  end
end

return {
  { -- nvim-treesitter/nvim-treesitter
    "nvim-treesitter/nvim-treesitter",
    opts = {
      highlight = {
        disable = disable_treesitter,
      },
    },
  },
  { -- Wansmer/treesj: Neovim plugin for splitting/joining blocks of code  {{{3
    "Wansmer/treesj",
    cmd = { "TSJToggle", "TSJSplit", "TSJJoin" },
    keys = {
      { "<leader>mj", "<cmd>TSJJoin<cr>", desc = "Join Code Block" },
      { "<leader>ms", "<cmd>TSJSplit<cr>", desc = "Split Code Block" },
      { "<leader>mm", "<cmd>TSJToggle<cr>", desc = "Join/Split Code Block" },
    },
    opts = {
      use_default_keymaps = false,
    },
  },
  { -- AckslD/nvim-FeMaco.lua: Fenced Markdown Code-block editing ----------- {{{3
    "AckslD/nvim-FeMaco.lua",
    cmd = "FeMaco",
    ft = { "markdown", "rmarkdown", "norg" },
    keys = {
      { "<localleader>o", "<cmd>FeMaco<cr>", desc = "FeMaco: Edit Code Block" },
    },
    config = true,
  },
}
