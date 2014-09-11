" ============================================================================
" File:        vim-project.vim
" Description: Plugin for organizing buffers. 
" Author:      Roman Fedotov
" Licence:     Vim licence
" Version:     0.0.1
"
" ============================================================================
let s:projectFiles = {}
let s:projectFileName = ""
let s:lastBufferNum = 0
let s:ungroupLnum = 0

function! s:GetBuffers()
  return filter(range(1, bufnr('$')), "buflisted(v:val)")
  "fnamemodify(bufname(v:val), ':p')")
endfunction

function! s:GetBuffersDict()
  let l = s:GetBuffers()
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

function! s:AddBufferToProject(bufferNum, groupName)
  let bufName = s:GetNameFromNum(a:bufferNum)

  if !has_key(s:projectFiles, a:groupName)
    let s:projectFiles[a:groupName] = [bufName]
  else
    call add(s:projectFiles[a:groupName], bufName)
  endif
endfunction

function! s:RemoveBufferFromProject(bufferNum)
  let bufName = s:GetNameFromNum(a:bufferNum)

  for key in keys(s:projectFiles)
    call filter(s:projectFiles[key], 'v:val != bufName')
    if empty(s:projectFiles[key])
      unlet s:projectFiles[key]
    endif
  endfor
endfunction

function! s:RemoveCurrentBufferFromProject()
  call s:RemoveBufferFromProject(bufnr('%'))
endfunction
function! s:PrintProject()
"let s:lastBufferNum = 0
  let lnum = 0
  setlocal modifiable
  normal! gg"_dG
  let buffersDict = s:GetBuffersDict()

  let groupedBuffers = []
  for b in values(s:projectFiles)
    let groupedBuffers += b
  endfor

  let ungroupedBuffers = keys(buffersDict)
  call filter(ungroupedBuffers, 'index(groupedBuffers, v:val) == -1')

  let allGroups = items(s:projectFiles)
  call add(allGroups, ["ungrouped", ungroupedBuffers])

  let res = []
  for [groupName, buffersList] in allGroups
    call add(res, groupName)
    if groupName == "ungrouped"
      let s:ungroupLnum = len(res)
    endif

    for i in buffersList
      if !has_key(buffersDict, i) | continue | endif
      let bufferNum = buffersDict[i]
			if getbufvar(bufferNum, "&bt") == "quickfix" | continue | endif

      let isCurrent = buffersDict[i] == s:lastBufferNum 
      let s = ["", "", ""] 
      let s[0] = bufloaded(bufferNum) ? (isCurrent? "a" : "h")  : " "
			let s[1] = getbufvar(bufferNum, "&ma") ? " " : "-"
			let s[1] = getbufvar(bufferNum, "&readonly") ? "=" : s[1]
			let s[2] = getbufvar(bufferNum, "&mod") ? "+" : " "

      call add(res, printf("%3i %s %-50s %-s", buffersDict[i], join(s,''), fnamemodify(i,':p:t'), fnamemodify(i,':p:h') ))
      let lnum += isCurrent ? len(res) : 0
    endfor
    call add(res, "")
  endfor

  call append(0, res)

  keepjumps keepalt exe "normal! " . lnum . "gg"
  setlocal nomodifiable
endfunction

function! s:CloseAllUnprojectBuffers()
  for i in s:GetBuffers()
    let bufName = fnamemodify(bufname(i), ':p')
    let all = []
    for val in values(s:projectFiles)
      let all += val
    endfor

    if index(all, bufName) == -1
      execute "bwipeout ".i
    endif

  endfor
endfunction

function! ProjectExplorer()
  let s:lastBufferNum = bufnr('%')
  exe "keepjumps drop __ProjectExplorer__"
  setlocal nobuflisted " TODO: solve this 
  call s:PrintProject()
endfunction

function! s:BufferSettings()
    setlocal buftype=nofile
    setlocal bufhidden=hide
    setlocal noswapfile
    setlocal nobuflisted
    setlocal filetype=gundo
    setlocal nolist
    setlocal nonumber
    setlocal relativenumber
    setlocal nowrap
    setlocal cursorline
    call s:SetupSyntax()
    call s:MapKeys()
    setlocal nomodifiable
endfunction

