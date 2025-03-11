local M = {}
local Picker = require("snacks.picker")
local pick = Picker.pick

local function get_folders(path)
  local folders = {}
  local entries = vim.fn.readdir(path)

  for _, entry in ipairs(entries) do
    local full_path = path .. "/" .. entry
    if vim.fn.isdirectory(full_path) == 1 then
      table.insert(folders, entry)
    end
  end

  return folders
end

M.fabric = function(opts)
  local pattern_dir = os.getenv("HOME") .. "/.config/fabric/patterns"
  local patterns = {}
  local pattern_names = get_folders(pattern_dir)

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
      ret[#ret + 1] = { item.text, "SnacksPickerLabel" }
      ret[#ret + 1] = { " ", virtual = true }
      local desc = pattern_desc[item.text] or pattern_desc[item.text:gsub("analyze", "analyse")] or ""
      ret[#ret + 1] = { desc, virtual = true }
      ret[#ret + 1] = { " ", virtual = true }
      return ret
    end,
    preview = "file",
    confirm = function(picker, item)
      picker:close()
      local cmd = { "fabric", "--pattern", item.text, "--stream" }
      if item.text == "translate" then
        table.insert(cmd, "-v=lang_code:zh_cn")
      end

      require("util").pipe(cmd, opts)
    end,
  })
end

return M
