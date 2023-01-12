let s:hlgroup = 'CodeiumSuggestion'
let s:annot_hlgroup = 'CodeiumAnnotation'
let s:request_nonce = 0

if !has('nvim')
  if empty(prop_type_get(s:hlgroup))
    call prop_type_add(s:hlgroup, {'highlight': s:hlgroup})
  endif
  if empty(prop_type_get(s:annot_hlgroup))
    call prop_type_add(s:annot_hlgroup, {'highlight': s:annot_hlgroup})
  endif
endif

let s:default_codeium_enabled = {
      \ 'help': 0,
      \ 'gitcommit': 0,
      \ 'gitrebase': 0,
      \ '.': 0}

function! codeium#Enabled() abort
  if !get(g:, 'codeium_enabled', v:true) || !get(b:, 'codeium_enabled', v:true)
      return v:false
  endif

  let codeium_enabled_languages = s:default_codeium_enabled
  call extend(codeium_enabled_languages, get(g:, 'codeium_enabled_languages', {}))
  if !get(codeium_enabled_languages, &ft, 1)
    return v:false
  endif

  return v:true
endfunction

function! codeium#CompletionText() abort
  try
    return remove(s:, 'completion_text')
  catch
    return ''
  endtry
endfunction

function! codeium#Accept() abort
  if mode() !~# '^[iR]' || !exists('b:_codeium_completions')
    return ''
  endif
  let default = get(g:, 'codeium_tab_fallback', pumvisible() ? "\<C-N>" : "\t")

  let current_completion = s:GetCurrentCompletionItem()
  if current_completion isnot v:null
    let range = current_completion.range
    let start_offset = get(range, 'startOffset', 0)
    let end_offset = get(range, 'endOffset', 0)
    let [start_row, start_col] = codeium#util#OffsetToPosition(start_offset)
    let [end_row, end_col] = codeium#util#OffsetToPosition(end_offset)
    let suffix = get(current_completion.completion, 'suffix', {})
    let suffix_text = get(suffix, 'text', '')

    let text = current_completion.completion.text . suffix_text
    if empty(text)
      return default
    endif

    let s:completion_text = text

    let insert_text = "\<C-R>\<C-O>=codeium#CompletionText()\<CR>"
    let move_to_start = "\<C-O>:call cursor(" . start_row . "," . start_col . ")\<CR>"
    let move_to_end = "\<C-O>:call cursor(" . end_row . "," . end_col . ")\<CR>"

    let delete_text = move_to_start
    if start_row == end_row
      if end_col > start_col
        let delete_text = move_to_start . "\<C-O>d" . (end_col - start_col) . "l"
      endif 
    else 
      " Delete last line, then intermediate lines.
      let delete_text = move_to_end . "\<C-O>d0" . move_to_start . repeat("\<C-O>DJ", end_row - start_row) . "\<C-O>dl"
    endif

    call codeium#server#Request('AcceptCompletion', {'metadata': codeium#server#RequestMetadata(), "completion_id": current_completion.completion.completionId})
    return delete_text . insert_text
  endif

  return default
endfunction

function! s:HandleCompletionsResult(out, status) abort
  if exists('b:_codeium_completions')
    let response_text = join(a:out, '')
    try
      let response = json_decode(response_text)
      let completionItems = get(response, 'completionItems', [])

      let b:_codeium_completions.items = completionItems
      let b:_codeium_completions.index = 0

      call s:RenderCurrentCompletion()
    catch
      call codeium#log#Error("Invalid response from language server")
      call codeium#log#Exception()
    endtry
  endif
endfunction

function! s:GetCurrentCompletionItem() abort
  if exists('b:_codeium_completions') &&
        \ has_key(b:_codeium_completions, 'items') && 
        \ has_key(b:_codeium_completions, 'index') && 
        \ b:_codeium_completions.index < len(b:_codeium_completions.items)
    return get(b:_codeium_completions.items, b:_codeium_completions.index)
  endif

  return v:null
endfunction

let s:nvim_extmark_ids = []

function! s:ClearCompletion() abort
  if has('nvim')
    let namespace = nvim_create_namespace('codeium')
    for id in s:nvim_extmark_ids
      call nvim_buf_del_extmark(0, namespace, id)
    endfor
    let s:nvim_extmark_ids = []
  else
    call prop_remove({'type': s:hlgroup, 'all': v:true})
    call prop_remove({'type': s:annot_hlgroup, 'all': v:true})
  endif
endfunction

