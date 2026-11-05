if vim.b.current_syntax then
  return
end
vim.b.current_syntax = "newsboat"
vim.wo.conceallevel = 2

vim.cmd([==[
syn match newsHeader /\v^\#+\s+.*$/
syn match newsKeyword /\v^(Feed|Link|Source|Last Access|Title|Author|Date):\ze/ conceal cchar= contained
syn match newsDecodeurl /\v(\%[0-9A-Fa-f]{2}){8,}.*$/ conceal cchar=󰇘 contained
syn match newsFeed /\v^Feed: .*$/ contains=newsKeyword
syn match newsFeed /\v^Source: .*$/ contains=newsKeyword
syn match newsDate /\v^Last Access: .*$/ contains=newsKeyword
syn match newsTitle /\v^Title: .*$/ contains=newsKeyword
syn match newsAuthor /\v^Author: .*$/ contains=newsKeyword
syn match newsLinkType /\v^Flags: .*$/ contains=newsKeyword
syn match newsDate /\v^Date: .*$/ contains=newsKeyword
syn match newsLink /\v^Link: [^ ]*$/hs=s+6 contains=newsKeyword,newsDecodeurl keepend
syn match newsInLink /\v\[[^\]\(]+\(link [^\)]+\)\]/ contains=newsLinkBracket
syn match newsLinkBracket /[\[\]]/ conceal contained
syn match newsLinkID /\v\[[0-9]+\]:?/
syn match newsLinkHeader /\vLinks:\ze\s*$/
syn region newsLink start="\v https?://"hs=s+1 end=/\v \([^\)]+\)/he=s-1 oneline contains=newsLinkType
syn match newsInLink /\v\[([^\]]|\n)*\]\ze\[[0-9]+\]/ contains=newsLinkBracket
syn region newsInLink start='\v\[image\s' end='\v\(link #[0-9]+\)\]' contains=newsLinkBracket keepend
syn match newsLinkType /\v\([^\)]+\)/hs=s+1,he=e-1 contained
syn match newsHighlightSymbol /\v(‹\[|\]›)/ contained conceal
syn match newsHighlightSymbol /\v(〚|〛)/ contained conceal
syn region newsHighlight start=/\V‹[/hs=s+2 end=/\V]›/he=s+1 contains=newsHighlightSymbol keepend
syn region newsHighlight start=/\V〚/hs=s+1 end=/\V〛/he=s+1 contains=newsHighlightSymbol keepend
syntax match MarkdownCode /\v`[^`]+`/
syntax match MarkdownQuote /\v^\>\ze( |$)/ conceal cchar=┃
syntax match MarkdownQuoteSpecial_pre /\v^\>\ze \[![^]]+\]/ conceal cchar=┏ contained
syntax match MarkdownQuoteSpecial /\v^\> \[![^]]+\]\s.*$/hs=s+2 keepend contains=MarkdownQuoteSpecial_pre,MarkdownQuoteSpecialMarker
syntax match MarkdownQuoteSpecialMarker /\v\[![^]]+\]/ contained
]==])

local colors = vim.g.lbs_colors or {}
local highlights = {
  "highlight def MarkdownCode guifg=" .. (colors.green or "NONE"),
  "highlight def MarkdownQuoteSpecial_pre guifg=" .. (colors.orange or "NONE"),
  "highlight def MarkdownHighlight guibg=" .. (colors.yellow or "NONE") .. " guifg=" .. (colors.darkblue or "NONE"),
  "highlight def MarkdownQuoteSpecial gui=underline guifg=" .. (colors.yellow or "NONE"),
  "highlight def MarkdownQuoteSpecialMarker gui=bold guibg="
    .. (colors.yellow or "NONE")
    .. " guifg="
    .. (colors.darkblue or "NONE"),
  "highlight def newsHighlight guifg=" .. (colors.yellow or "NONE") .. " guisp=" .. (colors.cyan or "NONE"),
  "highlight default link newsHeader Keyword",
  "highlight default link newsLinkType Keyword",
  "highlight default link newsLinkHeader HighlightedYankRegion",
  "highlight default link newsLinkID Constant",
  "highlight default link newsLink Underlined",
  "highlight default link newsInLink Underlined",
  "highlight default link newsTitle SpecialChar",
  "highlight default link newsAuthor SpecialChar",
  "highlight default link newsDate SpecialChar",
  "highlight default link newsFeed NotifyWarnTitle",
}
for _, command in ipairs(highlights) do
  vim.cmd(command)
end
