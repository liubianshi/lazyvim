return {
  { -- epwalsh/obsidian.nvim -------------------------------------------- {{{2
    "epwalsh/obsidian.nvim",
    version = "*",
    ft = { "markdown" },
    cmd = { "ObsidianQuickSwitch", "ObsidianNew", "ObsidianSearch" },
    keys = {
      { "<leader>nl", "<cmd>ObsidianQuickSwitch<cr>", desc = "Obsidian: Switch Note" },
      { "<leader>nn", "<cmd>ObsidianNew<cr>", desc = "Obsidian: Create new note" },
      { "<leader>no", "<cmd>ObsidianOpen<cr>", desc = "Obsidian: open a note in the Obsidian app" },
      { "<leader>nj", "<cmd>ObsidianToday<cr>", desc = "Obsidian: open/create a new daily note" },
      { "<leader>nf", "<cmd>ObsidianSearch<cr>", desc = "Obsidian: search for (or create) notes" },
    },
    opts = {
      -- A list of workspace names, paths, and configuration overrides.
      -- If you use the Obsidian app, the 'path' of a workspace should generally be
      -- your vault root (where the `.obsidian` folder is located).
      -- When obsidian.nvim is loaded by your plugin manager, it will automatically set
      -- the workspace to the first workspace in the list whose `path` is a parent of the
      -- current markdown file being edited.
      workspaces = {
        {
          name = "research",
          path = "~/Documents/Writing/vaults/research",
        },
        {
          name = "bb",
          path = "~/Documents/Writing/vaults/bb",
        },
        {
          name = "organize",
          path = "~/Documents/Writing/vaults/organize",
        },
      },

      -- Optional, if you keep notes in a specific subdirectory of your vault.
      -- notes_subdir = "notes",

      -- Optional, set the log level for obsidian.nvim. This is an integer corresponding to one of the log
      -- levels defined by "vim.log.levels.*".
      log_level = vim.log.levels.INFO,

      daily_notes = {
        -- Optional, if you keep daily notes in a separate directory.
        folder = "dailies",
        -- Optional, if you want to change the date format for the ID of daily notes.
        date_format = "%Y-%m-%d",
        -- Optional, if you want to change the date format of the default alias of daily notes.
        alias_format = "%B %-d, %Y",
        -- Optional, if you want to automatically insert a template from your template directory like 'daily.md'
        template = nil,
      },

      -- Optional, completion of wiki links, local markdown links, and tags using nvim-cmp.
      completion = {
        -- Set to false to disable completion.
        nvim_cmp = false,
        -- Trigger completion at 2 chars.
        min_chars = 2,
      },

      -- Optional, configure key mappings. These are the defaults. If you don't want to set any keymappings this
      -- way then set 'mappings = {}'.
      mappings = {
        -- Overrides the 'gf' mapping to work on markdown/wiki links within your vault.
        ["gf"] = {
          action = function()
            return require("obsidian").util.gf_passthrough()
          end,
          opts = { noremap = false, expr = true, buffer = true },
        },
        ["gb"] = {
          action = "<cmd>ObsidianBacklinks<cr>",
          opts = { noremap = true, buffer = true },
        },
        -- Toggle check-boxes.
        ["<leader>nh"] = {
          action = function()
            return require("obsidian").util.toggle_checkbox()
          end,
          opts = { buffer = true },
        },
      },

      -- Where to put new notes. Valid options are
      --  * "current_dir" - put new notes in same directory as the current buffer.
      --  * "notes_subdir" - put new notes in the default notes subdirectory.
      new_notes_location = "notes_subdir",

      -- Optional, customize how names/IDs for new notes are created.
      note_id_func = function(title)
        -- Create note IDs in a Zettelkasten format with a timestamp and a suffix.
        -- In this case a note with the title 'My new note' will be given an ID that looks
        -- like '1657296016-my-new-note', and therefore the file name '1657296016-my-new-note.md'
        local suffix = ""
        if title ~= nil then
          -- If title is given, transform it into valid file name.
          -- suffix = title:gsub(" ", "-"):gsub('[^%w\128-\191\192-\255\194-\244\227-\233]', "_"):gsub('_+', '_'):lower()
          suffix = title
        else
          -- If title is nil, just add 4 random uppercase letters to the suffix.
          for _ = 1, 4 do
            suffix = suffix .. string.char(math.random(65, 90))
          end
        end
        return suffix
      end,

      -- Optional, customize how wiki links are formatted.
      ---@param opts {path: string, label: string, id: string|?}
      ---@return string
      wiki_link_func = function(opts)
        if opts.id == nil then
          return string.format("[[%s]]", opts.label)
        elseif opts.label ~= opts.id then
          return string.format("[[%s|%s]]", opts.id, opts.label)
        else
          return string.format("[[%s]]", opts.id)
        end
      end,

      -- Optional, customize how markdown links are formatted.
      ---@param opts {path: string, label: string, id: string|?}
      ---@return string
      markdown_link_func = function(opts)
        return string.format("[%s](%s)", opts.label, opts.path)
      end,

      -- Either 'wiki' or 'markdown'.
      preferred_link_style = "markdown",

      -- Optional, customize the default name or prefix when pasting images via `:ObsidianPasteImg`.
      ---@return string
      image_name_func = function()
        -- Prefix image names with timestamp.
        return string.format("%s-", os.date("%Y%m%d%H%M"))
      end,

      -- Optional, boolean or a function that takes a filename and returns a boolean.
      -- `true` indicates that you don't want obsidian.nvim to manage frontmatter.
      disable_frontmatter = false,

      -- Optional, alternatively you can customize the frontmatter data.
      ---@return table
      note_frontmatter_func = function(note)
        -- Add the title of the note as an alias.
        if note.title then
          note:add_alias(note.title)
        end

        local out = { id = note.id, aliases = note.aliases, tags = note.tags }

        -- `note.metadata` contains any manually added fields in the frontmatter.
        -- So here we just make sure those fields are kept in the frontmatter.
        if note.metadata ~= nil and not vim.tbl_isempty(note.metadata) then
          for k, v in pairs(note.metadata) do
            out[k] = v
          end
        end

        return out
      end,

      -- Optional, for templates (see below).
      templates = {
        subdir = "templates",
        date_format = "%Y-%m-%d",
        time_format = "%H:%M",
        -- A map for custom variables, the key should be the variable and the value a function
        substitutions = {},
      },

      -- Optional, by default when you use `:ObsidianFollowLink` on a link to an external
      -- URL it will be ignored but you can customize this behavior here.
      ---@param url string
      follow_url_func = function(url)
        -- Open the URL in the default web browser.
        vim.fn.jobstart({ "open", url }) -- Mac OS
        -- vim.fn.jobstart({"xdg-open", url})  -- linux
      end,

      -- Optional, set to true if you use the Obsidian Advanced URI plugin.
      -- https://github.com/Vinzent03/obsidian-advanced-uri
      use_advanced_uri = false,

      -- Optional, set to true to force ':ObsidianOpen' to bring the app to the foreground.
      open_app_foreground = false,

      ---@diagnostic disable: missing-fields, unused-local
      picker = {
        -- Set your preferred picker. Can be one of 'telescope.nvim', 'fzf-lua', or 'mini.pick'.
        name = "fzf-lua",
        -- Optional, configure key mappings for the picker. These are the defaults.
        -- Not all pickers support all mappings.
        mappings = {
          -- Create a new note from your query.
          new = "<C-x>",
          -- Insert a link to the selected note.
          insert_link = "<C-l>",
        },
      },

      -- Optional, sort search results by "path", "modified", "accessed", or "created".
      -- The recommend value is "modified" and `true` for `sort_reversed`, which means, for example,
      -- that `:ObsidianQuickSwitch` will show the notes sorted by latest modified time
      sort_by = "modified",
      sort_reversed = true,

      -- Optional, determines how certain commands open notes. The valid options are:
      -- 1. "current" (the default) - to always open in the current window
      -- 2. "vsplit" - to open in a vertical split if there's not already a vertical split
      -- 3. "hsplit" - to open in a horizontal split if there's not already a horizontal split
      open_notes_in = "current",

      -- Optional, configure additional syntax highlighting / extmarks.
      -- This requires you have `conceallevel` set to 1 or 2. See `:help conceallevel` for more details.
      ui = {
        enable = true, -- set to false to disable all additional syntax features
        update_debounce = 200, -- update delay after a text change (in milliseconds)
        -- Define how various check-boxes are displayed
        checkboxes = {
          -- NOTE: the 'char' value has to be a single character, and the highlight groups are defined below.
          [" "] = { char = "󰄱", hl_group = "ObsidianTodo" },
          ["x"] = { char = "", hl_group = "ObsidianDone" },
          [">"] = { char = "", hl_group = "ObsidianRightArrow" },
          ["~"] = { char = "󰰱", hl_group = "ObsidianTilde" },
          -- Replace the above with this if you don't have a patched font:
          -- [" "] = { char = "☐", hl_group = "ObsidianTodo" },
          -- ["x"] = { char = "✔", hl_group = "ObsidianDone" },

          -- You can also add more custom ones...
        },
        -- Use bullet marks for non-checkbox lists.
        bullets = { char = "", hl_group = "ObsidianBullet" },
        external_link_icon = { char = "", hl_group = "ObsidianExtLinkIcon" },
        -- Replace the above with this if you don't have a patched font:
        reference_text = { hl_group = "ObsidianRefText" },
        highlight_text = { hl_group = "ObsidianHighlightText" },
        tags = { hl_group = "ObsidianTag" },
        hl_groups = {
          -- The options are passed directly to `vim.api.nvim_set_hl()`. See `:help nvim_set_hl`.
          ObsidianTodo = { bold = true, fg = "#f78c6c" },
          ObsidianDone = { bold = true, fg = "#89ddff" },
          ObsidianRightArrow = { bold = true, fg = "#f78c6c" },
          ObsidianTilde = { bold = true, fg = "#ff5370" },
          ObsidianBullet = { bold = true, fg = "#89ddff" },
          ObsidianRefText = { underline = true, fg = "#c792ea" },
          ObsidianExtLinkIcon = { fg = "#c792ea" },
          ObsidianTag = { italic = true, fg = "#89ddff" },
          -- ObsidianHighlightText = { bg = "#75662e" },
        },
      },

      -- Specify how to handle attachments.
      ---@diagnostic disable: missing-fields, unused-local
      attachments = {
        -- The default folder to place images in via `:ObsidianPasteImg`.
        -- If this is a relative path it will be interpreted as relative to the vault root.
        -- You can always override this per image by passing a full path to the command instead of just a filename.
        img_folder = "assets/imgs", -- This is the default
        -- A function that determines the text to insert in the note when pasting an image.
        -- It takes two arguments, the `obsidian.Client` and an `obsidian.Path` to the image file.
        -- This is the default implementation.
        ---@return string
        img_text_func = function(_, path)
          local link_path
          local buffer_dir = vim.fn.fnamemodify(vim.api.nvim_buf_get_name(0), ":p:h")
          local abs_path = vim.fn.fnamemodify(path.filename, ":p")
          local start_pos, end_pos = string.find(abs_path, buffer_dir .. "/img/", 1, true)

          if start_pos and end_pos then
            link_path = "img/" .. string.sub(abs_path, end_pos + 1, -1)
          else
            link_path = "img/" .. vim.fs.basename(abs_path)
            vim.uv.fs_link(abs_path, (buffer_dir .. "/" .. link_path))
          end

          local display_name = vim.fs.basename(link_path)
          return string.format("![%s](%s)", display_name, link_path)
        end,
      },
    },
  },
  { -- liubianshi/anki-panky -------------------------------------------- {{{3
    "liubianshi/anki-panky",
    dev = true,
    ft = { "markdown" },
    cmd = { "AnkiNew", "AnkiPush" },
    config = true,
  },
  { -- ellisonleao/glow.nvim: A markdown preview directly in your neovim.  {{{3
    "ellisonleao/glow.nvim",
    cmd = { "Glow" },
    config = true,
  },
  { -- OXY2DEV/markview.nvim -------------------------------------------- {{{3
    "OXY2DEV/markview.nvim",
    lazy = false,
    opts = function()
      local default_heading = {
        style = "icon",
        sign = " ",
      }
      local hl_normal = vim.api.nvim_get_hl(0, { name = "Normal" })
      local hl_code = vim.api.nvim_get_hl(0, { name = "MarkviewCode" })
      local hl_code_info = vim.api.nvim_get_hl(0, { name = "MarkviewCodeInfo" })
      hl_code.bg = hl_normal.bg
      hl_code_info.bg = hl_normal.bg
      local repeat_symbol = {
        type = "repeating",
        repeat_amount = function(_)
          local indent = vim.fn.indent(vim.fn.line("."))
          local wininfo = vim.fn.getwininfo(vim.api.nvim_get_current_win())[1]
          return math.floor(wininfo.width / 2) - wininfo.textoff - 1 - indent
        end,
        text = "─",
        hl = {
          "MarkviewGradient1",
          "MarkviewGradient2",
          "MarkviewGradient3",
          "MarkviewGradient4",
          "MarkviewGradient5",
          "MarkviewGradient6",
          "MarkviewGradient7",
          "MarkviewGradient8",
          "MarkviewGradient9",
          "MarkviewGradient10",
        },
        --- Placement direction of the gradient.
        ---@type "left" | "right"
        direction = "left",
      }

      return {
        modes = { "n", "i", "c", ":", "no", "io", "co" },
        hybrid_modes = { "i", "n" },
        ignore_nodes = { "list_item", "fenced_code_block", "block_quote" },
        headings = {
          enable = true,
          shift_width = 0,
          heading_1 = {
            style = "label",
            align = "left",
            icon = "",
            sign = " ",
            corner_left = " ░▒▓",
            padding_left = " ",
            corner_left_hl = "@comment.warning",
          },
          heading_2 = default_heading,
          heading_3 = default_heading,
          heading_4 = default_heading,
          heading_5 = default_heading,
          heading_6 = default_heading,
        },
        footnotes = {
          enable = false,
        },
        code_blocks = {
          enable = true,
          icons = "mini",
          style = "simple",
          hl = hl_code,
          info_hl = hl_code_info,
          pad_amount = 0,
          sign = false,
          language_direction = "left",
        },
        latex = {
          block = { enable = false },
        },
        list_items = {
          enable = false,
        },
        inline_codes = {
          enable = false,
        },
        links = {
          enable = false,
        },
        horizontal_rules = {
          enable = true,
          parts = {
            repeat_symbol,
            {
              type = "text",
              text = "  ",
              hl = "MarkviewGradient10",
            },
            repeat_symbol,
          },
        },
      }
    end,
  },
}