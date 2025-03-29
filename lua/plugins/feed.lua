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
      {
        "https://feedx.net/rss/nikkei.xml",
        name = "日经中文网",
        tags = { "news" },
      },
    },
    zen = {
      enabled = false,
    },
    protocol = {
      backend = "local",
      ttrss = {
        url = "http://rss.econc.blog:181/",
        user = "liubianshi",
        password = vim.fn.system("~/.private_info.sh ttrss"),
      },
    },
    options = {
      entry = {
        wo = {
          signcolumn = "yes:1",
        },
      },
    },
    progress = {
      backend = "fidget",
    },
    ui = {
      tags = {
        color = "FeedLabel",
        format = function(id, db)
          local icons = {
            news = "📰",
            tech = "💻",
            movies = "🎬",
            games = "🎮",
            music = "🎵",
            podcast = "🎧",
            books = "📚",
            unread = "🆕",
            read = "✅",
            junk = "🚮",
            star = "⭐",
          }

          local get_icon = function(name)
            if icons[name] then
              return icons[name]
            end
            local has_mini, MiniIcons = pcall(require, "mini.icons")
            if has_mini then
              local icon = MiniIcons.get("filetype", name)
              if icon then
                return icon .. " "
              end
            end
            return name
          end

          local tags = vim.tbl_map(get_icon, db:get_tags(id))
          table.sort(tags)
          return table.concat(tags, " ")
        end,
      },
    },
  },
}
