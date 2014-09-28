" ============================================================================
" File:        vim-project.vim
" Description: Plugin for organizing buffers.
" Author:      Roman Fedotov
" Licence:     Vim licence
" Version:     0.0.2
"
" ============================================================================
let s:projectFiles = [] " list of groups
" group : [groupData, groupBuffers]
let s:projectFileName = ""
let s:lastBufferNum = 0

let s:buffersDict = {}
let s:lineInfo = []
let s:buffersProperty = {}

function! s:GetBuffers() "{{{1
  return filter(range(1, bufnr('$')), "buflisted(v:val)")
  "fnamemodify(bufname(v:val), ':p')")
endfunction

function! s:GetBuffersDict() "{{{1
  let l = s:GetBuffers()
  let res = {}
  for i in l
    let bufName = fnamemodify(bufname(i), ':p')
    let res[bufName] = i
  endfor
  return res
endfunction

function! s:GetBuffersProperty() "{{{1
  redir => lsOutput
  silent buffers!
  redir END
  let lsLines = split(lsOutput, '\n')
  let res = {}
  for l in lsLines
    let res[str2nr(l[:2])]=l[4:7]
  endfor
  return res
endfunction

function! s:GetNameFromNum(bufNum) "{{{1
  return fnamemodify(bufname(a:bufNum), ":p")
endfunction

function! s:GroupData(groupName, ...)
    return [a:groupName] + (a:0 == 0 ? [0] : a:000)
endfunction

function! s:GroupDataGetName(groupData)
  return a:groupData[0]
endfunction

function! s:GroupDataSetName(groupData, name)
  let a:groupData[0] = a:name
endfunction

function! s:GroupDataGetClosed(groupData)
  return a:groupData[1]
endfunction

function! s:GroupDataSetClosed(groupData, isClosed)
  let a:groupData[1] = a:isClosed
endfunction


function! s:ProjectGetGroupBuffersByIndex(groupIndex) "{{{1
 return s:projectFiles[a:groupIndex][1]
endfunction

function! s:ProjectGetGroup(groupName, createNew) "{{{1
  for i in s:projectFiles
    if s:GroupDataGetName(i[0]) == a:groupName | return i | endif
  endfor
  if a:createNew
    let newGroup = [s:GroupData(a:groupName), []]
    call add(s:projectFiles, newGroup)
    return newGroup
  endif
  return []
endfunction


function! s:ProjectAddBuffer(bufferNum, groupName) "{{{1
  let bufName = s:GetNameFromNum(a:bufferNum)
  let group = s:ProjectGetGroup(a:groupName, 1)
  call add(group[1], bufName)
endfunction

function! s:ProjectRemoveBuffer(bufferNum) "{{{1
  let bufName = s:GetNameFromNum(a:bufferNum)

  for [groupData, buffers] in s:projectFiles
    call filter(buffers, 'v:val != bufName')
  endfor

  call filter(s:projectFiles, '!empty(v:val[1])')
endfunction

function! s:ProjectSave(fileName) "{{{1
  let lastBufferNum = bufnr('%')
  let buffersDict = s:GetBuffersDict()
  let res = []
  for [groupData, buffers]  in s:projectFiles
    call add(res, s:GroupDataGetName(groupData) . " " . s:GroupDataGetClosed(groupData))

    for b in buffers
      if !has_key(buffersDict, b) | continue | endif
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

function! s:ProjectLoad(fileName) "{{{1
  let s:projectFiles = []
"echo matchlist("abc-def", '\(.*\)-\(.*\)')
  let groupNameEx = '^\(\w\+\)\s\([01]\)$'
  let bufferNameEx = '^\s\s\(\S\+\)$'
  let currentList = []

  for l in readfile(a:fileName)
    if l =~ groupNameEx
      let [all, groupName, isClosed] = matchlist(l, groupNameEx)[:2]
      let currentList = []
      call add(s:projectFiles, [s:GroupData(groupName, isClosed), currentList])
    elseif l =~ bufferNameEx
      let bufferName = matchlist(l, bufferNameEx)[1]
      call add(currentList, bufferName)
      silent exe "badd " . bufferName
    endif
  endfor
  let s:projectFileName = a:fileName
endfunction

