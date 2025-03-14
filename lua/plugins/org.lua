return {
  { -- nvim-orgmode/orgmode: Orgmode clone written in Lua ------------------- {{{3
    {
      "nvim-orgmode/orgmode",
      ft = "org",
      cmd = { "OrgCapture" },
      dependencies = {
        "nvim-orgmode/org-bullets.nvim",
      },
      keys = {
        { "<leader>oa", desc = "Orgmode: agenda prompt" },
        { "<leader>oc", desc = "Orgmode: capture prompt" },
      },
      config = function()
        -- Load custom tree-sitter grammar for org filetype
        local orglib = "~/Documents/Writing/"
        local opts = {
          org_agenda_files = { orglib .. "*.org" },
          org_default_notes_file = orglib .. "refile.org",
          org_todo_keywords = {
            "TODO(t)",
            "PROJ(p)",
            "LOOP(r)",
            "STRT(s)",
            "WAIT(w)",
            "HOLD(h)",
            "IDEA(i)",
            "|",
            "DONE(d)",
            "KILL(k)",
            "CANCELLED(c)",
          },
          org_highlight_latex_and_related = "entities",
          org_startup_indented = false,
          org_hide_emphasis_markers = true,
          org_hide_leading_stars = true,
          diagnostics = false,
          org_capture_templates = {
            t = {
              description = "Todo",
              template = "\n* TODO %?\n %T",
              target = orglib .. "todo.org",
            },
            j = {
              description = "Short Journal",
              template = "\n*** %<%Y-%m-%d> %<%A>\n**** %U\n\n%?",
              target = orglib .. "journal.org",
            },
          },
        }
        require("orgmode").setup(opts)
        vim.api.nvim_create_user_command("OrgCapture", function()
          require("orgmode").action("capture.prompt")
          vim.schedule(function()
            vim.cmd([[only!]])
          end)
        end, { nargs = 0, desc = "Org Capture" })
      end,
    },
    {
      "akinsho/org-bullets.nvim",
      config = true,
      lazy = true,
    },
  },
}
