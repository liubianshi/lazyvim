local ls = require("luasnip")
local s = ls.snippet
local f = ls.function_node

ls.add_snippets("r", {

  s(":([-\\w.+*$]+)(?:([<>=])([^/>;]+)?)?", {
    f(function(args, snip)
      local m = string.match(args[1][1], "^([-]?%d[%d.]*L?|[-]|[.]|[+]|[*]|[$])([%a_].*)")
      local augument, params

      if m then
        augument = m[2]
        if m[1] == "+" then
          params = "TRUE"
        elseif m[1] == "-" then
          params = "FALSE"
        elseif m[1] == "." then
          params = "NA"
        elseif m[1] == "*" then
          params = "NULL"
        elseif m[1] == "$" then
          params = augument
        elseif m[1] == "00" then
          params = "NULL"
        else
          params = m[1]
        end
      else
        augument = args[1][1]
        if not args[2][1] then
          params = "TRUE"
        elseif args[2][1] == ">" then
          params = args[3][1] and args[3][1] .. ";" or "list;"
        elseif args[2][1] == "=" then
          local split = vim.split(args[3][1], "%s+")
          params = #split > 1 and "c(" .. table.concat(split, ", ") .. ")" or split[1]
        elseif args[2][1] == "<" then
          local split = vim.split(args[3][1], "%s+")
          local quoted = vim.tbl_map(function(s)
            return '"' .. s .. '"'
          end, split)
          params = #quoted > 1 and "c(" .. table.concat(quoted, ", ") .. ")" or quoted[1]
        end
      end
      return augument .. " = " .. params
    end),
  }),
})
