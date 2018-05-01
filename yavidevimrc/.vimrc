"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" 	Description: Yavide entry point (startup file)
" """"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""

" """"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" Yavide runtime path (root directory)
" """"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
let g:YAVIDE_ROOT_DIRECTORY = expand('<sfile>:p:h')

let g:yavide_configuration_files = [
\                   'core/.core.vimrc',
\                   'config/.user_settings.vimrc',
\                   'core/.api.vimrc',
\                   'core/.editor.vimrc',
\                   'core/.plugins.vimrc',
\                   'core/.globals.vimrc',
\                   'core/.autocommands.vimrc',
\                   'core/.commands.vimrc',
\                   'core/.custom.vimrc',
\]

for file in g:yavide_configuration_files
    execute('source ' . g:YAVIDE_ROOT_DIRECTORY . '/' . file)
endfor

