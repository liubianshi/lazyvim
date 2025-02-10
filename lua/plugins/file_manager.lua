return {
  { -- nvim-neo-tree/neo-tree.nvim: browse tree like structures --------- {{{3
    "nvim-neo-tree/neo-tree.nvim",
    enabled = false,
    cmd = "Neotree",
    dependencies = { "s1n7ax/nvim-window-picker" },
    opts = {
      sources = { "filesystem", "buffers", "git_status", "document_symbols" },
      open_files_do_not_replace_types = { "terminal", "Trouble", "qf", "Outline" },
      filesystem = {
        bind_to_cwd = false,
        follow_current_file = {
          enabled = true,
        },
        use_libuv_file_watcher = true,
      },
      default_component_configs = {
        indent = {
          with_expanders = true, -- if nil and file nesting is enabled, will enable expanders
          expander_collapsed = "",
          expander_expanded = "",
          expander_highlight = "NeoTreeExpander",
        },
        git_status = {
          symbols = {
            -- Change type
            added = "", -- or "✚", but this is redundant info if you use git_status_colors on the name
            modified = "", -- or "", but this is redundant info if you use git_status_colors on the name
            deleted = "✖", -- this can only be used in the git_status source
            renamed = "󰁕", -- this can only be used in the git_status source
            -- Status type
            untracked = "",
            ignored = "",
            unstaged = "󰄱",
            staged = "",
            conflict = "",
          },
        },
      },
      window = {
        width = 35,
        mappings = {
          ["<space>"] = "none",
          ["w"] = "none",
          ["l"] = "open",
          ["L"] = "open_with_window_picker",
          ["S"] = "split_with_window_picker",
          ["s"] = "vsplit_with_window_picker",
          ["h"] = "close_node",
        },
      },
    },
  },
  { -- stevearc/oil.nvim: file explorer: edit your filesystem like a buffer  {{{3
    "stevearc/oil.nvim",
    dependencies = {
      { "echasnovski/mini.icons", opts = {} },
    },
    opts = {
      columns = {
        { "icon", highlight = "Special" },
        { "mtime", format = "%Y-%m-%d %H:%M", highlight = "Number" },
        { "size", highlight = "String" },
      },
    },
  },
}
