return {
  "L3MON4D3/LuaSnip",
  lazy = true,
  build = "make install_jsregexp",
  keys = {
    {
      "<c-l>",
      function()
        require("luasnip").expand()
      end,
      mode = { "i", "s" },
      silent = true,
    },
  },
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
  opts = {
    history = true,
    delete_check_events = "TextChanged",
  },
}
