local pick = require("snacks.picker").pick

return function()
  pick({
    finder = function(_, ctx)
      return require("snacks.picker.source.proc").proc(
        ctx:opts({
          cmd = "cliphist",
          args = { "list" },
          transform = function(item)
            local id, content = item.text:match("^(%d+)%s+(.+)$")
            if id and content and not content:find("^%[%[%s+binary data") then
              item.text = content
              item.id = id
              setmetatable(item, {
                __index = function(_, k)
                  if k == "data" then
                    local data = vim.fn.system({ "cliphist", "decode", id })
                    rawset(item, "data", data)
                    if vim.v.shell_error ~= 0 then
                      error(data)
                    end
                    return data
                  elseif k == "preview" then
                    return {
                      text = item.data,
                      ft = "text",
                    }
                  end
                end,
              })
            else
              return false
            end
          end,
        }),
        ctx
      )
    end,
    sort = function(a, b)
      return a.id > b.id
    end,
    format = "text",
    preview = "preview",
    confirm = { "copy", "close" },
  })
end
