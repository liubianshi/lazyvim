return {
  "folke/snacks.nvim",
  opts = {
    bigfile = { enabled = true },
    image = {
      enabled = true,
      doc = {
        enabled = true,
        inline = true,
        float = true,
      },
      resolve = function(path, src)
        if require("obsidian.api").path_is_note(path) then
          return require("obsidian.api").resolve_image_path(src)
        end
      end,
      math = {
        enabled = false,
        latex = {
          font_size = "tiny",
        },
      },
    },
    zen = {
      win = {
        style = {
          width = 100,
          backdrop = { transparent = false },
        },
      },
    },
    dashboard = {
      enabled = function()
        local argv = vim.v.argv or {}
        if #argv == 1 or (#argv == 2 and argv[2] == "--embed") then
          return true
        else
          return false
        end
      end,
      width = 60,
      preset = {
        keys = {
          { icon = " ", key = "f", desc = "Find File", action = ":lua Snacks.dashboard.pick('files')" },
          { icon = "󱙺", key = "a", desc = "Chat New", action = ":CodeCompanionChat" },
          { icon = " ", key = "e", desc = "New File", action = ":silent ene | startinsert" },
          { icon = " ", key = "r", desc = "Recent Files", action = ":lua Snacks.dashboard.pick('oldfiles')" },
          { icon = " ", key = "n", desc = "Obsidian Note", action = ":Obsidian quick_switch" },
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
    picker = {
      ui_select = true,
      matcher = {
        cwd_bonus = true, -- give bonus for matching files in the cwd
        frecency = true, -- frecency bonus
        history_bonus = true, -- give more weight to chronological order
      },
      win = {
        preview = {
          wo = {
            relativenumber = false,
            number = false,
          },
        },
        input = {
          keys = {
            ["<c-x>d"] = { "delete_file", mode = { "n", "i" } },
          },
        },
      },
      actions = {
        delete_file = function(picker)
          -- Get the selected item from the picker
          local items = picker:selected({ fallback = true })

          for _, item in ipairs(items) do
            if not item or not item._path or type(item._path) ~= "string" then
              vim.notify(
                "No valid item selected or item path is invalid.",
                vim.log.levels.WARN,
                { title = "File Deletion" }
              )
              return
            end

            local file_path = item._path
            if not vim.uv.fs_stat(file_path) then
              vim.notify(
                "File or directory does not exist: " .. file_path,
                vim.log.levels.WARN,
                { title = "File Deletion" }
              )
              return
            end

            local filename = vim.fn.fnamemodify(file_path, ":t") -- Extracts filename from path
            Snacks.input({ prompt = string.format("Delete %s? (y/N): ", filename) }, function(answer)
              local normalized_answer = string.lower(answer or "")
              if normalized_answer == "y" or normalized_answer == "yes" then
                vim.uv.fs_unlink(file_path, function(unlink_err)
                  if unlink_err then
                    local error_message = string.format(
                      "Error deleting file %s: %s (%s)",
                      file_path,
                      unlink_err[1] or "Unknown Error", -- Error code string
                      unlink_err[2] or "No details" -- Error description string
                    )
                    vim.notify(error_message, vim.log.levels.ERROR, { title = "File Deletion" })
                  end
                end)
              end

              picker:close()
            end)
          end
        end,
      },
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
      "<leader>fn",
      function()
        local ori_cmd = vim.uv.cwd()
        vim.cmd.cd(vim.env.WRITING_LIB or vim.env.HOME .. "/Documents/writing")
        Snacks.picker.files({
          exclude = {
            "*.{bck,html}",
            "**/tags",
          },
          on_close = function()
            vim.cmd.cd(ori_cmd)
          end,
        })
      end,
      desc = "Search Personal Notes",
    },
    {
      "<leader>fN",
      function()
        local ori_cmd = vim.uv.cwd()
        vim.cmd.cd(vim.env.WRITING_LIB or vim.env.HOME .. "/Documents/writing")
        Snacks.picker.grep({
          exclude = {
            "*.{bck,html}",
            "**/tags",
          },
          on_close = function()
            vim.cmd.cd(ori_cmd)
          end,
        })
      end,
      desc = "Search Personal Notes",
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
