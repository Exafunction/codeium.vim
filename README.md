<p align="center">
  <img width="300" alt="Codeium" src="codeium.svg"/>
</p>

---

[![Discord](https://img.shields.io/discord/1027685395649015980?label=community&color=5865F2&logo=discord&logoColor=FFFFFF)](https://discord.gg/3XFf78nAx5)
[![Twitter Follow](https://img.shields.io/twitter/follow/codeiumdev)](https://twitter.com/intent/follow?screen_name=codeiumdev)
![License](https://img.shields.io/github/license/Exafunction/codeium.vim)

[![Visual Studio](https://img.shields.io/visual-studio-marketplace/d/Codeium.codeium?label=Visual%20Studio&logo=visualstudio)](https://marketplace.visualstudio.com/items?itemName=Codeium.codeium)
[![JetBrains](https://img.shields.io/jetbrains/plugin/d/20540?label=JetBrains)](https://plugins.jetbrains.com/plugin/20540-codeium/)
[![Open VSX](https://img.shields.io/open-vsx/dt/Codeium/codeium?label=Open%20VSX)](https://open-vsx.org/extension/Codeium/codeium)
[![Google Chrome](https://img.shields.io/chrome-web-store/users/hobjkcpmjhlegmobgonaagepfckjkceh?label=Google%20Chrome&logo=googlechrome&logoColor=FFFFFF)](https://chrome.google.com/webstore/detail/codeium/hobjkcpmjhlegmobgonaagepfckjkceh)

# codeium.vim

_Free, ultrafast Copilot alternative for Vim and Neovim_

Codeium autocompletes your code with AI in all major IDEs. We [launched](https://www.codeium.com/blog/codeium-copilot-alternative-in-vim) this implementation of the Codeium plugin for Vim and Neovim to bring this modern coding superpower to more developers. Check out our [playground](https://www.codeium.com/playground) if you want to quickly try out Codeium online.

Contributions are welcome! Feel free to submit pull requests and issues related to the plugin.

<br />

![Example](https://user-images.githubusercontent.com/1908017/213154744-984b73de-9873-4b85-998f-799d92b28eec.gif)

<br />

## 🚀 Getting started

1. Install [Vim](https://github.com/vim/vim) (at least 9.0.0185) or [Neovim](https://github.com/neovim/neovim/releases/latest) (at
   least 0.6)

2. Install `Exafunction/codeium.vim` using your vim plugin manager of
   choice, or manually. See [Installation Options](#-installation-options) below.

3. Run `:Codeium Auth` to set up the plugin and start using Codeium.

You can run `:help codeium` for a full list of commands and configuration
options, or see [this guide](https://www.codeium.com/vim_tutorial) for a quick tutorial on how to use Codeium.

## 🛠️ Configuration

### 🖥️ For Vim users

Codeium can be disabled for particular filetypes by setting the
`g:codeium_filetypes` variable in your vim config file (vimrc/init.vim):

```vim
let g:codeium_filetypes = {
    \ "bash": v:false,
    \ "typescript": v:true,
    \ }
```

Codeium is enabled by default for most filetypes.

You can also _disable_ codeium by default with the `g:codeium_enabled`
variable:

```vim
let g:codeium_enabled = v:false
```

For a full list of configuration options you can run `:help codeium`.

### 💻 For Neovim users

You can use the following Lua code to invoke the Vimscript function for autocompletion by this plugin:

```lua
vim.fn["codeium#Accept"]()
```

Since this function returns an **expression**, we need to specify it explicitly using `{ expr = true }`.
Here is a working example for both [wbthomason/packer.nvim](https://github.com/wbthomason/packer.nvim#specifying-plugins)
and [folke/lazy.nvim](https://github.com/folke/lazy.nvim):

```lua
-- Remove the `use` here if you're using folke/lazy.nvim.
use {
  'Exafunction/codeium.vim',
  config = function ()
    -- Change '<C-g>' here to any keycode you like.
    vim.keymap.set('i', '<C-g>', function ()
      return vim.fn['codeium#Accept']()
    end, { expr = true })
  end
}
```

(Make sure that you ran `:Codeium Auth` after installation.)


## 💾 Installation Options

### 🔌 vim-plug

```vim
Plug 'Exafunction/codeium.vim'
```

### 📦 Vundle

```vim
Plugin 'Exafunction/codeium.vim'
```

### 📦 packer.nvim:

```vim
use 'Exafunction/codeium.vim'
```

### 💪 Manual

#### 🖥️ Vim

Run the following. On windows, you can replace `~/.vim` with
`$HOME/vimfiles`:

```bash
git clone https://github.com/Exafunction/codeium.vim ~/.vim/pack/Exafunction/start/codeium.vim
```

#### 💻 Neovim

Run the following. On windows, you can replace `~/.config` with
`$HOME/AppData/Local`:

```bash
git clone https://github.com/Exafunction/codeium.vim ~/.config/nvim/pack/Exafunction/start/codeium.vim
```
