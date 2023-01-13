# Codeium.vim

## Getting started

1. Install [Vim](https://github.com/vim/vim) (at least 9.0.0185) or [Neovim](https://github.com/neovim/neovim/releases/latest) (at
least 0.6)

2.  Install `Exafunction/codeium.vim` using your vim plugin manager of
choice, or manually. See [Installation Options](#installation-options) below.

3. Run `:Codeium Auth` to set up the plugin and start using Codeium.

You can run `:help codeium` for a full list of commands and configuration
options.

## Configuration

Codeium can be disabled for particular filetypes by setting the
`g:codeium_filetypes` variable in your vim config file (vimrc/init.vim):

```
let g:codeium_filetypes = {
    \ "bash": v:false,
    \ "typescript": v:true,
    \ }
```

Codeium is enabled by default for most filetypes.

For a full list of configuration options you can run `:help codeium`.

## Installation Options

### vim-plug
```
Plug 'Exafunction/codeium.vim'
```

### Vundle
```
Plugin 'Exafunction/codeium.vim'
```

### packer.nvim:
```
use 'Exafunction/codeium.vim'
```

### Manual

#### Vim

Run the following. On windows, you can replace `~/.vim` with
`$HOME/vimfiles`:
```
git clone https://github.com/Exafunction/codeium.vim ~/.vim/pack/Exafunction/start/codeium.vim
```

#### Neovim

Run the following. On windows, you can replace `~/.config` with
`$HOME/AppData/Local`:

```
git clone https://github.com/Exafunction/codeium.vim ~/.config/nvim/pack/Exafunction/start/codeium.vim
```
