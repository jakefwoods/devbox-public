" === <leader>c commands ===
let g:WhichKeyDesc_Code = "<leader>c    +code"

let g:WhichKeyDesc_Code_CodeAction = "<leader>ca code-action"
nnoremap <leader>ca    :action ShowIntentionActions<CR>
vnoremap <leader>ca    :action ShowIntentionActions<CR>

let g:WhichKeyDesc_Code_Compile = "<leader>cc compile"
nnoremap <leader>cc    :action Compile<CR>
vnoremap <leader>cc    :action Compile<CR>

let g:WhichKeyDesc_Code_Recompile = "<leader>cC recompile"
nnoremap <leader>cC    :action CompileDirty<CR>
vnoremap <leader>cC    :action CompileDirty<CR>

let g:WhichKeyDesc_Code_Rename = "<leader>cr rename"
nnoremap <leader>cr    :action RenameElement<CR>
vnoremap <leader>cr    :action RenameElement<CR>
