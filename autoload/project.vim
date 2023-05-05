" ============================================================================
" File:        vim-project.vim
" Description: Plugin for organizing buffers.
" Author:      Roman Fedotov
" Licence:     Vim licence
" Version:     0.0.3
" ============================================================================

"--------------------------------------------------------------------------------
"                                      Data
"--------------------------------------------------------------------------------
" list of groups. [groupData, groupBuffers]
let s:projectGroups = [] " list of groups
" File name of the current project. Can be empty if project hasn't been saved
" into a file.
let s:projectFileName = ""
" number of the last opened buffer
let s:lastBufferNum = 0
" dictionary of the buffers {fileName : bufferNumber}
let s:buffersDict = {}
" dictionary of the hotkeys {fileName : letter}
let s:buffersHotKeys = {}

" list describes  very line in the project buffer.
" [groupIndex, bufferIndex, bufferNum]
let s:lineInfo = []
" dictionary of buffers properties (second column of the :buffers command) 
" {bufferNumber, propertiesString}
let s:buffersProperty = {}
"--------------------------------------------------------------------------------
"                                  Functions
"--------------------------------------------------------------------------------
function! s:GetBuffers() "{{{1
  return filter(range(1, bufnr('$')), "buflisted(v:val)")
  "fnamemodify(bufname(v:val), ':p')")
endfunction

"------------------------------------Hot Keys------------------------------------{{{1
function! s:HotKeyAdd(letter, bufName) "{{{1
  call s:HotKeyRemove(a:letter)
  let s:buffersHotKeys[a:bufName] = a:letter
  silent exe "nmap <silent> <M-" . a:letter . "> :call <SID>HotKeyJumpToBuffer(\"" . a:bufName . "\")<cr>"
endfunction

function! s:HotKeyJumpToBuffer(bufName) "{{{1
  let viewIsLoaded = bufloaded(a:bufName)
  exec 'keepalt b '.a:bufName
  if !viewIsLoaded
    loadview
  endif
endfunction

function! s:HotKeyRemove(letter) "{{{1
  for [bufName, keyLetter] in items(s:buffersHotKeys)
    if keyLetter == a:letter
      silent exe "nunmap <M-" . a:letter . ">"
      unlet s:buffersHotKeys[bufName]
    endif
  endfor
endfunction

function! s:HotKeyRemoveAll() "{{{1
  for k in keys(s:buffersHotKeys)
    call s:HotKeyRemove(s:buffersHotKeys[k])
  endfor
endfunction
"--------------------------------Buffers functions-------------------------------{{{1
function! s:GetNameFromNum(bufNum) "{{{1
  let n = fnamemodify(bufname(a:bufNum), ":p")
  if fnamemodify(bufname(a:bufNum), ':t') == ""
    return n."[NoName-".a:bufNum."]"
  else
    return n
  endif
endfunction

function! s:GetBuffersDict() "{{{1
  let l = s:GetBuffers()
  let res = {}
  for i in l
    let bufName = s:GetNameFromNum(i)
    let res[bufName] = i
  endfor
  return res
endfunction

function! s:GetBuffersProperty() "{{{1
  redir => lsOutput
  silent buffers
  redir END
  let lsLines = split(lsOutput, '\n')
  let res = {}
  let bufEx = '^\s*\(\d\+\)\s\(.*\)\s"'
  for l in lsLines
    let [bufNum, bufProp] = matchlist(l, bufEx)[1:2]
    let res[bufNum] = bufProp
  endfor
  return res
endfunction

"------------------------------------GroupData-----------------------------------{{{1
" creates group data structure
"
" groupName - string name of the group
" isClosed  - integer 1 if group is closed
function! s:GroupData(groupName, ...) "{{{1
    return [a:groupName] + (a:0 == 0 ? [0] : a:000)
endfunction

function! s:GroupDataGetName(groupData) "{{{1
  return a:groupData[0]
