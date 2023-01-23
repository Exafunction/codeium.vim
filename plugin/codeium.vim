if exists('g:loaded_codeium')
  finish
endif
let g:loaded_codeium = 1

command! -nargs=? -complete=customlist,codeium#command#Complete Codeium exe codeium#command#Command(<q-args>)

if !codeium#util#HasSupportedVersion()
    finish
endif

function! s:SetStyle() abort
  if &t_Co == 256
    hi def CodeiumSuggestion guifg=#808080 ctermfg=244
  else
    hi def CodeiumSuggestion guifg=#808080 ctermfg=8
  endif
  hi def link CodeiumAnnotation Normal
endfunction

function! s:MapTab() abort
  if !get(g:, 'codeium_no_map_tab', v:false)
    imap <script><silent><nowait><expr> <Tab> codeium#Accept()
  endif
endfunction

augroup codeium
  autocmd!
  autocmd InsertEnter,CursorMovedI,CompleteChanged * call codeium#DebouncedComplete()
  autocmd BufEnter     * if mode() =~# '^[iR]'|call codeium#DebouncedComplete()|endif
  autocmd InsertLeave  * call codeium#Clear()
  autocmd BufLeave     * if mode() =~# '^[iR]'|call codeium#Clear()|endif

  autocmd ColorScheme,VimEnter * call s:SetStyle()
  " Map tab using vim enter so it occurs after all other sourcing.
  autocmd VimEnter             * call s:MapTab()
augroup END

imap <Plug>(codeium-dismiss)     <Cmd>call codeium#Clear()<CR>
if empty(mapcheck('<C-]>', 'i'))
  imap <silent><script><nowait><expr> <C-]> codeium#Clear() . "\<C-]>"
endif
imap <Plug>(codeium-next)     <Cmd>call codeium#CycleCompletions(1)<CR>
imap <Plug>(codeium-previous) <Cmd>call codeium#CycleCompletions(-1)<CR>
imap <Plug>(codeium-complete)  <Cmd>call codeium#Complete()<CR>
if empty(mapcheck('<M-]>', 'i'))
  imap <M-]> <Plug>(codeium-next)
endif
if empty(mapcheck('<M-[>', 'i'))
  imap <M-[> <Plug>(codeium-previous)
endif
if empty(mapcheck('<M-Bslash>', 'i'))
  imap <M-Bslash> <Plug>(codeium-complete)
endif

call s:SetStyle()
call timer_start(0, function('codeium#server#Start'))

let s:dir = expand('<sfile>:h:h')
if getftime(s:dir . '/doc/codeium.txt') > getftime(s:dir . '/doc/tags')
  silent! execute 'helptags' fnameescape(s:dir . '/doc')
endif
