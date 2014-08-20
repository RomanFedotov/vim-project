let g:projectFiles = {}

function! s:GetBuffers()
  return filter(range(1, bufnr('$')), "buflisted(v:val)")
  "fnamemodify(bufname(v:val), ':p')")
endfunction

function! s:GetCurrentBufferName()
  return fnamemodify(bufname("%"), ":p")
endfunction

function! s:AddCurrentBufferToProject(groupName)
  let bufName = s:GetCurrentBufferName()

  if !has_key(g:projectFiles, groupName)
    let g:projectFiles[groupName] = [bufName]
  else
    call add(g:projectFiles[groupName], bufName)
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

function! s:CloseAllUnprojectBuffers()
  for i in s:GetBuffers()
    let bufName = fnamemodify(bufname(i), ':p')
    let all = []
    for val in values(g:projectFiles)
      all += val
    endfor

    if index(all, bufName) == -1
      execute "bwipeout ".i
    endif

  endfor
endfunction

:e /home/roman/Documents/projects/sandbox/py/testGp.py
:e /home/roman/Documents/projects/sandbox/py/plot.gpi
:e /home/roman/Documents/projects/numericalTable/ftable.cpp
:e /home/roman/Documents/projects/wikidpad-plugins/user_extensions/R_CodeSyntax.py
:e /home/roman/Documents/projects/wikidpad-plugins/user_extensions/R_QText.py

echo s:GetBuffers()
echo s:GetCurrentBufferName()
call s:AddCurrentBufferToProject()
:bn
call s:AddCurrentBufferToProject()
echo s:GetBuffers()
echo g:projectFiles
call s:CloseAllUnprojectBuffers()
echo g:projectFiles
