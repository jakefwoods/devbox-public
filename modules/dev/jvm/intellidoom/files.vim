" === <leader>f commands ===
let g:WhichKeyDesc_Files = "<leader>f    +files"

" Find files
let g:WhichKeyDesc_Files_GotoFileAlt = "<leader>fF goto-file"
nnoremap <leader>fF    :action GotoFile<CR>
vnoremap <leader>fF    :action GotoFile<CR>
let g:WhichKeyDesc_Files_GotoFile = "<leader>ff goto-file"
nnoremap <leader>ff    :action GotoFile<CR>
vnoremap <leader>ff    :action GotoFile<CR>

" Save all files
let g:WhichKeyDesc_Files_SaveAll = "<leader>fS save-all"
nnoremap <leader>fS    :action SaveAll<CR>
vnoremap <leader>fS    :action SaveAll<CR>

" Save single file (I think that Intellij autosaves anything by default anyway)
let g:WhichKeyDesc_Files_Save = "<leader>fs save"
nnoremap <leader>fs    :action SaveDocument<CR>
vnoremap <leader>fs    :action SaveDocument<CR>

" Save all files
let g:WhichKeyDesc_Files_SaveAll = "<leader>fS save-all"
nnoremap <leader>fS    :action SaveAll<CR>
vnoremap <leader>fS    :action SaveAll<CR>
