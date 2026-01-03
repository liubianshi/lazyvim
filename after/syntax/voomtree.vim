if exists("b:current_syntax")
  finish
endif
let b:current_syntax = "voomtree"

setlocal conceallevel=2

syn match voomPre "\v^[= ][ ]+([.][ ]+)?\|\W+\ze[ ]\w" contains=voomCurrentChar conceal cchar=
syn region voomCurrent start=/\v^\= \W+[ ]/hs=e+1 end="\n" contains=voomPre

hi def link voomPre Folded
hi def link voomCurrent helpURL

" syn match voomCurrentChar "\v\=" conceal contained {{{1
" syn match voomCurrentChar "\v\=" conceal contained {{{1
