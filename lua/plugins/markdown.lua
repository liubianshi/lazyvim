return {
  { -- obsidian-nvim/obsidian.nvim -------------------------------------------- {{{2
    "obsidian-nvim/obsidian.nvim",
    ft = { "markdown" },
    cmd = { "Obsidian" },
    keys = {
      { "<leader>nl", "<cmd>Obsidian quick_switch<cr>", desc = "Obsidian: Switch Note" },
      { "<leader>nn", "<cmd>Obsidian new<cr>", desc = "Obsidian: Create new note" },
      { "<leader>nj", "<cmd>Obsidian today<cr>", desc = "Obsidian: open/create a new daily note" },
      { "<leader>nf", "<cmd>Obsidian search<cr>", desc = "Obsidian: search for (or create) notes" },
    },
    opts = {
      legacy_commands = false,

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

      log_level = vim.log.levels.WARN,

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
        blink = true,
        -- Trigger completion at 2 chars.
        min_chars = 2,
      },
      callbacks = {
        enter_note = function(note) -- client, note
          local keymap = require("util").keymap
          -- stylua: ignore start
          keymap({ "<localleader>b", "<cmd>Obsidian backlinks<cr>",          buffer = note.bufnr, desc = "Obsidian: get back references",             })
          keymap({ "<localleader>o", "<cmd>Obsidian open<cr>",               buffer = note.bufnr, desc = "Obsidian: open note in APP",                })
          keymap({ "<localleader>t", "<cmd>Obsidian tags<cr>",               buffer = note.bufnr, desc = "Obsidian: get note with tag",               })
          keymap({ "<localleader>l", "<cmd>Obsidian link<cr>",               buffer = note.bufnr, desc = "Obsidian: get reference",                   })
          keymap({ "gf",             "<cmd>Obsidian follow_link vsplit<cr>", buffer = note.bufnr, desc = "Obsidian: follow reference",                })
          keymap({ "gf",             "<cmd>Obsidian link_new",               buffer = note.bufnr, desc = "Obsidian: create a new note",   mode = "v", })
        end,
        -- stylua: ignore end
      },

      footer = {
        format = "{{backlinks}} backlinks  {{properties}} properties  {{words}} words  {{chars}} chars",
        separator = string.rep("─", 80),
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

      frontmatter = {
        enabled = true,
        -- Optional, alternatively you can customize the frontmatter data.
        ---@return table
        func = function(note)
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
      },

      -- Optional, customize the default name or prefix when pasting images via `:ObsidianPasteImg`.
      ---@return string
      image_name_func = function()
        -- Prefix image names with timestamp.
        return string.format("%s-", os.date("%Y%m%d%H%M"))
      end,

      -- Optional, for templates (see below).
      templates = {
        subdir = "templates",
        date_format = "%Y-%m-%d",
        time_format = "%H:%M",
        -- A map for custom variables, the key should be the variable and the value a function
        substitutions = {},
      },

      ---@diagnostic disable: missing-fields, unused-local
      picker = {
        name = "snacks.pick",
        note_mappings = {
          ["new"] = "<C-x>n",
          ["insert_link"] = "<C-x>l",
        },
      },

      -- Optional, determines how certain commands open notes. The valid options are:
      -- 1. "current" (the default) - to always open in the current window
      -- 2. "vsplit" - to open in a vertical split if there's not already a vertical split
      -- 3. "hsplit" - to open in a horizontal split if there's not already a horizontal split
      open_notes_in = "current",

      -- Optional, configure additional syntax highlighting / extmarks.
      -- This requires you have `conceallevel` set to 1 or 2. See `:help conceallevel` for more details.
      ui = {
        enable = false, -- set to false to disable all additional syntax features
        update_debounce = 200, -- update delay after a text change (in milliseconds)
        -- Define how various check-boxes are displayed
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
        folder = "assets/imgs", -- This is the default
        -- A function that determines the text to insert in the note when pasting an image.
        -- It takes two arguments, the `obsidian.Client` and an `obsidian.Path` to the image file.
        -- This is the default implementation.
        ---@return string
        img_text_func = function(path)
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
  { -- MeanderingProgrammer/render-markdown.nvim ------------------------ {{{2
    "MeanderingProgrammer/render-markdown.nvim",
    dependencies = { "nvim-treesitter/nvim-treesitter", "nvim-mini/mini.icons" },
    ft = { "markdown", "quarto", "rmd", "codecompanion", "Avante" },
    opts = {
      render_modes = { "n", "i", "c", ":", "no", "io", "co" },
      anti_conceal = {
        enabled = true,
      },
      code = {
        disable_background = true,
        sign = true,
        style = "language",
        border = "hide",
        language = false,
      },
      dash = {
        enabled = true,
        width = 76,
      },
      heading = {
        width = "block",
        sign = false,
        -- icons = { "🌀  ", "🌕  ", "🌖  ", "🌗  ", "🌘  ", "🌑  " },
        icons = { "󰉫  ", "󰉬  ", "󰉭  ", "󰉮  ", "󰉯  ", "󰉰  " },
        position = "inline",
        right_pad = 0.02,
        backgrounds = {},
      },
      latex = {
        enabled = false,
      },
      indent = {
        enabled = true,
        skip_heading = true,
        skip_level = 2,
        icon = "",
      },
      html = {
        comment = {
          conceal = false,
        },
      },
    },
    config = function(_, opts)
      require("render-markdown").setup(opts)
      vim.api.nvim_set_hl(0, "RenderMarkdownIndent", { bg = nil })
    end,
  },
  {
    --  tadmccorkle/markdown.nvim --------------------------------------- {{{2
    "tadmccorkle/markdown.nvim",
    ft = "markdown",
    opts = {
      mappings = {
        inline_surround_toggle = "gs", -- (string|boolean) toggle inline style
        inline_surround_toggle_line = "gss", -- (string|boolean) line-wise toggle inline style
        inline_surround_delete = "ds", -- (string|boolean) delete emphasis surrounding cursor
        inline_surround_change = "cs", -- (string|boolean) change emphasis surrounding cursor
        link_add = "gl", -- (string|boolean) add link
        link_follow = "gx", -- (string|boolean) follow link
        go_curr_heading = "]c", -- (string|boolean) set cursor to current section heading
        go_parent_heading = "]p", -- (string|boolean) set cursor to parent section heading
        go_next_heading = "]]", -- (string|boolean) set cursor to next section heading
        go_prev_heading = "[[", -- (string|boolean) set cursor to previous section heading
      },
      on_attach = function(bufnr)
        local map = require("util").keymap
        map({ "<s-enter>", "<Cmd>MDListItemBelow<CR>", mode = { "n", "i" } })
      end,
    },
  },
}
