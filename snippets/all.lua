local ls = require("luasnip")
local s = ls.snippet
local t = ls.text_node
local i = ls.insert_node
local f = ls.function_node

ls.add_snippets("all", {
  s({ trig = "(%w+)%.par", regTrig = true, wordTrig = false }, {
    t("("),
    f(function(_, snip)
      return snip.captures[1]
    end),
    i(1),
    t(")"),
    i(0),
  }),

  s({ trig = [[\v\(([^()]*)\) ]], trigEngine = "vim" }, {
    t("（"),
    f(function(_, snip)
      return snip.captures[1]
    end),
    t("）"),
    i(0),
  }),

  s({ trig = '"([^"]*)" ', trigEngine = "pattern" }, {
    t("“"),
    f(function(_, snip)
      return snip.captures[1]
    end),
    t("”"),
    i(0),
  }),

  s({ trig = "'([^']*)' ", trigEngine = "pattern" }, {
    t("「"),
    f(function(_, snip)
      return snip.captures[1]
    end),
    t("」"),
    i(0),
  }),

  s({ trig = "^(%s*[-+*:])", trigEngine = "pattern" }, {
    f(function(_, snip)
      return snip.captures[1]
    end),
    t("   "),
    i(0),
  }),

  s({ trig = "^(%s*[1-9])", regTrig = true }, {
    f(function(_, snip)
      return snip.captures[1]
    end),
    t(".  "),
    i(0),
  }),

  s({ trig = "^(%s*[1-9][0-9])", regTrig = true }, {
    f(function(_, snip)
      return snip.captures[1]
    end),
    t(". "),
    i(0),
  }),

  s("printf", {
    t('printf("'),
    i(1, "%s"),
    t('\\n"'),
    f(function(args)
      return #args[1][1] > 0 and ", " or ")"
    end, { 1 }),
    i(2),
    t(");"),
  }),

  s({ trig = "([#*])(%d)", regTrig = true }, {
    f(function(_, snip)
      local dup = tonumber(snip.captures[2]) or 1
      return string.rep(snip.captures[1], dup) .. " "
    end),
  }),

  s({ trig = "LW", wordTrig = true }, {
    t({
      "------",
      "南开大学 APEC 研究中心",
      "天津市南开区卫津路 94 号南开大学文科创新楼 B309 室（300071）",
      "Tel:  86-22-2349 7558",
      "E-mail:  weiluonk@gmail.com",
      "",
    }),
    i(0),
  }),

  s({ trig = "cheat" }, {
    t({ "---", "syntax: " }),
    i(1, "r"),
    t({ "", "tags: [ " }),
    i(2, "untag"),
    t({ " ]", "---", "" }),
    i(0),
  }),
})
