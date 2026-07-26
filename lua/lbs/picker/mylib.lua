local pick = require("snacks.picker").pick
local util = require("lbs.picker.util")

return function()
  local function update(key)
    return function(picker, item)
      local default = item[key]
      if key == "author" then
        default = item["author_full"]
      end
      require("snacks.input").input({
        prompt = "Update " .. key .. ": ",
        default = default,
      }, function(value)
        if key == "tag" then
          value = "-r " .. value
        end
        vim.system({ "mylib", "update", "--" .. key, value, item["md5_short"] }, { text = true }, function(obj)
          if obj.code == 0 then
            picker:find({ refresh = true })
            vim.notify(key .. " updated", vim.log.levels.INFO)
          else
            vim.notify("Failed to update " .. key .. ": " .. obj.code, vim.log.levels.ERROR)
          end
        end)
      end)
    end
  end
  local function yank(key)
    return function(picker)
      local items = picker:selected({ fallback = true })
      picker:close()
      local re
      if key == "key" then
        re = table.concat(
          vim.tbl_map(function(item)
            return "@" .. item.key
          end, items),
          "; "
        )
      else
        re = table.concat(
          vim.tbl_map(function(item)
            return item[key]
          end, items),
          " "
        )
      end
      vim.fn.setreg("+", re)
    end
  end

  pick({
    finder = function(_, ctx)
      return require("snacks.picker.source.proc").proc(
        ctx:opts({
          cmd = "mylib",
          args = { "list", "--json" },
        }),
        ctx
      )
    end,
    transform = function(item)
      -- The proc finder yields raw JSON lines, but on refresh/re-entry snacks can
      -- pass already-transformed items back through here. By then item.text holds
      -- the formatted search string (not JSON), so keep the transform idempotent:
      -- only decode genuine JSON lines, which always start with "{".
      if type(item.text) ~= "string" or item.text:sub(1, 1) ~= "{" then
        return
      end
      local ok, fields = pcall(vim.json.decode, item.text)
      if not ok or type(fields) ~= "table" then
        vim.notify("mylib: skipped malformed JSON line: " .. item.text:sub(1, 60), vim.log.levels.WARN)
        return false
      end
      for key, value in pairs(fields) do
        item[key] = value ~= vim.NIL and value or ""
      end
      item.text = table.concat({ item.tag or "", item.year or "", item.author or "", item.title or "" }, " ")
      -- Read from the decoded `fields` (typed `any`) rather than `item.file`
      -- (typed `string`) so vim.deepcopy's table-only signature is satisfied.
      local filelist = type(fields.file) == "table" and vim.deepcopy(fields.file) or nil
      item.filelist = filelist
      if filelist and filelist["file_for_preview"] ~= vim.NIL then
        item.file = filelist["file_for_preview"]
      else
        item.file = ""
      end
    end,
    format = function(item)
      local ret = {}
      local sep = { " ", virtual = true }

      -- author
      if item.author and item.author ~= "" and item.author ~= "佚名" and item.author ~= "unknown" then
        table.insert(ret, { item.author, "SnacksPickerSpecial" })
        table.insert(ret, sep)
      end

      -- year
      if item.year and item.year ~= "" then
        table.insert(ret, { item.year, "SnacksPickerIndex" })
        table.insert(ret, sep)
      end

      -- tags
      if item.tag and item.tag ~= "" then
        local tags = vim.split(item.tag, ":")
        for _, tag in ipairs(tags) do
          table.insert(ret, { tag, "SnacksPickerDirectory" })
          table.insert(ret, sep)
        end
      end

      -- title
      if item.title and item.title ~= "" then
        table.insert(ret, { item.title, "SnacksPickerRow" })
        table.insert(ret, sep)
      end

      return ret
    end,
    actions = {
      update_tag = update("tag"),
      update_title = update("title"),
      update_category = update("category"),
      update_rate = update("rate"),
      update_file = update("file"),
      update_author = update("author"),
      update_keywords = update("keywords"),
      yank_id = yank("md5_short"),
      yank_key = yank("key"),
      yank_reference = util.get_reference,
      delete_record = function(picker, item)
        vim.system({ "mylib", "delete", "-f", item["md5_short"] }, { text = true }, function(obj)
          if obj.code ~= 0 then
            vim.notify("Failed to delete record " .. item["md5_short"] .. ": " .. obj.code)
          else
            vim.notify("Delete recode " .. item["md5_short"])
            picker:find({ refresh = true })
          end
        end)
      end,
    },
    win = {
      input = {
        keys = {
          ["ut"] = "update_tag",
          ["uh"] = "update_title",
          ["uc"] = "update_category",
          ["ur"] = "update_rate",
          ["ua"] = "update_author",
          ["uk"] = "update_keywords",
          ["yi"] = "yank_id",
          ["yk"] = "yank_key",
          ["yr"] = "yank_reference",
        },
      },
      list = {
        keys = {
          ["ut"] = "update_tag",
          ["uh"] = "update_title",
          ["uc"] = "update_category",
          ["ur"] = "update_rate",
          ["ua"] = "update_author",
          ["uk"] = "update_keywords",
          ["dD"] = "delete_record",
          ["yi"] = "yank_id",
          ["yk"] = "yank_key",
          ["yr"] = "yank_reference",
        },
      },
    },
  })
end
