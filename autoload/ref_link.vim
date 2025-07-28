" ref_link#GetID(url)
" Finds an existing Markdown reference link for a given URL or creates a new one.
"
" The function searches for a "<!-- Links -->" section at the end of the buffer.
" If the section exists, it scans for the URL. If found, it returns the
" existing link ID. If not found, it appends a new link definition with the
" next available ID. If the section doesn't exist, it creates it.
"
" @param url The URL string to find or add.
" @return {string} The link ID (e.g., '1', '2').
function! ref_link#GetID(url) abort
    let links_marker = '^<!-- Links -->$'
    let links_line = search(links_marker, 'nW') " Search without moving cursor

    " If the link section doesn't exist, create it and add the first link.
    if links_line == 0
        call append(line('$'), ["", "<!-- Links -->", "[1]: " . a:url])
        return '1'
    endif

    " Read all lines from the marker to the end of the file for efficient processing.
    let link_lines = getbufline('%', links_line + 1, '$')
    let max_id = 0
    let link_pattern = '\v^\[([0-9]+)\]:\s+(.*)\s*$'

    for line in link_lines
        let match = matchlist(line, link_pattern)
        if empty(match)
            continue
        endif

        let current_id = str2nr(match[1])
        let current_url = match[2]

        " If URL already exists, return its ID.
        if current_url ==? a:url
            return match[1]
        endif

        " Keep track of the highest ID to determine the next one.
        if current_id > max_id
            let max_id = current_id
        endif
    endfor

    " If URL was not found, append it with a new ID.
    let new_id = max_id + 1
    call append(line('$'), '[' . new_id . ']: ' . a:url)
    return string(new_id)
endfunction

" ref_link#add()
" Adds a Markdown reference-style link at the cursor position.
"
" It pulls a URL from the clipboard (+ register). If the clipboard content
" is not a URL, it prompts the user for one.
" It then checks if the cursor is on existing text like "[Some Text]".
" - If so, it converts it to a reference link: "[Some Text][id]".
" - If not, it fetches the URL's title and inserts a new link: "[Page Title][id]".
function! ref_link#add() abort
    " Attempt to get URL from the system clipboard.
    let url = trim(getreg('+'))

    " If clipboard is not a valid URL, prompt the user.
    if url !~? '\v^https?://'
        let url = trim(input('Input URL: '))
        call inputrestore()
        echo ""
        if empty(url) | return | endif
    endif

    let linkid = ref_link#GetID(url)

    " Check for text to be linked (e.g., `[visual selection]`)
    " Note: Relies on an external function `utils#GetContentBetween`.
    let title = utils#GetContentBetween('[', ']')

    if empty(title)
        " No text selected; create a new link with a fetched title.
        " NOTE: The system() call is synchronous and can cause a delay.
        let link_text = '[' . linkid . '][' . linkid . ']'
        call nvim_put([link_text], 'c', v:true, v:true)
    else
        " Text like "[some text]" exists; append the reference ID.
        " Move cursor to the closing bracket.
        if search(']', 'W')
            " Append the link ID, e.g., turn "[text]" into "[text][id]".
            execute "normal! a[" . linkid . "]"
        endif
    endif
endfunction
