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

function! s:Uuid() abort
  if has('win32')
    return system('powershell -Command "[guid]::NewGuid().Guid"')
  elseif executable('uuidgen')
    return system('uuidgen')
  endif

  throw 'Could not generate uuid. Please make sure uuidgen is installed.'
endfunction

function! s:ConfigDir() abort
  return $HOME . '/.codeium'
endfunction

function! codeium#command#ConfigDir() abort
  return s:ConfigDir()
endfunction

function! s:LoadConfig() abort
  let config_path = s:ConfigDir() . '/config.json'
  if filereadable(config_path)
    let contents = join(readfile(config_path), '')
    if !empty(contents)
      return json_decode(contents)
    endif
  endif

  return {}
endfunction

let s:api_key = get(s:LoadConfig(), 'apiKey', '')

let s:commands = {}

function! s:commands.Auth(...) abort
  if !codeium#util#HasSupportedVersion()
    if has('nvim')
      let min_version = 'NeoVim 0.6'
    else
      let min_version = 'Vim 9.0.0185'
    endif
    echo 'This version of Vim is unsupported. Install ' . min_version . ' or greater to use Codeium.'
    return
  endif

  let uuid = trim(s:Uuid())
  let url = 'https://www.codeium.com/profile?response_type=token&redirect_uri=vim-show-auth-token&state=' . uuid . '&scope=openid%20profile%20email&redirect_parameters_type=query'
  let browser = codeium#command#BrowserCommand()
  let opened_browser = v:false
  if !empty(browser)
    echo 'Press ENTER to login to Codeium in your browser.'

    let c = getchar()
    while c isnot# 13 && c isnot# 10 && c isnot# 0
      let c = getchar()
    endwhile

    echo 'Navigating to ' . url
    try
      call system(browser . ' ' . '"' . url . '"')
      if v:shell_error is# 0
        let opened_browser = v:true
      endif
    catch
    endtry

    if !opened_browser
      echo 'Failed to open browser. Please go to the link above.'
    endif
  else
    echo 'No available browser found. Please go to ' . url
  endif

  let api_key = ''
  let auth_token = input('Paste your token here: ')
  let tries = 0

  while empty(api_key) && tries < 3
    let command = 'curl -s https://api.codeium.com/register_user/ ' .
          \ '--header "Content-Type: application/json" ' .
          \ '--data ' . '"' . json_encode({'firebase_id_token': auth_token})->substitute('"', '\\"', 'g') . '"'
    let response = system(command)
    let res = json_decode(response)
    let api_key = get(res, 'api_key', '')
    if empty(api_key)
      let auth_token = input('Invalid token, please try again: ')
    endif
    let tries = tries + 1
  endwhile

  if !empty(api_key)
    let s:api_key = api_key
    let config_dir = s:ConfigDir()
    let config_path = config_dir . '/config.json'
    let config = s:LoadConfig()
    let config.apiKey = api_key

    try
      if !filereadable(config_path)
        call mkdir(config_dir, 'p')
      endif

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

function! s:commands.Enable(...) abort
  let g:codeium_enabled = 1
endfunction

function! s:commands.EnableBuffer(...) abort
  let b:codeium_enabled = 1
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
