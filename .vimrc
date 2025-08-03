syntax on

set encoding=utf-8
set smartindent
set tabstop=4
set shiftwidth=4
set expandtab
set ruler
set hlsearch
set number
set cursorline
set listchars=eol:↵,tab:»·,trail:╳,extends:»,precedes:«
set clipboard=unnamedplus

" Use // instead of /* */ in C, C++, Java, etc.
let g:NERDCustomDelimiters = {
  \ 'c': {'left': '//'},
  \ 'cpp': {'left': '//'},
  \ 'java': {'left': '//'},
  \ }

call plug#begin('~/.vim/plugged')
Plug 'preservim/nerdcommenter'
call plug#end()

