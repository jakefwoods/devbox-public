" === <leader>o commands ===
let g:WhichKeyDesc_Open = "<leader>o    +open"

" Activate terminal window
let g:WhichKeyDesc_Projects_OpenShell = "<leader>ot open-shell"
nnoremap <leader>ot    :action ActivateTerminalToolWindow<CR>
vnoremap <leader>ot    :action ActivateTerminalToolWindow<CR>


" Toggle project sidebar
let g:WhichKeyDesc_Projects_ToggleProjectSidebar = "<leader>op toggle-project-sidebar"
nnoremap <leader>op    :action ActivateProjectToolWindow<CR>
vnoremap <leader>op    :action ActivateProjectToolWindow<CR>