function! s:ProjectGetUngrouped() "{{{1
  let groupedBuffers = []
  for [gd, b] in s:projectFiles
    let groupedBuffers += b
  endfor

  let ungroupedBuffers = keys(s:buffersDict)
  call filter(ungroupedBuffers, 'index(groupedBuffers, v:val) == -1')
  return ungroupedBuffers
endfunction

function! s:ProjectPrint() "{{{1
"let s:lastBufferNum = 0
  let lnum = 0
  setlocal modifiable
  normal! gg"_dG

  let allGroups = copy(s:projectFiles)
  call add(allGroups, [s:GroupData("ungrouped"), s:ProjectGetUngrouped()])

  let res = []
  let s:lineInfo = [0]
  let numGroups = len(s:projectFiles)
  for i in range(len(allGroups))
    let [groupData, buffersList] = allGroups[i]
    let groupIndex = i < numGroups ? i : -1

    call add(res, (s:GroupDataGetClosed(groupData) ? "▶ " : "▼ ") .s:GroupDataGetName(groupData))
    call add(s:lineInfo, [groupIndex, -1, -1])

    if s:GroupDataGetClosed(groupData) | continue | endif

    for bufferIndex in range(len(buffersList))
      let bufferName = buffersList[bufferIndex]
      if !has_key(s:buffersDict, bufferName) | continue | endif
      let bufferNum = s:buffersDict[bufferName]
      let bufferProp = s:buffersProperty[bufferNum]
			if getbufvar(bufferNum, "&bt") == "quickfix" | continue | endif

      call add(res, printf("%3i %s %-50s %-s", bufferNum, bufferProp, fnamemodify(bufferName,':p:t'), fnamemodify(bufferName,':p:h') ))
      call add(s:lineInfo, [groupIndex, bufferIndex, bufferNum])
      let lnum += bufferNum == s:lastBufferNum ? len(res) : 0
    endfor
    call add(res, "")
    call add(s:lineInfo, [groupIndex, -1, -1])
  endfor

  call append(0, res)

  keepjumps keepalt exe "normal! " . lnum . "gg"
  setlocal nomodifiable
endfunction

function! s:ProjectGetLineInfo() "{{{1
  let [groupIndex, bufferIndex, bufferNum] = s:lineInfo[line('.')]
  let bufferName = (groupIndex != -1 && bufferIndex != -1) ? s:projectFiles[groupIndex][1][bufferIndex] : -1
  return [bufferNum, groupIndex, bufferIndex]
endfunction

function! s:ProjectGetLineByGroupIndex(groupIndex, bufferIndex)
  for i in range(1, len(s:lineInfo)-1)
    let curInfo = s:lineInfo[i]
    if curInfo[0] == a:groupIndex && curInfo[1] == a:bufferIndex | return i | endif
  endfor
endfunction

function! s:ProjectCloseAllUnprojectBuffers() "{{{1
  let s:buffersDict = s:GetBuffersDict()
  for bufferName in s:ProjectGetUngrouped()
    let bufferNum = s:buffersDict[bufferName]
    execute "bwipeout ".bufferNum
  endfor
endfunction

function! s:ProjectAskAddBuffer(bufferNum) "{{{1
  let l = ""
  let n = 1
  for [groupData, buffers] in s:projectFiles
    let l = l . n . ". " . s:GroupDataGetName(groupData) . "\n"
    let n += 1
  endfor
  let l = l."Enter nuber or name of group: "

  let groupName = input(l)
  let groupsBuffers = []
  if groupName =~ '^\d\+$'
    let groupsBuffers = s:projectFiles[groupName-1][1]
  else
    let groupsBuffers = s:ProjectGetGroup(groupName, 1)[1]
  endif

  call add(groupsBuffers, s:GetNameFromNum(a:bufferNum))
endfunction

function! s:ProjectRenameGroup(groupIndex) "{{{1
  let newName = input("Enter new group name: ")
  call s:GroupDataSetName(s:projectFiles[a:groupIndex][0] , newName)
endfunction

function! s:ProjectMoveGroup(groupIndex, delta) "{{{1
  let newIndex = a:groupIndex + a:delta
  if newIndex < 0 || newIndex >= len(s:projectFiles) | return a:groupIndex | endif
  let tmp = s:projectFiles[a:groupIndex]
  let s:projectFiles[a:groupIndex] = s:projectFiles[newIndex]
  let s:projectFiles[newIndex] = tmp
  return newIndex
