local ls = require("luasnip")
local s = ls.snippet
local t = ls.text_node
local i = ls.insert_node

ls.add_snippets("perl", {
  s({ trig = "head", name = "Description" }, {
    t({
      "#!/usr/bin/env perl",
      "# vim: set ft=perl nowrap fdm=marker",
      "",
      "use strict;",
      "use warnings;",
      "use Encode;",
      "use utf8;",
      "use File::Basename;",
      "use File::Spec;",
      "",
    }),
    i(1),
  }),
})
