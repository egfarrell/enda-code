" My misc functions

" E. Farrell 2021
" E. Farrell 2021
" E. Farrell 2021
" E. Farrell 2021
" E. Farrell 2021
" E. Farrell 2021

func! WolframPreview(expr)
    let command  = 'Export["/tmp/w.jpg", ' . a:expr . ']; StartProcess[{"viewnior", "/tmp/w.jpg"}];'
    call PasteCommand(command)
endfunc


func! SympyPreview(expr)
    " must have:
    " from sympy import preview
    let opts     = ", preamble=preamble"
    let opts    .= ", viewer='viewnior'"
    let command  = "preview('$$' + latex(" . a:expr . ") + '$$'" . opts . ")"
    call PasteCommand(command)
endfunc


func! SageMathPreview(expr)
    let command  = "view(" . a:expr .", margin=5)"
    call PasteCommand(command)
endfunc


func! TidyJupyterNotebook()
    " Remove existing cell markers
    :%s/#\ In\[.*$//ge

    " Create new cell markers above comments
    :%s/\n\n#/\r#\ In[\ ]:\r\r#/ge

    " Remove lines with only a comment
    :%s/^#\ $/\ /ge

    " remove paragraph tags
    :%s/<p>//ge
    :%s/<\/p>//ge

    " Insert final cell marker
    exec "normal! G"
    exec "normal! I# In[ ]: \<ESC><<"

    " remove multiple blank lines
    silent exec ':%!cat -s'
endfunc


