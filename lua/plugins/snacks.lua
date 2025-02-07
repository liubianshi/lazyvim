return {
  "folke/snacks.nvim",
  opts = {
    bigfile = { enabled = true },
    zen = {
      win = {
        style = {
          width = 100,
          backdrop = { transparent = false },
        },
      },
    },
    dashboard = {
      width = 60,
      preset = {
        keys = {
          { icon = " ", key = "f", desc = "Find File", action = ":lua Snacks.dashboard.pick('files')" },
          { icon = "󱙺", key = "a", desc = "Chat New", action = ":GpChatNew" },
          { icon = " ", key = "e", desc = "New File", action = ":silent ene | startinsert" },
          { icon = " ", key = "r", desc = "Recent Files", action = ":lua Snacks.dashboard.pick('oldfiles')" },
          { icon = " ", key = "n", desc = "Obsidian Note", action = ":ObsidianQuickSwitch" },
          {
            icon = " ",
            key = "c",
            desc = "Config",
            action = ":lua Snacks.dashboard.pick('files', {cwd = vim.fn.stdpath('config')})",
          },
          { icon = " ", key = "s", desc = "Restore Session", section = "session" },
          { icon = "󰒲 ", key = "l", desc = "Lazy", action = ":Lazy" },
          { icon = " ", key = "q", desc = "Quit", action = ":qa" },
        },
      },
      sections = {
        { section = "header" },
        { section = "keys", padding = 1, gap = 0 },
        {
          pane = 1,
          icon = " ",
          title = "Projects",
          enabled = require("util").get_git_root("") == nil,
          section = "projects",
          indent = 2,
          padding = 1,
        },
        {
          pane = 1,
          icon = " ",
          title = require("util").get_git_root(""),
          section = "terminal",
          enabled = require("util").get_git_root("") ~= nil,
          cmd = "git status --short --branch --renames",
          padding = 1,
          ttl = 5 * 60,
          indent = 0,
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
          and not vim.tbl_contains({ "norg", "quarto", "markdown" }, vim.bo[buf].filetype)
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
  keys = {
    {
      "<leader>fm",
      function()
        Snacks.picker.recent()
      end,
      desc = "Smart",
    },
    {
      "<A-x>",
      function()
        Snacks.picker.commands({ layout = { preset = "ivy" } })
      end,
      desc = "Run Command",
    },
  },
}
