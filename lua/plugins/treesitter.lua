return {
  { -- nvim-treesitter/nvim-treesitter: Treesitter configurations ------- {{{3
    "nvim-treesitter/nvim-treesitter",
    cmd = "TSEnable",
    event = { "BufReadPost", "BufNewFile" },
    opts = function(_, opts)
      local disable_treesitter = function(lang, buf)
        local disable_lang_list = { "tsv", "perl" }
        for _, v in ipairs(disable_lang_list) do
          if v == lang then
            return true
          end
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
      vim.treesitter.language.register("markdown", "rmd")
      vim.treesitter.language.register("markdown", "qmd")
      vim.treesitter.language.register("markdown_inline", "qmd")
      opts = vim.tbl_deep_extend("force", opts or {}, {
        ensure_installed = {
          "r",
          "bash",
          "vim",
          "org",
          "lua",
          "dot",
          "perl",
          "html",
          "xml",
          "markdown",
          "markdown_inline",
          "bibtex",
          "css",
          "json",
          "regex",
          "vim",
          "vimdoc",
          "query",
          "latex",
          "jq",
          "rnoweb",
          "yaml",
        },
        highlight = {
          enable = true,
          additional_vim_regex_highlighting = false,
          disable = disable_treesitter,
        },
        indent = {
          enable = true,
          disable = disable_treesitter,
        },
      })
      return opts
    end,
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
  },
}
