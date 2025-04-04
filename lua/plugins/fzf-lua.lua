-- vim.env.FZF_DEFAULT_OPTS = vim.env.FZF_DEFAULT_OPTS .. " --color=gutter:-1"
-- if vim.o.background == "light" then
--   vim.env.FZF_DEFAULT_OPTS = "--select-1 --exit-0"
-- end
vim.env.FZF_DEFAULT_OPTS = "--ansi --bind ctrl-l:jump --select-1 --exit-0"
local my_border = require("util").border("═", "top")

-- integration with project.nvim ---------------------------------------- {{{2
local _previous_cwd
local function list_projects(opts)
  if not opts then
    opts = {}
  end
  local project_hist = vim.fn.stdpath("data") .. "/project_nvim/project_history"
  if not vim.uv.fs_stat(project_hist) then
    return
  end

  local project_dirs = vim.fn.readfile(project_hist)
  local iconify = function(path, color, icon)
    local ansi_codes = require("fzf-lua.utils").ansi_codes
    icon = ansi_codes[color](icon)
    path = require("fzf-lua.path").relative_to(path, vim.fn.expand("$HOME"))
    return ("%s  %s"):format(icon, path)
  end

  local dedup = {}
  local entries = {}
  local add_entry = function(path, color, icon)
    if not path then
      return
    end
    path = vim.fn.expand(path)
    if dedup[path] ~= nil then
      return
    end
    entries[#entries + 1] = iconify(path, color or "blue", icon or "")
    dedup[path] = true
  end

  coroutine.wrap(function()
    add_entry(vim.loop.cwd(), "magenta", "")
    add_entry(_previous_cwd, "yellow")
    for _, path in ipairs(project_dirs) do
      add_entry(path)
    end
    local fzf_fn = function(cb)
      for _, entry in ipairs(entries) do
        cb(entry, function(err)
          if err then
            return
          end
          cb(nil, function() end)
        end)
      end
    end
    opts.fzf_opts = {
      ["--ansi"] = "",
      ["--no-multi"] = "",
      ["--prompt"] = "Projects❯ ",
      ["--header-lines"] = "1",
      ["--preview"] = "eza" .. " --color always -T -L 2 -lh $HOME/{2..}",
    }

    local get_cwd = function(selected)
      if not selected then
        return
      end
      _previous_cwd = vim.loop.cwd()
      local newcwd = selected[1]:match("[A-Za-z0-9_.].*$")
      newcwd = require("fzf-lua.path").is_absolute(newcwd) and newcwd
        or require("fzf-lua.path").join({ vim.fn.expand("$HOME"), newcwd })
      return newcwd
    end

    opts.actions = {
      ["default"] = function(selected, _)
        local wd = get_cwd(selected)
        vim.cmd("cd " .. wd)
        require("fzf-lua").files({ cwd = wd })
      end,
    }
    require("fzf-lua").fzf_exec(fzf_fn, opts)
  end)()
end
vim.api.nvim_create_user_command("ProjectChange", list_projects, {
  nargs = 0,
  desc = "Change Project",
})

-- 插入参考文献的引用 --------------------------------------------------- {{{2
local function insert_citation()
  local normal_mode = vim.fn.mode():find("^n")
  local cursor = vim.api.nvim_win_get_cursor(0)
  local line = vim.api.nvim_buf_get_lines(0, cursor[1] - 1, cursor[1], true)[1]
  local char_before_cursor = line:sub(cursor[2] + 1, cursor[2] + 1)
  local char_after_cursor = line:sub(cursor[2] + 2, cursor[2] + 2)
  local prefix = (cursor[2] ~= 0 and char_before_cursor ~= " ") and " " or ""
  local suffix = char_after_cursor ~= " " and " " or ""

  require("fzf-lua").fzf_exec("bibtex-ls ~/Documents/url_ref.bib", {
    preview = "pistol \"$(mylib get bibtex -- '{-1}')\"",
    fzf_opts = { ["--multi"] = "" },
    actions = {
      ["default"] = function(selected, _)
        local obj = vim
          .system({ "bibtex-cite", "-prefix=@", "-postfix=", "-separator=; @" }, { text = true, stdin = selected })
          :wait(50)
        local r = obj.stdout
        vim.api.nvim_win_set_cursor(0, cursor)
        vim.api.nvim_put({ prefix .. r .. suffix }, "c", (normal_mode and cursor[2] ~= 0) or at_end_of_line(), true)
      end,
      ["ctrl-x"] = function(selected, _)
        local obj = vim
          .system({ "bibtex-cite", "-prefix=@", "-postfix=", "-separator=; @" }, { text = true, stdin = selected })
          :wait(50)
        local r = obj.stdout
        vim.api.nvim_win_set_cursor(0, cursor)
        vim.api.nvim_put(
          { prefix .. "[" .. r .. "]" .. suffix },
          "c",
          (normal_mode and cursor[2] ~= 0) or at_end_of_line(),
          true
        )
      end,
    },
  })
end

-- 列出所有 buffers ----------------------------------------------------- {{{2
local function list_all_buffers()
  require("fzf-lua").fzf_exec(function(fzf_cb)
    coroutine.wrap(function()
      local buffers = {}
      for _, b in ipairs(vim.api.nvim_list_bufs()) do
        local name = vim.api.nvim_buf_get_name(b)
        -- if name == "" then name = "[No Name]" end
        if not (name == "" or string.find(name, "Wilder Float") or string.find(name, "/sbin/sh")) then
          buffers[b] = name
        end
      end
      local co = coroutine.running()
      for b, name in pairs(buffers) do
        vim.schedule(function()
          fzf_cb(b .. "\t" .. name, function()
            coroutine.resume(co)
          end)
        end)
        coroutine.yield()
      end
      fzf_cb()
    end)()
  end, {
    fzf_opts = { ["+m"] = "", ["--preview-window"] = "hidden" },
    actions = {
      ["default"] = function(selected, _)
        local bufno = string.gsub(selected[1], "\t.*", "")
        vim.cmd("buffer " .. bufno)
      end,
    },
  })
end

-- 通过 fasd 跳转文件 --------------------------------------------------- {{{2
local function jump_with_fasd()
  local actions = require("fzf-lua.actions")
  require("fzf-lua").fzf_exec("fasd -al", {
    preview = "pistol {1..}",
    actions = {
      ["default"] = actions.file_edit,
      ["ctrl-s"] = actions.file_split,
      ["ctrl-v"] = actions.file_vsplit,
      ["ctrl-t"] = actions.file_tabedit,
      ["alt-q"] = actions.file_sel_to_qf,
    },
  })
end

-- 定义查询 stata 帮助文件的命令 ---------------------------------------- {{{2
local function Shelp_Action(vimcmd)
  return function(selected, _)
    local path = string.gsub(selected[1], "^.*\t", "")
    local command = string.gsub(selected[1], " *\t+.*$", "")
    local r = vim.fn.system(",sh -v -r " .. path)
    vim.cmd(vimcmd .. " " .. r)
    vim.cmd('file `="[' .. command .. ']"`')
    vim.cmd([[
                    setlocal bufhidden=delete
                    setlocal buftype=nofile
                    setlocal noswapfile
                    setlocal nobuflisted
                    setlocal nomodifiable
                    setlocal nocursorline
                    setlocal nocursorcolumn
                ]])
  end
end

-- asynctasks ----------------------------------------------------------- {{{2
-- From:
-- https://github.com/skywind3000/asynctasks.vim/wiki/UI-Integration
local function run_async_tasks()
  local rows = vim.fn["asynctasks#source"](math.floor(vim.go.columns * 48 / 100))
  if #rows == 0 then
    local LOG_LEVEL_WARN = 3
    vim.notify("No task attated to the buffer", LOG_LEVEL_WARN, { title = "AsyncTasks" })
    return
  end
  require("fzf-lua").fzf_exec(function(cb)
    for _, e in ipairs(rows) do
      local color = require("fzf-lua").utils.ansi_codes
      local line = color.green(e[1]) .. " " .. color.cyan(e[2]) .. ": " .. color.yellow(e[3])
      if #rows == 1 then
        line = line .. "\n"
      end
      cb(line)
    end
    cb()
  end, {
    actions = {
      ["default"] = function(selected, _)
        local str = require("fzf-lua").utils.strsplit(selected[1], " ")
        local command = "AsyncTask " .. vim.fn.fnameescape(str[1])
        vim.api.nvim_exec2(command, { output = false })
      end,
    },
    fzf_opts = {
      ["--no-multi"] = "",
      ["--preview-window"] = "hidden",
      ["--nth"] = "1",
    },
    winopts = {
      row = 0.9,
      height = #rows + 1,
      width = 0.6,
    },
  })
end

-- vim command fuzzy search --------------------------------------------- {{{2
local function run_command()
  require("fzf-lua").commands({
    winopts = {
      -- split            = "belowright 10new",
      height = 0.4,
      width = 1,
      row = 1,
      col = 0.5,
      preview = {
        horizontal = "right:40%",
        layout = "horizontal",
      },
    },
    fzf_opts = {
      ["--no-multi"] = "",
      ["--layout"] = "default",
    },
    actions = {
      ["default"] = function(selected, _)
        local command = selected[1]
        vim.cmd("stopinsert")
        local nargs = vim.api.nvim_get_commands({})[command].nargs
        if nargs:match("[0*?]") then
          vim.cmd(command)
        else
          vim.fn.feedkeys(string.format(":%s", command), "n")
        end
      end,
    },
  })
end

-- Find Roam Node ------------------------------------------------------- {{{2
local function insert_new_node()
  local last_query = require("fzf-lua").config.__resume_data.last_query
  vim.cmd([[normal l]])
  vim.fn["utils#RoamInsertNode"](last_query, "split")
  vim.cmd([[wincmd J]])
  vim.cmd([[res 8]])
end

local function fzf_selection_action(cmd)
  cmd = cmd or "cite"
  if cmd == "cite" then
    return function(selected, _)
      if not selected[1] then
        return insert_new_node()
      end
      if not vim.fn["utils#IsPrintable_CharUnderCursor"]() then
        vim.cmd("normal! a ")
      end
      local buf = vim.fn.bufnr()
      local row_col = vim.api.nvim_win_get_cursor(0)
      local row = row_col[1] - 1
      local col = row_col[2] + 1
      local cite = vim.fn.system("roam_id_title --cite  -n '" .. selected[1] .. "'")
      vim.api.nvim_buf_set_text(buf, row, col, row, col, { cite })
      vim.cmd("normal! 3f]")
    end
  else
    return function(selected, _)
      local file =
        vim.fn.system("roam_id_title  -n '" .. selected[1] .. "'  | cut -f1 | xargs -I {} roam_id_title -i {}")
      vim.cmd(cmd .. " " .. file)
    end
  end
end

-- cheat ---------------------------------------------------------------- {{{2
local function Cheat_Action(vimcmd)
  return function(selected, opts)
    local item = next(selected) and selected[1] or opts.last_query:gsub("^'", "")
    if not item then
      return
    end
    local dir = vim.env.HOME .. "/.config/cheat/cheatsheets/personal/"
    local target_file = vim.fn.system("help -p '" .. item .. "' 2>/dev/null")
    if string.match(target_file, "\n") then
      return
    end

    if vimcmd == "rename" then
      local newname = vim.fn.input("Enter newname: ")
      vim.fn.system("help -r " .. newname .. " " .. item)
    elseif vimcmd == "Glow" then
      local tmp = vim.fn.tempname() .. ".md"
      vim.fn.system("ln -sf " .. vim.fn.fnameescape(target_file) .. " " .. tmp)
      vim.cmd("Glow " .. tmp)
    else
      vim.cmd(vimcmd .. " " .. vim.fn.fnameescape(target_file))
      vim.cmd("cd " .. dir)
    end
  end
end

-- mylib ---------------------------------------------------------------- {{{2
local function handle_mylib_selected(selected, method)
  method = method or "edit"
  local key = vim.split(selected[1], [[%s+]])[1]
  local re = vim.system({ "mylib", "get", "file_for_open", "--", key }, { text = true }):wait()
  local file = string.gsub(re.stdout, "\n", "")
  if vim.tbl_contains({ "newsboat", "md", "bibtex", "bib" }, vim.fn.fnamemodify(file, ":e")) then
    vim.cmd[method](file)
    vim.api.nvim_buf_set_var(0, "mylib_key", key)
  else
    vim.ui.open(file)
  end
end

local function list_mylib_items()
  require("fzf-lua").fzf_exec("mylib list", {
    actions = {
      ["default"] = function(selected, _)
        handle_mylib_selected(selected, "edit")
      end,
      ["ctrl-v"] = function(selected, _)
        handle_mylib_selected(selected, "vsplit")
      end,
      ["ctrl-x"] = function(selected, _)
        handle_mylib_selected(selected, "split")
      end,
      ["ctrl-t"] = function(selected, _)
        handle_mylib_selected(selected, "tabedit")
      end,
    },
    preview = [[mylib get file_for_preview -- {1} | tr '\n' '\0' | xargs -0 -I _ scope '_']],
  })
end

-- config fzf-lua ------------------------------------------------------- {{{2
return {
  "ibhagwan/fzf-lua",
  enabled = false,
  branch = "main",
  cmd = {
    "FzfLua",
    "Shelp",
    "Urlopen",
    "RoamNodeFind",
    "Cheat",
    "ProjectChange",
  },
  keys = {
    { "<leader>pp", list_projects, desc = "Select Project" },
    -- { "<leader>fq", list_mylib_items, desc = "Open my library file" },
    -- { "<leader>ic", insert_citation, desc = "Insert Citation Keys" },
    -- { "<localleader>c", insert_citation, desc = "Insert Citation Keys", mode = "i" },
    -- { "<leader>fz", jump_with_fasd, desc = "Jump with fasd" },
    -- { "<leader>bB", list_all_buffers, desc = "List All Buffers" },
    -- { "<leader>ot", run_async_tasks, desc = "Run async tasks" },
    -- { "<A-x>", run_command, desc = "Run commands" },
    -- { "<leader>:", "<cmd>FzfLua command_history<cr>", desc = "FzfLua: Command History" },
    -- { "<leader>hc", "<cmd>Cheat<cr>", desc = "FzfLua: Cheatsheet" },
    -- { "<leader>bb", "<cmd>FzfLua buffers<cr>", desc = "FzfLua: Select buffer" },
    -- { "<leader>ou", "<cmd>Urlopen<cr>", desc = "FzfLua: Open urls" },
    -- { "<leader>st", "<cmd>FzfLua tags<cr>", desc = "FzfLua: tags" },
    -- { "<leader>sk", "<cmd>FzfLua keymaps<cr>", desc = "FzfLua: keymaps table" },
    -- { "<leader>sT", "<cmd>FzfLua btags<cr>", desc = "FzfLua: buffer tags" },
    -- { "<leader>qs", "<cmd>FzfLua quickfix<cr>", desc = "FzfLua: quickfix" },
    -- { "<leader>sC", "<cmd>FzfLua colorschemes<cr>", desc = "FzfLua: colorschemes" },
    -- { "<leader>sR", "<cmd>FzfLua grep_project<cr>", desc = "FzfLua: Grep project" },
    -- { "<leader>pr", "<cmd>FzfLua grep_project<cr>", desc = "FzfLua: Grep project" },
    -- { "<c-b>", "<cmd>FzfLua grep_cword<cr>", desc = "FzfLua: Grep cword", mode = { "n", "x" } },
  },
  config = function(_, _)
    local opts = {
      hls = {
        normal = "Normal",
      },
      fzf_colors = true,
      winopts = {
        border = my_border,
        preview = {
          scrollchars = { "│", "" },
          winopts = {
            border = my_border,
          },
        },
      },
      previewers = {
        builtin = {
          extensions = {
            -- neovim terminal only supports `viu` block output
            ["png"] = { "ueberzug" },
            ["jpg"] = { "ueberzug" },
            ["xlsx"] = { "scope" },
            ["xls"] = { "scope" },
            ["csv"] = { "scope" },
            ["dta"] = { "scope" },
            ["Rds"] = { "scope" },
            ["pdf"] = { "scope" },
          },
        },
        man = {
          cmd = "echo %s | tr -d '()'  | xargs -r man | col -bx",
        },
      },
      files = {
        previewer = "builtin",
        prompt = "Files❯ ",
        file_icons = true,
        fzf_opts = {
          ["--preview"] = vim.fn.shellescape("printf {1} | perl -plE 's!\\A[^\\s\\/A-z]+\\s!!' | xargs scope"),
        },
      },
      grep = {
        winopts = {
          -- split = "belowright new",
          height = 0.4,
          width = 1,
          row = 1,
          col = 0,
          preview = {
            horizontal = "right:40%",
            layout = "horizontal",
          },
        },
      },
    }
    vim.api.nvim_create_user_command("Shelp", function(opt)
      require("fzf-lua").fzf_exec(",sh -l " .. opt.args, {
        preview = "scope {2..}",
        fzf_opts = {
          ["--no-multi"] = "",
        },
        actions = {
          ["default"] = Shelp_Action("edit"),
          ["ctrl-v"] = Shelp_Action("vsplit"),
          ["ctrl-s"] = Shelp_Action("split"),
          ["ctrl-t"] = Shelp_Action("tabedit"),
        },
      })
    end, { nargs = "*" })

    -- Open urls ------------------------------------------------------------ {{{2
    vim.api.nvim_create_user_command("Urlopen", function(opt)
      require("fzf-lua").fzf_exec(vim.fn["utils#Fetch_urls"](opt.args), {
        preview = nil,
        actions = {
          ["default"] = function(selected, _)
            local command = "linkhandler '" .. selected[1] .. "'"
            vim.cmd([[Lazy! load asyncrun.vim]])
            vim.fn["asyncrun#run"]("", { silent = 1, pos = "hide" }, command)
          end,
        },
      })
    end, { nargs = 0, desc = "FzfLua: Open urls" })

    vim.api.nvim_create_user_command("RoamNodeFind", function(_)
      require("fzf-lua").fzf_exec("roam_id_title", {
        preview = 'cd "' .. vim.env.home .. '/documents/writing/roam/"; scope {-1}',
        fzf_opts = { ["--no-multi"] = "" },
        actions = {
          ["default"] = fzf_selection_action("edit"),
          ["ctrl-l"] = function(_, _)
            insert_new_node()
          end,
          ["ctrl-e"] = fzf_selection_action("cite"),
        },
      })
    end, { nargs = 0, desc = "fzflua: find org roam node" })

    vim.api.nvim_create_user_command("Cheat", function(_)
      local command = vim.env.HOME .. "/useScript/bin/help"
      require("fzf-lua").fzf_exec(command .. " -l", {
        preview = command .. " {}",
        fzf_opts = {
          ["--no-multi"] = "",
        },
        actions = {
          ["default"] = Cheat_Action("Glow"),
          ["ctrl-e"] = Cheat_Action("edit"),
          ["ctrl-v"] = Cheat_Action("vsplit"),
          ["ctrl-x"] = Cheat_Action("split"),
          ["ctrl-t"] = Cheat_Action("tabedit"),
          ["ctrl-r"] = Cheat_Action("rename"),
        },
      })
    end, { nargs = "*", desc = "FzfLua: Cheat" })

    require("fzf-lua").setup(opts)
  end,
}
