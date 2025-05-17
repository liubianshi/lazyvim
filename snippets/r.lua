local ls = require("luasnip")
local s = ls.snippet
local t = ls.text_node
local i = ls.insert_node
local f = ls.function_node

return {
  -- Rscript Header (Simple text snippet)
  s({
    trig = "libs",
    name = "Rscript Header",
    dscr = "Standard Rscript library imports",
  }, {
    t({
      "box::use(magrittr[`%>%`, `%<>%`, `%T>%`])",
      "box::use(stringr[glue = str_glue])",
      "box::use(data.table[setDT, as.data.table, data.table, setnames])",
      "",
    }),
    i(0),
  }),

  -- local block (Word trigger - no change needed)
  s({ trig = "local", name = "Local Block", dscr = "R local({...}) block", wordTrig = true }, {
    t({ "local({", "\t" }),
    i(1),
    t({ "", "})" }),
    i(0),
  }),

  -- showtext font setting (Simple text snippet - no change needed)
  s({ trig = "showtext", name = "Showtext Setup", dscr = "Setup showtext library and font" }, {
    t({
      'library("showtext")',
      "showtext_auto()",
      'font_add("Noto Serif CJK SC", "NotoSerifCJK-Regular.ttc")',
      "",
    }),
    i(0),
  }),

  -- vim modeline (Simple text snippet - no change needed)
  s({ trig = "# vim", name = "Vim Modeline", dscr = "Add vim modeline" }, {
    t("# vim: set tw=0 nowrap fdm=marker"),
    i(0),
  }),

  -- Externally callable function with Roxygen comments (Regex trigger with ECMA engine using [[...]])
  s({
    trig = [[^@(\w+(?:,\w+)*)]], -- Much clearer!
    regTrig = true,
    trigEngine = "ecma",
    name = "Exported Function Stub",
    dscr = "Create exported function with Roxygen comments",
  }, {
    t("# "),
    f(function(_, snip)
      local args = snip.captures
      local keywords_str = args[1]
      -- Use Lua pattern match
      local funname = string.match(keywords_str, "^[^,]+")
      return funname or ""
    end, { 1 }),
    t({ "", "#' " }),
    i(1, "Description"),
    t({ "", "#'" }),
    f(function(_, snip)
      local args = snip.captures
      local keywords_str = args[1]
      local params_doc = { "" }
      local keywords = vim.split(keywords_str, ",")
      for idx = 2, #keywords do
        table.insert(params_doc, "#' @param " .. keywords[idx])
      end
      t(params_doc)
    end, { 1 }),
    t({ "#' @return " }),
    i(2, "NULL"),
    t({ "", "#'", "#' @example", "#' NULL", "#' @export", "" }),
    f(function(_, snip)
      local keywords_str = snip.captures[1]
      local keywords = vim.split(keywords_str, ",") -- Helper uses Lua patterns
      local funname = keywords[1] or ""
      local params_list = {}
      for idx = 2, #keywords do
        table.insert(params_list, keywords[idx])
      end
      local args_str = table.concat(params_list, ", ")
      return funname .. " <- function(" .. args_str .. ")"
    end, { 1 }),
    t({ "", "{" }),
    t({ "\t" }),
    i(0),
    t({ "", "}" }),
  }),
}
