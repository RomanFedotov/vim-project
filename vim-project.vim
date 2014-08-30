let g:projectFiles = {}
let s:running = 0

function! s:GetBuffers()
  return filter(range(1, bufnr('$')), "buflisted(v:val)")
  "fnamemodify(bufname(v:val), ':p')")
endfunction

function! s:GetBuffersDict()
  let l = filter(range(1, bufnr('$')), "buflisted(v:val)")
  let res = {}
  for i in l
    let bufName = fnamemodify(bufname(i), ':p')
    let res[bufName] = i
  endfor
  return res
endfunction

function! s:GetCurrentBufferName()
  return fnamemodify(bufname("%"), ":p")
endfunction

function! s:AddCurrentBufferToProject(groupName)
  let bufName = s:GetCurrentBufferName()

  if !has_key(g:projectFiles, a:groupName)
    let g:projectFiles[a:groupName] = [bufName]
  else
    call add(g:projectFiles[a:groupName], bufName)
  endif
endfunction

function! s:RemoveCurrentBufferFromProject()
  let bufName = s:GetCurrentBufferName()

  for key in keys(g:projectFiles)
    call filter(g:projectFiles[key], 'v:val != bufName')
    if empty(g:projectFiles[ket])
      unlet g:projectFiles[key]
    endif
  endfor
endfunction

function! s:PrintProject()
  let buffersDict = s:GetBuffersDict()
  let res = []
  for p in keys(g:projectFiles)
    call add(res, p)
    for i in g:projectFiles[p]
      call add(res, printf("%i  %-30s --- %-s", buffersDict[i], fnamemodify(i,':p:t'), fnamemodify(i,':p:h') ))
    endfor
    call add(res, "")
  endfor
  call append(0, res)
endfunction

function! s:CloseAllUnprojectBuffers()
  for i in s:GetBuffers()
    let bufName = fnamemodify(bufname(i), ':p')
    let all = []
    for val in values(g:projectFiles)
      let all += val
    endfor

    if index(all, bufName) == -1
      execute "bwipeout ".i
    endif

  endfor
endfunction

function! s:ProjectExplorer()
  let name = 'ProjectExplorer'
    " Make sure there is only one explorer open at a time.
  if s:running == 1
    " Go to the open buffer.

    return
  endif

  exec "drop" name

  setlocal buftype=nofile
  setlocal modifiable
  setlocal noswapfile
  setlocal nowrap
  call s:SetupSyntax()
  call s:PrintProject()
  setlocal nomodifiable
endfunction


function! s:SetupSyntax()
    if has("syntax")
        syn match bufExplorerBufNbr   /^\s*\d\+/
        syn match bufExplorerGroupName   "^\w\+$"

        hi def link bufExplorerBufNbr Number
        hi def link bufExplorerGroupName Statement


    endif
endfunction

function! s:MapKeys()
    if exists("b:displayMode") && b:displayMode == "winmanager"
        nnoremap <buffer> <silent> <tab> :call <SID>SelectBuffer()<CR>
    endif

    nnoremap <script> <silent> <buffer> <2-leftmouse> :call <SID>SelectBuffer()<CR>
    nnoremap <script> <silent> <buffer> <CR>          :call <SID>SelectBuffer()<CR>
    nnoremap <script> <silent> <buffer> q             :call <SID>Close()<CR>

    for k in ["G", "n", "N", "L", "M", "H"]
        exec "nnoremap <buffer> <silent>" k ":keepjumps normal!" k."<CR>"
    endfor
endfunction

"return s:Close()

function! s:SelectBuffer(...)
    let _bufNbr = str2nr(getline('.'))
    "return s:Close()
    exec 'b '._bufNbr

endfunction
"134 dfdf df df df 

function! s:Close()
    " If we needed to split the main window, close the split one.
    if (s:splitMode != "")
        exec "wincmd c"
    endif
endfunction




:e /home/roman/Documents/projects/sandbox/py/testGp.py
:e /home/roman/Documents/projects/sandbox/py/plot.gpi
:e /home/roman/Documents/projects/numericalTable/ftable.cpp
:e /home/roman/Documents/projects/wikidpad-plugins/user_extensions/R_CodeSyntax.py
:e /home/roman/Documents/projects/wikidpad-plugins/user_extensions/R_QText.py

"echo s:GetBuffers()
"echo s:GetCurrentBufferName()
call s:AddCurrentBufferToProject('group1')
:bn
call s:AddCurrentBufferToProject('group2')
:bn
call s:AddCurrentBufferToProject('group2')
"echo g:projectFiles
call s:CloseAllUnprojectBuffers()
"echo s:GetBuffers()
"echo g:projectFiles
"call s:PrintProject()
call s:ProjectExplorer()
