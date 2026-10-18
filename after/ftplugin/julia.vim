if exists("b:did_julia_slime_blocks")
  finish
endif
let b:did_julia_slime_blocks = 1

" Julia block starters. This handles:
" function ... end
" begin ... end
" if/for/while/let/try/struct/macro/do ... end
let s:julia_block_start =
      \ '\v<(function|macro|if|for|while|let|begin|try|quote|struct|do)>|mutable\s+struct'

let s:julia_block_end = '\v<end>'

" Skip matches inside strings/comments if Julia syntax highlighting is active.
let s:julia_skip =
      \ "synIDattr(synID(line('.'), col('.'), 1), 'name') =~? 'comment\\|string\\|char'"

function! s:FindJuliaBlock() abort
  let l:save = getcurpos()

  " Find nearest enclosing Julia block start.
  let l:start = searchpairpos(
        \ s:julia_block_start,
        \ '',
        \ s:julia_block_end,
        \ 'bcW',
        \ s:julia_skip
        \ )

  if l:start[0] == 0
    call setpos('.', l:save)
    return [0, 0]
  endif

  " Find its matching end.
  call cursor(l:start[0], l:start[1])

  let l:end = searchpairpos(
        \ s:julia_block_start,
        \ '',
        \ s:julia_block_end,
        \ 'cnW',
        \ s:julia_skip
        \ )

  call setpos('.', l:save)

  if l:end[0] == 0
    return [0, 0]
  endif

  return [l:start[0], l:end[0]]
endfunction

function! s:FindJuliaFunction() abort
  let l:save = getcurpos()

  while 1
    let l:start = searchpairpos(
          \ s:julia_block_start,
          \ '',
          \ s:julia_block_end,
          \ 'bcW',
          \ s:julia_skip
          \ )

    if l:start[0] == 0
      call setpos('.', l:save)
      return [0, 0]
    endif

    let l:line = getline(l:start[0])

    " Climb outward until the enclosing block is a function or macro.
    if l:line =~# '\v<(function|macro)>'
      call cursor(l:start[0], l:start[1])

      let l:end = searchpairpos(
            \ s:julia_block_start,
            \ '',
            \ s:julia_block_end,
            \ 'cnW',
            \ s:julia_skip
            \ )

      call setpos('.', l:save)

      if l:end[0] == 0
        return [0, 0]
      endif

      return [l:start[0], l:end[0]]
    endif

    " Move before this block and search again for the parent block.
    if l:start[0] <= 1
      call setpos('.', l:save)
      return [0, 0]
    endif

    call cursor(l:start[0] - 1, 1)
  endwhile
endfunction

function! s:SendRangeToSlime(first, last) abort
  let l:text = join(getline(a:first, a:last), "\n") . "\n"

  if exists("*SlimeSend")
    call SlimeSend(l:text)
  elseif exists("*slime#send")
    call slime#send(l:text)
  else
    echoerr "vim-slime send function not found"
  endif
endfunction

function! s:SlimeJuliaBlock() abort
  let [l:first, l:last] = s:FindJuliaBlock()

  if l:first == 0
    echo "No enclosing Julia block found"
    return
  endif

  call s:SendRangeToSlime(l:first, l:last)
endfunction

function! s:SlimeJuliaFunction() abort
  let [l:first, l:last] = s:FindJuliaFunction()

  if l:first == 0
    echo "No enclosing Julia function found"
    return
  endif

  call s:SendRangeToSlime(l:first, l:last)
endfunction

" Send nearest enclosing begin/if/for/function/.../end block
nnoremap <buffer> <leader>sb :<C-u>call <SID>SlimeJuliaBlock()<CR>

" Send nearest enclosing function ... end or macro ... end
nnoremap <buffer> <leader>sf :<C-u>call <SID>SlimeJuliaFunction()<CR>
