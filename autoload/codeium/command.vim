function! codeium#command#BrowserCommand() abort
  if has('win32') && executable('rundll32')
    return 'rundll32 url.dll,FileProtocolHandler'
  elseif isdirectory('/private') && executable('/usr/bin/open')
    return '/usr/bin/open'
  elseif executable('xdg-open')
    return 'xdg-open'
  else
    return ''
  endif
endfunction

function! codeium#command#XdgConfigDir() abort
  let config_dir = $XDG_CONFIG_HOME
  if empty(config_dir)
    let config_dir = $HOME . '/.config'
  endif
  return config_dir . '/codeium'
endfunction

function! codeium#command#HomeDir() abort
  return $HOME . '/.codeium'
endfunction

function! codeium#command#LoadConfig(dir) abort
  let config_path = a:dir . '/config.json'
  if filereadable(config_path)
    let contents = join(readfile(config_path), '')
    if !empty(contents)
      return json_decode(contents)
    endif
  endif

  return {}
endfunction

let s:api_key = get(codeium#command#LoadConfig(codeium#command#HomeDir()), 'apiKey', '')

let s:commands = {}

function! s:commands.Auth(...) abort
  if !codeium#util#HasSupportedVersion()
    if has('nvim')
      let min_version = 'NeoVim 0.6'
    else
      let min_version = 'Vim 9.0.0185'
    endif
    echoerr 'This version of Vim is unsupported. Install ' . min_version . ' or greater to use Codeium.'
    return
  endif

  let url = 'https://www.codeium.com/profile?response_type=token&redirect_uri=vim-show-auth-token&state=a&scope=openid%20profile%20email&redirect_parameters_type=query'
  let browser = codeium#command#BrowserCommand()
  let opened_browser = v:false
  if !empty(browser)
    echomsg 'Navigating to ' . url
    try
      call system(browser . ' ' . '"' . url . '"')
      if v:shell_error is# 0
        let opened_browser = v:true
      endif
    catch
    endtry

    if !opened_browser
      echomsg 'Failed to open browser. Please go to the link above.'
    endif
  else
    echomsg 'No available browser found. Please go to ' . url
  endif

  let api_key = ''
  call inputsave()
  let auth_token = inputsecret('Paste your token here: ')
  call inputrestore()
  let tries = 0

  while empty(api_key) && tries < 3
    let command = 'curl -sS https://api.codeium.com/register_user/ ' .
          \ '--header "Content-Type: application/json" ' .
          \ '--data ' . shellescape(json_encode({'firebase_id_token': auth_token}))
    let response = system(command)
    let res = json_decode(response)
    let api_key = get(res, 'api_key', '')
    if empty(api_key)
      echomsg 'Unexpected response: ' . response
      call inputsave()
      let auth_token = inputsecret('Invalid token, please try again: ')
      call inputrestore()
    endif
    let tries = tries + 1
  endwhile

  if !empty(api_key)
    let s:api_key = api_key
    let config_dir = codeium#command#HomeDir()
    let config_path = config_dir . '/config.json'
    let config = codeium#command#LoadConfig(config_dir)
    let config.apiKey = api_key

    try
      call mkdir(config_dir, 'p')
      call writefile([json_encode(config)], config_path)
    catch
      call codeium#log#Error('Could not persist api key to config.json')
    endtry
  endif
endfunction

function! s:commands.Disable(...) abort
  let g:codeium_enabled = 0
endfunction

function! s:commands.DisableBuffer(...) abort
  let b:codeium_enabled = 0
endfunction

" Run codeium server only if its not already started
function! codeium#command#StartLanguageServer() abort
  if !get(g:, 'codeium_server_started', v:false)
    call timer_start(0, function('codeium#server#Start'))
    let g:codeium_server_started = v:true
  endif
endfunction

function! s:commands.Enable(...) abort
  let g:codeium_enabled = 1
  call codeium#command#StartLanguageServer()
endfunction

function! s:commands.EnableBuffer(...) abort
  let b:codeium_enabled = 1
  call codeium#command#StartLanguageServer()
endfunction

function! codeium#command#ApiKey() abort
  return s:api_key
endfunction

function! codeium#command#Complete(arg, lead, pos) abort
  let args = matchstr(strpart(a:lead, 0, a:pos), 'C\%[odeium][! ] *\zs.*')
  return sort(filter(keys(s:commands), { k -> strpart(k, 0, len(a:arg)) ==# a:arg }))
endfunction

function! codeium#command#Command(arg) abort
  let cmd = matchstr(a:arg, '^\%(\\.\|\S\)\+')
  let arg = matchstr(a:arg, '\s\zs\S.*')
  if !has_key(s:commands, cmd)
    return 'echoerr ' . string("Codeium: command '" . string(cmd) . "' not found")
  endif
  let res = s:commands[cmd](arg)
  if type(res) == v:t_string
    return res
  else
    return ''
  endif
endfunction
