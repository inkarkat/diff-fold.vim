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
" Dependencies:
"   - ingo/strdisplaywidth.vim autoload script
"   - ingo/window/dimensions.vim autoload script
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
"   0.52 - (2018/04/09):
"       * Use :keepjumps / cursor() to avoid cluttering the jump list.
"       * Split off autoload script.
"
"   0.51 - (2018/04/04):
"       * ENH: Also support git diff format which has i/... w/...
"       * BUG: Don't fold a single diff... (or changeset...) line. Introduce
"         s:FoldMultipleLines() and :call that instead of a plain :fold (which
"         will happily create a single-line fold if asked to).
"
"   0.50 - (2018/03/16):
"       * ENH: Also support git diff format which has c/... i/... instead of
"       a/... b/...
"
"   0.49 - (2014/09/15):
"       * BUG: Following Index: parts without hunks are folded together with the
"         last hunk. Augment the regexp to match any border and explicitly check
"         for a jump to a hunk beginning.
"       * Turn off wrapping, turn on matching on current position (can happen
"         because of G command) for search() tests.
"
"   0.48 - (2014/06/25):
"       * Truncate the Index: filespec to the filename when it wouldn't fit the
"         window width. Requires the ingo-library.
"
"   0.47 - (2014/05/30):
"       * Maintain the original cursor position.
"
"   0.46 - (2013/06/14):
"       * Make matchlist() robust against 'ignorecase'.
"
"   0.45 - (2012/07/05):
"       * rename global, generic MyDiffFoldText() function to
"       diff_fold#FoldText().
"
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
function! s:FoldMultipleLines() range
    if a:firstline != a:lastline
        execute a:firstline . ',' . a:lastline . 'fold'
    endif
endfunction
function! diff_fold#ProcessBuffer()
    if ! (&l:foldmethod ==# 'manual' || &l:foldmethod ==# 'marker')
        return
    endif

    " get number of lines
    let last_line=line('$')
    let l:save_cursor = getpos('.')[1:2]
    call cursor(1, 1)

    try
        " delete all existing folds
        silent! normal! zE

        " fold all hunks
        silent! keepjumps global/^@@/.,/\(\nchangeset\|^Index: \|^diff\|^--- .*\%( ----\)\@<!$\|^@@\)/-1 fold
        call cursor(line('$'), 1)
        if search('\(\nchangeset\|^Index: \|^diff\|^--- .*\%( ----\)\@<!$\|^@@\)', 'bcW') && getline('.') =~# '^@@'
            exec ".," . last_line . "fold"
        endif

        " fold file diffs
        silent! keepjumps global/^Index: \|^diff/.,/\(\nchangeset\|^Index: \|^diff\)/-1 call s:FoldMultipleLines()
        silent! keepjumps global/^--- .*\%( ----\)\@<!$/.,/\(\nchangeset\|^Index: \|^diff\|^--- .*\%( ----\)\@<!$\)/-1 call s:FoldSmallerFoldlevel(1)
        call cursor(line('$'), 1)
        if search('^Index: \|^diff', 'bcW')
            exec ".," . last_line . "fold"
        elseif search('^--- .*\%( ----\)\@<!$', 'bcW')
            exec ".," . last_line . "fold"
        endif

        " fold changesets (if any)
        if search('^changeset', '')
            silent! keepjumps global/^changeset/.,/\nchangeset/-1 call s:FoldMultipleLines()
            call cursor(line('$'), 1)
            if search('^changeset', 'bcW')
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
            let matches = matchlist(line, '\C\sa/\(.*\)\s\s\+/')
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
