" Display an error message. ============================================== {{{1
function! utils#Warn(msg)
  echohl ErrorMsg
  echomsg a:msg
  echohl NONE
endfunction

" Get char under cursor ================================================= {{{1
function! utils#IsPrintable_CharUnderCursor()
    let line = getline('.')
    let col = col('.')
    let code = char2nr(line[col-1:col-1])
    return code < 128 ? v:true : v:false
endfunction

" Get content between =================================================== {{{1

" Find the start position for content between delimiters.
"
" Searches backwards from the given position to find the opening delimiter `left`,
" correctly handling nested pairs of `left` and `right`.
"
" @param left   The opening delimiter string.
" @param right  The closing delimiter string.
" @param col    The 1-based column on the current line to start the search from.
" @return A [line, col] list for the position *after* the delimiter,
"         or [0, 0] if not found.
function! s:GetEnclosingLeftDelimiterPosition(left, right, col)
    " Save current cursor position to restore later.
    let save_cursor = getcurpos()
    " `searchpairpos()` starts from the cursor, so we move it to the desired start point.
    call cursor(line('.'), a:col)

    " Escape delimiters for use in regex. `\V` (very nomagic) ensures they are
    " treated literally. We only need to escape the backslash itself.
    let l_pat = '\V' . escape(a:left, '\')
    let r_pat = '\V' . escape(a:right, '\')

    " Find the position of the enclosing opening delimiter.
    " 'b' searches backwards. 'W' allows the search to cross line boundaries.
    let pos = searchpairpos(l_pat, '', r_pat, 'bW')

    " Restore original cursor position to prevent side effects.
    call setpos('.', save_cursor)

    if pos != [0, 0]
        " If found, return the position *after* the delimiter by adding its
        " byte-length to the column.
        let pos[1] += len(a:left)
    endif

    return pos
endfunction

" Find the end position for content between delimiters.
"
" Searches forwards from the given position to find the closing delimiter `right`,
" correctly handling nested pairs of `left` and `right`.
"
" @param left   The opening delimiter string.
" @param right  The closing delimiter string.
" @param col    The 1-based column on the current line to start the search from.
" @return A [line, col] list for the position *at the start of* the delimiter,
"         or [0, 0] if not found.
function! s:GetEnclosingRightDelimiterPosition(left, right, col)
    let save_cursor = getcurpos()
    call cursor(line('.'), a:col)

    let l_pat = '\V' . escape(a:left, '\')
    let r_pat = '\V' . escape(a:right, '\')

    " Find the position of the enclosing closing delimiter.
    " 'W' allows the search to cross line boundaries. Forward search is the default.
    let pos = searchpairpos(l_pat, '', r_pat, 'W')

    call setpos('.', save_cursor)

    " The returned position is the start of the delimiter, which is what we need.
    return pos
endfunction

" Get the content between two delimiters, searching from the current cursor position.
"
" This function is the public API. It uses the helper functions to find the
" boundaries and then extracts the text content between them.
"
" @param left   The opening delimiter string (e.g., '(', '{', '"').
" @param right  The closing delimiter string (e.g., ')', '}', '"').
" @param col    (Optional) The column to start the search from. Defaults to the
"               current cursor column.
" @return The string content between the delimiters, or an empty string if the
"          pair is not found or invalid.
function! utils#GetContentBetween(left, right, col = -1)
    if a:left == '' || a:right == ''
        return ''
    endif

    " Use the current cursor column if no column is specified.
    let search_col = a:col == -1 ? col('.') : a:col

    " Find the position *after* the opening delimiter.
    let start_pos = s:GetEnclosingLeftDelimiterPosition(a:left, a:right, search_col)
    if start_pos == [0, 0]
        return ''
    endif

    " Find the position *of* the closing delimiter.
    let end_pos = s:GetEnclosingRightDelimiterPosition(a:left, a:right, search_col)
    if end_pos == [0, 0]
        return ''
    endif

    let [start_line, start_col] = start_pos
    let [end_line, end_col] = end_pos

    " Sanity check: The start position must not be after the end position.
    if start_line > end_line || (start_line == end_line && start_col >= end_col)
        return ''
    endif

    " Case 1: Content is on a single line.
    if start_line == end_line
        let line_content = getline(start_line)
        " Use strpart() for safe substring extraction. It is 0-indexed.
        return strpart(line_content, start_col - 1, end_col - start_col)
    endif

    " Case 2: Content spans multiple lines.
    " Use `getbufline` to efficiently read all relevant lines from the buffer.
    let lines = getbufline('%', start_line, end_line)

    if empty(lines)
        return ''
    endif

    " Trim the start of the first line.
    let lines[0] = strpart(lines[0], start_col - 1)

    " Trim the end of the last line.
    let last_line_idx = len(lines) - 1
    let lines[last_line_idx] = strpart(lines[last_line_idx], 0, end_col - 1)

    return join(lines, "\n")
endfunction

" Extract all urls ====================================================== {{{1
function! utils#Fetch_urls(update = "")
    if has_key(b:, "fetched_urls") && a:update !=? "update"
        return b:fetched_urls
    endif

    let fn = expand('%')
    let uniq_from_perl = "perl -nle '$c{$_} //= $. } { print join q/\n/, (sort {$c{$a} <=> $c{$b}} keys %c)'"
    if fn == ""
        let urls = system("xurls | " . uniq_from_perl, getline(1, '$'))
    else
        let urls = system("xurls " . shellescape(fn) . " | " . uniq_from_perl)
    endif
    let b:fetched_urls = split(urls, '\n', 0)
    return b:fetched_urls
endfunction

" Open url ============================================================== {{{1
function! utils#OpenUrl(url, in = "", type = "")
    if type(a:url) == v:t_dict
        if len(a:url) == 0 | return | endif
        let url = a:url['url']
        let type = a:url['type']
    else
        if a:url == "" | return | endif
        let url = a:url
        let type = a:type
    endif

    if url !~ '\v^\s*(https?://|[-A-z_]+(.[-A-z_]+){3,}/)' | return | end
    let command = "linkhandler " . (type ==# "image" ? "-t image " : "")
    if a:in ==# "in"
        let image_path = system(command . "-V " . "'".url."'")
        exec "ImageToggle " . image_path
    else
        Lazy! load asyncrun.vim
        call asyncrun#run("", {'silent': 1, 'pos': 'hide'}, command . "'".url."'" )
    endif
endfunction


" math equation preview ================================================== {{{1
function! utils#Math_Preview() range
    return
endfunction

" 在末尾添加符号 ======================================================== {{{1
" Add a line of repeated symbols to create section separators or underlines.
"
" This function appends a repeated symbol (like '=', '-', '#') to the end of
" a line to fill it up to a target width, useful for creating visual separators
" in comments or documentation.
"
" @param symbol The character(s) to repeat (e.g., '=', '-', '#')
" @param line   Optional line content to process. If empty, uses current line.
"
" Special behaviors:
" - For empty lines: fills with symbols matching previous line's display width
" - Preserves fold markers at the end of lines
" - Respects textwidth setting (defaults to 78 if not set)
function! utils#AddDash(symbol, line = "") abort
    " Get the line content to process
    if a:line == ""
        " Remove trailing whitespace from current line
        silent! execute 'substitute/\s*$//e'
        let line_content = getline('.')
    else
        let line_content = a:line
    endif

    " Handle empty lines: fill with symbols matching previous line's width
    if line_content =~# '^\s*$'
        call s:FillEmptyLineWithSymbols(a:symbol)
        return
    endif

    " Get target width (use textwidth if set, otherwise default to 78)
    let target_width = &l:textwidth == 0 ? 78 : &l:textwidth
    
    " Extract and preserve fold marker if present
    let [line_content, fold_marker] = s:ExtractFoldMarker(line_content)
    
    " Clean existing symbols and trailing spaces from line
    let line_content = s:CleanLineEnd(line_content, a:symbol)
    
    " Check if line is already at or exceeds target width
    let current_width = strdisplaywidth(line_content)
    if current_width >= target_width
        return
    endif
    
    " Calculate number of symbols to add (leave 6 chars margin for readability)
    let available_space = target_width - current_width - 6
    let symbol_count = available_space / strlen(a:symbol)
    
    " Don't add symbols if there's no space
    if symbol_count <= 0
        return
    endif
    
    " Build and set the new line
    let symbol_line = repeat(a:symbol, symbol_count)
    let new_line = line_content . ' ' . symbol_line . fold_marker
    call setline('.', new_line)
endfunction

" Fill an empty line with symbols matching the display width of previous line.
" Preserves the indentation of the previous line.
function! s:FillEmptyLineWithSymbols(symbol) abort
    let prev_line = getline(line('.') - 1)
    
    " Extract leading whitespace (indentation) from previous line
    let indentation = matchstr(prev_line, '^\s*')
    
    " Extract content (non-whitespace part) from previous line
    let content = matchstr(prev_line, '^\s*\zs.*')
    
    " Calculate display width of content
    let content_width = strdisplaywidth(content)
    
    " Create line with same indentation filled with symbols
    let new_line = indentation . repeat(a:symbol, content_width)
    call setline('.', new_line)
endfunction

" Extract fold marker from end of line if present.
" Returns a list: [cleaned_line, fold_marker]
" The fold_marker includes a leading space if found, empty string otherwise.
function! s:ExtractFoldMarker(line) abort
    " Get the opening fold marker pattern (e.g., '{{{' from '{{{,}}}')
    let fold_markers = split(&l:foldmarker, ',')
    if empty(fold_markers)
        return [a:line, '']
    endif
    
    let fold_marker_pattern = fold_markers[0]
    let marker_regex = '\V' . escape(fold_marker_pattern, '\')
    
    " Check for fold marker with level digit (e.g., ' {{{1')
    " Pattern: fold_marker followed by a digit at end of line
    if a:line =~# marker_regex . '\d\$'
        let marker_with_level = matchstr(a:line, marker_regex . '\d\$')
        let marker_len = len(marker_with_level)
        
        " Extract marker (with leading space) and cleaned line
        let fold_marker = ' ' . marker_with_level
        let cleaned_line = a:line[0:-(marker_len + 2)]  " Remove space + marker
        return [cleaned_line, fold_marker]
    endif
    
    " Check for fold marker without level (e.g., ' {{{')
    if a:line =~# marker_regex . '\$'
        let marker_with_level = matchstr(a:line, marker_regex . '\$')
        let marker_len = len(marker_with_level)
        
        let fold_marker = ' ' . marker_with_level
        let cleaned_line = a:line[0:-(marker_len + 2)]
        return [cleaned_line, fold_marker]
    endif
    
    " No fold marker found
    return [a:line, '']
endfunction

" Remove trailing spaces and existing symbol repetitions from line end.
" This cleans up any previous dash additions to allow recalculation.
function! s:CleanLineEnd(line, symbol) abort
    " Pattern matches: the symbol or space, repeated zero or more times, at end of line
    let escaped_symbol = escape(a:symbol, '\')
    let pattern = '\V\(' . escaped_symbol . '\| \)\*\$'
    return substitute(a:line, pattern, '', 'g')
endfunction

" 在末尾添加 comment symbol 和 folder marker ============================ {{{1
function! utils#AddFoldMark(symbol) abort
    let comment = split(&commentstring, '%s')
    let comment_start = " " . comment[0]
    if len(comment) == 1
        let comment_end = ""
    else
        let comment_end = " " . comment[1]
    endif
    let fold_symbol = split(&foldmarker, ',')[0] . foldlevel(".")

    let line = getline('.')  . comment_start  . fold_symbol . comment_end
    call utils#AddDash(a:symbol, line)
endfunction


" 代码格式化 ============================================================= {{{1
function! utils#RFormat() range
    if g:rplugin.nvimcom_port == 0
        return
    endif
    let lns = getline(a:firstline, a:lastline)
    call writefile(lns, g:rplugin.tmpdir . "/unformatted_code")
    call AddForDeletion(g:rplugin.tmpdir . "/unformatted_code")
    let cmd = "styler::style_text(readLines(\"" . g:rplugin.tmpdir . "/unformatted_code\"), transformers = styler::tidyverse_style(strict = FALSE, indent_by = 4))"
    silent exe a:firstline . "," . a:lastline . "delete"
    silent exe ':normal k'
    call RInsert(cmd, "here")
endfunction

" insert org-mode roam node ============================================= {{{1
function! utils#RoamInsertNode(title, method = "")
    let external_command = 'org-mode-roam-node "' . a:title . '"'
    let @* = a:title
    let ori = @0
    let line = getline(line('.'))
    let pos = col('.') - 1
    let @0 = substitute(system(external_command), "\n$", "", "g")
    if pos != 0 && line[pos - 1:pos - 1] != " "
        let @0 = " " . @0
    end
    if line[pos:pos] != " " && line[pos:pos] != ""
        let @0 = @0 . " "
    end
    exec "normal! i\<c-r>0\<esc>2h"
    let @0 = ori
    if a:method !=? ""
        call utils#RoamOpenNode(a:method)
    endif
endfunction

" open org-roam node under cursor ======================================= {{{1
function! utils#RoamOpenNode(method = "edit")
    let content = utils#GetContentBetween('[[',']]')
    let id = content == "" ? "" : split(content, '][')[0]
    if id =~? '\v^\s*(https?://|[-A-z_]+(.[-A-z_]+){3,}/)'
        call utils#OpenUrl(id, "in")
    elseif id =~? '\v\.png$'
        let dirname = v:lua.vim.fs.dirname(expand('%:p'))
        call utils#Preview_image_under_cursor(dirname . "/" . id)
    elseif id =~ '\v\s*id:'
        let filepath = system("org-mode-roam-node -j " . shellescape(id))
        exec a:method . " " . filepath
    endif
endfunction

" Prewiew file under cursor ============================================= {{{1
function! utils#Preview_image_under_cursor(filename)
    let fname = fnamemodify(a:filename, ":p")
    if fname !~? '\v\.png$' || ! filereadable(fname)
        return
    endif
    exec "PreviewImage! infile " . fname
endfunction

" insert rmd-style picture =============================================== {{{1
function! utils#RmdClipBoardImage()
    execute "normal! i```{r, out.width = '70%', fig.pos = 'h', fig.show = 'hold'}\n"
    call mdip#MarkdownClipboardImage()
    execute "normal! \<esc>g_\"iyi)VCknitr::include_graphics(\"\")\<esc>F\"\"iPo```\n"
endfunction

" RmarkdownPasteImage for md-img-paste
function! utils#RmarkdownPasteImage(relpath)
    execute "normal! i```{r, out.width = '70%', fig.pos = 'h', fig.show = 'hold'}\n" .
          \ "knitr::include_graphics(\"" . a:relpath . "\")\r" .
          \ "```\n"
endfunction

" insert org-mode style image =========================================== {{{1
function! utils#OrgModeClipBoardImage()
    call mdip#MarkdownClipboardImage()
    s/\v!\[([^]]*)]\(([^)]+)\)/[[\2][\1]]/
endfunction

" 选择光标下文字 Super useful! From an idea by Michael Naumann =========== {{{1
function! utils#VisualSelection(direction, extra_filter) range
    let l:saved_reg = @"
    execute "normal! vgvy"

    let l:pattern = escape(@", "\\/.*'$^~[]")
    let l:pattern = substitute(l:pattern, "\n$", "", "")

    if a:direction == 'gv'
        call CmdLine("Ack '" . l:pattern . "' " )
    elseif a:direction == 'replace'
        call CmdLine("%s" . '/'. l:pattern . '/')
    endif
    let @/ = l:pattern
    let @" = l:saved_reg
endfunction

" quickfix managing ====================================================== {{{1
function! utils#QuickfixToggle()
    if g:quickfix_is_open
        cclose
        let g:quickfix_is_open = 0
    else
        copen
        let g:quickfix_is_open = 1
    endif
endfunction

" shift specific line =================================================== {{{1
function! utils#ShiftLine(lnum, col)
    let line_content = substitute(getline(a:lnum), '^\s*', "" , "")
    if ! &l:expandtab
        let tab_num = a:col / shiftwidth()
        let left_space_num -= tab_num * shiftwidth()
        let prefix_space = repeat("\t", tab_num) . repeat(" ", let_space_num)
    else
        let prefix_space = repeat(" ", a:col)
    endif
    call setline(a:lnum, prefix_space . line_content)
    call cursor(a:lnum, a:col + 1)
endfunction

" move the cusror to align with the specific string of previous line ==== {{{1
function! utils#MoveCursorTo(...)
    let previous_line = getline(line('.') - 1)
    if a:0 == 0
        let symbol = input("The target string: ")
    else
        let symbol = a:1
    endif
    if symbol == ""
        let space_num = match(previous_line, '\S')
    else
        let space_num = stridx(previous_line, symbol)
    endif
    call utils#ShiftLine(line('.'), space_num)
endfunction

" Zen {{{1
function! utils#ZenMode_Insert(start = v:true) abort
    let ww = winwidth(0)
    if ! (exists('b:zen_oriwin') && b:zen_oriwin['zenmode'])
        if a:start
            let b:zen_oriwin = {
                \ 'zenmode': v:true,
                \ 'foldcolumn': &l:foldcolumn,
                \ 'signcolumn': &l:signcolumn,
                \ 'number': &l:number,
                \ 'numberwidth': &l:numberwidth,
                \ 'scrolloff': &l:scrolloff,
                \ 'relativenumber': &l:relativenumber,
                \ 'foldenable': &l:foldenable,
                \ 'showcmd': &l:showcmd,
                \ }
        else
            return
        endif
    endif
    setlocal nonumber
    setlocal norelativenumber
    set laststatus=0
    set showtabline=0
    set noshowcmd
    let winh = winheight(0)
    let &l:scrolloff = float2nr(min([winh / 3, max([0, winh - 6])]))
    let &l:foldcolumn = "0"
    if ww < 89
        let &l:signcolumn = "yes:1"
    else
        let &l:signcolumn = "yes:" . min([float2nr((ww - 85) / 4), 9])
    endif
    lua require('lualine').hide()
    let w:zen_mode = v:true
endfunction

function! utils#ZenMode_Leave(exit = v:true) abort
    set noshowcmd
    if !exists('b:zen_oriwin') || !b:zen_oriwin['zenmode']
        return
    endif
    for attr in keys(b:zen_oriwin)
        if attr != 'zenmode'
            exec 'let &l:' . attr . " = '" . b:zen_oriwin[attr] . "'"
        endif
        let &showtabline = get(g:, "showtabline", 1)
    endfor
    if a:exit
        unlet b:zen_oriwin
    endif
    lua require('lualine').hide({unhide=true})
    let w:zen_mode = v:false
endfunction

function! utils#ToggleZenMode() abort
    if ! exists('b:zen_oriwin') || ! b:zen_oriwin['zenmode']
        call utils#ZenMode_Insert()
    else
        call utils#ZenMode_Leave()
    endif
endfunction

" R 语言函数定义 ========================================================= {{{1
function! utils#R_view_df(dfname, row, method, max_width)
    let fname = "/tmp/r_obj_preview_data.tsv"
    let Rcommand = 'fViewDFonVim("' . a:dfname . '", ' . a:row . ', "' . a:method . '", ' . a:max_width . ', "' . fname . '")'
    exec "lua require('r.send').source_lines({'" . Rcommand . "'})"
    sleep 100m
    call utils#Preview_data(fname, "r_obj_preview_bufnr")
endfunction
function! utils#R_view_df_sample(method)
    let dfname = @"
    let row = 40
    let max_width = 30
    return utils#R_view_df(dfname, row, a:method, max_width)
endfunction
function! utils#R_view_df_full(max_width)
    let dfname = @"
    let row = 0
    let method = 'ht'
    return utils#R_view_df(dfname, row, method, a:max_width)
endfunction
function! utils#R_view_srdm_table()
    let dfname = "srdm_tables"
    let row = 0
    let method = 'ht'
    let max_width = 40
    return utils#R_view_df(dfname, row, method, max_width)
endfunction
function! utils#R_view_srdm_var()
    let dfname = "srdm_vars"
    let row = 0
    let method = 'ht'
    let max_width = 40
    return utils#R_view_df(dfname, row, method, max_width)
endfunction

" Stata dolines ========================================================== {{{1
function! utils#RunDoLines()
    let selectedLines = getbufline('%', line("'<"), line("'>"))
    if col("'>") < strlen(getline(line("'>")))
        let selectedLines[-1] = strpart(selectedLines[-1], 0, col("'>"))
    endif
    if col("'<") != 1
        let selectedLines[0] = strpart(selectedLines[0], col("'<")-1)
    endif
    let temp = "/tmp/statacmd.do"
    call writefile(selectedLines, temp)

    if(has("mac"))
        silent exec "!open /tmp/statacmd.do"
    else
        silent exec "! nohup bash ~/.config/nvim/runStata.sh >/dev/null 2>&1 &"
    endif
endfun

" Status Line ============================================================ {{{1
function! utils#Status()
    if &laststatus == 0
        "call plug#load('vim-airline', 'vim-airline-themes')
        let &laststatus = 3
    else
        let &laststatus = 0
    endif
endfunction

" Plug Load Management ================================================== {{{1
function! utils#PlugHasLoaded(plugName) abort
    " 判断插件是否已经载入
    if has_key(g:, "plug_manage_tool") && g:plug_manage_tool == "lazyvim"
        let loaded_plugs = v:lua.LoadedPlugins()
        return(has_key(loaded_plugs, a:plugName))
    endif

    if !has_key(g:plugs, a:plugName)
        return(0)
    endif
    let plugdir = g:plugs[a:plugName].dir
    let plugdir_noenddash = strpart(plugdir, 0, strlen(plugdir) - 1)
    return (
       \ has_key(g:plugs, a:plugName) &&
       \ stridx(&rtp, plugdir_noenddash) >= 0)
endfunction

function! s:PlugConfHasLoaded(plugName) abort
    " 是否已经载入插件的个人配置文件
    return(
        \ has_key(g:plugs_lbs_conf, a:plugName) &&
        \ g:plugs_lbs_conf[a:plugName] > 0
        \ )
endfunction

function! utils#Load_Plug_Conf(plugName) abort
    " 载入插件对应的配置文档
    if <SID>PlugConfHasLoaded(a:plugName) == 0
        let fname = stdpath("config") . "/Plugins/" . a:plugName
        let fname_vim = fname . ".vim"
        let fname_lua = fname . ".lua"
        if filereadable(fname_vim)
            exec "source " . fnameescape(fname_vim)
        elseif filereadable(fname_lua)
            exec "luafile " . fnameescape(fname_lua)
        endif
        let g:plugs_lbs_conf[a:plugName] = 1
    endif
endfunction

function! utils#Load_Plug(plugname)
    " 手动加载特定插件
    if utils#PlugHasLoaded(a:plugname) == 0
        if has_key(g:, "plug_manage_tool") && g:plug_manage_tool == "lazyvim"
            exec "lua require('lazy').load({plugins = '" . a:plugname . "'})"
        else
            call utils#Load_Plug_Conf(a:plugname)
            call plug#load(a:plugname)
        endif
    endif
endfunction

function! utils#Load_Plug_Confs(plugNames) abort
    " load config file for loaded plug
    for plugname in a:plugNames
        if utils#PlugHasLoaded(plugname) == 1
            call utils#Load_Plug_Conf(plugname)
        endif
    endfor
endfunction

" Input Method Toggle ==================================================== {{{1
function! utils#LToggle()
    if g:lbs_input_status == g:lbs_input_method_on
        let g:input_toggle = 1
        let l:a = system(g:lbs_input_method_inactivate)
    elseif g:lbs_input_status != g:lbs_input_method_on && g:input_toggle == 1
        let l:a = system(g:lbs_input_method_activate)
        let g:input_toggle = 0
    endif
    return("")
endfunction

" View csv lines ========================================================= {{{1
function! utils#ViewLines() range
    let selectedLines = getbufline('%', a:firstline, a:lastline)
    let selectedLines = [getline(1)] + selectedLines
    let tmpfile = tempname()
    if &filetype ==# "tsv"
        let sep = "\t"
    elseif &filetype ==# "csv_pipe"
        let sep = "|"
    elseif &filetype ==# "csv_semicolon"
        let sep = ";"
    elseif &filetype ==# "csv"
        let sep = ","
    else
        return 0
    endif

    let listcontents = system("xsv flatten -s '" . repeat("─", 30) . "' -d '" . sep . "'", selectedLines)
    let listcontents = repeat("─", 30) . "\n" . listcontents
    silent cexpr listcontents
    silent copen
    let g:quickfix_is_open = 1
    syn match qfVarname  "^|| \w\+"hs=s+3 contains=qfPre
    syn match qfLineSep  "^|| ─\+"hs=s+3 contains=qfPre
    exec "wincmd L"
    exec "vertical resize 40"
    exec "set nowrap"
    exec "wincmd h"
    "call writefile(selectedLines, tmpfile) exec "split " . tmpfile
endfunction

" Vim Auto List Completion =============================================== {{{1
" From https://gist.github.com/sedm0784/dffda43bcfb4728f8e90
" Auto lists: Automatically continue/end lists by adding markers if the
" previous line is a list item, or removing them when they are empty
function! utils#AutoFormatNewline()
  if getline(".")[col("."):] =~ '\v^\s*\)+\s*$'
    exec "normal ax\<left>\<enter>\<Esc>lxh"
  else
      let l:preceding_line = getline(line("."))
      if l:preceding_line =~ '\v^\s*(\d+\.|[-+*])\s'
        let l:space_before = matchstr(l:preceding_line, '\v^\zs\s*\ze(\d+\.|[-+*])\s+')
        let l:symbol       = matchstr(l:preceding_line, '\v^\s*\zs(\d+\.|[-+*])\ze\s+')
        let l:space_after  = matchstr(l:preceding_line, '\v^\s*(\d+\.|[-+*])\zs\s+\ze')
        exec "normal a\<enter>"
        if l:preceding_line =~ '\v^\s*\d+\.\s+[^ ]'
            call setline(".", l:space_before . (l:symbol + 1) . "." . l:space_after)
        elseif l:preceding_line =~ '\v^\s*\d+\.\s+$'
            call setline(line(".") - 1, "")
        elseif l:preceding_line =~ '\v^\s*[-+*]\s+[^ ]'
            call setline(".", l:space_before . l:symbol . l:space_after)
        elseif l:preceding_line =~ '\v^\s*[-+*]\s+$'
          call setline(line(".") - 1, "")
        endif
        exec "normal $"
      else
          exec "normal \<enter>"
      endif
    endif
endfunction

" 翻译操作符 ============================================================= {{{1
function! utils#Trans_string(str)
    let cmd = "deepl \"%s\" 2>/dev/null"
    let daily_trans_file = luaeval('require"util".get_daily_filepath("md", "ReciteWords")')
    if ! filereadable(daily_trans_file)
      call writefile(["# Daily translation ", ""], daily_trans_file, "a")
    endif
    if len(split(a:str, ' ')) <= 3 && a:str =~? '\v^[a-z]'
        call v:lua.require'kd'.translate_word(a:str, daily_trans_file)
        return ""
    endif
    let cmd = printf(cmd, a:str)
    let re = systemlist(cmd)
    let engine = re[0]
    let re = join(re[1:], "\n")
    if v:shell_error != 0
        return ""
    else
        call luaeval("vim.notify(_A[1] .. '\\n' .. _A[2], vim.log.levels.INFO, {title = _A[3]})", [a:str, re, engine])
        let prefix = ["", "<!-- start_anki trans -->", "### " . a:str, ""]
        let suffix = ["<!-- end_anki -->", ""]
        call writefile(prefix + split(re, "\n") + suffix, daily_trans_file, 'a')
        return re
    endif
endfunction

function! utils#Trans2clip(type = '')
    if a:type == ''
        set opfunc=utils#Trans2clip
        return 'g@'
    endif

    let visual_marks_save = [getpos("'<"), getpos("'>")]

    try
        let commands = #{line: "'[V']y", char: "`[v`]y", block: "`[\<c-v>`]y", v:"`<v`>y"}
        silent exe 'noautocmd normal! ' .. get(commands, a:type, '')
        let oritext = substitute(@", "\n", " ", "g")
        let @" = utils#Trans_string(oritext)
        " cexpr @"
    finally
        call setpos("'<", visual_marks_save[0])
        call setpos("'>", visual_marks_save[1])
    endtry
endfunction

function! utils#Trans_Subs()
    normal! vF=d
    let string_ori = substitute(getreg('"'), '\v^\s*\=\s*', "", "")
    let string_translated = trim(utils#Trans_string(string_ori))
    echom string_translated
    if string_translated == ""
        let string_translated = "= " . string_ori
    endif
    call luaeval('vim.api.nvim_put({_A.str}, "c", true, true)', {'str': string_translated})
endfunction


" tab, window, buffer related ============================================ {{{1
" 查找 bufnr 所在的标签序号 ---------------------------------------------- {{{2
function! s:find_buftabnr(buffernr) abort
    let l:tabnr = -1
    for tnr in range(1, tabpagenr('$'))
        for bnr in tabpagebuflist(tnr)
            if bnr ==# a:buffernr
                let l:tabnr = tnr
                break
            endif
        endfo
        if l:tabnr != -1
            break
        endif
    endfor
    return l:tabnr
endfunction

" 查找 bufnr 的标签 ------------------------------------------------------ {{{2
function! utils#Find_bufwinnr(buffernr) abort
    let l:tabnr = <sid>find_buftabnr(a:buffernr)
    let l:winid = -1
    if l:tabnr != -1
        exe l:tabnr . "tabnext"
        let l:winid = bufwinid(a:buffernr)
    endif
    return l:winid
endfunction

" open file in spec buffer
function! utils#Preview_data(fname, globalvar, method = "tabnew", close = "n", filetype = "tsv")
    if !has_key(g:, a:globalvar)
        if a:close ==? "y" | return | endif
        let bufnr = bufadd(a:fname)
        let g:[a:globalvar] = bufnr
    else
        let bufnr = get(g:, a:globalvar)
    endif
    let l:winlist = win_findbuf(bufnr)
    if empty(l:winlist)
        if a:close ==? "y" | return | endif
        exec a:method | exec "buffer" . bufnr
        setlocal buftype=nowrite
        setlocal noswapfile
        let &l:filetype = a:filetype
        if a:filetype ==? "csv" || a:filetype ==? "tsv"
            try
                RainbowAlign
                catch /.*/
            endtry
        endif
    else
        call win_gotoid(l:winlist[0])
        exec "edit"
        if a:close ==? "y"
            Bclose
            quit
        endif
    endif
endfunction

" Stata Related ========================================================== {{{1
function! utils#StataGenHelpDocs(keywords, oft = "txt") abort
    if a:oft ==? "pdf"
        call system(",sh -o pdf " . a:keywords)
        return ""
    endif
    let l:target = system(",sh -v " . a:keywords)
    if l:target !~? '^\(\s*Cannot.*\|\s*\)$'
        if &ft ==? "statadoc"
            exec "edit " . l:target
        else
            exec "split " . l:target
        end
        help
        q
    endif
endfunction

" Markdown Snippets Preview ============================================== {{{1
function! utils#MdPreview(method = "infile") range  abort
  if executable('surf')
    lua require('util').md_preview()
    return
  endif

  let bg = synIDattr(synIDtrans(hlID("StatusLine")), "bg#")

  if !(($TERM ==? "xterm-kitty" || $WEZTERM_EXECUTABLE != "") && v:lua.PlugExist('image.nvim') && has('mac'))
    let outfile = shellescape(stdpath('cache') . "/vim_markdown_preview.png")
    let command = "mdviewer --wname " . sha256(expand('.')) .
                \ " --outfile " . outfile
    Lazy! load asyncrun.vim
    call asyncrun#run("", {'silent': 1, 'pos': 'hide'}, command, 1, a:firstline, a:lastline)
    return
  endif

  let outfile = stdpath('cache') . "/kitty_markdown_preview.png"
  let command = "mdviewer --outfile " . outfile . " --quietly --bg '" . bg . "'"
  let lines = getline(a:firstline, a:lastline)
  call system(command, lines)

  exec "PreviewImage! " . a:method . " " . outfile
endfunction


" Check the syntax group in the current cursor position, see ============= {{{1
" https://stackoverflow.com/q/9464844/6064933 and
" https://jordanelver.co.uk/blog/2015/05/27/working-with-vim-colorschemes/
function! utils#SynGroup() abort
  if !exists('*synstack')
    return
  endif
  echo map(synstack(line('.'), col('.')), 'synIDattr(v:val, "name")')
endfunction

" Get highlight group color ============================================= {{{1
function! utils#GetHlColor(hlg, element)
    return synIDattr(synIDtrans(hlID(a:hlg)), a:element)
endfun

" Redirect command output to a register for later processing. ============ {{{1
" Ref: https://stackoverflow.com/q/2573021/6064933 and https://unix.stackexchange.com/q/8101/221410 .
function! utils#CaptureCommandOutput(command) abort
  let l:tmp = @m
  redir @m
  silent! execute a:command
  redir END

  "create a scratch buffer for dumping the text, ref: https://vi.stackexchange.com/a/11311/15292.
  tabnew | setlocal buftype=nofile bufhidden=wipe nobuflisted noswapfile

  let l:lines = split(@m, '\n')
  call nvim_buf_set_lines(0, 0, 0, 0, l:lines)

  let @m = l:tmp
endfunction

" Buffer Delete ========================================================== {{{1
" From: https://github.com/rbgrouleff/bclose.vim/blob/master/plugin/bclose.vim
function! utils#Bclose(bang, buffer)
    if empty(a:buffer)
        let btarget = bufnr('%')
    elseif a:buffer =~ '^\d\+$'
        let btarget = bufnr(str2nr(a:buffer))
    else
        let btarget = bufnr(a:buffer)
    endif
    if btarget < 0
        call utils#Warn('No matching buffer for '.a:buffer)
        return
    endif
    if empty(a:bang) && getbufvar(btarget, '&modified')
        call utils#Warn('No write since last change for buffer ' .
                     \  btarget . ' (use :Bclose!)')
        return
    endif
    " Numbers of windows that view target buffer which we will delete.
    let wnums = filter(range(1, winnr('$')), 'winbufnr(v:val) == btarget')
    let wcurrent = winnr()
    for w in wnums
        execute w.'wincmd w'
        let prevbuf = bufnr('#')
        if prevbuf > 0 && buflisted(prevbuf) && prevbuf != w
            buffer #
        else
            bprevious
        endif
        if btarget == bufnr('%')
            " Numbers of listed buffers which are not the target to be deleted.
            let blisted = filter(range(1, bufnr('$')),
                                \ 'buflisted(v:val) && v:val != btarget')
            " Listed, not target, and not displayed.
            let bhidden = filter(copy(blisted), 'bufwinnr(v:val) < 0')
            " Take the first buffer, if any (could be more intelligent).
            let bjump = (bhidden + blisted + [-1])[0]
            if bjump > 0
                execute 'buffer '.bjump
            else
                execute 'enew'.a:bang
            endif
        endif
    endfor
    execute 'bdelete'.a:bang.' '.btarget
    execute wcurrent.'wincmd w'
endfunction

" 查看当前光标下的高亮组 ================================================ {{{1
function! utils#Extract_hl_group_link()
    echom v:lua.extract_hl_group_link(0, line('.') - 1, col('.') -1)
endfunction

" 获取光标下方最接近的空行行号 ========================================== {{{1
function! utils#GetNearestEmptyLine(linenr = -1)
    let cursor_line = a:linenr == -1 ? line('.') : a:linenr
    let total_lines = line('$')
    let nearest_empty_line = -1

    for line_number in range(cursor_line + 1, total_lines)
        if getline(line_number) =~# '^\s*$'
            let nearest_empty_line = line_number
            break
        endif
    endfor

    return nearest_empty_line
endfunction

" 调整到特定的 Buffer
function! utils#JumpToBuffer(bufname)
    let windows = getwininfo()
    for window in windows
        " 检查每个窗口中的缓冲区名称
        let win_bufname = bufname(window.bufnr)
        " 如果缓冲区名称与给定名称匹配，则跳转到该窗口
        if win_bufname == a:bufname
            execute window.winnr . "wincmd w"
            return
        endif
    endfor
    echo "Buffer not found in current tab."
endfunction

" Insert line before or after
function! utils#InsertLine(content, target, bufnr = 0, check = v:null, after = v:false) abort
    let cur_bufnr = bufnr()
    if a:bufnr != 0
        exec "buffer " . a:bufnr
    endif
    if a:check != v:null && search(a:check, 'n') != 0
        exec "buffer " . cur_bufnr
        return -1
    endif
    let target_linenr = search(a:target, 'n')
    if target_linenr == 0
        let target_linenr = line('$')
    endif
    if a:after
        call append(target_linenr, a:content)
    else
        call append(target_linenr - 1, a:content)
    endif
    exec "buffer " . cur_bufnr
    return 1
endfunction


" End =================================================================== {{{1
" vim: fdm=marker:
