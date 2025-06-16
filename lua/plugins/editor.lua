return {
  { -- junegunn/vim-easy-align: text alignment tool --------------------- {{{3
    "junegunn/vim-easy-align",
    init = function()
      vim.keymap.set({ "n", "x" }, "ga", "<Plug>(EasyAlign)", { desc = "Easy Align" })
    end,
    keys = { "ga" },
    cmd = "EasyAlign",
    event = "VeryLazy",
  },
  { -- stevearc/quicker.nvim: Improved quickfix ------------------------- {{{3
    "stevearc/quicker.nvim",
    event = "FileType qf",
    config = function()
      vim.keymap.set("n", "<leader>uq", function()
        require("quicker").toggle()
      end, {
        desc = "Toggle quickfix",
      })
      vim.keymap.set("n", "<leader>ql", function()
        require("quicker").toggle({ loclist = true })
      end, {
        desc = "Toggle loclist",
      })
      require("quicker").setup({
        keys = {
          {
            ">",
            function()
              require("quicker").expand({ before = 2, after = 2, add_to_existing = true })
            end,
            desc = "Expand quickfix context",
          },
          {
            "<",
            function()
              require("quicker").collapse()
            end,
            desc = "Collapse quickfix context",
          },
        },
      })
    end,
  },
  { -- folke/flash.nvim: Navigate tools --------------------------------- {{{3
    "folke/flash.nvim",
    keys = {
      { "s", false, mode = { "n", "x", "o" } },
      {
        "ss",
        mode = { "n", "x", "o" },
        function()
          require("flash").jump()
        end,
        desc = "Flash",
      },
      {
        "r",
        mode = "o",
        function()
          require("flash").remote()
        end,
        desc = "Remote Flash",
      },
      {
        "R",
        mode = { "o", "x" },
        function()
          require("flash").treesitter_search()
        end,
        desc = "Flash Treesitter Search",
      },
      {
        "<c-s>",
        mode = { "c" },
        function()
          require("flash").toggle()
        end,
        desc = "Toggle Flash Search",
      },
      {
        "st",
        mode = { "n", "x", "o" },
        function()
          require("flash").treesitter()
        end,
        desc = "Flash Treesitter",
      },
    },
    opts = {
      style = "overlay",
      modes = {
        char = {
          enabled = true,
          keys = { "f", "F", "t", "T", [";"] = "|", "," },
          multi_line = false,
          jump_labels = true,
        },
        search = {
          enabled = false,
        },
      },
      jump = {
        autojump = false,
      },
    },
    specs = {
      {
        "folke/snacks.nvim",
        opts = {
          picker = {
            win = {
              input = {
                keys = {
                  ["<a-s>"] = { "flash", mode = { "n", "i" } },
                  ["s"] = { "flash" },
                },
              },
            },
            actions = {
              flash = function(picker)
                require("flash").jump({
                  pattern = "^",
                  label = { after = { 0, 0 } },
                  search = {
                    mode = "search",
                    exclude = {
                      function(win)
                        return vim.bo[vim.api.nvim_win_get_buf(win)].filetype ~= "snacks_picker_list"
                      end,
                    },
                  },
                  action = function(match)
                    local idx = picker.list:row2idx(match.pos[1])
                    picker.list:_move(idx, true, true)
                  end,
                })
              end,
            },
          },
        },
      },
    },
  },
  { -- rainzm/flash-zh.nvim --------------------------------------------- {{{3
    "rainzm/flash-zh.nvim",
    event = "VeryLazy",
    keys = {
      {
        "sc",
        mode = { "n", "x", "o" },
        function()
          require("flash-zh").jump({
            chinese_only = true,
            labels = " ;,.123456789[]",
          })
        end,
        desc = "Flash between Chinese",
      },
    },
  },
  { -- easymotion/vim-easymotion: motion tools -------------------------- {{{3
    "easymotion/vim-easymotion",
    init = function()
      vim.g.EasyMotion_do_mapping = 0 -- Disable default mappings
      vim.g.EasyMotion_smartcase = 1
      vim.g.EasyMotion_use_migemo = 1
    end,
    keys = {
      {
        "<localleader>s",
        "<esc><Plug>(easymotion-sl)",
        mode = { "i" },
        desc = "EasyMotion: Find Char (current line)",
      },
      {
        "s.",
        "<Plug>(easymotion-repeat)",
        desc = "EasyMotion: Repeat last motion",
      },
      {
        "sl",
        "<Plug>(easymotion-sl)",
        mode = { "n", "v" },
        desc = "EasyMotion: Find Char (current line)",
      },
      { "sj", "<plug>(easymotion-j)", desc = "EasyMotion: Line Downward" },
      {
        "sJ",
        "<plug>(easymotion-eol-j)",
        desc = "EasyMotion: Line Downword (end)",
      },
      { "sk", "<plug>(easymotion-k)", desc = "EasyMotion: Line Forward" },
      {
        "sK",
        "<plug>(easymotion-eol-k)",
        desc = "EasyMotion: Line Forward (end)",
      },
      { "sn", "<Plug>(easymotion-n)", desc = "EasyMotion: latest search" },
      {
        "sN",
        "<Plug>(easymotion-N)",
        desc = "EasyMotion: latest search (backward)",
      },
      {
        "sw",
        "<Plug>(easymotion-w)",
        desc = "EasyMotion: Beginning of word",
      },
      {
        "sW",
        "<Plug>(easymotion-W)",
        desc = "EasyMotion: Beginning of WORD",
      },
      {
        "sb",
        "<Plug>(easymotion-b)",
        desc = "EasyMotion: EasyMotion: Beginning of word (backward)",
      },
      {
        "sB",
        "<Plug>(easymotion-B)",
        desc = "EasyMotion: EasyMotion: Beginning of WORD (backward)",
      },
      { "se", "<Plug>(easymotion-e)", desc = "EasyMotion: End of word" },
      { "sE", "<Plug>(easymotion-E)", desc = "EasyMotion: End of WROD" },
      {
        "sge",
        "<Plug>(easymotion-e)",
        desc = "EasyMotion: End of word (backward)",
      },
      {
        "sgE",
        "<Plug>(easymotion-E)",
        desc = "EasyMotion: End of WROD (backward)",
      },
    },
  },
  { -- kevinhwang91/nvim-ufo: ultra fold in Neovim ---------------------- {{{3
    "kevinhwang91/nvim-ufo",
    event = "BufReadPost", -- later or on keypress would prevent saving folds
    init = function()
      vim.o.foldcolumn = "0" -- '0' is not bad
      vim.o.foldlevel = 99 -- Using ufo provider need a large value, feel free to decrease the value
      vim.o.foldlevelstart = 99
      vim.o.foldenable = true
    end,
    dependencies = {
      "kevinhwang91/promise-async",
    },
    config = function()
      local ftMap = {
        python = { "indent" },
        stata = "",
        lua = { "treesitter", "indent" },
        norg = { "treesitter" },
        org = { "treesitter" },
        r = { "treesitter", "indent" },
        markdown = { "treesitter", "indent" },
        vim = nil,
        sagaoutline = "",
        git = nil,
      }
      local ufo = require("ufo")
      local handler = function(virtText, lnum, endLnum, width, truncate)
        local newVirtText = {}
        local suffix = (" ────────  %d "):format(endLnum - lnum)
        local sufWidth = vim.fn.strdisplaywidth(suffix)
        local targetWidth = width - sufWidth
        local curWidth = 0
        for _, chunk in ipairs(virtText) do
          local chunkText = chunk[1]
          local chunkWidth = vim.fn.strdisplaywidth(chunkText)
          if targetWidth > curWidth + chunkWidth then
            table.insert(newVirtText, chunk)
          else
            chunkText = truncate(chunkText, targetWidth - curWidth)
            local hlGroup = chunk[2]
            table.insert(newVirtText, { chunkText, hlGroup })
            chunkWidth = vim.fn.strdisplaywidth(chunkText)
            -- str width returned from truncate() may less than 2nd argument, need padding
            if curWidth + chunkWidth < targetWidth then
              suffix = suffix .. (" "):rep(targetWidth - curWidth - chunkWidth)
            end
            break
          end
          curWidth = curWidth + chunkWidth
        end
        table.insert(newVirtText, { suffix, "MoreMsg" })
        return newVirtText
      end

      ---@diagnostic disable: missing-fields, unused-local
      ufo.setup({
        open_fold_hl_timeout = 150,
        close_fold_kinds_for_ft = {
          default = { "imports", "comment" },
        },
        fold_virt_text_handler = handler,
        preview = {
          win_config = {
            border = { "", "─", "", "", "", "─", "", "" },
            winhighlight = "Normal:Folded",
            winblend = 0,
          },
          mappings = {
            scrollU = "<C-u>",
            scrollD = "<C-d>",
            jumpTop = "[",
            jumpBot = "]",
          },
        },
        provider_selector = function(bufnr, filetype, buftype)
          -- if you prefer treesitter provider rather than lsp,
          -- return ftMap[filetype] or {'treesitter', 'indent'}
          return ftMap[filetype] or { "treesitter", "indent" }

          -- refer to ./doc/example.lua for detail
        end,
      })

      vim.keymap.set("n", "zR", require("ufo").openAllFolds)
      vim.keymap.set("n", "zM", require("ufo").closeAllFolds)
      vim.keymap.set("n", "zr", require("ufo").openFoldsExceptKinds)
      vim.keymap.set("n", "zm", require("ufo").closeFoldsWith) -- closeAllFolds == closeFoldsWith(0)
    end,
  },
  { -- chrisgrieser/nvim-origami: Fold with relentless elegance --------- {{{2
    "chrisgrieser/nvim-origami",
    event = "BufReadPost",
    opts = {
      keepFoldsAcrossSessions = package.loaded["ufo"] ~= nil,
      pauseFoldsOnSearch = true,
      FoldKeymaps = {
        setup = true,
        hOnlyOpensOnFirstColumn = true,
      },
    },
  },
  { -- chrisgrieser/nvim-early-retirement ------------------------------- {{{2
    "chrisgrieser/nvim-early-retirement",
    config = true,
    event = "VeryLazy",
  },
  { -- kylechui/nvim-surround: Surround selections, stylishly ----------- {{{3
    "kylechui/nvim-surround",
    version = "*",
    event = "VeryLazy",
    ft = { "markdown", "stata" },
    keys = { "ys", "ds", "cs" },
    config = function()
      local surround = require("nvim-surround")
      local config = require("nvim-surround.config")
      local gen_surround = function(left, right)
        if not left or not right then
          return
        end
        return {
          add = { left, right },
          find = function()
            return config.get_selection({ pattern = vim.pesc(left) .. ".-" .. vim.pesc(right) })
          end,
          delete = "^(" .. vim.pesc(left) .. " ?)().-( ?" .. vim.pesc(right) .. ")()$",
        }
      end

      local global_opts = {
        keymaps = {
          insert = ";s",
          insert_line = ";S",
        },
      }

      local filetype_opts = {
        markdown = {
          surrounds = {
            ["w"] = gen_surround("[[", "]]"),
            ["h"] = gen_surround("==", "=="),
          },
        },
        stata = {
          surrounds = {
            ["'"] = gen_surround([[`"]], [["']]),
          },
        },
      }

      surround.setup(global_opts)
      local group_surround = vim.api.nvim_create_augroup("Surround_buffer", { clear = true })
      for type, opt in pairs(filetype_opts) do
        vim.api.nvim_create_autocmd({ "FileType" }, {
          group = group_surround,
          pattern = { type },
          callback = function()
            surround.buffer_setup(opt)
          end,
        })
      end
    end,
  },
  { -- tpope/vim-repeat: repeat operation ------------------------------- {{{3
    "tpope/vim-repeat",
    keys = {
      { ".", mode = { "n", "v", "x" } },
    },
  },
  { -- tpope/vim-rsi: Readline style insertion -------------------------- {{{3
    "tpope/vim-rsi",
    init = function()
      vim.g.rsi_no_meta = 1
    end,
  },
  { -- liubianshi/icon-picker.nvim -------------------------------------- {{{3
    "liubianshi/icon-picker.nvim",
    enabled = true,
    dev = true,
    cmd = { "IconPickerNormal", "IconPickerYank" },
    keys = {
      {
        "<localleader>i",
        "<cmd>IconPickerInsert history nerd_font_v3 alt_font symbols emoji<cr>",
        desc = " Pick Icon and insert it to the buffer",
        mode = "i",
        silent = true,
        noremap = true,
      },
      {
        "<leader>si",
        "<cmd>IconPickerYank history nerd_font_v3 alt_font symbols emoji<cr>",
        desc = "Pick Icon and yank it to register",
        mode = "n",
        silent = true,
        noremap = true,
      },
    },
    config = function()
      require("icon-picker").setup({ history_path = vim.env.HOME .. "/.config/diySync/uni_history" })
    end,
  },
  { -- gbprod/yanky.nvim: Improved Yank and Put functionalities --------- {{{3
    "gbprod/yanky.nvim",
    dependencies = {
      "folke/snacks.nvim",
    },
    keys = {
      {
        "<leader>sy",
        function()
          Snacks.picker.yanky()
        end,
        desc = "Open Yank History",
      },
    },
    opts = {
      highlight = { timer = 1000 },
      ring = {
        storage = jit.os:find("Windows") and "shada" or "sqlite",
        ignore_registers = { "_" },
      },
      textobj = { enabled = true },
    },
  },
  { -- dhruvasagar/vim-table-mode: Table Mode for instant table creation  {{{3
    "dhruvasagar/vim-table-mode",
    ft = { "markdown", "pandoc", "rmd", "org" },
    init = function()
      vim.g.table_mode_map_prefix = "<localleader>t"
      vim.g.table_mode_corner = "|"
    end,
    config = function()
      vim.api.nvim_exec2(
        [[
        function! s:isAtStartOfLine(mapping)
          let text_before_cursor = getline('.')[0 : col('.')-1]
          let mapping_pattern = '\V' . escape(a:mapping, '\')
          let comment_pattern = '\V' . escape(substitute(&l:commentstring, '%s.*$', '', ''), '\')
          return (text_before_cursor =~? '^' . ('\v(' . comment_pattern . '\v)?') . '\s*\v' . mapping_pattern . '\v$')
        endfunction
        inoreabbrev <expr> <bar><bar>
          \ <SID>isAtStartOfLine('\|\|') ?
          \ '<c-o>:TableModeEnable<cr><bar><space><bar><left><left>' : '<bar><bar>'
        inoreabbrev <expr> __
          \ <SID>isAtStartOfLine('__') ?
          \ '<c-o>:silent! TableModeDisable<cr>' : '__'
        ]],
        { output = false }
      )
      require("util").wk_reg({
        { "<localleader>t", group = "Table Mode .." },
      })
    end,
  },
  { -- mg979/vim-visual-multi ------------------------------------------- {{{3
    "mg979/vim-visual-multi",
    init = function()
      vim.g.VM_leader = "\\"

      local has_nvim_hlslens, hlslens = pcall(require, "hlslens")
      if not has_nvim_hlslens then
        return
      end
      local overrideLens = function(render, posList, nearest, idx, relIdx)
        local _ = relIdx
        local lnum, col = unpack(posList[idx])

        local text, chunks
        if nearest then
          text = ("[%d/%d]"):format(idx, #posList)
          chunks = { { " ", "Ignore" }, { text, "VM_Extend" } }
        else
          text = ("[%d]"):format(idx)
          chunks = { { " ", "Ignore" }, { text, "HlSearchLens" } }
        end
        render.setVirt(0, lnum - 1, col - 1, chunks, nearest)
      end
      local lensBak
      local config = require("hlslens.config")
      local gid = vim.api.nvim_create_augroup("VMlens", {})
      vim.api.nvim_create_autocmd("User", {
        pattern = { "visual_multi_start", "visual_multi_exit" },
        group = gid,
        callback = function(ev)
          if ev.match == "visual_multi_start" then
            lensBak = config.override_lens
            config.override_lens = overrideLens
          else
            config.override_lens = lensBak
          end
          hlslens.start()
        end,
      })
    end,
    branch = "master",
    keys = {
      {
        "<C-n>",
        desc = "Find Word",
        mode = { "n", "v", "x" },
      },
      { "<A-j>", "<Plug>(VM-Add-Cursor-Down)", desc = "Add Cursors Down" },
      { "<A-k>", "<Plug>(VM-Add-Cursor-Up)", desc = "Add Cursors Up" },
    },
    config = true,
  },
  { -- andymass/vim-matchup: 显示匹配符号之间的内容 --------------------- {{{3
    "andymass/vim-matchup",
    config = function()
      vim.api.nvim_exec2(
        [[
          function! s:matchup_convenience_maps()
            xnoremap <sid>(std-I) I
            xnoremap <sid>(std-A) A
            xmap <expr> I mode()=='<c-v>'?'<sid>(std-I)':(v:count?'':'1').'i'
            xmap <expr> A mode()=='<c-v>'?'<sid>(std-A)':(v:count?'':'1').'a'
            for l:v in ['', 'v', 'V', '<c-v>']
              execute 'omap <expr>' l:v.'I%' "(v:count?'':'1').'".l:v."i%'"
              execute 'omap <expr>' l:v.'A%' "(v:count?'':'1').'".l:v."a%'"
            endfor
          endfunction
          call s:matchup_convenience_maps()
        ]],
        { output = false }
      )
    end,
  },
  { -- Wraps long lines virtually at a specific column ------------------ {{{3
    "rickhowe/wrapwidth",
    init = function()
      vim.g.wrapwidth_sign = "↵"
      vim.g.wrapwidth_number = 0
    end,
    config = function()
      vim.cmd("Wrapwidth 80")
    end,
  },
  { -- Efficient targetted menu built for fast buffer navigation {{{3 --- {{{2
    "leath-dub/snipe.nvim",
    keys = {
      {
        "gb",
        function()
          require("snipe").open_buffer_menu()
        end,
        desc = "Open Snipe buffer menu",
      },
    },
    opts = {},
  },
  { -- simulates wrapping a single line at a time ----------------------- {{{3
    "benlubas/wrapping-paper.nvim",
    keys = {
      {
        "gww",
        function()
          require("wrapping-paper").wrap_line()
        end,
        desc = "fake wrap current line",
      },
    },
    config = true,
  },
  { -- monaqa/dial.nvim ------------------------------------------------- {{{3
    "monaqa/dial.nvim",
    opts = function(_, opts)
      local augend = require("dial.augend")
      opts.dials_by_ft.r = "r"
      opts.groups.r = {
        augend.constant.new({
          elements = {
            "TRUE",
            "FALSE",
          },
          word = true,
          cyclic = true,
        }),
      }
      return opts
    end,
  },
}
