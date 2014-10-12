" ============================================================================
" File:        vim-project.vim
" Description: Plugin for organizing buffers.
" Author:      Roman Fedotov
" Licence:     Vim licence
" Version:     0.0.3
" ============================================================================


" {{{1 commands
command! -nargs=0 ProjectExplorer call project#windowOpen()
command! -nargs=0 ProjectCloseUngroup call project#closeAllUnprojectBuffers()
command! -nargs=0 ProjectCloseUnlisted call project#closeAllUnlistedBuffers()
command! -nargs=1 ProjectLoad call project#load("<args>")
command! -nargs=? ProjectSave call project#save("<args>")

"ProjectLoad /home/roman/Documents/prj.txt