endfunction

function! s:GroupDataSetName(groupData, name) "{{{1
  let a:groupData[0] = a:name
endfunction

function! s:GroupDataGetClosed(groupData) "{{{1
  return a:groupData[1]
endfunction

function! s:GroupDataSetClosed(groupData, isClosed) "{{{1
  let a:groupData[1] = a:isClosed
endfunction

"--------------------------------------------------------------------------------{{{1
function! s:ProjectRemoveClosedBuffers() "{{{1
  for [gd, buffers] in s:projectGroups
    call filter(buffers, "has_key(s:buffersDict, v:val)")
  endfor
endfunction

function! s:ProjectGetGroupBuffersByIndex(groupIndex) "{{{1
 return s:projectGroups[a:groupIndex][1]
endfunction

function! s:ProjectGetGroup(groupName, createNew) "{{{1
  for i in s:projectGroups
    if s:GroupDataGetName(i[0]) == a:groupName | return i | endif
  endfor
  if a:createNew
    let newGroup = [s:GroupData(a:groupName), []]
    call add(s:projectGroups, newGroup)
    return newGroup
  endif
  return []
endfunction


function! s:ProjectAddBuffer(bufferNum, groupName) "{{{1
  let bufName = s:GetNameFromNum(a:bufferNum)
  let group = s:ProjectGetGroup(a:groupName, 1)
  call add(group[1], bufName)
endfunction

function! s:ProjectRemoveBuffers(bufferNums) "{{{1
  for i in a:bufferNums
    let bufName = s:GetNameFromNum(i)

    for [groupData, buffers] in s:projectGroups
      call filter(buffers, 'v:val != bufName')
    endfor
  endfor

  call filter(s:projectGroups, '!empty(v:val[1])')
endfunction

function! project#save(fileName) "{{{1
  "wa
  let lastBufferNum = bufnr('%')
  let buffersDict = s:GetBuffersDict()
  let res = []
  for [groupData, buffers]  in s:projectGroups
    call add(res, s:GroupDataGetName(groupData) . " " .  s:GroupDataGetClosed(groupData)) 

    for b in buffers
      if !has_key(buffersDict, b) | continue | endif

      let line = "  ".b
      if has_key(s:buffersHotKeys, b) | let line .= " hotkey:".s:buffersHotKeys[b] | endif
      call add(res, line)

      let bufferNum = buffersDict[b]
      if bufloaded(bufferNum)
        exec 'keepalt keepjumps b '.bufferNum
        mkview
      endif
    endfor
  endfor
  
  let s:projectFileName = empty(a:fileName) ? s:projectFileName : a:fileName
  if !empty(s:projectFileName)
    call writefile(res, s:projectFileName )
    exec 'keepalt b '.lastBufferNum
  endif
endfunction

function! project#load(fileName) "{{{1
  call s:HotKeyRemoveAll()
  let s:projectGroups = []
  "echo matchlist("abc-def", '\(.*\)-\(.*\)')
  "                   <name--><---close> 
  let groupNameEx = '^\(\w\+\)\s\([01]\)$'
  "                                  <hotkey----------->
  let bufferNameEx = '^\s\s\(.\{-}\)\%(\shotkey:\(.\)\)\?$'
  let currentList = []

  for l in readfile(a:fileName)
    if l =~ groupNameEx
      let [all, groupName, isClosed] = matchlist(l, groupNameEx)[:2]
      let currentList = []
      call add(s:projectGroups, [s:GroupData(groupName, isClosed), currentList])
    elseif l =~ bufferNameEx
      let [all ,bufferName, hotKey] = matchlist(l, bufferNameEx)[:2]
      call add(currentList, bufferName)
      silent exe "badd " . bufferName
      if hotKey != ""
        call s:HotKeyAdd(hotKey, bufferName)
      endif
    endif
  endfor
  let s:projectFileName = a:fileName
  call project#closeAllUnlistedBuffers()
  call project#closeAllUnprojectBuffers()
  call project#windowOpen()