function! s:RenderCurrentCompletion() abort
  call s:ClearCompletion()

  if mode() !~# '^[iR]' || (v:false && pumvisible())
    return ''
  endif
  let current_completion = s:GetCurrentCompletionItem()
  if current_completion is v:null
    return ''
  endif

  let start_offset = get(current_completion.range, 'startOffset', 0)
  let [start_row, start_col] = codeium#util#OffsetToPosition(start_offset)
  if start_row != line('.')
    call codeium#log#Info("Ignoring completion, line number is not the current line.")
    return ''
  endif

  let parts = get(current_completion, 'completionParts', [])

  let idx = 0
  for part in parts
    let [row, col] = codeium#util#OffsetToPosition(part.offset)
    let text = part.text

    if part.type == 'COMPLETION_PART_TYPE_INLINE' && idx == 0
      " For first inline completion, strip any characters the user has typed
      " that match the start of the completion.
      let cursor_col = col('.')
      let typed = strpart(getline('.'), col - 1, cursor_col - 1)
      if strpart(text, 0, len(typed)) != typed
        call s:ClearCompletion()
        return ''
      endif
      let text = strpart(text, len(typed))
      let col += len(typed)
    endif

    if has('nvim')
      let data = {'id': idx + 1, 'hl_mode': 'combine', 'virt_text_win_col': virtcol('.') - 1}
      if part.type == 'COMPLETION_PART_TYPE_INLINE'
        let data.virt_text = [[text, s:hlgroup]]
      elseif part.type == 'COMPLETION_PART_TYPE_BLOCK'
        let lines = split(text, "\n", 1)
        if empty(lines[-1])
          call remove(lines, -1)
        endif
        let data.virt_lines = map(lines, { _, l -> [[l, s:hlgroup]] })
      else
        continue
      endif

      call add(s:nvim_extmark_ids, data.id)
      call nvim_buf_set_extmark(0, nvim_create_namespace('codeium'), row - 1, col - 1, data)
    else
      if part.type == 'COMPLETION_PART_TYPE_INLINE'
        call prop_add(row, col, {'type': s:hlgroup, 'text': text})
      elseif part.type == 'COMPLETION_PART_TYPE_BLOCK'
        let text = split(part.text, "\n", 1)
        if empty(text[-1])
          call remove(text, -1)
        endif

        for line in text
          call prop_add(row, 0, {'type': s:hlgroup, 'text_align': 'below', 'text': line})
        endfor
      endif
    endif

    let idx = idx + 1
  endfor
endfunction

function! codeium#Clear(...) abort 
  if exists('g:_codeium_timer')
    call timer_stop(remove(g:, '_codeium_timer'))
  endif

  " Cancel any existing request.
  if exists('b:_codeium_completions')
    let request_id = get(b:_codeium_completions, 'request_id', 0)
    if request_id > 0
      try
        call codeium#server#Request('CancelRequest', {'request_id': request_id})
      catch
        call codeium#log#Exception()
      endtry
    endif
    call s:RenderCurrentCompletion()
    unlet! b:_codeium_completions
  endif

  if a:0 == 0
    call s:RenderCurrentCompletion()
  endif
  return ''
endfunction

function! codeium#CycleCompletions(n) abort
  if s:GetCurrentCompletionItem() is v:null
    return
  endif

  let b:_codeium_completions.index += a:n
  let n_items = len(b:_codeium_completions.items)

  if b:_codeium_completions.index < 0
    let b:_codeium_completions.index += n_items
  endif

  let b:_codeium_completions.index %= n_items

  call s:RenderCurrentCompletion()
endfunction

function! codeium#Complete(...) abort
  if a:0 == 2
    let bufnr = a:1
    let timer = a:2

    if timer isnot# get(g:, '_codeium_timer', -1) 
      return
    endif

    call remove(g:, '_codeium_timer')

    if mode() !=# 'i' || bufnr !=# bufnr('')
      return
    endif
  endif

  if exists('g:_codeium_timer')
    call timer_stop(remove(g:, '_codeium_timer'))
  endif

  if !codeium#Enabled()
    return
  endif

  let data = {
        \ "metadata": codeium#server#RequestMetadata(),
        \ "document": codeium#doc#GetCurrentDocument(),
        \ "editor_options": codeium#doc#GetEditorOptions(),
        \ "api_server_params": {
        \   "api_timeout_ms": 5000,
        \   "first_temperature":0.2,
        \   "max_completions": 10,
        \   "max_newlines":20,
        \   "max_tokens":256,
        \   "min_log_probability":-15.0,
        \   "temperature":0.2,
        \   "top_k":50,
        \   "top_p":1.0
        \ }
        \ }
    
  if exists('b:_codeium_completions.request_data') && b:_codeium_completions.request_data ==# data
    return
  endif

  " Add request id after we check for identical data.
  let request_data = deepcopy(data)

  let s:request_nonce += 1
  let request_id = s:request_nonce
  let data.metadata.request_id = request_id

  try
    let request_job = codeium#server#Request('GetCompletions', data, function('s:HandleCompletionsResult', []))

    let b:_codeium_completions = {
          \ "request_data": request_data,
          \ "request_id": request_id,
          \ "job": request_job
          \ }
  catch
    call codeium#log#Exception()
  endtry
endfunction

function! codeium#DebouncedComplete(...) abort
  call codeium#Clear(v:false)
  let current_buf = bufnr('')
  let delay = get(g:, 'codeium_idle_delay', 75)
  let g:_codeium_timer = timer_start(delay, function('codeium#Complete', [current_buf]))
endfunction
