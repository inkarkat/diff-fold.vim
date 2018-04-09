"-------------------------------------------------------------------------------
" File: ftplugin/diff_fold.vim
" Description: Folding script for Mercurial diffs
"
" Version: 0.4
"
" Original Author: Ryan Mechelke <rfmechelke AT gmail DOT com>
" Author:	Ingo Karkat <ingo@karkat.de>
"
" DEPENDENCIES:
"   - diff_fold.vim autoload script
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
