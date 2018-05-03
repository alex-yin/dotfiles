set number
set relativenumber

let g:indent_guides_auto_colors = 0
highlight Visual cterm=reverse ctermbg=NONE gui=reverse
highlight Pmenu ctermfg=22 ctermbg=18 guifg=#005f00 guibg=#00005f
highlight PmenuSel ctermfg=22 ctermbg=144 guifg=#005f00 guibg=#afaf87 
autocmd VimEnter,Colorscheme * :hi IndentGuidesOdd  guibg=DarkGray   ctermbg=8
autocmd VimEnter,Colorscheme * :hi IndentGuidesEven guibg=Gray       ctermbg=0
set hlsearch
set incsearch

" General mapping
nnoremap <C-t> :IndentLinesToggle<CR>
nnoremap NT :NERDTreeToggle<CR>
nnoremap NC :NERDTreeClose<CR>
nnoremap <C-s> :w <CR>

" Normal custom keys
nnoremap <S-Up> :resize +5<CR>
nnoremap <S-Down> :resize -5<CR>
nnoremap <S-Left> :vertical resize -5<CR>
nnoremap <S-Right> :vertical resize +5<CR>
nnoremap nl o<Esc>
nnoremap Nl O<Esc>

" Insert mode custom keys
inoremap <C-j> <Down>
inoremap <C-k> <Up>
inoremap <C-h> <Left>
inoremap <C-l> <Right>

" Visual mode custom keys
" / search selection
vnoremap // y/<C-R>"<CR>"
" substitute in selection
vnoremap ss :s/\%V//g <Left><Left><Left><Left>

" final setting
set showcmd