endfunction

function! s:ProjectMoveBuffer(groupIndex, bufferIndex, delta) "{{{1
  let buffers = s:projectFiles[a:groupIndex][1]
  let newIndex = a:bufferIndex + a:delta
  if newIndex < 0 || newIndex >= len(buffers) | return a:bufferIndex | endif
  let tmp = buffers[a:bufferIndex]
  let buffers[a:bufferIndex] = buffers[newIndex]
  let buffers[newIndex] = tmp
  return newIndex
endfunction

function! WindowOpen() "{{{1
  let s:buffersProperty = s:GetBuffersProperty()
  let s:buffersDict = s:GetBuffersDict()

  let s:lastBufferNum = bufnr('%')
  exe "keepjumps drop __ProjectExplorer__"
  setlocal nobuflisted " TODO: solve this
  call s:ProjectPrint()
endfunction

function! s:WindowBufferSettings() "{{{1
    setlocal buftype=nofile
    setlocal bufhidden=hide
    setlocal noswapfile
    setlocal nobuflisted
    setlocal nolist
    setlocal nonumber
    setlocal relativenumber
    setlocal nowrap
    setlocal cursorline
    call s:WindowSetupSyntax()
    call s:WindowMapKeys()
    setlocal nomodifiable
endfunction

function! s:WindowSetupSyntax() "{{{1
    if has("syntax")
        "'[u ][%# ][ah ][-= ][+x ] \S\+'
        syn match projectExplorerBufNbr         /^\s*\d\+/
        syn match projectExplorerGroupName      "^[▶▼] \w\+$"
        syn match projectExplorerLoadedBuffer   '[u ][%# ]h[-= ][+x ] \S\+'
        syn match projectExplorerCurrentBuffer  '[u ][%# ]a[-= ][+x ] \S\+'
        syn match projectExplorerModifiedBuffer '[u ][%# ][ah ][-= ]+ \S\+'

        hi def link projectExplorerBufNbr Number
        hi def link projectExplorerGroupName Statement
        hi def link projectExplorerLoadedBuffer Constant
        hi def link projectExplorerCurrentBuffer Type
        hi def link projectExplorerModifiedBuffer PreProc

    endif
endfunction

function! s:WindowMapKeys() "{{{1
    if exists("b:displayMode") && b:displayMode == "winmanager"
        nnoremap <buffer> <silent> <tab> :call <SID>WindowJumpToBuffer()<CR>
    endif

    nnoremap <script> <silent> <buffer> <2-leftmouse> :call <SID>WindowJumpToBuffer()<CR>
    nnoremap <script> <silent> <buffer> <CR>          :call <SID>WindowJumpToBuffer()<CR>
    nnoremap <script> <silent> <buffer> q             :call <SID>WindowClose()<CR>
    nnoremap <script> <silent> <buffer> -             :call <SID>WindowAddRemoveBuffer()<cr>
    nnoremap <script> <silent> <buffer> D             :call <SID>WindowWipeBuffer()<CR>
    nnoremap <script> <silent> <buffer> <C-j>         :call <SID>WindowMoveBuffer(1)<cr>
    nnoremap <script> <silent> <buffer> <C-k>         :call <SID>WindowMoveBuffer(-1)<cr>
    nnoremap <script> <silent> <buffer> J             :call <SID>WindowMoveGroup(1)<cr>
    nnoremap <script> <silent> <buffer> K             :call <SID>WindowMoveGroup(-1)<cr>
    nnoremap <script> <silent> <buffer> r             :call <SID>WindowRenameGroup ()<cr>
    nnoremap <script> <silent> <buffer> zo            :call <SID>WindowOpenCloseGroup(0)<cr>
    nnoremap <script> <silent> <buffer> zc            :call <SID>WindowOpenCloseGroup(1)<cr>

    for k in ["G", "n", "N", "L", "M", "H"]
        exec "nnoremap <buffer> <silent>" k ":keepjumps normal!" k."<CR>"
    endfor
endfunction

function! s:WindowSetCursorToIndex(groupIndex, bufferIndex) "{{{1
  keepjumps keepalt exe "normal! " . s:ProjectGetLineByGroupIndex(a:groupIndex, a:bufferIndex) . "gg"