endfunction

function! s:ProjectGetUngrouped() "{{{1
  let groupedBuffers = []
  for [gd, b] in s:projectGroups
    let groupedBuffers += b
  endfor

  let ungroupedBuffers = keys(s:buffersDict)
  call filter(ungroupedBuffers, 'index(groupedBuffers, v:val) == -1')
  return ungroupedBuffers
endfunction

function! s:ProjectPrint() "{{{1
  let lastBufferName = s:GetNameFromNum(s:lastBufferNum)
  let lnum = 0
  setlocal modifiable
  normal! gg"_dG

  let allGroups = copy(s:projectGroups)
  let ungrouped = s:ProjectGetUngrouped()
  if !empty(ungrouped) | call add(allGroups, [s:GroupData("ungrouped"), ungrouped]) | endif

  let res = []
  let s:lineInfo = [0]
  let numGroups = len(s:projectGroups)

  call add(res, printf("    -~={ %s }=~-",fnamemodify(s:projectFileName, ":p:t:r")))

  call add(s:lineInfo, [-1, -1, -1])

  for i in range(len(allGroups))
    let [groupData, buffersList] = allGroups[i]
    let groupIndex = i < numGroups ? i : -1

    call add(res, (s:GroupDataGetClosed(groupData) ? "▶ " : "▼ ") .s:GroupDataGetName(groupData))
    call add(s:lineInfo, [groupIndex, -1, -1])

    if s:GroupDataGetClosed(groupData) &&  index(buffersList, lastBufferName) == -1 | continue | endif

    for bufferIndex in range(len(buffersList))
      let bufferName = buffersList[bufferIndex]
      if !has_key(s:buffersDict, bufferName) | continue | endif
      let bufferNum = s:buffersDict[bufferName]
      let bufferProp = s:buffersProperty[bufferNum]
			if getbufvar(bufferNum, "&bt") == "quickfix" | continue | endif

      let hotKey = ' '
      if has_key(s:buffersHotKeys, bufferName) | let hotKey = s:buffersHotKeys[bufferName] | endif

      call add(res, printf("%3i %s %s %-50s %-s", bufferNum, hotKey, bufferProp, fnamemodify(bufferName,':p:t'), fnamemodify(bufferName,':p:h') ))
      call add(s:lineInfo, [groupIndex, bufferIndex, bufferNum])
      let lnum += bufferNum == s:lastBufferNum ? len(res) : 0
    endfor
    call add(res, "")
    call add(s:lineInfo, [groupIndex, -1, -1])
  endfor

  call append(0, res)
  $delete _

  keepjumps keepalt exe "normal! " . lnum . "gg"
  setlocal nomodifiable
  normal zb
endfunction

function! s:ProjectGetLineInfo(lineNum) "{{{1
  let [groupIndex, bufferIndex, bufferNum] = s:lineInfo[a:lineNum]
  let bufferName = (groupIndex != -1 && bufferIndex != -1) ? s:projectGroups[groupIndex][1][bufferIndex] : -1
  return [groupIndex, bufferIndex, bufferNum]
endfunction

function! s:ProjectGetCurrentLineInfo() "{{{1
  return s:ProjectGetLineInfo(line('.'))
endfunction

function! s:ProjectGetLineByGroupIndex(groupIndex, bufferIndex)
  for i in range(1, len(s:lineInfo)-1)
    let curInfo = s:lineInfo[i]
    if curInfo[0] == a:groupIndex && curInfo[1] == a:bufferIndex | return i | endif
  endfor
endfunction

function! s:ProjectGetLineByBufferNum(bufferNum)
  for i in range(1, len(s:lineInfo)-1)
    let curInfo = s:lineInfo[i]
    if curInfo[2] == a:bufferNum | return i | endif
  endfor
