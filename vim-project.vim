let g:projectFiles = {}
let s:lastBufferNum = 0
let s:ungroupLnum = 0

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

function! s:GetNameFromNum(bufNum)
  return fnamemodify(bufname(a:bufNum), ":p")
endfunction

function! s:AddBufferToProject(buferNum, groupName)
  let bufName = s:GetNameFromNum(a:buferNum)

  if !has_key(g:projectFiles, a:groupName)
    let g:projectFiles[a:groupName] = [bufName]
  else
    call add(g:projectFiles[a:groupName], bufName)
  endif
endfunction

function! s:RemoveBufferFromProject(buferNum)
  let bufName = s:GetNameFromNum(a:buferNum)

  for key in keys(g:projectFiles)
    call filter(g:projectFiles[key], 'v:val != bufName')
    if empty(g:projectFiles[key])
      unlet g:projectFiles[key]
    endif
  endfor
endfunction

function! s:RemoveCurrentBufferFromProject()
  call s:RemoveBufferFromProject(bufnr('%'))
endfunction
function! s:PrintProject()
  setlocal modifiable
  normal ggdG
  let buffersDict = s:GetBuffersDict()
  let ungroupedBuffers = copy(buffersDict)
  let res = []
  for p in keys(g:projectFiles)
    call add(res, p)
    for i in g:projectFiles[p]
      call add(res, printf("%i  %-30s --- %-s", buffersDict[i], fnamemodify(i,':p:t'), fnamemodify(i,':p:h') ))
      if has_key(ungroupedBuffers, i)
        unlet ungroupedBuffers[i]
      endif
    endfor
    call add(res, "")
  endfor

  let s:ungroupLnum = len(res)  
  if !empty(ungroupedBuffers)
    call add(res, "ungruped")
    for i in keys(ungroupedBuffers)
        call add(res, printf("%i  %-30s --- %-s", ungroupedBuffers[i], fnamemodify(i,':p:t'), fnamemodify(i,':p:h') ))
    endfor
  endif

  call append(0, res)
  setlocal nomodifiable
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

function! ProjectExplorer()
  let s:lastBufferNum = bufnr('%')
  exe "drop __ProjectExplorer__"
  call s:PrintProject()
  setlocal nobuflisted

endfunction

function! s:BufferSettings()
    setlocal buftype=nofile
    setlocal bufhidden=hide
    setlocal noswapfile
    setlocal nobuflisted
    setlocal nomodifiable
    setlocal filetype=gundo
    setlocal nolist
    setlocal nonumber
    setlocal norelativenumber
    setlocal nowrap
    setlocal cursorline
    call s:SetupSyntax()
    call s:MapKeys()
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
        nnoremap <buffer> <silent> <tab> :call <SID>JumpToSelectedBuffer()<CR>
    endif

    nnoremap <script> <silent> <buffer> <2-leftmouse> :call <SID>JumpToSelectedBuffer()<CR>
    nnoremap <script> <silent> <buffer> <CR>          :call <SID>JumpToSelectedBuffer()<CR>
    nnoremap <script> <silent> <buffer> q             :call <SID>Close()<CR>
    nnoremap <script> <silent> <buffer> -             :call <SID>RemoveAddSelectedBuffer()<cr>

    for k in ["G", "n", "N", "L", "M", "H"]
        exec "nnoremap <buffer> <silent>" k ":keepjumps normal!" k."<CR>"
    endfor
endfunction


function! s:GetSelectedBufferNum()
    return str2nr(getline('.'))
endfunction

function! s:JumpToSelectedBuffer()
    let _bufNbr = s:GetSelectedBufferNum()
    exec 'b '._bufNbr
endfunction

function! s:Close()
    exec 'b '.s:lastBufferNum
endfunction

function! s:RemoveAddSelectedBuffer()
	let lnum = line('.')
  if lnum > s:ungroupLnum
    call s:AddSelectedBufferToProject()
  else
    call s:RemoveSelectedBufferFromProject()
  endif
endfunction

function! s:RemoveSelectedBufferFromProject()
  let bufferNum = s:GetSelectedBufferNum()
	let lnum = line('.')
  call s:RemoveBufferFromProject(bufferNum)
  call s:PrintProject()
  keepjumps exe "normal " . lnum . "gg"
endfunction

function! s:AddSelectedBufferToProject()
  let bufferNum = s:GetSelectedBufferNum()
			"let color = inputlist(['Select color:', '1. red', '2. green', '3. blue'])
  let l = []
  let n = 0
  for key in keys(g:projectFiles)
    call append(l, n . ". " . key)
    let n += 1
  endfor
  
  let group = inputlist(l)

  echo "addToProject!!"
endfunction

autocmd BufNewFile __ProjectExplorer__ call s:BufferSettings()



function! s:AddCurrentBufferToProject(groupName)
  call s:AddBufferToProject(bufnr('%'), a:groupName)
endfunction
"--------------------------------------------------------------------------------
:e /home/roman/Documents/projects/sandbox/py/testGp.py
:e /home/roman/Documents/projects/sandbox/py/plot.gpi
:e /home/roman/Documents/projects/numericalTable/ftable.cpp
:e /home/roman/Documents/projects/wikidpad-plugins/user_extensions/R_CodeSyntax.py
:e /home/roman/Documents/projects/wikidpad-plugins/user_extensions/R_QText.py

"echo s:GetBuffers()
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
"call ProjectExplorer()
