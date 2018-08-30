set nocompatible              " be iMproved, required
set magic
set number
set relativenumber
set splitbelow
set splitright
set autoread
filetype off                  " required

" set the runtime path to include Vundle and initialize
set rtp+=~/.vim/bundle/Vundle.vim
call vundle#begin()
"" PLUGIN LIST""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
Plugin 'VundleVim/Vundle.vim'
Plugin 'kien/ctrlp.vim'
Plugin 'scrooloose/nerdtree'
Plugin 'vim-python/python-syntax'
Plugin 'flazz/vim-colorschemes'
Plugin 'tpope/vim-fugitive'
Plugin 'Valloric/YouCompleteMe'
Plugin 'Xuyuanp/git-nerdtree'
Plugin 'majutsushi/tagbar'
Plugin 'tpope/vim-surround'
Plugin 'vim-airline/vim-airline'
Plugin 'vim-airline/vim-airline-themes'
Plugin 'Yggdroot/indentLine'
Plugin 'scrooloose/nerdcommenter'
Plugin 'mhinz/vim-startify'
Plugin 'easymotion/vim-easymotion'
Plugin 'matze/vim-move'
Plugin 'dhruvasagar/vim-table-mode'
call vundle#end()            " required
filetype plugin indent on    " required

set runtimepath+=~/.vim_runtime
source ~/.vim_runtime/vimrcs/basic.vim
source ~/.vim_runtime/vimrcs/filetypes.vim

" Display and highlight settings
let g:python_highlight_all = 1
autocmd VimEnter,Colorscheme * :hi IndentGuidesOdd  guibg=DarkGray   ctermbg=8
autocmd VimEnter,Colorscheme * :hi IndentGuidesEven guibg=Gray       ctermbg=0
set hlsearch
set incsearch

"" PLUGIN CONFIG""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" NERDTree setting
let g:NERDTreeDirArrowExpandable = '▸'
let g:NERDTreeDirArrowCollapsible = '▾'
let g:NERDTreeDirArrows = 1
let g:NERDTreeGlyphReadOnly = "RO"
let g:NERDTreeWinPos = "left"

" Ctrlp setting
let g:ctrlp_map = '<c-p>'
let g:ctrlp_cmd = 'CtrlP'
let g:ctrlp_working_path_mode = 'ra'
let g:ctrlp_show_hidden = 1
let g:ctrlp_match_window = 'bottom,order:ttb,min:1,max:10,results:10'
let g:ctrlp_use_caching = 1
let g:ctrlp_clear_cache_on_exit = 0
let g:ctrlp_cache_dir = $HOME.'/.cache/ctrlp'

" YCM setting
let g:ycm_autoclose_preview_window_after_completion = 1
let g:ycm_max_num_candidates = 5
let g:ycm_python_binary_path = 'python3'
let g:ycm_goto_buffer_command = 'new-tab'
let g:ycm_show_diagnostics_ui = 0

" Nerdcommenter setting
let g:NERDSpaceDelims = 0
let g:NERDCompactSexyComs = 1
let g:NERDDefaultAlign = 'left'
let g:NERDRemoveExtraSpaces = 1
let g:NERDTrimTrailingWhitespace = 1

" Airline setting
let g:airline#extensions#tabline#enabled = 1
let g:airline_theme='badwolf'
let g:airline_powerline_fonts = 1

" Easymotion setting
let g:EasyMotion_do_mapping = 0
let g:EasyMotion_smartcase = 1
nmap <Leader>s <Plug>(easymotion-overwin-f2)
nmap <Leader>j <Plug>(easymotion-j)
nmap <Leader>k <Plug>(easymotion-k)

" Startify
let g:startify_session_persistence = 1

" Move
let g:move_map_keys = 0
vmap <C-k> <Plug>MoveBlockUp
vmap <C-j> <Plug>MoveBlockDown

" indentLine
let g:indentLine_char = "¦"
let g:indentLine_setColors = 1
"" PLUGIN CONFIG""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""

"" KEY MAPPING""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" General mapping
let mapleader = ","
map <C-t> :IndentLinesToggle<CR>
map <C-n> :NERDTreeToggle<CR>
map <C-c> :NERDTreeClose<CR>
map <leader><cr> :noh<cr>

" Normal custom keys
nnoremap <S-Up> :resize +5<CR>
nnoremap <S-Down> :resize -5<CR>
nnoremap <S-Left> :vertical resize -5<CR>
nnoremap <S-Right> :vertical resize +5<CR>
nnoremap nl o<Esc>
nnoremap Nl O<Esc>
nnoremap <C-G> :YcmCompleter GoTo<CR>
nnoremap <F8> :TagbarToggle<CR>
nnoremap qq :q<CR>
nnoremap <leader>w :w!<cr>

" Insert mode custom keys
inoremap <C-j> <Down>
inoremap <C-k> <Up>
inoremap <C-h> <Left>
inoremap <C-l> <Right>

" Visual mode custom keys
vnoremap // y/<C-R>"<CR>"
vnoremap ss :s///g <Left><Left><Left><Left>
"" KEY MAPPING""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""

" final setting
colorscheme xoria256
highlight Visual cterm=reverse ctermbg=NONE gui=reverse
highlight Pmenu ctermfg=22 ctermbg=45 guifg=#005f00 guibg=#00005f
highlight PmenuSel ctermfg=22 ctermbg=144 guifg=#005f00 guibg=#afaf87 
set showcmd
set cursorline
set diffopt+=vertical
set guifont=Monospace\ 11
set mouse=a
set guicursor=n:blinkon1

