local pick = require("snacks.picker").pick
local util = require("lbs.picker.util")

return function(opts)
  local mode = vim.api.nvim_get_mode().mode
  local filetype = vim.bo.filetype
  local pattern_dir = os.getenv("HOME") .. "/.config/fabric/patterns"
  local patterns = {}
  local pattern_names = util.get_folders(pattern_dir)

  local pattern_desc_file = pattern_dir .. "/pattern_explanations.md"
  local file_fh = io.open(pattern_desc_file, "r")
  if not file_fh then
    return nil, "Failed to open file"
  end
  local pattern_desc = {}
  for line in file_fh:lines() do
    if line:match("^%d+") then
      local key = line:match("^%d+%.%s+%*%*([^%*]+)%*%*")
      local value = line:match(":%s*(.+)$")
      if key and value then
        pattern_desc[key] = value
      end
    end
  end
  file_fh:close()

  for _, pattern in ipairs(pattern_names) do
    table.insert(patterns, { text = pattern, cwd = pattern_dir, file = pattern .. "/system.md" })
  end

  pick({
    items = patterns,
    format = function(item, _)
      local ret = {}
      ret[#ret + 1] = { item.text, "SnacksPickerDirectory" }
      ret[#ret + 1] = { ": ", virtual = true }
      local desc = pattern_desc[item.text] or pattern_desc[item.text:gsub("analyze", "analyse")] or ""
      ret[#ret + 1] = { desc, "SnacksPickerDesc" }
      ret[#ret + 1] = { " ", virtual = true }
      return ret
    end,
    preview = "file",
    actions = {
      confirm = function(picker, item)
        picker:close()
        opts = opts or {}
        if mode == "v" or mode == "V" or mode == "\22" then
          opts.stdin = require("util.term").get_pipe_stdin({ mode = mode })
        end

        local cmd = { "fabric", "--pattern", item.text, "--stream" }
        local ok, progress = pcall(require, "fidget.progress")
        local progress_handle
        if ok then
          progress_handle = progress.handle.create({
            title = " Requesting Fabric (" .. item.text .. ")",
            message = "In progress...",
            lsp_client = {
              name = "Fabric",
            },
          })
          opts.handle = {
            name = "fidget",
            handle = progress_handle,
            on_exit = function(handle, status)
              if status == "success" then
                handle.message = "Completed"
              elseif status == "error" then
                handle.message = " Error"
              else
                handle.message = "󰜺 Cancelled"
              end
              handle:finish()
            end,
          }
        end

        if item.text == "translate" then
          local translate_model = vim.tbl_contains({ "quarto" }, filetype) and "-m=gpt-4.1"
            or "-m=gemini-2.5-flash-preview-05-20"
          table.insert(cmd, translate_model)
        end

        if item.text == "translate" and not opts.stdin then
          table.insert(cmd, "-v=lang_code:zh_CN")
          require("util.term").pipe(cmd, opts)
        elseif item.text == "translate" then
          opts.stdin = require("lbs.buf").join_strings_by_paragraph(opts.stdin)
          local head_chars = vim.trim(opts.stdin[1]):sub(1, 20)
          local is_cjk = false
          for _, char in ipairs(vim.fn.split(head_chars, "\\zs")) do
            if is_cjk_character(char) then
              is_cjk = true
              break
            end
          end
          if is_cjk then
            table.insert(cmd, "-v=lang_code:en_US")
          else
            table.insert(cmd, "-v=lang_code:zh_CN")
          end
        end
        require("util.term").pipe(cmd, opts)
      end,
    },
  })
end