function! s:SetupSyntax()
    if has("syntax")
        syn match bufExplorerBufNbr   /^\s*\d\+/
        syn match bufExplorerGroupName   "^\w\+$"
        syn match bufExplorerLoadedBuffer   "h[ -=][ +] \S\+"
        syn match bufExplorerCurrentBuffer  "a[ -=][ +] \S\+"
        syn match bufExplorerModifiedBuffer "h[ -=]+ \S\+"

        hi def link bufExplorerBufNbr Number
        hi def link bufExplorerGroupName Statement
        hi def link bufExplorerLoadedBuffer Constant
        hi def link bufExplorerCurrentBuffer Type
        hi def link bufExplorerModifiedBuffer PreProc

    endif
endfunction

function! s:MapKeys()
    if exists("b:displayMode") && b:displayMode == "winmanager"
        nnoremap <buffer> <silent> <tab> :call <SID>JumpToSelectedBuffer()<CR>
    endif

    nnoremap <script> <silent> <buffer> <2-leftmouse> :call <SID>JumpToSelectedBuffer()<CR>
    nnoremap <script> <silent> <buffer> <CR>          :call <SID>JumpToSelectedBuffer()<CR>
    nnoremap <script> <silent> <buffer> q             :call <SID>CloseSelectedBuffer()<CR>
    nnoremap <script> <silent> <buffer> -             :call <SID>AddRemoveSelectedBuffer()<cr>
    nnoremap <script> <silent> <buffer> D             :call <SID>WipeSelectedBuffer()<CR>
    nnoremap <script> <silent> <buffer> <C-j>         :call <SID>MoveSelectedBuffer(1)<cr>
    nnoremap <script> <silent> <buffer> <C-k>         :call <SID>MoveSelectedBuffer(-1)<cr>
    for k in ["G", "n", "N", "L", "M", "H"]
        exec "nnoremap <buffer> <silent>" k ":keepjumps normal!" k."<CR>"
    endfor
endfunction

function! IsSelectedBuffer()
  let bufferNameEx = '^\s*\s\+ '
  return getline('.') =~ bufferNameEx
endfunction

function! s:GetSelectedBufferNum()
    return str2nr(getline('.'))
endfunction

function! s:JumpToSelectedBuffer()
    if !IsSelectedBuffer() | return | endif

    let bufferNum = s:GetSelectedBufferNum()
    let viewIsLoaded = bufloaded(bufferNum)
    exec 'keepalt b '.bufferNum
    if !viewIsLoaded
      loadview
    endif
endfunction

function! s:CloseSelectedBuffer()
    exec 'keepalt b '.s:lastBufferNum
endfunction

function! s:WipeSelectedBuffer()
  if !IsSelectedBuffer() | return | endif

	let lnum = line('.')
  let bufferNum = s:GetSelectedBufferNum()
  call s:RemoveBufferFromProject(bufferNum)
  execute "bwipeout ".bufferNum
  call s:PrintProject()
  keepjumps keepalt exe "normal! " . lnum . "gg"
endfunction

function! s:AddRemoveSelectedBuffer()
  if !IsSelectedBuffer() | return | endif

  let bufferNum = s:GetSelectedBufferNum()
	let lnum = line('.')
  if lnum > s:ungroupLnum
    call s:AddSelectedBufferToProject()
  else
    call s:RemoveSelectedBufferFromProject()
  endif
endfunction

function! s:RemoveSelectedBufferFromProject()
  if !IsSelectedBuffer() | return | endif

  let bufferNum = s:GetSelectedBufferNum()
	let lnum = line('.')
  call s:RemoveBufferFromProject(bufferNum)
  call s:PrintProject()
  keepjumps keepalt exe "normal! " . lnum . "gg"
endfunction

function! s:AskAddBufferToProject(bufferNum)
  let l = ""
  let n = 1
  for key in keys(s:projectFiles)
    "call add(l, n . ". " . key)
    let l = l . n . ". " . key . "\n"
    let n += 1
  endfor
  let l = l."Enter nuber or name of group: "
  
  let groupName = input(l)
  if groupName =~ '^\d\+$'
    let groupName = keys(s:projectFiles)[groupName-1]
  elseif !has_key(s:projectFiles, groupName)
    let  s:projectFiles[groupName] = []
  endif

  call add(s:projectFiles[groupName], s:GetNameFromNum(a:bufferNum))
endfunction

function! s:AddSelectedBufferToProject()
  if !IsSelectedBuffer() | return | endif

  let bufferNum = s:GetSelectedBufferNum()
  call s:AskAddBufferToProject(bufferNum)
  call s:PrintProject()