endfunction

function! project#closeAllUnprojectBuffers() "{{{1
  let s:buffersDict = s:GetBuffersDict()
  for bufferName in s:ProjectGetUngrouped()
    let bufferNum = s:buffersDict[bufferName]
    execute "bwipeout ".bufferNum
  endfor
endfunction

function! project#closeAllUnlistedBuffers() "{{{1
  let unlistedBuffers = filter(range(1, bufnr('$')), "!buflisted(v:val) && bufexists(v:val)")
  for i in unlistedBuffers
    let bufShortName =  fnamemodify(bufname(i), ":t")
    if bufShortName[0] != "[" && bufShortName[0] != "_" && bufShortName !~ "NERD_tree_.*"
      execute "bwipeout ".i
    endif
  endfor
endfunction

function! s:ProjectAskBuffer() "{{{1
  let l = ""
  let n = 1
  for [groupData, buffers] in s:projectGroups
    let l = l . n . ". " . s:GroupDataGetName(groupData) . "\n"
    let n += 1
  endfor
  let l = l."Enter nuber or name of group: "

  let groupName = input(l)
  let groupBuffers = []
  if groupName =~ '^\d\+$'
    let groupBuffers = s:projectGroups[groupName-1][1]
  else
    let groupBuffers = s:ProjectGetGroup(groupName, 1)[1]
  endif

  return groupBuffers
endfunction

function! s:ProjectAskAddBuffer(bufferNum) "{{{1
  let groupBuffers = s:ProjectAskBuffer()
  call add(groupBuffers, s:GetNameFromNum(a:bufferNum))
endfunction

function! s:ProjectRenameGroup(groupIndex) "{{{1
  let newName = input("Enter new group name: ")
  call s:GroupDataSetName(s:projectGroups[a:groupIndex][0] , newName)
endfunction

function! s:ProjectMoveGroup(groupIndex, delta) "{{{1
  let newIndex = a:groupIndex + a:delta
  if newIndex < 0 || newIndex >= len(s:projectGroups) | return a:groupIndex | endif
  let tmp = s:projectGroups[a:groupIndex]
  let s:projectGroups[a:groupIndex] = s:projectGroups[newIndex]
  let s:projectGroups[newIndex] = tmp
  return newIndex
endfunction

function! s:ProjectMoveBuffer(buffersInfo, delta) "{{{1
  let [groupIndex, firstBufferIndex, firstBufferNum] = a:buffersInfo[0]
  call filter(a:buffersInfo, "v:val[0] == groupIndex")
  let buffers = s:projectGroups[groupIndex][1]

  let numLines = len(a:buffersInfo)

  if firstBufferIndex + a:delta < 0 || firstBufferIndex + a:delta + numLines - 1 >= len(buffers) 
    return [groupIndex, firstBufferIndex]
  endif

  let from = a:delta == -1 ? firstBufferIndex - 1            : firstBufferIndex + numLines
  let to   = a:delta == -1 ? firstBufferIndex + numLines - 1 : firstBufferIndex

  let tmp = buffers[from]
  call remove(buffers, from)
  call insert(buffers, tmp, to)

  return [groupIndex, firstBufferIndex + a:delta]
endfunction

function! s:WindowOpenProjectExplorerBuffer() "{{{1
  let bufNum = bufnr("__ProjectExplorer__")
  if bufNum == -1
    exe "edit __ProjectExplorer__"
    return
  endif

  let existingWindow = bufwinnr(bufNum)
  if existingWindow != -1 && winnr() != existingWindow
    exe existingWindow . "wincmd w"
    return
  endif

  exe "buffer __ProjectExplorer__"
endfunction

