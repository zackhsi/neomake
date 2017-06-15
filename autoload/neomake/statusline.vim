scriptencoding utf-8

let s:qflist_counts = {}
let s:loclist_counts = {}

function! s:incCount(counts, item, buf) abort
    let type = toupper(a:item.type)
    if !empty(type) && (!a:buf || a:item.bufnr ==# a:buf)
        let a:counts[type] = get(a:counts, type, 0) + 1
        return 1
    endif
    return 0
endfunction

function! neomake#statusline#ResetCountsForBuf(...) abort
    let bufnr = a:0 ? +a:1 : bufnr('%')
    if has_key(s:loclist_counts, bufnr)
      let r = s:loclist_counts[bufnr] != {}
      unlet s:loclist_counts[bufnr]
      if r
          call neomake#utils#hook('NeomakeCountsChanged', {
                \ 'reset': 1, 'file_mode': 1, 'bufnr': bufnr})
      endif
      return r
    endif
    return 0
endfunction

function! neomake#statusline#ResetCountsForProject(...) abort
    let r = s:qflist_counts != {}
    let s:qflist_counts = {}
    if r
        call neomake#utils#hook('NeomakeCountsChanged', {
              \ 'reset': 1, 'file_mode': 0, 'bufnr': bufnr('%')})
    endif
    return r
endfunction

function! neomake#statusline#ResetCounts() abort
    let r = neomake#statusline#ResetCountsForProject()
    for bufnr in keys(s:loclist_counts)
        let r = neomake#statusline#ResetCountsForBuf(bufnr) || r
    endfor
    let s:loclist_counts = {}
    return r
endfunction

function! neomake#statusline#AddLoclistCount(buf, item) abort
    let s:loclist_counts[a:buf] = get(s:loclist_counts, a:buf, {})
    return s:incCount(s:loclist_counts[a:buf], a:item, a:buf)
endfunction

function! neomake#statusline#AddQflistCount(item) abort
    return s:incCount(s:qflist_counts, a:item, 0)
endfunction

function! neomake#statusline#LoclistCounts(...) abort
    let buf = a:0 ? a:1 : bufnr('%')
    if buf is# 'all'
        return s:loclist_counts
    endif
    return get(s:loclist_counts, buf, {})
endfunction

function! neomake#statusline#QflistCounts() abort
    return s:qflist_counts
endfunction

function! s:showErrWarning(counts, prefix) abort
    let w = get(a:counts, 'W', 0)
    let e = get(a:counts, 'E', 0)
    if w || e
        let result = a:prefix
        if e
            let result .= 'E:'.e
        endif
        if w
            if e
                let result .= ','
            endif
            let result .= 'W:'.w
        endif
        return result
    else
        return ''
    endif
endfunction

function! neomake#statusline#LoclistStatus(...) abort
    return s:showErrWarning(neomake#statusline#LoclistCounts(), a:0 ? a:1 : '')
endfunction

function! neomake#statusline#QflistStatus(...) abort
    return s:showErrWarning(neomake#statusline#QflistCounts(), a:0 ? a:1 : '')
endfunction


function! neomake#statusline#get_counts(bufnr) abort
    return [get(s:loclist_counts, a:bufnr, {}), s:qflist_counts]
endfunction

function! neomake#statusline#get_filtered_counts(bufnr, ...) abort
    let include = a:0 ? a:1 : []
    let exclude = a:0 > 1 ? a:2 : []
    let empty = a:0 > 2 ? a:3 : ''

    let [loclist_counts, qf_errors] = neomake#statusline#get_counts(a:bufnr)

    let errors = []
    for [type, c] in items(loclist_counts)
        if len(include) && index(include, type) == -1 | continue | endif
        if len(exclude) && index(exclude, type) != -1 | continue | endif
        let errors += [type . ':' .c]
    endfor
    if ! empty(qf_errors)
        for [type, c] in items(qf_errors)
            if len(include) && index(include, type) == -1 | continue | endif
            if len(exclude) && index(exclude, type) != -1 | continue | endif
            let errors += [type . ':' .c]
        endfor
    endif
    if len(errors)
        return ' '.join(errors)
    endif
    return empty
endfunction


let s:formatter = {
            \ 'args': {},
            \ }
function! s:formatter.running_job_names() abort
    return join(map(s:running_jobs(self.args.bufnr), 'v:val.name'), ', ')
endfunction

function! s:formatter._substitute(m) abort
    if !has_key(self, a:m)
        call neomake#utils#ErrorMessage(printf(
                    \ 'Unknown statusline format: %s.', a:m))
        return '{{'.a:m.'}}'
    endif
    try
        return call(self[a:m], [], self)
    catch
        call neomake#utils#ErrorMessage(printf(
                    \ 'Error while formatting statusline: %s.', v:exception))
    endtry
