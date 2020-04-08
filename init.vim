"vim-plug
call plug#begin('~/.config/nvim/plugged')

Plug 'joshdick/onedark.vim' "theme
Plug 'vim-airline/vim-airline' "line with mode in botton

Plug 'scrooloose/nerdtree' "file explorer
Plug 'ryanoasis/vim-devicons' "icons in file explorer
Plug 'tiagofumo/vim-nerdtree-syntax-highlight' "color icons in file explorer

Plug 'luochen1990/rainbow' "rainbow parenthesis
Plug 'tpope/vim-surround' "enable surround shortcuts
Plug 'tpope/vim-repeat' "enable . repeat for surround
Plug 'Raimondi/delimitMate' "auto closing parenthesis
Plug 'vim-scripts/paredit.vim' "wrap, move, delete parenthesis

Plug 'fatih/vim-go' "Go

Plug 'tpope/vim-fireplace' "Clojure
Plug 'venantius/vim-cljfmt' "formatter
Plug 'venantius/vim-eastwood' "linting
Plug 'vim-syntastic/syntastic'
Plug 'Olical/conjure', { 'tag': 'v2.1.2', 'do': 'bin/compile'}

Plug 'Shougo/deoplete.nvim', { 'do': ':UpdateRemotePlugins' } "extensible and asynchronous completion
Plug 'ctrlpvim/ctrlp.vim' "Full path fuzzy file, buffer, mru, tag, ... finder for Vim
Plug 'tpope/vim-fugitive' "git integration
Plug 'mileszs/ack.vim' "search inside files across dir

Plug 'preservim/nerdcommenter' "comment/uncoment

call plug#end()

"vim
syntax on "code syntax highlighting
set termguicolors "vim colors same as terminal
set autoindent "new lines inherit identation of previous lines
set expandtab "convert tabs to spaces
set shiftround "when shifting lines, round the identation to the nearest multiple of shiftwith
set shiftwidth=4 "4 spaces for shifting
set smarttab "insert tabstop number of spaces when pressing tab
set tabstop=4
set hlsearch "Enable search highlighting.
set ignorecase "Ignore case when searching.
set incsearch "Incremental search that shows partial matches.
set smartcase "Automatically switch search to case-sensitive when search query contains an uppercase letter.
set number "show line numbers
set relativenumber "show relative line numbers
set mouse=a "enable mouse for scroll and zoom
set title "see current file title
set encoding=UTF-8 "sets encoding
set splitright
set splitbelow

"shortcuts
let mapleader=" "
nmap <leader>q :q<CR>
nmap <leader><leader>q :q!<CR>
nmap <leader>w :w<CR>
nmap <leader>v <C-w>v 
nmap <leader>l <C-w>l 
nmap <leader>h <C-w>h 

"theme
colorscheme onedark

"airline
let g:airline_theme = 'onedark'
let g:airline_powerline_fonts = 1

"nerdtree
let NERDTreeQuitOnOpen=1
map <leader>n :NERDTreeToggle<CR>

"rainbow
let g:rainbow_active = 1

"deoplete
let g:deoplete#enable_at_startup = 1
imap <C-Space> <C-x><C-o>
call deoplete#custom#option('omni_patterns', { 'go': '[^. *\t]\.\w*' })
call deoplete#custom#option('keyword_patterns', {'clojure': '[\w!$%&*+/:<=>?@\^_~\-\.#]*'})


"delimitMate
let delimitMate_expand_cr=1 "when pressing enter the cursor will indent

"paredit
nmap <leader>. <leader>>
nmap <leader>, <leader><

"clojure
"  fireplace
autocmd FileType clojure nmap <leader>t :RunTests<CR>
"  cljfmt
autocmd FileType clojure nmap <leader>f :Cljfmt<Cr>

"go 
autocmd FileType go nmap <leader>t :GoTest<CR>
autocmd FileType go nmap <leader>f :GoFmt<CR>


"git-fugitive
set statusline+=%#warningmsg#
set statusline+=%{SyntasticStatuslineFlag()}
set statusline+=%*

"syntastic
let g:syntastic_always_populate_loc_list = 1
let g:syntastic_auto_loc_list = 1
let g:syntastic_check_on_open = 1
let g:syntastic_check_on_wq = 0

let g:syntastic_clojure_checkers = ['eastwood']

"commenter
nmap <leader>/ <Space>c<Space>

"conjure
let g:conjure_log_direction = "horizontal"
let g:conjure_log_blacklist = ["up", "ret", "ret-multiline", "load-file", "eval"]
