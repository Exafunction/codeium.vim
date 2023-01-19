let s:line_endings = {
      \ "unix": "\n",
      \ "dos": "\r\n",
      \ "mac": "\r",
      \ }

function! codeium#util#LineEndingChars(...) abort
  if has_key(s:line_endings, &ff)
    return get(s:line_endings, &ff)
  endif
  if a:0 && !empty(a:1)
    return a:1
  else
    return "\n"
  endif
endfunction

function! codeium#util#UTF8Width(str) abort
  return strchars(substitute(a:str, "\\%#=2[^\u0001-\uffff]", "    ", 'g'))
endfunction

function! codeium#util#PositionToOffset(row, col) abort
  let lines_pre = getline(1, line(a:row) - 1)
  let line = getline(a:row)
  let col_index = col(a:col) - (mode() =~# '^[iR]' || empty(line))
  call add(lines_pre, strpart(line, 0, col_index))

  let text_pre = join(lines_pre, codeium#util#LineEndingChars())
  return codeium#util#UTF8Width(text_pre)
endfunction

function! codeium#util#OffsetToPosition(offset) abort
  " Ideally we could just use byte2line, but encoding might not be UTF-8.
  let line_ending_len = len(codeium#util#LineEndingChars())
  let char_offset = a:offset + 1
  let row = 1

  for line in getline(1, '$')
    let line_len = codeium#util#UTF8Width(line) + line_ending_len
    if line_len >= char_offset
      let col_num = 1

      for s:char in split(getline(row), '\zs')
        let char_width = codeium#util#UTF8Width(s:char)
        if char_width >= char_offset
          return [row, col_num]
        endif
        let col_num = col_num + 1
        let char_offset = char_offset - char_width
      endfor
      return [row, col([row, '$'])]
    endif
    let char_offset = char_offset - line_len
    let row = row + 1
  endfor

  let row = line('$')
  return [row, col([row, '$'])]
endfunction

function! codeium#util#HasSupportedVersion() abort
  let s:nvim_virt_text_support = has('nvim-0.6') && exists('*nvim_buf_get_mark')
  let s:vim_virt_text_support = has('patch-9.0.0185') && has('textprop')

  return s:nvim_virt_text_support || s:vim_virt_text_support
endfunction
