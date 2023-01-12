if exists('g:loaded_codeium_log')
  finish
endif
let g:loaded_codeium_log = 1

if !exists('s:logfile')
  let s:logfile = expand(get(g:, 'codeium_log_file', tempname() . '-codeium.log'))
  try
    call writefile([], s:logfile)
  catch
  endtry
endif

function! codeium#log#Logfile() abort
  return s:logfile
endfunction

function! codeium#log#Log(level, msg) abort
  let min_level = toupper(get(g:, 'codeium_log_level', 'WARN'))
  " echo "logging to: " . s:logfile . "," . min_level . "," . a:level . "," a:msg
  for level in ['ERROR', 'WARN', 'INFO', 'DEBUG', 'TRACE']
    if level == toupper(a:level)
      try
        if filewritable(s:logfile)
          call writefile(split(a:msg, "\n", 1), s:logfile, 'a')
        endif
      catch
      endtry
    endif
    if level == min_level
      break
    endif
  endfor
endfunction

function! codeium#log#Error(msg) abort
  call codeium#log#Log('ERROR', a:msg)
endfunction

function! codeium#log#Warn(msg) abort
  call codeium#log#Log('WARN', a:msg)
endfunction

function! codeium#log#Info(msg) abort
  call codeium#log#Log('INFO', a:msg)
endfunction

function! codeium#log#Debug(msg) abort
  call codeium#log#Log('DEBUG', a:msg)
endfunction

function! codeium#log#Trace(msg) abort
  call codeium#log#Log('TRACE', a:msg)
endfunction

function! codeium#log#Exception() abort
  if !empty(v:exception)
    call codeium#log#Error('Exception: ' . v:exception . ' [' . v:throwpoint . ']')
  endif
endfunction