function! project#windowOpen() "{{{1
  let s:buffersProperty = s:GetBuffersProperty()
  let s:buffersDict = s:GetBuffersDict()
  call s:ProjectRemoveClosedBuffers()

  let s:lastBufferNum = bufnr('%')
  call s:WindowOpenProjectExplorerBuffer()
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
    nnoremap <script> <silent> <buffer> -             :call <SID>WindowRemoveBuffersFromProject()<cr>
    vnoremap <script> <silent> <buffer> -             :call <SID>WindowRemoveBuffersFromProject()<cr>
    nnoremap <script> <silent> <buffer> m             :call <SID>WindowMoveBufferToGroup()<cr>
    vnoremap <script> <silent> <buffer> m             :call <SID>WindowMoveBufferToGroup()<cr>
    nnoremap <script> <silent> <buffer> D             :call <SID>WindowWipeBuffer()<CR>
    nnoremap <script> <silent> <buffer> <Down>         :call <SID>WindowMoveBuffer(1)<cr>
    vnoremap <script> <silent> <buffer> <Down>         :call <SID>WindowMoveBuffer(1)<cr>
    nnoremap <script> <silent> <buffer> <Up>         :call <SID>WindowMoveBuffer(-1)<cr>
    vnoremap <script> <silent> <buffer> <Up>         :call <SID>WindowMoveBuffer(-1)<cr>
    nnoremap <script> <silent> <buffer> J             :call <SID>WindowMoveGroup(1)<cr>
    nnoremap <script> <silent> <buffer> K             :call <SID>WindowMoveGroup(-1)<cr>
    nnoremap <script> <silent> <buffer> r             :call <SID>WindowRenameGroup ()<cr>
    nnoremap <script> <silent> <buffer> zo            :call <SID>WindowOpenCloseGroup(0)<cr>
    nnoremap <script> <silent> <buffer> zc            :call <SID>WindowOpenCloseGroup(1)<cr>
    nnoremap <script> <silent> <buffer> e             :call <SID>WindowSetBufferHotKey()<cr>

    command! -buffer -nargs=0 Load                    :call <SID>WindowLoadSelectedProject()


    for k in ["G", "n", "N", "L", "M", "H"]
        exec "nnoremap <buffer> <silent>" k ":keepjumps normal!" k."<CR>"
    endfor
endfunction

function! s:WindowSetCursorToIndex(groupIndex, bufferIndex) "{{{1
  keepjumps keepalt exe "normal! " . s:ProjectGetLineByGroupIndex(a:groupIndex, a:bufferIndex) . "gg"
endfunction

function! s:WindowSetCursorBufferNum(bufferNum) "{{{1
  keepjumps keepalt exe "normal! " . s:ProjectGetLineByBufferNum(a:bufferNum) . "gg"
endfunction

function! s:WindowSelectLines(numLines) "{{{1
  if a:numLines > 1 | exe "normal V".(a:numLines - 1)."j" | endif
endfunction

function! s:WindowJumpToBuffer() "{{{1
  let [groupIndex, bufferIndex, bufferNum] = s:ProjectGetCurrentLineInfo()
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
  let [groupIndex, bufferIndex, bufferNum] = s:ProjectGetCurrentLineInfo()
  if bufferIndex == -1 | return | endif

	let lnum = line('.')
  unlet s:buffersDict[s:GetNameFromNum(bufferNum)]
  call s:ProjectRemoveBuffers([bufferNum])
  execute "bwipeout! ".bufferNum
  call s:ProjectPrint()
  keepjumps keepalt exe "normal! " . lnum . "gg"
endfunction

function! s:WindowGetCurrentLinesInfo(startLine, lastLine) "{{{1
  let bufferNums = []

  for i in range(a:startLine, a:lastLine)
    let [groupIndex, bufferIndex, bufferNum] = s:ProjectGetLineInfo(i)
    if bufferIndex != -1  
      call add(bufferNums, [groupIndex, bufferIndex, bufferNum]) 
    endif
  endfor

  return bufferNums
endfunction