endfunction

function! s:formatter.format(f, args) abort
    let self.args = a:args
    return substitute(a:f, '{{\(.*\)}}', '\=self._substitute(submatch(1))', 'g')
endfunction


function! s:running_jobs(bufnr) abort
    return filter(copy(neomake#GetJobs()),
                \ "v:val.bufnr == a:bufnr && get(v:val, 'running', 1)")
endfunction

function! neomake#statusline#get_status(bufnr, options) abort
    let running_jobs = s:running_jobs(a:bufnr)

    if !empty(running_jobs)
        let format_running = get(a:options, 'format_running', '… ({{running_job_names}})')
        let r = s:formatter.format(format_running, {'bufnr': a:bufnr})
    else
        let counts = neomake#statusline#get_counts(a:bufnr)
        if counts == [{}, {}]
            let format_ok = get(a:options, 'format_ok', '✓')
            let r = s:formatter.format(format_ok, {'bufnr': a:bufnr})
        else
            let r = ''
            let errors = neomake#statusline#get_filtered_counts(a:bufnr, ['E'])
            if len(errors)
                let r .= '%#StatColorNeomakeError#'.errors
            endif
            let nonerrors = neomake#statusline#get_filtered_counts(a:bufnr, [], ['E'])
            if len(nonerrors)
                let r .= '%#StatColorNeomakeNonError#'.nonerrors
            endif
        endif
    endif
    return r
endfunction

function! neomake#statusline#clear_cache(bufnr) abort
    call s:clear_cache(a:bufnr)
endfunction

" Key: bufnr, Value: dict with cache keys.
let s:cache = {}
function! s:clear_cache(bufnr) abort
    if has_key(s:cache, a:bufnr)
        unlet s:cache[a:bufnr]
    endif
endfunction

augroup neomake_statusline
    autocmd!
    autocmd User NeomakeJobStarted,NeomakeJobFinished call s:clear_cache(g:neomake_hook_context.jobinfo.bufnr)
    " Trigger redraw of all statuslines.
    autocmd User NeomakeJobFinished let &stl = &stl
    autocmd BufWipeout * call s:clear_cache(expand('<abuf>'))
augroup END

function! neomake#statusline#get(bufnr, options) abort
    let cache_key = string(a:options)
    if !has_key(s:cache, a:bufnr)
        let s:cache[a:bufnr] = {}
    endif
    if has_key(s:cache[a:bufnr], cache_key)
        return s:cache[a:bufnr][cache_key]
    endif

    let bufnr = +a:bufnr
    let r = ''
    let [disabled, source] = neomake#config#get_with_source('disabled', -1, {'bufnr': bufnr})
    if disabled != -1
        if disabled
            let r .= source[0].'-'
        else
            let r .= source[0].'+'
        endif
    endif

    let status = neomake#statusline#get_status(bufnr, a:options)
    if has_key(a:options, 'format_status')
        let status = printf(a:options.format_status, status)
    endif
    let r .= status

    let s:cache[a:bufnr][cache_key] = r
    return r
endfunction