func! ShowFileLocation()
    try
        let lines      =  '● ' . FormatThousands(line("$"))
        let curr_line  =  '◐ ' . FormatThousands(line("."))
        let curr_col   =  '◻ ' . virtcol(".")
        let ftype      =  '▷ ' . &filetype
        let percent    =  '▷ ' . LinePercent()

        if exists ('*popup_atcursor')
            let  infolist = []
            call add(infolist, percent)
            call add(infolist, '')
            call add(infolist, curr_line)
            call add(infolist, lines)
            call add(infolist, '')
            call add(infolist, curr_col)
            " call add(infolist, ftype)
            call popup_atcursor(infolist, #{ highlight: 'Visual', padding: [1, 2, 1, 2]} )
        else
            call FileInfo('')
        endif
    catch
        echo "\n" . v:exception
    endtry
endfunc


func! ShowCalTime()
    try
        let time   = '▶ ' . strftime('%H:%M')
        let date   = strftime('%b-%d')

        if exists ('*popup_atcursor')
            let  infolist = []
            call add(infolist, time . '   □ ' . date)
            call popup_atcursor(infolist, #{ highlight: 'Visual', padding: [1, 2, 1, 2]} )
        else
            call BlankLine()
            call EchoItem('Date:', date, 'NONE')
            call EchoItem('Time:', time,  'NONE')
            call BlankLine()
        endif
    catch
        echo "\n" . v:exception
    endtry
endfunc


func! CustomTagJump()
    try
        " set noignorecase <-- if you want more exact jumping
        exec 'tjump ' . expand("<cword>")
        " set ignorecase
        if exists ('*popup_atcursor')
            " display current filename in popup
            let file_name  = ' ▶ ' . expand('%')
            " let curr_line  = FormatThousands(line("."))
            let curr_line  = line(".")
            let infolist   = [file_name . '  :' . curr_line]
            call popup_atcursor(infolist, #{  highlight: 'Visual', padding: [1, 1, 1, 0]} )
        endif
    catch
        echo "\n" . v:exception
    endtry
endfunc


func! Proccess_ctrl_n()
    let thisbuf = bufname()
    if (thisbuf == '!gdb') || (thisbuf == 'debugged program')
        " Exit normal mode & return to Terminal-Job mode.
        echo "Terminal-Job"
        normal! i
    else
        " We're in the source code
        echo "<c-n> disabled in source window"
    endif
endfunc


func! DebugSetup()
        " Customise GDB debugging session

        " Source code buffer mappings
        " --------------------------------
        " Note: "Over"  = gdb "next"
        nnoremap    N          :Over<CR>
        nnoremap    <CR>       :Over<CR>
        nnoremap    B          :Break<CR>
        nnoremap    X          :Clear<CR>
        nnoremap    S          :Step<CR>
        nnoremap    F          :Finish<CR>
        nnoremap    C          :Continue<CR>
        nnoremap    Q          :Stop<CR>


        " Terminal 'tmap' mappings
        " ----------------------------------
        " <c-f>:  Next window
        " <c-e>:  Next tab
        " <c-n>:  Enter "Terminal-Normal" mode
        tnoremap <silent>  <c-f>    <C-W>W
        tnoremap <silent>  <c-e>    <C-W>gt
        tnoremap <silent>  <c-n>    <c-W>N:echo "Normal Mode"<CR>


        " Normal mode mappings
        " ----------------------------------
        " e.g. for 'Source Window'
        " <c-f>:  Next window
        " <c-e>:  Next tab
        " <c-n>:  Special behaviour depending on window
        nnoremap <silent>  <c-f>    <C-W><C-W>
        nnoremap <silent>  <c-e>    <C-W>gt
        noremap  <silent>  <c-n>    :call Proccess_ctrl_n()<CR>


        " Misc settings
        " ----------------------------------
        set number


        " Activate termdebug
        " ----------------------------------
        packadd termdebug
        Termdebug


        " put "program window" in separate *TAB*
        wincmd j
        wincmd T
        exec "normal! \<c-w>gt"
endfunc


function! AddBulletpoint()
    let first_char = getline('.')[0]
    if first_char == '#'
        " We're on a heading.
        " Insert top-level bullet point
        exec "normal! A\<CR>\<tab>-"
        exec "normal! \<right>\<right>"
    else
        " insert bullet-point on new line with 
        " correct indentation
        exec "normal! A\<CR>-"
        exec "normal! <<"
    endif
    startinsert
endfunc


function! SetViewer()
    let viewer = inputlist(['Set Viewer:',
        \  '1. pdf_viewer   = Firefox',
        \  '2. pdf_viewer   = Evince',
        \  '3. image_viewer = gpicview',
        \  '4. image_viewer = Kolourpaint',
        \  '5. video_viewer = mpv',
        \  '6. video_viewer = Firefox',
        \  '7. web_browser  = Firefox',
        \  '8. web_browser  = Chromium'])
    if viewer == 1
        let g:pdf_viewer   = 'firefox'
    elseif viewer == 2
        let g:pdf_viewer   = 'evince'
    elseif viewer == 3
        let g:image_viewer = 'gpicview'
    elseif viewer == 4
        let g:image_viewer = 'kolourpaint'
    elseif viewer == 5
        let g:video_viewer = 'vlc'
    elseif viewer == 6
        let g:video_viewer = 'firefox'
    elseif viewer == 7
        let g:web_browser  = 'firefox'
    elseif viewer == 8
        let g:web_browser  = 'chromium-browser'
    else
        " pass
    endif
endfunc


function! FindFootnote()
    " position cursor at start of footnote
    let current_char = getline('.')[col('.') - 1]
    if current_char != '^'
        " find next footnote
        normal! f^
    endif
    let current_char = getline('.')[col('.') - 1]
    if current_char == '^'
        try
            " copy footnote to 'f' reg and search
            normal! ve"fy
            exec 'normal! /\V' . @f . ']' . "\<CR>"
        catch
        endtry
    endif
endfunc


function! ScreenshotMove(target_path)
    " Call bash script to move Screenshots from 'Downloads' to 'target_path'.
    " Then insert the new image path into current vim buffer.
    if (a:target_path =~ 'jpg')
        " target has file extension already
        let file_extension = ''
    else
        " add file extension
        let file_extension  = '.jpg'
    endif

    " define script
    let bash_script = '$HOME/bin/screenshot_move.sh ' . a:target_path . file_extension

    " Execute script & afterwards insert image path into buffer
    " (image path stored in tmp file: 'screenshot_path')
    exec ':AsyncRun -post=read\ /tmp/screenshot_path ' . bash_script
endfunc


function! TmuxSendText(text)
    " TmuxSendText/TmuxSendText based on https://github.com/benmills/vimux
    " Copyright (c) 2103 Benjamin Mills

    " HACK: 'send-keys' cant send ';' as final character.
    " Bad for SQL and Maxima. Add trailing space to fix.
    if a:text[-1:] == ';'
        let trailing_space = ' '
    else
        let trailing_space = ''
    endif

    call TmuxSendKeys('"' . escape(a:text, '\"$`') . trailing_space . '"')
endfunc


function! TmuxSetTargetPane()
    " Paste into which Tmux window/pane?
    let current_win  = system("tmux display-message -p '#I'")
    let current_win  = substitute(current_win, '\n', '', 'g')
    let tmux_pane    = '2'
    let target = current_win . "." . tmux_pane
    return target
endfunc


function! TmuxSendKeys(keys)
    let target = TmuxSetTargetPane()   " too slow for Gitbash
    " let target = g:TmuxTargetPane

    if (strpart(a:keys, 0, 3) == '"--') ||
    \  (strpart(a:keys, 0, 2) == '--')
        " Send-keys fails if keystrokes begin with "--".
        " This affects SQL comments and an iPython command.
        " Add literal option "-l" to fix.
        let rc = system("tmux send-keys -t " . target . " -l '' " . a:keys)
    else
        let rc = system("tmux send-keys -t " . target . " " . a:keys)
    endif

    if (rc != "") | echo "Error: " . rc | endif
endfunc


func! TempBuf(split)
    " Create buffer to hold list of files
    if a:split == g:h_split
        " horizontal
        10new
    else
        " vertical
        vertical 45new
    endif

    " buffer options
    setlocal bt=nofile bh=wipe nobl noswf

    " Auto-delete this buffer when leaving
    let g:temp_bufnr = bufnr("%")
    autocmd WinLeave <buffer> silent! exec "bwipe " . g:temp_bufnr

    " Mappings
    nnoremap <silent> <buffer>   <CR>    :call TempBuf_LoadFile()<CR>
    cnoremap <silent> <buffer>   <c-g>    <c-c>:q!<CR>
    cnoremap <silent> <buffer>   <c-o>    <c-c>
endfunc


func! TempBuf_LoadFile()
    normal! 0
    " Get file under cursor
    let current_path = expand("<cfile>:p", g:no_wildignore)
    " Jump to previous window split.
    " (Side effect: deletes this 'TempBuf')
    wincmd p
    if isdirectory(current_path)
        call MyFileBrowser(current_path, g:v_split, 1)
    else
        exec 'edit ' . current_path
    endif
endfunc


func! ValidateFiles(list)
    let valid_files = []
    for f in a:list
        " Only return files that EXIST
        if ! empty(glob(f, g:no_wildignore))
            call add(valid_files, f)
        endif
    endfor
    return uniq(valid_files)
endfunc


func! MyRecentFiles()
    call TempBuf(g:h_split)
    " Save jumplist to 'j' register and create list.
    " (clunky method - works with old vim versions)
    redir @j
    silent! ju
    redir END
    let jumplist = split(@j, "\n")

    " extract filename from jumps (stored position 16 onwards)
    let ju_files = []
    for jump in jumplist
        let f = jump[16:]
        call add(ju_files, f)
    endfor

    let valid_old = ValidateFiles(v:oldfiles)
    let valid_ju  = ValidateFiles(ju_files)

    " paste file lists into buffer,
    " most recent at the bottom...
    silent! put =valid_old
    silent! put =valid_ju
    silent! exec '%s/\ /\\ /g'
    silent! normal! G

    " Restrict search to *filename* only.
    " (ignore path by using a regex lookahead)
    silent! call feedkeys("?" . g:negative_lookahead, 'n')
    silent! call feedkeys("\<HOME>")
endfunc


func! MyFileBrowser(dir, split_type, depth)
    " create file buffer
    call TempBuf(a:split_type)

    if a:split_type == g:h_split
        " HORIZONTAL WINDOW [above]
        silent! exec ":read! find " . a:dir . " -maxdepth " . a:depth . g:MyFileBrowser_Exclude . " -or -type f"
        silent! exec '%s/\ /\\ /g'
        silent! exec ':sort i'
        silent! normal! "_dd
        call matchadd('Comment', '^.*\/')
        silent! call feedkeys('/' . g:negative_lookahead, 'n') " 'n' = dont remap keys
        silent! call feedkeys("\<HOME>")
    else
        " VERTICAL WINDOW [left]
        " A poor mans 'netrw' replacement...
        silent! exec ":read! ls --group-directories-first " . a:dir
        silent! exec '%s/\ /\\ /g'
        silent! normal! gg
        " insert handy link to parent folder
        silent! exec "normal! i../\<ESC>"
        exec 'cd ' . a:dir
    endif
endfunc


func! InsertCalDate()
    " note: hours/mins  (%H:%M)
    let today = strftime("%d-%b-%y %a")
    exec "normal! O### " . today . "\<esc>"
endfunc


func! BubbleLineUp()
    let last_line = line('$')
    if line('.') == 1
        echo "Top of buffer"
    elseif line('.') == last_line
        normal! "zddk"zp
    else
        normal! "zddk"zP
    endif
endfunc


func! YankAll()
    " copy buffer to clipboard
    if has('unnamedplus')
        exec '%y+'
    else
        exec '%y'
    endif
endfunc


func! RemoveWhitespace()
    " Removes :
    "   - leading blank lines at top of file
    "   - trailing whitespace from each line
    "   - trailing blank lines from bottom of file

    " save position
    normal! mt

    " remove leading blanklines (top of file)
    0/\S
    let leading_blank_lines  = line (".") - 1
    if leading_blank_lines > 0
        normal! 1G
        exec 'normal! "_' . leading_blank_lines . 'dd'
    endif

    " remove trailing whitespace (end of line)
    :%s/\s\+$//e

    " remove trailing blanklines (end of file)
    "    \(    Start match group
    "    $\n   Match a new line (end-of-line character followed by carriage return).
    "    \s*   Allow any amount of whitespace on this new line
    "    \)    End match group
    "    \+    Allow any number of occurrences of this group (one or more).
    "    \%$   Match the end of the file
    "    e     supress error msgs
    :%s#\($\n\s*\)\+\%$##e

    " restore position
    silent! normal! `tzz
endfunc


func! GoMiddle()
    let line_length = len(getline ("."))
    let half_way    = line_length / 2
    exec "normal! 0" . half_way . "l"
endfunc


func! GoLeft()
    " jump to first non-whitespace character in current line...
    let save_col = virtcol('.')
    normal! ^
    let new_col = virtcol('.')
    if (save_col == new_col)
        " already at first non-whitespace character,
        " jump to start of line instead...
        normal! 0
    endif
endfunc


func! EchoWordCount()
    exe "silent normal! g\<c-g>"
    let s:word_count = str2nr(split(v:statusmsg)[11])
    echo 'Word Count: ' . FormatThousands(s:word_count)
endfunc


func! OverPaste_EOL()
    " firstly, save position and
    " delete to end of line
    normal! mz
    normal! "_D

    " remove carriage return lines from all 3 paste registers
    " (because I never know which one its pasted from)
    try
        let @+ = RemoveLineEndings(@+)
    catch
    endtry
    try
        let @* = RemoveLineEndings(@*)
    catch
    endtry
    let @" = RemoveLineEndings(@")
    normal! P
    normal! `z
endfunc


func! PasteEndLine(add_space)
    " save current search and position
    let save_search = @/
    normal! mz

    " remove trailing whitespace from current line
    " ('//e': supress error msgs)
    execute ':.s/\s\+$//e'
    " paste-append at end of current line
    if a:add_space
        exec "normal! A\<space>\<esc>p"
    else
        exec "normal! $p"
    endif
    " restore old values
    let @/ = save_search
    silent! normal! `z
endfunc


func! MyAlternate()
  if expand('#') == ""
      bprevious
  else
    exe "normal! \<c-^>"
  endif
endfunc


func! VisualBlockParagraph(animate)
        " Create a visual block, one column wide, to end of current paragraph.
        " Or to end-of-file if "end_paragraph" is empty...
        let eof = line('$')
        exec "normal! }"
        if line('.') == eof
            let end_paragraph = ''
        else
            let end_paragraph = line('.') - 1
        end
        " return to starting position
        " and create visual block.
        exec "normal! \<c-o>"
        exec "normal! \<c-v>" . end_paragraph . "G"
        if a:animate
            sleep 20m
        endif
endfunc


func! ToggleSpelling()
    if (&spell)
        " disable spelling
        syntax enable
        setlocal nospell
        let g:spell_status = ''
    else
        " enable spelling
        set syntax=dummy
        setlocal spell spelllang=en_gb
        let g:spell_status = '[SPELL]'
    endif
endfunc


func! CustomSaveAs()
    call BlankLine()
    let current_path = expand('%:p:h') . '/'
    let new_name     = input('Save As: ', current_path, 'file')
    try
        " Attempt to save buffer using new file name.
        " (sometimes windows adds extra escape characters
        " so remove them using 'fnameescape'...)
        exec ':saveas ' . fnameescape(new_name)
    catch
        call BlankLine()
        call EchoItem('Error: ', v:exception, 'ErrorMsg')
    endtry
endfunc


func! SudoSave()
    echohl User2
    let new_name = input('-- [SUDO] Save As: ', expand('%:p'), 'file')
    echohl None
    if (new_name != '')
        " escape any spaces in name
        let escape_new_name = fnameescape(new_name)
        try
            " use tee with sudo permissions to write the buffer
            :silent exec 'write !sudo tee ' . escape_new_name . '>/dev/null' | silent edit!
        catch
            call BlankLine()
            call EchoItem('Error: ', v:exception, 'ErrorMsg')
        endtry
    endif
endfunc


func! DeleteFile()
    let filename = fnameescape(expand('%:p'))
    let confirm = input('Delete this file? (y/[n]) ')
    set noignorecase
    if confirm == "y"
        try
            let result = delete(filename)
            if result == 0
                exec ':bdelete! ' . filename
                redraw!
                echo "\nFile deleted."
            else
                echo "\nDelete Failed. Return code: " . string(result)
            endif
        catch
            call BlankLine()
            call EchoItem('Error: ', v:exception, 'ErrorMsg')
        endtry
    else
        redraw!
        echo "Delete aborted."
    endif
    set ignorecase
endfunc


func! RenameFile()
    let old_name = expand('%:p')
    let new_name = input('Rename: ', old_name, 'file')
    " Compare names
    " (case sensitive: "!=#")
    if (new_name !=# old_name)
        try
            " 1. Save new buffer
            " 2. Delete old buffer & file
            exec ':saveas '   . fnameescape(new_name)
            exec ':bdelete! ' . fnameescape(old_name)
            call delete(old_name)
            redraw!
        catch
            echohl ErrorMsg | echo "\n" . v:exception | echohl None
        endtry
    else
        redraw!
        echo "Name unchanged."
    endif
endfunc


func! GrepCustomFolder(custom_folder, search_term)
    " Wrapper for searching non-standard folder
    call GrepQuickFix(a:custom_folder, '*', a:search_term)
endfunc


func! GrepQuickFix(folder, files, pattern)
    " Sanity check
    if !isdirectory(a:folder)
        echo 'Not found: ' . a:folder
        return
    endif

    if (a:files == 'my-txt-files.txt' || a:files == 'my-pdfs.txt')
        " Non-standard:
        " I'm looking for a *file name*,
        " rather than piece of text.
        let g:qf_special_case = 1
    else
        let g:qf_special_case = 0
    endif


    " Change directory and create new buffer.
    " (this sets CWD='a:folder' ensuring
    " grep doesn't output long filepaths)
    exec 'cd ' . a:folder
    enew

    if has('win32')
        " use slower 'vimgrep' on windows
        echo 'Searching...'
        exec 'vimgrep  /' .  a:pattern . '/j ' . '**/*'
    else

        if g:qf_special_case == 1
            " non-standard case:
            " Match a filename at end of a filepath.
            " (Use '-P' and negative lookback to match after final '/')
            let file_sep = "/"
            let regex    = "'^.*" . file_sep . ".*" . a:pattern . "((?!" . file_sep . ").)*$'"
            silent exec "silent grep! -Iir -P " . regex . " " . a:files
        else
            " standard case
            silent exec "silent grep! -Iir -e "     .  a:pattern . ' ' . a:files
        endif
    endif

    " display results in quickfix
    " and delete earlier buffer
    copen
    redraw!
    wincmd p
    exec 'bdelete'
    call clearmatches()

    " highlight matches
    if g:qf_special_case == 1
        " Note: '\\c' = ignore case
        call matchadd('User8_paths',  "$.*\/")
        call matchadd(g:qf_highlight_color, a:pattern . "\\(.*\/\\)\\@!\\c")
    else
        call matchadd(g:qf_highlight_color, "\\(|.*\\)\\@<=" . a:pattern . "\\c")
    endif

    " store grep pattern in search register
    let @/ = a:pattern
endfunc


func! MyFileOpener()
    " Custom function to open PDFs, images, txt....
    let file = expand("<cfile>", g:no_wildignore)

    if empty(glob(file, g:no_wildignore))
        " Cant find file. Jump to end-of-line and try again.
        " (Maybe bulletpoint in the way)
        silent! normal! g_
        let file = expand("<cfile>", g:no_wildignore)

        if empty(glob(file, g:no_wildignore))
            " Still cant find file - quit!
            echo 'Not found: ' . file
            return
        endif
    endif

    if file =~ '\(\.jpg\|\.png\|\.gif\|\.svg\)'
        call ViewFile(file, g:image_viewer)

    elseif file =~ '\.pdf'
        call ViewFile(file, g:pdf_viewer)

    elseif file =~ '\(\.mp4\|\.mkv\|\.m3u\|\.mp3\|\.webm\|\.flv\|\.3gp\)'
        call ViewFile(file, g:video_viewer)

    elseif file =~ '\.djvu'
        call ViewFile(file, g:djvu_viewer)

    else
        " ordinary file/folder
        exec 'edit ' . file
    endif

endfunc


func! ViewFile(filepath, viewer)
    let path = a:filepath

    if has('win32unix')
        " We're in GitBash. Convert POSIX path to Windows.
        let path = system("cygpath.exe -aw " . path)
        let path = substitute(path, '\n', '', 'g')
        let path = shellescape(path)
    endif

    " alternative:
    " silent! exec ':AsyncRun ' . a:viewer . " " . path

    " Run as a background job, routing all messages to NULL
    silent! exec '!' . a:viewer . " " . path . ' &> /dev/null &'
    redraw!
endfunc


func! OpenURL(line)
    " match all non-whitespace characters from 'http' onwards...
    " (regex halts when encounters a blank space)
    let URL  = matchstr (a:line, '\(http\|file:\)\+\S*')
    " let URL  = matchstr (a:line, 'http\S*')
    " remove any trailing brackets
    let URL = substitute(URL, ')', '', 'g')
    if empty(URL)
        echo 'URL not found.'
    else
        try
            " old way: use AsyncRun
            " (but AsyncRun  routes output into the quickfix
            " window which I dont want when opening URLs)
            " silent! exec ':AsyncRun! ' . g:web_browser. " " . shellescape(URL, 1)

            " Run as a background job, routing output to NULL
            silent! exec '!' . g:web_browser . " " . shellescape(URL, 1) . ' &> /dev/null &'
            redraw!
        catch
            echo "\n" . v:exception
        endtry
    endif
endfunc


func! GoogleSearch(search_string)
    try
        let cmd = 'https://www.google.co.uk/search?q=' . a:search_string
        silent! exec ':AsyncRun ' . g:web_browser. " " . shellescape(cmd, 1)
        redraw!
    catch
        echo "\n" . v:exception
    endtry
endfunc


func! SplitWindow(split_type)
    " first create window split
    exec 'wincmd ' . a:split_type
    " try to load the alternate file
    " or just use the prefious buffer
    " if no alternate...
    if expand('#') == ""
        bprevious
    else
        edit #
    endif
    " place cursor in new split
    wincmd w
endfunc


func! MarkdownCompile()
    if &filetype == 'markdown'
        " compile markdown file using pandoc
        " (use Bash function defined in ~/.bash_aliases)
        exec ':silent ! compile_md %'
        redraw!
    else
        echo "Cannot compile. Not a Markdown file."
    endif
endfunc


func! LatexCompile()
    if &filetype == 'tex'
        " compile current Latex file
        " (use Bash function defined in ~/.bash_aliases)
        exec ':silent ! compile_tex %'
        redraw!
    else
        echo "Cannot compile. Non-Latex file."
    endif
endfunc


func! CustomBufferDelete()
    let window_count = winnr('$')
    if (window_count > 1)
        " We're in a split. A deleted buffer will break the split
        " which is jarring. Just load previous buffer instead.
        try
            bprevious
        catch
        endtry
    else
        " No split: safe to delete!
        bdelete!
    endif
endfunc


func! CodeCellYank()
    try
        " locate both cell markers and yank inbetween them
        silent! normal! mz
        silent normal! 0j
        silent exec 'normal! ?'  . g:CODE_CELL_START . "\<CR>"
        silent normal! 0j
        silent exec 'normal! v/' . g:CODE_CELL_END   . "\<CR>"
        silent normal! k$
        silent normal! y
        silent! normal! `z
    catch
        " Execute "ctrl+c" to ensure we're not
        " stuck in a funny mode.
        silent! exec "normal! \<C-c>"
        " Clear all clipboard registers so nothing funny
        " gets pasted into a repl further down the line.
        try | let @+ = '' | catch | endtry
        try | let @* = '' | catch | endtry
        try | let @" = '' | catch | endtry
        echoerr "Cannot find Code cell"
    endtry
endfunc


func! CodeCellPaste()
    " Send code cell contents into a Tmux pane
    call CodeCellYank()
    call PasteClipboard()
endfunc


func! CodeCellAdvance()
    " move to start of next code cell
    silent! exec 'normal! /' . g:CODE_CELL_START . "\<CR>"
    silent! normal! zz
endfunc


func! RemoveLispComments(string)
    " Use NON-GREEDY regex search... 
    " to remove from ';' to end of current line
    return substitute(a:string, ';.\{-}\n', '', 'g')
endfunc


func! RemoveLineEndings(string)
    return substitute(a:string, '\n', ' ', 'g')
endfunc


func! RemoveBlankLines(string)
    " Do step-by-step approach,
    " otherwise get funny result sometimes.
    let new = substitute(a:string, '\n\n',  '\n', 'g')
    let new = substitute(new,      '\n\n',  '\n', 'g')
    let new = substitute(new,      '\n\n',  '\n', 'g')
    let new = substitute(new,      '\_s*$', '',   '') " trailing white space
    " dont remove leading blank lines (maxima looks better)
    " let new = substitute(new,      '^\n',   '',   '') " leading blank line
    return new
endfunc


func! PasteCommand(command)
    if a:command != ''
        " paste command into Tmux pane (REPL)
        call TmuxSendText(a:command)
        call TmuxSendKeys("Enter")
    endif
endfunc


func! PasteClipboard()
    " use Tmux to send clipboard contents to REPL
    let clipboard = @"

    if (&filetype == 'python')
        if g:ipython_clipboard_paste
            " Use system clipboard.
            " '-q' = dont echo pasted block (quiet).
            call TmuxSendText("%paste -q")
            call TmuxSendKeys("Enter")
        else
            " use iPython '%cpaste' instead of clipboard
            " and terminate with "--"
            call TmuxSendText('%cpaste -q')
            call TmuxSendKeys("Enter")
            sleep 200m

            " " Method 1
            " let cell_lines = split(clipboard, "\n")
            " for line in cell_lines
                " " ignore comments and blank lines
                " if (line !~ "^#") && (line !~ "^\s*$")
                    " sleep 50m
                    " call TmuxSendText(line)
                    " sleep 50m
                    " call TmuxSendKeys("Enter")
                " endif
            " endfor

            " Method 2
            call TmuxSendText(clipboard)

            sleep 50m
            call TmuxSendKeys("Enter")
            call TmuxSendKeys("--")
            call TmuxSendKeys("Enter")
        endif

    elseif (&filetype == 'lisp')   ||
         \ (&filetype == 'scheme') 
        " Remove comments, line-breaks etc
        let clipboard = RemoveLispComments(clipboard)
        let clipboard = RemoveLineEndings(clipboard)
        call TmuxSendText(clipboard)
        call TmuxSendKeys("Enter")

    elseif (&filetype == 'clojure')   
        " Remove comments, line-breaks etc
        let clipboard = RemoveLispComments(clipboard)
        if (g:use_tmux_clojure == 1)
            let clipboard = RemoveLineEndings(clipboard)
        endif
        call TmuxSendText(clipboard)
        call TmuxSendKeys("Enter")

    elseif (&filetype == 'maxima') ||
         \ (&filetype == 'wl')
        " Remove line-breaks first
        let clipboard = RemoveLineEndings(clipboard)
        call TmuxSendText(clipboard)
        call TmuxSendKeys("Enter")

    else
        " all other file types
        call TmuxSendText(clipboard)
        call TmuxSendKeys("Enter")
    endif
endfunc


func! FormatThousands(number)
    " Via stackoverflow
    let separator = ','
    return substitute(a:number, '\(\d,\d*\)\@<!\d\ze\(\d\{3}\)\+\d\@!', '&' . separator, 'g')
endfunc

" Where in a file are we?
function! LinePercent()
    return line('.') * 100 / line('$') . '%'
endfunction


func! FileInfo(how_much)
        let file_name  =  expand('%')
        let path       =  expand('%:p:~:h')
        let x          =  virtcol(".")
        let y          =  line(".")
        let curr_line  =  '◐ ' . FormatThousands(line("."))
        let lines      =  '● ' . FormatThousands(line("$"))
        let loc        =  curr_line  . ' ... ' . lines


        if (a:how_much == 'short') && (exists ('*popup_atcursor'))
            let infolist = []
            call add(infolist, '▶ ' . file_name)
            call add(infolist, '')
            call add(infolist, '  ▷ ' . &filetype)
            call add(infolist, '  '   . path)
            call popup_atcursor(infolist, #{ highlight: 'Visual', padding: [1, 2, 1, 2]} )
        else
            call BlankLine()
            call EchoItem('file:',  file_name             , 'Normal')
            call EchoItem('path:',  path                  , 'Normal')
            call EchoItem('ft:' ,   '(' . &filetype . ')' , 'Normal')
            call EchoItem('loc:',   loc                   , 'Normal')
            call EchoItem('col:',   x                     , 'Comment')
            call EchoItem('tw:',    &tw                   , 'Comment')
            call EchoItem('ff:',    &ff                   , 'Comment')
            call EchoItem('fenc:',  &fileencoding         , 'Comment')
            call EchoItem('enc:',   &encoding             , 'Comment')
            call BlankLine()
        endif
endfunc


func! EchoItem(label, text, colour)
    set nomore
    " draw label
    echohl Comment
    if len(a:label) < 8
        let  padded_label = ''
        let  padded_label = a:label . repeat(' ', 8 - len(a:label))
        echo padded_label
    else
        echo a:label
    endif
    " draw text in specified colour
    exec 'echohl ' . a:colour
    echon a:text
    echohl None
    set more
endfunc


func! BlankLine()
    set nomore
    echo ' '
    set more
endfunc
