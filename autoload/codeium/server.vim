let s:language_server_version = '1.2.52'
let s:language_server_sha = '689bb8b889e7b8ea08f7f68736c259deb538ea10'
let s:root = expand('<sfile>:h:h:h')
let s:bin = v:null

if has('nvim')
  let s:ide = 'neovim'
else
  let s:ide = 'vim'
endif

if !exists('s:editor_version')
  if has('nvim')
    let s:ide_version = matchstr(execute('version'), 'NVIM v\zs[^[:space:]]\+')
  else
    let major = v:version / 100
    let minor = v:version % 100
    if exists('v:versionlong')
      let patch = printf('%04d', v:versionlong % 1000)
      let s:ide_version =  major . '.' . minor . '.' . patch
    else
      let s:ide_version =  major . '.' . minor
    endif
  endif
endif

let s:server_port = v:null
let g:codeium_server_job = v:null

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

function! codeium#server#RequestMetadata() abort
  return {
        \ 'api_key': codeium#command#ApiKey(),
        \ 'ide_name':  s:ide,
        \ 'ide_version':  s:ide_version,
        \ 'extension_name': 'vim',
        \ 'extension_version':  s:language_server_version,
        \ }
endfunction

function! codeium#server#Request(type, data, ...) abort
  if s:server_port is# v:null
    throw 'Server port has not been properly initialized.'
  endif
  let uri = 'http://localhost:' . s:server_port .
      \ '/exa.language_server_pb.LanguageServerService/' . a:type
  let data = json_encode(a:data)
  let args = [
              \ 'curl', uri,
              \ '--header', 'Content-Type: application/json',
              \ '-d@-'
              \ ]
  let result = {'out': []}
  let ExitCallback = a:0 && !empty(a:1) ? a:1 : function('s:NoopCallback')
  if has('nvim')
    let jobid = jobstart(args, {
                \ 'on_stdout': { channel, data, t -> add(result.out, join(data, "\n")) },
                \ 'on_exit': { job, status, t -> ExitCallback(result.out, status) },
                \ })
    call chansend(jobid, data)
    call chanclose(jobid, 'stdin')
    return jobid
  else
    let job = job_start(args, {
                \ 'in_mode': 'raw',
                \ 'out_mode': 'raw',
                \ 'out_cb': { channel, data -> add(result.out, data) },
                \ 'exit_cb': { job, status -> s:OnExit(result, status, ExitCallback) },
                \ 'close_cb': { channel -> s:OnClose(result, ExitCallback) }
                \ })
    let channel = job_getchannel(job)
    call ch_sendraw(channel, data)
    call ch_close_in(channel)
    return job
  endif
endfunction

function! s:FindPort(dir, timer) abort
  let time = localtime()
  for name in readdir(a:dir)
    let path = a:dir . '/' . name
    if time - getftime(path) <= 5 && getftype(path) ==# 'file'
      call codeium#log#Info('Found port: ' . name)
      let s:server_port = name
      call timer_stop(a:timer)
      break
    endif
  endfor
endfunction

function! s:SendHeartbeat(timer) abort
  try
    call codeium#server#Request('Heartbeat', {'metadata': codeium#server#RequestMetadata()})
  catch
    call codeium#log#Exception()
  endtry
endfunction

function! codeium#server#Start(...) abort
  silent let os = substitute(system('uname'), '\n', '', '')
  silent let arch = substitute(system('uname -m'), '\n', '', '')
  let is_arm = stridx(arch, 'arm') == 0 || stridx(arch, 'aarch64') == 0

  if os ==# 'Linux' && is_arm
    let bin_suffix = 'linux_arm'
  elseif os ==# 'Linux'
    let bin_suffix = 'linux_x64'
  elseif os ==# 'Darwin' && is_arm
    let bin_suffix = 'macos_arm'
  elseif os ==# 'Darwin'
    let bin_suffix = 'macos_x64'
  else
    let bin_suffix = 'windows_x64.exe'
  endif

  let sha = get(codeium#command#LoadConfig(codeium#command#XdgConfigDir()), 'sha', s:language_server_sha)
  let bin_dir = codeium#command#HomeDir() . '/bin/' . sha
  let s:bin = bin_dir . '/language_server_' . bin_suffix
  call mkdir(bin_dir, 'p')

  if !filereadable(s:bin)
    call delete(s:bin)
    if sha ==# s:language_server_sha
      let url = 'https://github.com/Exafunction/codeium/releases/download/language-server-v' . s:language_server_version . '/language_server_' . bin_suffix . '.gz'
    else
      let url = 'https://storage.googleapis.com/exafunction-dist/codeium/' . sha . '/language_server_' . bin_suffix . '.gz'
    endif
    let args = ['curl', '-Lo', s:bin . '.gz', url]
    if has('nvim')
      let s:download_job = jobstart(args, {'on_exit': { job, status, t -> s:UnzipAndStart(status) }})
    else
      let s:download_job = job_start(args, {'exit_cb': { job, status -> s:UnzipAndStart(status) }})
    endif
  else
    call s:ActuallyStart()
  endif
endfunction

function! s:UnzipAndStart(status) abort
  if has('win32')
    " Save old settings.
    let old_shell = &shell
    let old_shellquote = &shellquote
    let old_shellpipe = &shellpipe
    let old_shellxquote = &shellxquote
    let old_shellcmdflag = &shellcmdflag
    let old_shellredir = &shellredir
    " Switch to powershell.
    let &shell = 'powershell'
    set shellquote= shellpipe=\| shellxquote=
    set shellcmdflag=-NoLogo\ -NoProfile\ -ExecutionPolicy\ RemoteSigned\ -Command
    set shellredir=\|\ Out-File\ -Encoding\ UTF8
    call system('& { . ' . shellescape(s:root . '/powershell/gzip.ps1') . '; Expand-File ' . shellescape(s:bin . '.gz') . ' }')
    " Restore old settings.
    let &shell = old_shell
    let &shellquote = old_shellquote
    let &shellpipe = old_shellpipe
    let &shellxquote = old_shellxquote
    let &shellcmdflag = old_shellcmdflag
    let &shellredir = old_shellredir
  else
    call system('gzip -d ' . s:bin . '.gz')
    call system('chmod +x ' . s:bin)
  endif
  if !filereadable(s:bin)
    call codeium#log#Error('Failed to download language server binary.')
    return ''
  endif
  call s:ActuallyStart()
endfunction

function! s:ActuallyStart() abort
  let config = get(g:, 'codeium_server_config', {})
  let manager_dir = tempname() . '/codeium/manager'
  call mkdir(manager_dir, 'p')

  let args = [
        \ s:bin,
        \ '--api_server_url', get(config, 'api_url', 'https://server.codeium.com'),
        \ '--manager_dir', manager_dir
        \ ]
  if has_key(config, 'api_url') && !empty(config.api_url)
    let args += ['--enterprise_mode']
  endif

  call codeium#log#Info('Launching server with manager_dir ' . manager_dir)
  if has('nvim')
    let g:codeium_server_job = jobstart(args, {
                \ 'on_stderr': { channel, data, t -> codeium#log#Info('[SERVER] ' . join(data, "\n")) },
                \ })
  else
    let g:codeium_server_job = job_start(args, {
                \ 'out_mode': 'raw',
                \ 'err_cb': { channel, data -> codeium#log#Info('[SERVER] ' . data) },
                \ })
  endif
  call timer_start(500, function('s:FindPort', [manager_dir]), {'repeat': -1})
  call timer_start(5000, function('s:SendHeartbeat', []), {'repeat': -1})
endfunction