function! s:WindowRemoveBuffersFromProject() range "{{{1
  let bufferNums = s:WindowGetCurrentLinesInfo(a:firstline, a:lastline)
  call map(bufferNums, 'v:val[2]')
  if empty(bufferNums)  | return | endif

	let lnum = line('.')
  call s:ProjectRemoveBuffers(bufferNums)
  call s:ProjectPrint()
  keepjumps keepalt exe "normal! " . lnum . "gg"

endfunction

function! s:WindowMoveBufferToGroup() range "{{{1
  let bufferNums = s:WindowGetCurrentLinesInfo(a:firstline, a:lastline)
  call map(bufferNums, 'v:val[2]')
  if empty(bufferNums)  | return | endif

  call s:ProjectRemoveBuffers(bufferNums)
  let groupBuffers = s:ProjectAskBuffer()
  let groupBuffers += map(copy(bufferNums), 's:GetNameFromNum(v:val)')
  call s:ProjectPrint()
  call s:WindowSetCursorBufferNum(bufferNums[0])
  call s:WindowSelectLines(len(bufferNums))
endfunction

function! s:WindowMoveBuffer(delta) range "{{{1
  let buffersInfo = s:WindowGetCurrentLinesInfo(a:firstline, a:lastline)
  if empty(buffersInfo)  | return | endif

  let [groupIndex, firstBufferIndex] = s:ProjectMoveBuffer(buffersInfo, a:delta)

  call s:ProjectPrint()
  call s:WindowSetCursorToIndex(groupIndex, firstBufferIndex)
  call s:WindowSelectLines(len(buffersInfo))
endfunction

function! s:WindowMoveGroup (delta) "{{{1
  let [groupIndex, bufferIndex, bufferNum] = s:ProjectGetCurrentLineInfo()
  if groupIndex == -1 | return | endif

  let groupIndex =  s:ProjectMoveGroup(groupIndex, a:delta)
  call s:ProjectPrint()
  call s:WindowSetCursorToIndex(groupIndex, bufferIndex)
endfunction

function! s:WindowRenameGroup () "{{{1
  let [groupIndex, bufferIndex, bufferNum] = s:ProjectGetCurrentLineInfo()
  if groupIndex == -1 | return | endif

  call s:ProjectRenameGroup(groupIndex)
  call s:ProjectPrint()
  call s:WindowSetCursorToIndex(groupIndex, bufferIndex)
endfunction

function! s:WindowOpenCloseGroup (close) "{{{1
  let [groupIndex, bufferIndex, bufferNum] = s:ProjectGetCurrentLineInfo()
  if groupIndex == -1 | return | endif

  call s:GroupDataSetClosed(s:projectGroups[groupIndex][0], a:close)
  call s:ProjectPrint()
  call s:WindowSetCursorToIndex(groupIndex, -1)
endfunction

function! s:WindowSetBufferHotKey() "{{{1
  let [groupIndex, bufferIndex, bufferNum] = s:ProjectGetCurrentLineInfo()
  if bufferIndex == -1 | return | endif

  let bufName = s:GetNameFromNum(bufferNum)

  let hotKey = input("Enter buffer hot key: ")
  if hotKey == " " && has_key(s:buffersHotKeys, bufName)
    call s:HotKeyRemove(s:buffersHotKeys[bufName])
  elseif hotKey != ""
    call s:HotKeyAdd(hotKey, bufName)
  endif

  call s:ProjectPrint()
  call s:WindowSetCursorToIndex(groupIndex, bufferIndex)
endfunction

function! s:WindowLoadSelectedProject() "{{{1
  let [groupIndex, bufferIndex, bufferNum] = s:ProjectGetCurrentLineInfo()
  if bufferIndex == -1 | return | endif

  let bufName = s:GetNameFromNum(bufferNum)
  call project#load(bufName)
endfunction

autocmd BufNewFile __ProjectExplorer__ call s:WindowBufferSettings()

" vim: set foldmethod=marker:
