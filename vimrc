" vim-plug plugins
call plug#begin('~/.vim/plugged')

" Git integration
Plug 'tpope/vim-fugitive'
Plug 'airblade/vim-gitgutter'

" Editing enhancements
Plug 'tpope/vim-surround'

" File navigation
Plug 'preservim/nerdtree'
Plug 'junegunn/fzf', { 'do': { -> fzf#install() } }
Plug 'junegunn/fzf.vim'

" YAML
Plug 'pedrohdz/vim-yaml-folds'

" Markdown
Plug 'preservim/vim-markdown'

" Go
Plug 'fatih/vim-go', { 'do': ':GoUpdateBinaries' }

" Terminal
Plug 'voldikss/vim-floaterm'

" Async linting
Plug 'dense-analysis/ale'

" Status line
Plug 'vim-airline/vim-airline'
Plug 'vim-airline/vim-airline-themes'

call plug#end()

" General settings
set number
set tabstop=4
set shiftwidth=4
set expandtab
set autoindent
set smartindent
set hlsearch
set incsearch
set ignorecase
set smartcase
set cursorline
set laststatus=2
set encoding=utf-8
set backspace=indent,eol,start
set hidden
set foldlevelstart=20
set autoread

" Auto-reload files changed externally
autocmd FocusGained,BufEnter,CursorHold,CursorHoldI * if mode() != 'c' | checktime | endif
autocmd FileChangedShellPost * echohl WarningMsg | echo "File changed on disk. Buffer reloaded." | echohl None

" Syntax highlighting
syntax enable

" NERDTree settings
nnoremap <C-n> :NERDTreeToggle<CR>
nnoremap <C-t> :NERDTreeFocus<CR>
nnoremap <C-e> :wincmd p<CR>
let NERDTreeShowHidden=1
let NERDTreeIgnore=['\.git$', '\.pyc$', '__pycache__', '\.swp$', '\.DS_Store$', 'node_modules']
let NERDTreeMinimalUI=1
let NERDTreeDirArrows=1
let NERDTreeAutoDeleteBuffer=1
let NERDTreeQuitOnOpen=0
let NERDTreeWinSize=35
let NERDTreeShowLineNumbers=0
let NERDTreeStatusline=''
" Close vim if NERDTree is the only window left
autocmd BufEnter * if tabpagenr('$') == 1 && winnr('$') == 1 && exists('b:NERDTree') && b:NERDTree.isTabTree() | quit | endif
" Open NERDTree on directory open
autocmd StdinReadPre * let s:std_in=1
autocmd VimEnter * if argc() == 1 && isdirectory(argv()[0]) && !exists('s:std_in') | execute 'NERDTree' argv()[0] | wincmd p | enew | execute 'cd '.argv()[0] | endif

" FZF settings
nnoremap <C-p> :Files<CR>
nnoremap <C-g> :Rg<CR>
nnoremap <C-b> :Buffers<CR>
let g:fzf_layout = { 'down': '40%' }

" ALE settings
let g:ale_linters = {
\   'go': ['gopls', 'golint'],
\   'yaml': ['yamllint'],
\   'sh': ['shellcheck'],
\}
let g:ale_fixers = {
\   '*': ['remove_trailing_lines', 'trim_whitespace'],
\   'go': ['gofmt', 'goimports'],
\}
let g:ale_fix_on_save = 1
let g:ale_sign_error = '✗'
let g:ale_sign_warning = '⚠'

" vim-go settings
let g:go_fmt_command = "goimports"
let g:go_highlight_functions = 1
let g:go_highlight_methods = 1
let g:go_highlight_structs = 1
let g:go_highlight_operators = 1
let g:go_def_mode='gopls'
let g:go_info_mode='gopls'

" GitGutter settings
set updatetime=100

" Airline settings
let g:airline#extensions#tabline#enabled = 1
let g:airline#extensions#ale#enabled = 1
let g:airline_powerline_fonts = 0
let g:airline_theme = 'dark'

" Markdown settings
let g:vim_markdown_folding_disabled = 1
let g:vim_markdown_conceal = 0
let g:vim_markdown_frontmatter = 1
let g:vim_markdown_no_extensions_in_markdown = 1

" ============================================
" Custom shortcuts
" ============================================

" Buffer navigation (like browser tabs) - skip in NERDTree
nnoremap <expr> <Tab> &filetype ==# 'nerdtree' ? "\<Tab>" : ":bnext\<CR>"
nnoremap <expr> <S-Tab> &filetype ==# 'nerdtree' ? "\<S-Tab>" : ":bprevious\<CR>"

" Save file
nnoremap <C-s> :w<CR>
inoremap <C-s> <Esc>:w<CR>

" Close buffer (keeps window open) - skip in NERDTree
nnoremap <expr> <C-q> &filetype ==# 'nerdtree' ? "" : ":bd\<CR>"

" Clear search highlight
nnoremap <Esc> :noh<CR><Esc>

" Terminal (floaterm)
let g:floaterm_width = 0.9
let g:floaterm_height = 0.9
nnoremap <C-\> :FloatermToggle<CR>
tnoremap <C-\> <C-\><C-n>:FloatermToggle<CR>
tnoremap <C-h> <C-\><C-n>:FloatermPrev<CR>
tnoremap <C-l> <C-\><C-n>:FloatermNext<CR>
tnoremap <C-n> <C-\><C-n>:FloatermNew<CR>
tnoremap <C-q> <C-\><C-n>:FloatermKill<CR>

" Window/pane navigation
nnoremap <C-h> :wincmd h<CR>
nnoremap <C-l> :wincmd l<CR>

" Git shortcuts (use :G for status, :Git commit, :Git push)
