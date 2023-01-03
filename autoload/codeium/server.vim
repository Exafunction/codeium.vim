function! s:OnExit(result, status, on_complete_cb) abort
  let did_close = has_key(a:result, 'closed')
  if did_close
    call remove(a:result, 'closed')
    call a:on_complete_cb(a:result.out, a:status)
  else
    " Wait until we receive OnClose, and call on_complete_cb then.
    let a:result.exit_status = a:status
  endif
endfunction

function! s:OnClose(result, on_complete_cb) abort
  let did_exit = has_key(a:result, 'exit_status')
  if did_exit
    call a:on_complete_cb(a:result.out, a:result.exit_status)
  else
    " Wait until we receive OnExit, and call on_complete_cb then.
    let a:result.closed = v:true
  endif
endfunction

function! s:NoopCallback(...) abort
endfunction

function! codeium#server#Request(port, type, data, ...) abort
    let uri = 'http://localhost:' . a:port . 
        \ '/exa.language_server_pb.LanguageServerService/' . a:type
    let args = [
                \ 'curl', uri,
                \ '--header', 'Content-Type: application/json',
                \ '--data', json_encode(a:data)
                \ ]
    let result = {"out": []}
    let Callback = a:0 && !empty(a:1) ? a:1 : function('s:NoopCallback')
    return job_start(args, {
                \ 'out_mode': 'raw',
                \ 'out_cb': { channel, data -> add(result.out, data) },
                \ 'exit_cb': { job, status -> s:OnExit(result, status, Callback) },
                \ 'close_cb': { channel -> s:OnClose(result, Callback) }
                \ })
endfunction