endfunction

function! s:MoveSelectedBuffer(delta)
  if !IsSelectedBuffer() | return | endif

  let lastBufNumTemp = s:lastBufferNum
  let s:lastBufferNum = s:GetSelectedBufferNum()
  let bufferName = s:GetNameFromNum(s:GetSelectedBufferNum())

  for groupName in keys(s:projectFiles)
    let buffersList = s:projectFiles[groupName]
    let pos = index(buffersList, bufferName)
    if pos != -1 
      let newPos = pos + a:delta
      if newPos < 0 || newPos >= len(buffersList) | continue | endif
      let buffersList[pos] = buffersList[newPos]
      let buffersList[newPos] = bufferName
      call s:PrintProject()
      break
    endif
  endfor
  let s:lastBufferNum = lastBufNumTemp
endfunction


autocmd BufNewFile __ProjectExplorer__ call s:BufferSettings()

function! s:SaveProject(fileName)
  let lastBufferNum = bufnr('%')
  let buffersDict = s:GetBuffersDict()
  let res = []
  for key in keys(s:projectFiles)
    if empty(s:projectFiles[key])
      continue
    endif
    call add(res, key)
    "call filter(s:projectFiles[key], 'v:val != bufName')
    for b in s:projectFiles[key]
      if !has_key(buffersDict, b)
        continue
      endif
      call add(res, "  ".b)
      let bufferNum = buffersDict[b]
      if bufloaded(bufferNum)
        exec 'keepalt keepjumps b '.bufferNum
        mkview
      endif
    endfor
  endfor

  call writefile(res, empty(a:fileName) ? s:projectFileName : a:fileName )

  exec 'keepalt b '.lastBufferNum
endfunction

function! s:LoadProject(fileName)
  let s:projectFiles = {}
"echo matchlist("abc-def", '\(.*\)-\(.*\)')
  let groupNameEx = '^\(\w\+\)$'
  let bufferNameEx = '^\s\s\(\S\+\)$'
  let currentList = []

  for l in readfile(a:fileName)
    if l =~ groupNameEx 
      let groupName = matchlist(l, groupNameEx)[1]
      let currentList = []
      let s:projectFiles[groupName] = currentList
    elseif l =~ bufferNameEx 
      let bufferName = matchlist(l, bufferNameEx)[1]
      call add(currentList, bufferName)
      silent exe "badd " . bufferName
    endif
  endfor
  let s:projectFileName = a:fileName
endfunction

function! s:AskAddCurrentBufferToProject(groupName)
  let bufferNum = bufnr('%')
  call s:RemoveBufferFromProject(bufferNum)
  call s:AskAddBufferToProject(bufferNum, a:groupName)
endfunction

function! s:AddCurrentBufferToProject(groupName)
  let bufferNum = bufnr('%')
  call s:RemoveBufferFromProject(bufferNum)
  call s:AddBufferToProject(bufferNum, a:groupName)
endfunction

command! -nargs=0 ProjectExplorer call ProjectExplorer()
command! -nargs=0 ProjectCloseUngroup call <SID>CloseAllUnprojectBuffers()
command! -nargs=1 LoadProject call <SID>LoadProject("<args>")
command! -nargs=? SaveProject call <SID>SaveProject("<args>")

"--------------------------------------------------------------------------------
"call writefile(['1. zzz', '2. ppp'], '/home/users/romanf/Documents/test.txt' )
"echo matchlist("abc-def", '\(.*\)-\(.*\)')
"--------------------------------------------------------------------------------
":e /home/roman/Documents/projects/sandbox/py/testGp.py
":e /home/roman/Documents/projects/sandbox/py/plot.gpi
":e /home/roman/Documents/projects/numericalTable/ftable.cpp
":e /home/roman/Documents/projects/wikidpad-plugins/user_extensions/R_CodeSyntax.py
":e /home/roman/Documents/projects/wikidpad-plugins/user_extensions/R_QText.py

"call s:AddCurrentBufferToProject('group1')
":bn
"call s:AddCurrentBufferToProject('group2')
":bn
"call s:AddCurrentBufferToProject('group2')
""call s:CloseAllUnprojectBuffers()
":bn
""call SaveProject("/home/roman/Documents/prj.txt")
"call ProjectExplorer()
LoadProject /home/roman/Documents/prj.txt
"call s:CloseAllUnprojectBuffers()


