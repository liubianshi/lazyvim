return {
  "neo451/feed.nvim",
  cmd = "Feed",
  opts = {
    feeds = {
      -- These two styles both work
      "https://neovim.io/news.xml",
      {
        "http://feeds.feedburner.com/ruanyifeng",
        name = "阮一峰的网络日志",
        tags = { "blog", "tech" }, -- tags given are inherited by all its entries
      },
    },
  },
}
