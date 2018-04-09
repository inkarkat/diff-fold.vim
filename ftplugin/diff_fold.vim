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

if ! diff_fold#ProcessBuffer()
    finish
endif

" make the foldtext more friendly
setlocal foldtext=diff_fold#FoldText()

augroup diff_fold
    autocmd! BufEnter <buffer> call diff_fold#UpdateDiffFolds()
augroup END

let b:undo_ftplugin = (exists('b:undo_ftplugin') ? b:undo_ftplugin . '|' : '') . 'setlocal foldtext< | execute "autocmd! diff_fold * <buffer>"'
