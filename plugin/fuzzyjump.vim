" fuzzyjump - Jump to where you (almost) want
" Version: 0.1.1
" Originally written by:
" 	Copyright (C) 2008 Yuki KODAMA <http://blog.endflow.net/>
" Modified and the document written by:
" 	Copyright (C) 2008 kana <http://whileimautomaton.net/>
" License: MIT license  {{{
"     Permission is hereby granted, free of charge, to any person obtaining
"     a copy of this software and associated documentation files (the
"     "Software"), to deal in the Software without restriction, including
"     without limitation the rights to use, copy, modify, merge, publish,
"     distribute, sublicense, and/or sell copies of the Software, and to
"     permit persons to whom the Software is furnished to do so, subject to
"     the following conditions:
"
"     The above copyright notice and this permission notice shall be included
"     in all copies or substantial portions of the Software.
"
"     THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS
"     OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
"     MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
"     IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY
"     CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT,
"     TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE
"     SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
" }}}

if exists('loaded_fuzzyjump') || v:version < 701
  finish
endif
let loaded_fuzzyjump = 1




" Variables  "{{{1

"if !exists('g:FuzzyJump_RelativeJumpPrefix')
"  let g:FuzzyJump_RelativeJumpPrefix = ';;'
"endif

if !exists('g:FuzzyJump_Debug')
  let g:FuzzyJump_Debug = 0
endif




" Functions - Core  "{{{1

function! s:FuzzyJumpTo(line, col)
  let M = 10
  let win = {'line':M * winheight(0), 'col':M * winwidth(0)}        " window size
  let kbd = {'line':M * (4 - 1), 'col':M * (11 - 1)}                " keyboard size
  let fctr = {'line':win.line / kbd.line, 'col':win.col / kbd.col}  " factor for mapping
  let scrl = s:GetScrollMetrics()                                   " scroll metrics
  let tgt = {}                                                      " target pos

  let pos = s:GetPos()

  if a:line == 0
    let tgt.line = scrl.top
  elseif a:line == -1
    let tgt.line = scrl.bottom
  else
    let tgt.line = fctr.line * a:line + scrl.top
  endif
  let pos.line = tgt.line
  call s:SetPos(pos)

  if a:col == 0
    let tgt.col = 1
  elseif a:col == -1
    let tgt.col = col('$')
  else
    let tgt.col = fctr.col * a:col
  endif
  let pos.col = tgt.col
  call s:SetPos(pos)

  call s:Msg(printf('moved: tgt[%s,%s], [%s,%s]', tgt.line, tgt.col, line('.'), col('.')))

  let offset = {'max':5, 'val':0, 'count':0}
  while s:Abs(offset.val) <= offset.max
    call s:Msg('start: '.offset.val.'['.offset.count.']')
    call s:Msg(printf('kbd=[%s,%s], tgt=[%s,%s], [%s,%s]', a:line, a:col
        \ , tgt.line, tgt.col, line('.'), col('.')))
    let apos = s:GetPos() " actual position
    if 5 < tgt.col - apos.col
      call s:Msg('search: diff='.(tgt.col - apos.col))
      if s:Contains(scrl.top, tgt.line + offset.val, scrl.bottom)
        call s:Msg(printf('contains: %s, %s, %s', scrl.top, tgt.line + offset.val, scrl.bottom))
        let pcol = s:SavePos().col " previous column
        let apos.line = tgt.line + offset.val
        call s:SetPos(apos)
        let apos.col = tgt.col
        call s:SetPos(apos)
        let apos = s:GetPos()
        if (tgt.col - pcol) <= (tgt.col - apos.col)
          call s:Msg(printf('restore: %s - %s <= %s - %s', tgt.col, pcol, tgt.col, apos.col))
          call s:RestorePos()
        endif
      endif
    else
      call s:Msg('end: '.offset.val.'['.offset.count.']')
      break
    endif
    let offset.count = offset.count + 1
    let offset.val = offset.val + s:NegIfOdd(offset.count)
  endwhile

  call s:Msg(printf('kbd=[%s,%s], tgt=[%s,%s], [%s,%s]', a:line, a:col
      \ , tgt.line, tgt.col, line('.'), col('.')))
endfunction




" Functions - KeyMapper  "{{{1

let s:KeyMapper = {
  \ 'maps':{
  \   '1':[0,0], '2':[0,1], '3':[0,2], '4':[0,3], '5':[0,4], '6':[0,5], '7':[0,6], '8':[0,7], '9':[0,8], '0':[0,9], '-':[0,-1],
  \   'q':[1,0], 'w':[1,1], 'e':[1,2], 'r':[1,3], 't':[1,4], 'y':[1,5], 'u':[1,6], 'i':[1,7], 'o':[1,8], 'p':[1,9], '@':[1,-1],
  \   'a':[2,0], 's':[2,1], 'd':[2,2], 'f':[2,3], 'g':[2,4], 'h':[2,5], 'j':[2,6], 'k':[2,7], 'l':[2,8], ';':[2,9], ':':[2,-1],
  \   'z':[-1,0],'x':[-1,1],'c':[-1,2],'v':[-1,3],'b':[-1,4],'n':[-1,5],'m':[-1,6],',':[-1,7],'.':[-1,8],'/':[-1,9],'\':[-1,-1]
  \ }}

function! s:KeyMapper.map() dict
  for [key, pos] in items(self.maps)
    execute printf('noremap <silent> <Plug>(fuzzyjump-prefix)%s :<C-u>call <SID>FuzzyJumpTo(%s, %s)<CR>',
        \ key, pos[0], pos[1])
  endfor
  execute printf('noremap <silent> <Plug>(fuzzyjump-prefix) <Nop>')
endfunction




" Functions - Utilities  "{{{1

function! s:GetPos()
  let pos = getpos('.')
  return {'line':pos[1], 'col':pos[2], 'bufnum':pos[0], 'off':pos[3]}
endfunction

function! s:SetPos(pos)
  call setpos('.', [a:pos.bufnum, a:pos.line, a:pos.col, a:pos.off])
endfunction

function! s:SavePos()
  let s:save_pos_cursor = s:GetPos()
  return s:save_pos_cursor
endfunction

function! s:RestorePos()
  call s:SetPos(s:save_pos_cursor)
  return s:save_pos_cursor
endfunction

function! s:GetScrollMetrics()
  call s:SavePos()
  let met = {}
  normal! H
  let met['top'] = line('.')
  normal! L
  let met['bottom'] = line('.')
  call s:RestorePos()
  return met
endfunction

function! s:Abs(n)
  return a:n < 0 ? -1 * a:n : a:n
endfunction

function! s:NegIfOdd(n)
  return a:n % 2 == 0 ? -1 * a:n : a:n
endfunction

function! s:Contains(min, n, max)
  return a:min <= a:n && a:n <= a:max ? 1 : 0
endfunction

function! s:Msg(msg)
  if g:FuzzyJump_Debug
    call confirm(a:msg, '', '', '')
  endif
endfunction




" Initialization  "{{{1

call s:KeyMapper.map()

if !(hasmapto('<Plug>(fuzzyjump-prefix)', 'n')
\    || hasmapto('<Plug>(fuzzyjump-prefix)', 'v')
\    || hasmapto('<Plug>(fuzzyjump-prefix)', 'o'))
  map ;  <Plug>(fuzzyjump-prefix)
endif




" __END__  "{{{1
" vim: foldmethod=marker
