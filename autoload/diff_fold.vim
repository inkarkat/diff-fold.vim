"-------------------------------------------------------------------------------
" File: autoload/diff_fold.vim
"
" Original Author: Ryan Mechelke <rfmechelke AT gmail DOT com>
" Author:    Ingo Karkat <ingo@karkat.de>
"
" DEPENDENCIES:
"   - ingo/strdisplaywidth.vim autoload script
"   - ingo/window/dimensions.vim autoload script
"
"-------------------------------------------------------------------------------

function! s:FoldSmallerFoldlevel( foldLevel ) range
    if foldlevel('.') < a:foldLevel
        execute foldlevel('.') a:firstline . ',' . a:lastline . 'fold'
    endif
endfunction
function! s:FoldMultipleLines() range
    if a:firstline != a:lastline
        execute a:firstline . ',' . a:lastline . 'fold'
    endif
endfunction
function! diff_fold#ProcessBuffer( ... )
    if ! (&l:foldmethod ==# 'manual' || &l:foldmethod ==# 'marker')
        return
    endif

    if a:0
        let l:changesetExpr = a:1
    elseif exists('b:diff_fold_changesetExpr')
        let l:changesetExpr = b:diff_fold_changesetExpr
    else
        let l:changesetExpr = '^# HG changeset patch'
    endif

    " get number of lines
    let last_line=line('$')
    let l:save_cursor = getpos('.')[1:2]
    call cursor(1, 1)

    try
        " delete all existing folds
        silent! normal! zE

        " fold all hunks
        silent! execute printf('keepjumps global/^@@/.,/\(%s\|^Index: \|^diff\|^--- .*\%( ----\)\@<!$\|^@@\)/-1 fold', l:changesetExpr)
        call cursor(line('$'), 1)
        if search(printf('\(%s\|^Index: \|^diff\|^--- .*\%( ----\)\@<!$\|^@@\)', l:changesetExpr), 'bcW') && getline('.') =~# '^@@'
            exec ".," . last_line . "fold"
        endif

        " fold file diffs
        silent! execute printf('keepjumps global/^Index: \|^diff/.,/\(%s\|^Index: \|^diff\)/-1 call s:FoldMultipleLines()', l:changesetExpr)
        silent! execute printf('keepjumps global/^--- .*\%( ----\)\@<!$/.,/\(%s\|^Index: \|^diff\|^--- .*\%( ----\)\@<!$\)/-1 call s:FoldSmallerFoldlevel(1)', l:changesetExpr)
        call cursor(line('$'), 1)
        if search('^Index: \|^diff', 'bcW')
            exec ".," . last_line . "fold"
        elseif search('^--- .*\%( ----\)\@<!$', 'bcW')
            exec ".," . last_line . "fold"
        endif

        " fold changesets (if any)
        if search(l:changesetExpr, '')
            let b:diff_fold_changesetExpr = l:changesetExpr

            silent! execute printf('keepjumps global/%s/.,/%s/-1 call s:FoldMultipleLines()', l:changesetExpr, l:changesetExpr)
            call cursor(line('$'), 1)
            if search(l:changesetExpr, 'bcW')
                exec ".," . last_line . "fold"
            endif
        endif
    catch /E350/
        return 0
    finally
        nohlsearch
        call cursor(l:save_cursor)
        call histdel('search', -1)
    endtry

    let b:diff_fold_update = b:changedtick
    return 1
endfunction

function! diff_fold#FoldText()
    let foldtext = "+" . v:folddashes . " "
    let line = getline(v:foldstart)

    if line =~# "^changeset.*"
        let foldtext .= substitute(line, "\:   ", " ", "")
    elseif line =~# "^diff.*"
        if (line =~# "diff -r")
            let matches = matchlist(line, '\Cdiff \%(-r [a-z0-9]\+ \)\+\(.*\)$')
            let foldtext .= matches[1]
        else
            let matches = matchlist(line, '\C\sa/\(.*\)\s\+b/')
            if empty(matches)
                let matches = matchlist(line, '\C\sc/\(.*\)\s\+i/')
            endif
            if empty(matches)
                let matches = matchlist(line, '\C\si/\(.*\)\s\+w/')
            endif
            if ! empty(matches)
                let foldtext .= matches[1]
            endif
        endif
    elseif line =~# "^Index: .*"
        if ingo#strdisplaywidth#HasMoreThan(line, ingo#window#dimensions#NetWindowWidth() - len(foldtext) - 1)
            let foldtext .= 'Index: ' . fnamemodify(line[7:], ':t')
        else
            let foldtext .= line
        endif
    else
        let foldtext .= line
    endif

    let foldtext .= " (" . (v:foldend - v:foldstart) . " lines)\t"

    return foldtext
endfunction

function! diff_fold#UpdateDiffFolds()
    if ! exists('b:diff_fold_update') || b:changedtick != b:diff_fold_update
        call diff_fold#ProcessBuffer()
    endif
endfunction
