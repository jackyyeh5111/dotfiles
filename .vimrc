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
set ignorecase
set smartcase
set wildmenu

" ref:
" https://unix.stackexchange.com/questions/348771/why-do-vim-colors-look-different-inside-and-outside-of-tmux
" For some reason, inside tmux, vim wasn't detecting a dark background. 
set background=dark

" Insert mode binding
inoremap jk <Esc>

" Move line up/down with Option-j (Meta-j)
" On Mac, need addional setting for iTerm2
" Open Preferences → Profiles → Keys.
nnoremap <M-j> :m .+1<CR>==
nnoremap <M-k> :m .-2<CR>==

" For visual mode (multiple lines)
vnoremap <C-j> :m '>+1<CR>gv=gv
vnoremap <C-k> :m '<-2<CR>gv=gv

" copy and paste across vim and other app
vnoremap <C-c> "+y
map <C-v> "+p

call plug#begin('~/.vim/plugged')

" Example plugins:
" After adding plugin, remember to ':PlugInstall'
Plug 'christoomey/vim-tmux-navigator'
Plug 'tpope/vim-sensible'
Plug 'junegunn/fzf', { 'do': { -> fzf#install() } }
Plug 'junegunn/fzf.vim'
Plug 'jiangmiao/auto-pairs'
" Status line
Plug 'itchyny/lightline.vim'
" Surrounding text operations
Plug 'tpope/vim-surround'

" Comment toggling
Plug 'tpope/vim-commentary'

" Repeat support for custom motions
Plug 'tpope/vim-repeat'
"Jump to any location specified by two characters.
Plug 'justinmk/vim-sneak'

Plug 'mg979/vim-visual-multi'

call plug#end()

