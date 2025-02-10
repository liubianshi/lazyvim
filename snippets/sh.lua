local ls = require("luasnip")
local s = ls.snippet
local t = ls.text_node
local i = ls.insert_node

ls.add_snippets("sh", {
  s({
    trig = "head",
    name = "set header",
    dscr = "set header",
    condition = function(line_to_cursor)
      return line_to_cursor:match("^%s*$")
    end,
  }, {
    t({ "#!/usr/bin/env bash", "set -eu -o pipefail", "", "" }),
    i(0),
    t({ "", "", "exit 0" }),
  }),

  s({
    trig = "normal",
    name = "normal output",
    dscr = "set normal output",
    condition = function(line_to_cursor)
      return line_to_cursor:match("^%s*$")
    end,
  }, {
    t("normal=\"$(printf '\\033[0m')\""),
    i(0),
  }),

  -- Similar entries for bold/italic/underline/color snippets
  s({
    trig = "bold",
    name = "bold output",
    dscr = "set bold output",
    condition = function(line_to_cursor)
      return line_to_cursor:match("^%s*$")
    end,
  }, {
    t("bold=\"$(printf '\\033[1m')\""),
    i(0),
  }),

  s({
    trig = "italic",
    name = "italic output",
    dscr = "set italic output",
    condition = function(line_to_cursor)
      return line_to_cursor:match("^%s*$")
    end,
  }, {
    t("italic=\"$(printf '\\033[3m')\""),
    i(0),
  }),

  s({
    trig = "exithandler",
    name = "Exit Handler",
    dscr = "Handle Exit Info",
    condition = function(line_to_cursor)
      return line_to_cursor:match("^%s*$")
    end,
  }, {
    t({
      "# Exit status",
      "_ES_SUCCESS=0",
      "_ES_FAILURE=1",
      "_ES_UNKNOWN_SYSTEM=2",
      "_ES_UNKNOWN_RELEASE=3",
      "_ES_UNKNOWN_PACKAGE=4",
      "_ES_UNKNOWN_ARGUMENT=5",
      "",
      "# Ansi colors",
      "_ANSI_END='\\e[0m'",
      "_ANSI_BOLD='\\e[1m'",
      "_ANSI_RED='\\e[91m'",
      "_ANSI_GREEN='\\e[92m'",
      "_ANSI_YELLOW='\\e[93m'",
      "_ANSI_BLUE='\\e[94m'",
      "_ANSI_MAGENTA='\\e[95m'",
      "_ANSI_CYAN='\\e[96m'",
      "_ANSI_WHITE='\\e[97m'",
      "",
      "_info() {",
      '\tprintf "${_ANSI_BOLD}${_ANSI_CYAN}%s${_ANSI_END}\\n" "$*"',
      "}",
      "",
      "_warn() {",
      '\tprintf "${_ANSI_BOLD}${_ANSI_YELLOW}%s${_ANSI_END}\\n" "$*"',
      "}",
      "",
      "_err() {",
      '\tprintf "${_ANSI_BOLD}${_ANSI_MAGENTA}%s${_ANSI_END}\\n" "$*"',
      "}",
      "",
      "_die() {",
      '\t_err "${@:2}"',
      '\texit "$1"',
      "}",
    }),
    i(0),
  }),
})
