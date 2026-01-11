# Vim Plugins

## Plugin Manager

| Plugin | Repository | Description |
|--------|------------|-------------|
| vim-plug | [junegunn/vim-plug](https://github.com/junegunn/vim-plug) | Minimalist plugin manager |

## Installed Plugins

### Git Integration

| Plugin | Repository | Description |
|--------|------------|-------------|
| vim-fugitive | [tpope/vim-fugitive](https://github.com/tpope/vim-fugitive) | Git wrapper - `:G`, `:Git blame`, `:Gdiffsplit` |
| vim-gitgutter | [airblade/vim-gitgutter](https://github.com/airblade/vim-gitgutter) | Shows git diff in the gutter (+/-/~) |

### Editing Enhancements

| Plugin | Repository | Description |
|--------|------------|-------------|
| vim-surround | [tpope/vim-surround](https://github.com/tpope/vim-surround) | Change surroundings - `cs"'` changes `"` to `'` |

### File Navigation

| Plugin | Repository | Description |
|--------|------------|-------------|
| nerdtree | [preservim/nerdtree](https://github.com/preservim/nerdtree) | File system explorer sidebar |
| fzf | [junegunn/fzf](https://github.com/junegunn/fzf) | Fuzzy finder core |
| fzf.vim | [junegunn/fzf.vim](https://github.com/junegunn/fzf.vim) | Fuzzy finder vim integration - `:Files`, `:Rg`, `:Buffers` |

### Language Support

| Plugin | Repository | Description |
|--------|------------|-------------|
| vim-yaml-folds | [pedrohdz/vim-yaml-folds](https://github.com/pedrohdz/vim-yaml-folds) | YAML folding by indentation |
| vim-markdown | [preservim/vim-markdown](https://github.com/preservim/vim-markdown) | Markdown syntax, folding, TOC |
| vim-go | [fatih/vim-go](https://github.com/fatih/vim-go) | Go development - gopls, goimports, syntax highlighting |

### Terminal

| Plugin | Repository | Description |
|--------|------------|-------------|
| vim-floaterm | [voldikss/vim-floaterm](https://github.com/voldikss/vim-floaterm) | Floating terminal with tabs |

### Linting

| Plugin | Repository | Description |
|--------|------------|-------------|
| ale | [dense-analysis/ale](https://github.com/dense-analysis/ale) | Async linting engine - Go, YAML, Shell |

### UI

| Plugin | Repository | Description |
|--------|------------|-------------|
| vim-airline | [vim-airline/vim-airline](https://github.com/vim-airline/vim-airline) | Status line with git branch, file info |
| vim-airline-themes | [vim-airline/vim-airline-themes](https://github.com/vim-airline/vim-airline-themes) | Themes for airline |

## Configured Linters (ALE)

| Language | Linters |
|----------|---------|
| Go | gopls, golint |
| YAML | yamllint |
| Shell | shellcheck |

## Configured Fixers (ALE)

| Language | Fixers |
|----------|--------|
| All | remove_trailing_lines, trim_whitespace |
| Go | gofmt, goimports |
