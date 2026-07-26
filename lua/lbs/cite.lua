-- 文献引用：对 bibkey 弹出动作菜单。
local M = {}

local get_item_info = function(b, field, command)
  field = field or "note"
  local valid_items = { "note", "pdf", "bib", "newsboat", "html", "md", "path", "title", "url" }
  local item_path
  if field == "note" then
    item_path = vim.fn.trim(vim.fn.system("mylib note @" .. b))
  elseif vim.tbl_contains(valid_items, field) then
    item_path = vim.fn.trim(vim.fn.system("mylib get " .. field .. " -- @" .. b))
  end
  if command then
    if vim.fn.filewritable(item_path) == 0 then
      return
    end
    vim.cmd(command .. " " .. vim.fn.fnameescape(item_path))
  else
    return item_path
  end
end

function M.bibkey_action(bibkey)
  if not bibkey then
    return
  end
  bibkey = "@" .. bibkey
  local bibkey_action = function(key)
    local command = {
      ["e"] = function()
        get_item_info(bibkey, "note", "edit ")
      end,
      ["v"] = function()
        get_item_info(bibkey, "note", "vsplit ")
      end,
      ["t"] = function()
        get_item_info(bibkey, "note", "tabnew ")
      end,
      ["s"] = function()
        get_item_info(bibkey, "note", "split ")
      end,
      ["o"] = function()
        get_item_info(bibkey, "path", "Lf ")
      end,
      ["n"] = function()
        get_item_info(bibkey, "newsboat", "edit ")
      end,
      ["p"] = function()
        local pdf_file = get_item_info(bibkey, "pdf")
        if not pdf_file or vim.fn.filereadable(pdf_file) == 0 then
          return
        end
        vim.ui.open(pdf_file)
      end,
      ["u"] = function()
        local url = get_item_info(bibkey, "url")
        if not url then
          return
        end
        vim.ui.open(url)
      end,
    }
    return command[key]
  end
  local items = {
    { key = "e", text = "edit note" },
    { key = "n", text = "newsboat" },
    { key = "o", text = "open dir" },
    { key = "p", text = "open pdf file" },
    { key = "s", text = "split note" },
    { key = "t", text = "tabnew note" },
    { key = "u", text = "open url" },
    { key = "v", text = "vsplit note" },
    { key = "", text = "---------------" },
    { key = "q", text = "Quit" },
  }
  local select = require("lbs.ui.popup").select
  select(items, { title = "Choose an action:", callback = bibkey_action })
end

return M
