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

let g:ycm_clangd_binary_path = trim(system('brew --prefix llvm')).'/bin/clangd'
