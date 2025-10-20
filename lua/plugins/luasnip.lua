return {
  "L3MON4D3/LuaSnip",
  enabled = true,
  lazy = true,
  build = "make install_jsregexp",
  dependencies = {
    {
      "rafamadriz/friendly-snippets",
      config = function()
        require("luasnip.loaders.from_vscode").lazy_load()
        require("luasnip.loaders.from_vscode").lazy_load({ paths = { vim.fn.stdpath("config") .. "/snippets" } })
        require("luasnip.loaders.from_lua").load({ paths = { vim.fn.stdpath("config") .. "/snippets" } })
      end,
    },
  },
  opts = function(_, opts)
    return vim.tbl_deep_extend("force", opts or {}, {
      history = true,
      delete_check_events = "TextChanged",
      ft_func = function(bufnr)
        local func = require("luasnip/extras/filetype_functions").extend_load_ft({
          markdown = { "yaml", "r" },
          quarto = { "r", "yaml" },
        })
        bufnr = bufnr or 0
        return func(bufnr)
      end,
    })
  end,
  config = function(_, opts)
    local ls = require("luasnip")
    ls.setup(opts)
    ls.filetype_extend("markdown_inline", { "markdown" })
    ls.filetype_extend("codecompanion", { "codecompanion", "markdown" })
    ls.filetype_extend("quarto", { "quarto", "markdown" })
  end,
}
