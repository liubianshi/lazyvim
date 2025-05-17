local ls = require("luasnip")
local snip = ls.snippet
local insert = ls.insert_node
local text = ls.text_node

return {
  snip({ trig = "cbr", name = "Code Chunk", dscr = "Code Chunk" }, {
    text({ "```{r}", "" }),
    insert(1),
    text({ "", "```" }),
    insert(0),
  }),
}
