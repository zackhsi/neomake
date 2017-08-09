" vim: ts=4 sw=4 et

function! neomake#makers#ft#rst#SupersetOf() abort
    return 'text'
endfunction

function! neomake#makers#ft#rst#EnabledMakers() abort
    if executable('sphinx-build')
                \ && !empty(neomake#utils#FindGlobFile('conf.py'))
        return ['sphinx']
    endif
    return ['rstlint', 'rstcheck']
endfunction

function! neomake#makers#ft#rst#rstlint() abort
    return {
        \ 'exe': 'rst-lint',
        \ 'errorformat':
            \ '%EERROR %f:%l %m,'.
            \ '%WWARNING %f:%l %m,'.
            \ '%IINFO %f:%l %m,'.
            \ '%C%m',
        \ }
endfunction

function! neomake#makers#ft#rst#rstcheck() abort
    return {
        \ 'errorformat':
            \ '%I%f:%l: (INFO/1) %m,'.
            \ '%W%f:%l: (WARNING/2) %m,'.
            \ '%E%f:%l: (ERROR/3) %m,'.
            \ '%E%f:%l: (SEVERE/4) %m',
        \ }
endfunction

function! neomake#makers#ft#rst#sphinx() abort
    if !exists('s:sphinx_cache')
        let s:sphinx_cache = tempname()
    endif
    let conf = neomake#utils#FindGlobFile('conf.py')
    if empty(conf)
        throw 'Neomake: sphinx: could not find conf.py'
    endif
    let srcdir = fnamemodify(conf, ':h')
    return {
        \ 'exe': 'sphinx-build',
        \ 'args': ['-n', '-E', '-q', '-N', '-b', 'pseudoxml', srcdir, s:sphinx_cache],
        \ 'append_file': 0,
        \ 'errorformat':
            \ '%E%f:%l: SEVER%t: %m,' .
            \ '%f:%l: %tRROR: %m,' .
            \ '%f:%l: %tARNING: %m,' .
            \ '%E%f:: SEVER%t: %m,' .
            \ '%f:: %tRROR: %m,' .
            \ '%f:: %tARNING: %m,' .
            \ '%trror: %m,' .
            \
            \ '%WWARNING: %f:%l: (%tRROR/3) %m,' .
            \ '%C%m,' .
            \ '%-G',
        \ 'output_stream': 'stderr',
        \ }
endfunction
