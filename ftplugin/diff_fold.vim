"-------------------------------------------------------------------------------
" File: diff_fold.vim
" Description: Folding script for Mercurial diffs
"
" Version: 0.4
"
" Author: Ryan Mechelke <rfmechelke AT gmail DOT com>
"
" Installation: Place in your ~/.vim/ftplugin folder
"
" Usage:
"   Pipe various Mercurial diff output to vim and see changesets, files, and
"   hunks folded nicely together.
"
"   Some examples:
"       hg in --patch | vim - -c "setlocal ft=diff"
"       hg diff | gvim -
"       hg diff -r 12 -r 13 | vim -
"
" Issues:
"   * Doesn't work with 'hg export' yet
"   * Hasn't really been tested with much beyond above use cases
"
" Changelog:
"   0.44 - (2011/09/12):
"       * filter away multiple "-r {GUID}" in foldtext, and do case-sensitive
"         comparisons there
"
"   0.43 - (2011/09/10):
"       * only do processing when suitable foldmethod is set, and otherwise
"         avoid error on 'zE'
"
"   0.42 - (2011/09/03):
"       * avoid polluting search history
"
"   0.41 - (2011/06/03):
"       * support diffs starting with "Index: " header
"
"   0.4 - (2011/05/24):
"       * support for dynamic updating of folds via autocmd
"
"   0.3 - (2011/05/24):
"       * support folding of unified diffs without a "diff" header line
"       * gracefully handle 'foldmethod' settings other than "manual" and
"         "marker" where :fold throws E350
"       * suppress search messages from :g command and avoid nested try...catch
"         for E16 by using :silent!
"
"   0.2 - (2010/10/1):
"       * changed all "exec normal" calls to "normal!"
"       * checking for existence of final hunks/diffs/changesets to avoid
"         double-folding
"       * foldtext now being set with "setlocal"
"
"   0.1 - (2010/9/30):
"       * Initial upload to vimscripts and bitbucket
"
" Thanks:
"   Ingo for the 0.2 patch!
"
"-------------------------------------------------------------------------------

function! s:FoldSmallerFoldlevel( foldLevel ) range
    if foldlevel('.') < a:foldLevel
        execute foldlevel('.') a:firstline . ',' . a:lastline . 'fold'
    endif
endfunction
function! s:ProcessBuffer()
    if ! (&l:foldmethod ==# 'manual' || &l:foldmethod ==# 'marker')
        return
    endif

    " get number of lines
    let last_line=line('$')
    normal! gg

    try
        " delete all existing folds
        silent! normal! zE
        
        " fold all hunks
        silent! g/^@@/.,/\(\nchangeset\|^Index: \|^diff\|^--- .*\%( ----\)\@<!$\|^@@\)/-1 fold
        normal! G
        if search('^@@', 'b')
            exec ".," . last_line . "fold"
        endif

        " fold file diffs
        silent! g/^Index: \|^diff/.,/\(\nchangeset\|^Index: \|^diff\)/-1 fold
        silent! g/^--- .*\%( ----\)\@<!$/.,/\(\nchangeset\|^Index: \|^diff\|^--- .*\%( ----\)\@<!$\)/-1 call s:FoldSmallerFoldlevel(1)
        normal! G
        if search('^Index: \|^diff', 'b')
            exec ".," . last_line . "fold"
        elseif search('^--- .*\%( ----\)\@<!$', 'b')
            exec ".," . last_line . "fold"
        endif

        " fold changesets (if any)
        if search('^changeset', '')
            silent! g/^changeset/.,/\nchangeset/-1 fold
            normal! G
            if search('^changeset', 'b')
                exec ".," . last_line . "fold"
            endif
        endif
    catch /E350/
        return 0
    finally
        noh
    endtry

    let b:diff_fold_update = b:changedtick
    call histdel('search', -1)
    return 1
endfunction
if ! s:ProcessBuffer()
    finish
endif

" make the foldtext more friendly
function! MyDiffFoldText()
    let foldtext = "+" . v:folddashes . " "
    let line = getline(v:foldstart)

    if line =~# "^changeset.*"
        let foldtext .= substitute(line, "\:   ", " ", "")
    elseif line =~# "^diff.*"
        if (line =~# "diff -r")
            let matches = matchlist(line, 'diff \%(-r [a-z0-9]\+ \)\+\(.*\)$')
            let foldtext .= matches[1]
        else
            let matches = matchlist(line, 'a/\(.*\) b/')
            let foldtext .= matches[1]
        endif
    else
        let foldtext .= line
    endif

    let foldtext .= " (" . (v:foldend - v:foldstart) . " lines)\t"

    return foldtext
endfunction
setlocal foldtext=MyDiffFoldText()

function! s:UpdateDiffFolds()
    if ! exists('b:diff_fold_update') || b:changedtick != b:diff_fold_update
        call s:ProcessBuffer()
    endif
endfunction
augroup diff_fold
    autocmd! BufEnter <buffer> call <SID>UpdateDiffFolds()
augroup END

let b:undo_ftplugin = (exists('b:undo_ftplugin') ? b:undo_ftplugin . '|' : '') . 'setlocal foldtext< | execute "autocmd! diff_fold * <buffer>"'
