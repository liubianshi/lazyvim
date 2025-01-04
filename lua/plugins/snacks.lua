return {
  "folke/snacks.nvim",
  opts = {
    bigfile = { enabled = true },
    dashboard = {
      width = 60,
      preset = {
        keys = {
          { icon = " ", key = "f", desc = "Find File", action = ":lua Snacks.dashboard.pick('files')" },
          { icon = " ", key = "e", desc = "New File", action = ":silent ene | startinsert" },
          { icon = " ", key = "r", desc = "Recent Files", action = ":lua Snacks.dashboard.pick('oldfiles')" },
          { icon = " ", key = "g", desc = "Find Text", action = ":lua Snacks.dashboard.pick('live_grep')" },
          { icon = " ", key = "n", desc = "Obsidian Note", action = ":ObsidianQuickSwitch" },
          {
            icon = " ",
            key = "c",
            desc = "Config",
            action = ":lua Snacks.dashboard.pick('files', {cwd = vim.fn.stdpath('config')})",
          },
          { icon = " ", key = "s", desc = "Restore Session", section = "session" },
          { icon = " ", key = "x", desc = "Lazy Extras", action = ":LazyExtras" },
          { icon = "󰒲 ", key = "l", desc = "Lazy", action = ":Lazy" },
          { icon = " ", key = "q", desc = "Quit", action = ":qa" },
        },
      },
      sections = {
        { section = "header" },
        { section = "keys", padding = 1, gap = 0 },
        { pane = 1, icon = " ", title = "Projects", section = "projects", indent = 2, padding = 1 },
        {
          pane = 1,
          icon = " ",
          title = "Git Status",
          section = "terminal",
          enabled = require("util").get_git_root("") ~= nil,
          cmd = "git status --short --branch --renames",
          height = 5,
          padding = 1,
          ttl = 5 * 60,
          indent = 3,
        },
        {
          pane = 2,
          section = "terminal",
          enabled = require("util").get_git_root("") == nil,
          cmd = "fortune -s",
          -- height = 6,
          indent = 1,
          ttl = 5 * 60,
          padding = 1,
        },
        { section = "startup" },
      },
    },
    indent = {
      enabled = true,
      filter = function(buf)
        return vim.g.snacks_indent ~= false
          and vim.b[buf].snacks_indent ~= false
          and vim.bo[buf].buftype == ""
          and vim.bo[buf].filetype ~= "norg"
      end,
    },
    notifier = {
      enabled = true,
      timeout = 3000,
    },
    quickfile = { enabled = true },
    terminal = { enabled = true },
    statuscolumn = {
      enabled = false,
      folds = {
        open = true,
        git_hl = true,
      },
    },
    scoll = { enabled = true },
    words = { enabled = true },
    styles = {
      notification = {
        wo = { wrap = true }, -- Wrap notifications
      },
    },
  },
}