endfunction

"function! s:WindowGetBufferNum() "{{{1
    "return str2nr(getline('.'))
"endfunction
function! s:WindowJumpToBuffer() "{{{1
  let [bufferNum, groupIndex, bufferIndex] = s:ProjectGetLineInfo()
  if bufferIndex == -1 | return | endif

  let viewIsLoaded = bufloaded(bufferNum)
  exec 'keepalt b '.bufferNum
  if !viewIsLoaded
    loadview
  endif
endfunction

function! s:WindowClose() "{{{1
    exec 'keepalt b '.s:lastBufferNum
endfunction

function! s:WindowWipeBuffer() "{{{1
  let [bufferNum, groupIndex, bufferIndex] = s:ProjectGetLineInfo()
  if bufferIndex == -1 | return | endif

	let lnum = line('.')
  unlet s:buffersDict[s:GetNameFromNum(bufferNum)]
  call s:ProjectRemoveBuffer(bufferNum)
  execute "bwipeout ".bufferNum
  call s:ProjectPrint()
  keepjumps keepalt exe "normal! " . lnum . "gg"
endfunction

function! s:WindowAddRemoveBuffer() "{{{1
  let [bufferNum, groupIndex, bufferIndex] = s:ProjectGetLineInfo()
  if bufferIndex == -1 | return | endif

  if groupIndex == -1
    call s:WindowAddBufferToProject()
  else
    call s:WindowRemoveBufferFromProject()
  endif
endfunction

function! s:WindowRemoveBufferFromProject() "{{{1
  let [bufferNum, groupIndex, bufferIndex] = s:ProjectGetLineInfo()
  if bufferIndex == -1 | return | endif

	let lnum = line('.')
  call s:ProjectRemoveBuffer(bufferNum)
  call s:ProjectPrint()
  keepjumps keepalt exe "normal! " . lnum . "gg"
endfunction

function! s:WindowAddBufferToProject() "{{{1
  let [bufferNum, groupIndex, bufferIndex] = s:ProjectGetLineInfo()
  if bufferIndex == -1 | return | endif

  call s:ProjectAskAddBuffer(bufferNum)
  call s:ProjectPrint()
endfunction

function! s:WindowMoveBuffer(delta) "{{{1
  let [bufferNum, groupIndex, bufferIndex] = s:ProjectGetLineInfo()
  if bufferIndex == -1 | return | endif

  let bufferIndex = s:ProjectMoveBuffer(groupIndex, bufferIndex, a:delta)
  call s:ProjectPrint()
  call s:WindowSetCursorToIndex(groupIndex, bufferIndex)
endfunction

function! s:WindowMoveGroup (delta) "{{{1
  let [bufferNum, groupIndex, bufferIndex] = s:ProjectGetLineInfo()
  if groupIndex == -1 | return | endif

  let groupIndex =  s:ProjectMoveGroup(groupIndex, a:delta)
  call s:ProjectPrint()
  call s:WindowSetCursorToIndex(groupIndex, bufferIndex)
endfunction

function! s:WindowRenameGroup () "{{{1
  let [bufferNum, groupIndex, bufferIndex] = s:ProjectGetLineInfo()
  if groupIndex == -1 | return | endif

  call s:ProjectRenameGroup(groupIndex)
  call s:ProjectPrint()
  call s:WindowSetCursorToIndex(groupIndex, bufferIndex)
endfunction

function! s:WindowOpenCloseGroup (close) "{{{1
  let [bufferNum, groupIndex, bufferIndex] = s:ProjectGetLineInfo()
  if groupIndex == -1 | return | endif

  call s:GroupDataSetClosed(s:projectFiles[groupIndex][0], a:close)
  call s:ProjectPrint()
  call s:WindowSetCursorToIndex(groupIndex, -1)
endfunction


autocmd BufNewFile __ProjectExplorer__ call s:WindowBufferSettings()

" {{{1 commands
command! -nargs=0 ProjectExplorer call WindowOpen()
command! -nargs=0 ProjectCloseUngroup call <SID>ProjectCloseAllUnprojectBuffers()
command! -nargs=1 ProjectLoad call <SID>ProjectLoad("<args>")
command! -nargs=? ProjectSave call <SID>ProjectSave("<args>")

ProjectLoad /home/roman/Documents/prj.txt
