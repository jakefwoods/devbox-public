" === <leader> commands ===

" Execute an action. Like <M-x>
let g:WhichKeyDesc_Leader_Space = "<leader><Space> run-command"
nnoremap <leader><Space>    :action GotoAction<CR>
vnoremap <leader><Space>    :action GotoAction<CR>

" Search in project files
let g:WhichKeyDesc_Leader_SearchProject = "<leader>/ search-project"
nnoremap <leader>/    :action FindInPath<CR>
vnoremap <leader>/    :action FindInPath<CR>
