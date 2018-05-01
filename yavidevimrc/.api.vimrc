" --------------------------------------------------------------------------------------------------------------------------------------
"
"   SCRIPT LOCAL VARIABLES
"
" --------------------------------------------------------------------------------------------------------------------------------------
let s:y_prev_line = 0
let s:y_prev_col  = 0
let s:y_prev_char = ''

" --------------------------------------------------------------------------------------------------------------------------------------
"
"   YAVIDE VIMSCRIPT UTILS
"
" --------------------------------------------------------------------------------------------------------------------------------------
" """"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" Function:     Y_Utils_AppendToFile()
" Description:  Writes 'lines' to 'file'
" Dependency:
" """"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
function! s:Y_Utils_AppendToFile(file, lines)
    call writefile(readfile(a:file) + a:lines, a:file)
endfunction

" """"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" Function:     Y_Utils_SerializeCurrentBufferContents()
" Description:  Writes current buffer contents to 'filename'
" Dependency:
" """"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
function! Y_Utils_SerializeCurrentBufferContents(filename)
python << EOF
import vim
temp_file = open(vim.eval('a:filename'), "w", 0)
temp_file.writelines(line + '\n' for line in vim.current.buffer)
EOF
endfunction

" --------------------------------------------------------------------------------------------------------------------------------------
"
"   ENVIRONMENT INIT/DEINIT API
" 
" --------------------------------------------------------------------------------------------------------------------------------------
" """"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" Function:     Y_Env_Init()
" Description:  Initializes the environment.
" Dependency:
" """"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
function! Y_Env_Init()
    " Start Yavide server background service
    call Y_ServerStart()
endfunction

" """"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" Function:     Y_Env_Deinit()
" Description:  Deinitializes the environment.
" Dependency:
" """"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
function! Y_Env_Deinit()
    " Shutdown Yavide server background service
    call Y_ServerStop()
endfunction

" --------------------------------------------------------------------------------------------------------------------------------------
"
"   PROJECT MANAGEMENT API
" 
" --------------------------------------------------------------------------------------------------------------------------------------
" """"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" Function:
" Description:
" Dependency:
" """"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
function! s:Y_Project_Create(bEmptyProject)
    " Ask user to provide a project name
    call inputsave()
    let l:project_name = input('Project name: ')
    call inputrestore()

    if l:project_name != ""
        " Ask user to provide a project root directory
        call inputsave()
        let l:project_root_directory = input('Project directory: ', '', 'file')
        call inputrestore()

        echo '  '

        if l:project_root_directory != ""
            " Check if directory exists
            if a:bEmptyProject == 0 && isdirectory(l:project_root_directory) == 0
                return 1
            endif

            " Ask user to provide project type
            let l:type_list = ['Project type:']
            for [descr, proj_type] in items(g:project_supported_types)
                let l:type_string = '[' . proj_type.id . '] ' . descr
                call add(l:type_list, type_string)
            endfor
            call inputsave()
            let l:project_type = inputlist(sort(l:type_list))
            call inputrestore()

            if l:project_type > 0
                " Ask user to provide project category
                echo ' '
                let l:category_list = ['Project category:']
                for [descr, proj_category] in items(g:project_supported_categories)
                    let l:cat_string = '[' . proj_category.id . '] ' . descr
                    call add(l:category_list, cat_string)
                endfor
                call inputsave()
                let l:project_category = inputlist(sort(l:category_list))
                call inputrestore()

                if l:project_category > 0
                    " Create project root directory for new projects
                    if a:bEmptyProject == 1
                        let l:project_root_directory = l:project_root_directory . '/' . l:project_name
                        call mkdir(l:project_root_directory, "p")
                    endif
                    execute('cd ' . l:project_root_directory)

                    " Make this an absolute path
                    let l:project_root_directory = getcwd()

                    " Create project specific files
                    call system('touch ' . g:project_configuration_filename)
                    if (l:project_type == g:project_supported_types['C'].id ||
\                       l:project_type == g:project_supported_types['C++'].id ||
\                       l:project_type == g:project_supported_types['Mixed'].id)
                        call system('touch ' . g:project_autocomplete_filename)
                    endif
                    if (l:project_category == g:project_supported_categories['Makefile'].id)
                        if !filereadable('Makefile')
                            call system('touch ' . 'Makefile')
                        endif
                    endif

                    " 'Mixed' type of projects require an information about programming languages being used throughout the project
                    if (l:project_type == g:project_supported_types['Mixed'].id)
                        " Let us 'auto-detect' the languages
                        let l:lang_list = s:Y_Project_AutoDetectProgLanguages(l:project_root_directory)

                        " Build a file extension list
                        let l:extension_list = []
                        if index(l:lang_list, 'Cxx') >= 0
                            call extend(l:extension_list, g:project_type_c.extensions)
                            call extend(l:extension_list, g:project_type_cpp.extensions)
                        endif
                        if index(l:lang_list, 'Java') >= 0
                            call extend(l:extension_list, g:project_type_java.extensions)
                        endif

                        " Remove duplicates if any
                        let g:project_type_mixed.extensions = filter(copy(l:extension_list), 'index(l:extension_list, v:val, v:key+1)==-1')
                    endif

                    " Find out if project exposes compilation database
                    " TODO allow out-of-source compilation db's
                    let l:project_env_compilation_db_path = ''
                    if filereadable(g:project_supported_compilation_db['json'].name)
                        let l:project_env_compilation_db_path = l:project_root_directory . '/' . g:project_supported_compilation_db['json'].name
                    elseif filereadable(g:project_supported_compilation_db['txt'].name)
                        let l:project_env_compilation_db_path = l:project_root_directory . '/' . g:project_supported_compilation_db['txt'].name
                    else
                        echo ' '
                        echohl WarningMsg | echomsg 'No config file found which exposes project-specific compiler flags. Functionality will be limited!' | echohl None
                        echohl MoreMsg
                        echomsg 'Supported ways of providing compiler flags are:'
                        for [descr, comp_db_type] in items(g:project_supported_compilation_db)
                            echomsg '[' . comp_db_type.id . '] ' . comp_db_type.name . '  (' . comp_db_type.description . ')'
                        endfor
                        echohl None
                        call input('Press <Enter> to continue')
                    endif

                    " Store project specific settings into the project configuration file
                    let l:project_settings = []
                    call add(l:project_settings, 'let g:' . 'project_root_directory = ' . "\'" . l:project_root_directory . "\'")
                    call add(l:project_settings, 'let g:' . 'project_name = ' . "\'" . l:project_name . "\'")
                    call add(l:project_settings, 'let g:' . 'project_category = ' . l:project_category)
                    call add(l:project_settings, 'let g:' . 'project_type = ' . l:project_type)
                    call add(l:project_settings, 'let g:' . 'project_env_compilation_db_path = ' . "\'" . l:project_env_compilation_db_path . "\'")
                    call writefile(l:project_settings, g:project_configuration_filename)
                    return 0
                endif
            endif
        endif
    endif
    return 1
endfunction

function! s:Y_Project_AutoDetectProgLanguages(project_root_directory)
    let l:lang_list = []

python << EOF
import vim
import os

prog_languages = set()
for dirpath, dirnames, files in os.walk(vim.eval('a:project_root_directory')):
    for file in files:
        file_type = os.path.splitext(file)[1]
        if file_type != '':
            plang = YavideUtils.file_type_to_programming_language(file_type)
            if plang != '':
                prog_languages.add(plang)
for lang in prog_languages:
    vim.command("call add(l:lang_list, '" + lang + "')")
EOF

    return l:lang_list
endfunction

" """"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" Function:
" Description:
" Dependency:
" """"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
function! s:Y_Project_Load()
    " Load project general settings
    if filereadable(g:project_configuration_filename)
        execute('source ' . g:project_configuration_filename)
        let g:project_java_tags = g:project_root_directory . '/' . g:project_java_tags_filename
        let g:project_cxx_tags  = g:project_root_directory . '/' . g:project_cxx_tags_filename

        " If there were no compilation database previously,
        " check if one has been added in the meantime.
        if g:project_env_compilation_db_path == ''
            if filereadable(g:project_supported_compilation_db['json'].name)
                let g:project_env_compilation_db_path = g:project_root_directory . '/' . g:project_supported_compilation_db['json'].name
            elseif filereadable(g:project_supported_compilation_db['txt'].name)
                let g:project_env_compilation_db_path = g:project_root_directory . '/' . g:project_supported_compilation_db['txt'].name
            endif
            if g:project_env_compilation_db_path != ''
                echo ' ' | echohl MoreMsg | echomsg 'New compiler-flags config file detected! Re-run the indexer (<ctrl>-\ r).' | echohl None
                call s:Y_Project_SaveEnv()
                call input('Press <Enter> to continue')
            endif
        endif

        " Load project session information
        if filereadable(g:project_session_filename)
            execute('source ' . g:project_session_filename)
        endif

        " Start background services
        call Y_ServerStartAllServices()

        call Y_Buffer_CloseEmpty()
        let g:project_loaded = 1
    endif
endfunction

" """"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" Function:
" Description:
" Dependency:
" """"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
function! s:Y_Project_RemoveEnv()
    let cmd = 'sed -i "/^let g:project_env/d" ' . g:project_configuration_filename
    let resp = system(cmd) 
endfunction

" """"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" Function:
" Description:
" Dependency:
" """"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
function! s:Y_Project_SaveEnv()
    " Remove the existing env section
    call s:Y_Project_RemoveEnv()
    
    " And replace it with most current env config
    let l:project_env = []
    call add(l:project_env, 'let g:' . 'project_env_build_preproces_command = ' . "\'" . g:project_env_build_preproces_command . "\'")
    call add(l:project_env, 'let g:' . 'project_env_build_command = ' . "\'" . g:project_env_build_command . "\'")
    call add(l:project_env, 'let g:' . 'project_env_compilation_db_path = ' . "\'" . g:project_env_compilation_db_path . "\'")
    call s:Y_Utils_AppendToFile(g:project_configuration_filename, l:project_env)
endfunction

" """"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" Function:
" Description:
" Dependency:
" """"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
function! Y_Project_New(bCreateEmpty)
    " Close any previously opened projects if any
    call Y_Project_Close()

    " Create completely new project or import existing code base
    let l:ret = s:Y_Project_Create(a:bCreateEmpty)

    if l:ret == 0
        " Load project specific stuff
        call s:Y_Project_Load()

        " Restore the layout
        call Y_Layout_Refresh()

        " Finally, save project into the new session
        call Y_Project_Save()
    endif
endfunction

" """"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" Function:
" Description:
" Dependency:
" """"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
function! Y_Project_Open()
    " Close any previously opened projects if any
    call Y_Project_Close()

    " TODO present user with the list of recently opened projects

    " Ask user to provide a project root directory
    call inputsave()
    let l:project_root_directory = input('Project directory: ', '', 'file')
    call inputrestore()

    " Initialize the environment
    if l:project_root_directory != "" && isdirectory(l:project_root_directory) != 0
        execute('cd ' . l:project_root_directory)
        call s:Y_Project_Load()
        call Y_Layout_Refresh()
        
        " TODO lock the session
        
        if g:project_loaded == 0
            execute('cd -')
            redraw | echomsg "No project found at '" . l:project_root_directory . "'"
        endif
    endif
endfunction

" """"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" Function:
" Description:
" Dependency:
" """"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
function! Y_Project_Close()
    if g:project_loaded == 0
        return 1
    endif

    " Ask user if he wants to save the session
    let l:save_changes = confirm('Save all changes made to "' . g:project_name . '"?', "&Yes\n&No", 1)
    if l:save_changes == 1
        call Y_Project_Save()
    endif

    " Stop background services
    call Y_ServerStopAllServices(v:true)

    " Close all buffers
    call Y_Buffer_CloseAll(1)

    " Close all but the current window
    if winnr('$') > 1
        execute 'only!'
    endif

    " Close all but the current tab
    if tabpagenr('$') > 1
        execute('tabonly!')
    endif

    " Reset the working directory
    execute('cd ~/')

    " TODO unlock the session

    " Reset the session
    let v:this_session = ''
    let g:project_loaded = 0
endfunction

" """"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" Function:
" Description:
" Dependency:
" """"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
function! Y_Project_Save()
    if g:project_loaded == 0
        return 1
    endif

    " Save project-specific variables
    call s:Y_Project_SaveEnv()

    " Save all modified files
    call Y_Buffer_SaveAll()

    " Save Vim session
    execute('mksession! ' . g:project_session_filename)

    " Delete NERDTree & Tagbar related entries
    let cmd = 'sed -i ' . '"' . '\:' . 'NERD_tree\|Tagbar' . ':d' . '" ' . g:project_session_filename
    let resp = system(cmd)
endfunction

" """"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" Function:
" Description:
" Dependency:
" """"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
function! Y_Project_Delete()
    if g:project_loaded == 0
        return 1
    endif

    " TODO ask user if he wants to delete the project directory as well
endfunction


" --------------------------------------------------------------------------------------------------------------------------------------
"
"   SEARCH API
" 
" --------------------------------------------------------------------------------------------------------------------------------------
" """"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" Function:
" Description:
" Dependency:
" """"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
function! Y_Prompt_Find()
    :promptfind
endfunction

" """"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" Function:
" Description:
" Dependency:
" """"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
function! Y_Prompt_FindAndReplace()
    :promptrepl
endfunction


" --------------------------------------------------------------------------------------------------------------------------------------
"
"   BUFFER MANAGEMENT API
" 
" --------------------------------------------------------------------------------------------------------------------------------------
" """"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" Function:
" Description:
" Dependency:
" """"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
function! Y_Buffer_Save(buf_nr)
    let l:curr_buffer = bufnr('%')
    let l:buf_modified = getbufvar(a:buf_nr, "&modified")
    if l:buf_modified == 1
        execute('buffer ' . a:buf_nr)
        if bufname(a:buf_nr) == ''
            :browse w
        else
            :w
        endif
        execute('buffer ' . l:curr_buffer)
    endif
endfunction

" """"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" Function:
" Description:
" Dependency:
" """"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
function! Y_Buffer_SaveAll()
    let [i, n; buf] = [1, bufnr('$')]
    while i <= n
        if bufexists(i)
            call Y_Buffer_Save(i)
        endif
        let i += 1
    endwhile
endfunction

" """"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" Function:
" Description:
" Dependency:
" """"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
function! Y_Buffer_Close(buf_nr, override_buf_modified)
    let l:nr_of_listed_buffers = len(filter(range(1, bufnr('$')), 'buflisted(v:val) && getbufvar(v:val, "&buftype") == ""'))
    if l:nr_of_listed_buffers == 1
        let l:close_cmd = 'new | bwipeout'
    else
        let l:close_cmd = 'call Y_Buffer_GoTo(0) | sp | call Y_Buffer_GoTo(1) | bwipeout'
    endif

    let l:curr_buf = bufnr(a:buf_nr)
    let l:buf_type = getbufvar(l:curr_buf, "&buftype")
    if l:buf_type != 'nofile' && l:buf_type != 'quickfix' && l:buf_type != 'help'
       let l:buf_modified = getbufvar(l:curr_buf, "&modified")
       if l:buf_modified == 1
           if a:override_buf_modified == 1
               let l:close_cmd .= '!'
           else
               let l:save_changes = confirm('Save changes to "' . bufname(l:curr_buf) . '"?', "&Yes\n&No", 1)
               if l:save_changes == 1
                   call Y_Buffer_Save(l:curr_buf)
               else
                   let l:close_cmd .= '!'
               endif
           endif
       endif

       let l:close_cmd .= ' ' . l:curr_buf
       execute(l:close_cmd)
    endif
endfunction

" """"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" Function:
" Description:
" Dependency:
" """"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
function! Y_Buffer_CloseAll(override_buf_modified)
    let [i, n; buf] = [1, bufnr('$')]
    while i <= n
        if bufexists(i)
            call Y_Buffer_Close(i, a:override_buf_modified)
        endif
        let i += 1
    endwhile
endfunction

" """"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" Function:
" Description:
" Dependency:
" """"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
function! Y_Buffer_CloseAllButCurrentOne(override_buf_modified)
    let [i, n; buf] = [1, bufnr('$')]
    let l:curr_buff = bufnr('%')
    while i <= n
        if bufexists(i) && i != l:curr_buff
           call Y_Buffer_Close(i, a:override_buf_modified)
        endif
        let i += 1
    endwhile
endfunction

" """"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" Function:
" Description:
" Dependency:
" """"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
function! Y_Buffer_CloseEmpty()
    let [i, n; empty] = [1, bufnr('$')]
    while i <= n
        if bufexists(i) && bufname(i) == ''
            call add(empty, i)
        endif
        let i += 1
    endwhile
    if len(empty) > 0
        exe 'bwipeout' join(empty)
    endif
endfunction

" """"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" Function:
" Description:
" Dependency:
" """"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
function! Y_Buffer_GoTo(bGoToNext)
    if &buftype != 'nofile' && &buftype != 'quickfix' && &buftype != 'help'
        let cmd = a:bGoToNext == 1 ? ":bnext" : ":bprevious"
        exec cmd
        if &buftype ==# 'quickfix'
            exec cmd
        endif
    endif
endfunction

" """"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" Function:
" Description:
" Dependency:
" """"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
function! Y_Buffer_Scroll(bScrollDown)
    if (a:bScrollDown == 1)
        execute("normal \<C-e>")
    else
        execute("normal \<C-y>")
    endif
endfunction

" """"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" Function:     Y_Buffer_StripTrailingWhitespaces()
" Description:  Strips trailing whitespaces from current buffer
" Dependency:   None
" """"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
function! Y_Buffer_StripTrailingWhitespaces()
    " Preparation: save last search, and cursor position.
    let _s=@/
    let l = line(".")
    let c = col(".")
    " Do the business:
    %s/\s\+$//e
    " Clean up: restore previous search history, and cursor position
    let @/=_s
    call cursor(l, c)
endfunction

" """"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" Function:     Y_Buffer_AutoHighlightToggle()
" Description:  Highlight all occurences of word under cursor.
" Dependency:
" """"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
function! Y_Buffer_AutoHighlightToggle(on)
    let @/ = ''
    if a:on
        augroup auto_highlight
            au!
            au CursorHold * let @/ = '\V\<'.escape(expand('<cword>'), '\').'\>'
        augroup end
        let &updatetime=g:editor_auto_highlight_word_occurences_after_ms
    else
        au! auto_highlight
        augroup! auto_highlight
        setl updatetime=4000
    endif
endfunction

" --------------------------------------------------------------------------------------------------------------------------------------
"
"   TEXT MANAGEMENT API
" 
" --------------------------------------------------------------------------------------------------------------------------------------
" """"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" Function:
" Description:
" Dependency:
" """"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
function! Y_Text_SelectAll()
    execute('normal ggVG')
endfunction

" """"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" Function:
" Description:
" Dependency:
" """"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
function! Y_Text_Cut()
    execute('normal \"+x')
endfunction

" """"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" Function:
" Description:
" Dependency:
" """"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
function! Y_Text_Copy()
    execute('normal \"+y')
endfunction

" """"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" Function:
" Description:
" Dependency:
" """"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
function! Y_Text_Paste()
    execute('normal +gP')
endfunction

" """"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" Function:
" Description:
" Dependency:
" """"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
function! Y_Text_Undo()
    execute('normal u')
endfunction

" """"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" Function:
" Description:
" Dependency:
" """"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
function! Y_Text_Redo()
endfunction


" --------------------------------------------------------------------------------------------------------------------------------------
"
"   SOURCE CODE NAVIGATION API
" 
" --------------------------------------------------------------------------------------------------------------------------------------
" """"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" Function:     Y_SrcNav_OpenFile()
" Description:  Opens the file under the cursor
" Dependency:   cscope
" """"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
function! Y_SrcNav_OpenFile()
    execute('cs find f '.expand("<cfile>"))
endfunction

" """"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" Function:     Y_SrcNav_SwitchBetweenHeaderImpl()
" Description:  Switches between header and implementation files
" Dependency:   'A' plugin
" """"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
function! Y_SrcNav_SwitchBetweenHeaderImpl(bShowInVerticalSplit)
    if (a:bShowInVerticalSplit == 1)
        :AV
    else
        :A
    endif
endfunction

" """"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" Function:     Y_SrcNav_GoToDefinition()
" Description:  Go to definition of token under the cursor
" Dependency:   ctags exuberant
" """"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
function! Y_SrcNav_GoToDefinition()
    execute('tjump '.expand("<cword>"))
endfunction

" """"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" Function:     Y_SrcNav_FindAllReferences()
" Description:  Find all references to the token under the cursor
" Dependency:   cscope
" """"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
function! Y_SrcNav_FindAllReferences()
    execute('cs find s '.expand("<cword>"))
endfunction

" """"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" Function:     Y_SrcNav_FindGlobalDefinitions()
" Description:  Find global definitions of token under the cursor
" Dependency:   cscope
" """"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
function! Y_SrcNav_FindGlobalDefinitions()
    execute('cs find g '.expand("<cword>"))
endfunction

" """"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" Function:     Y_SrcNav_FindAllCallers()
" Description:  Find all functions calling the function under the cursor
" Dependency:   cscope
" """"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
function! Y_SrcNav_FindAllCallers()
    execute('cs find c '.expand("<cword>"))
endfunction

" """"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" Function:     Y_SrcNav_FindAllCallees()
" Description:  Find all functions called by the function under the cursor
" Dependency:   cscope
" """"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
function! Y_SrcNav_FindAllCallees()
    execute('cs find d '.expand("<cword>"))
endfunction

" """"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" Function:     Y_SrcNav_FindAllIncludes()
" Description:  Find all files that include the filename under the cursor
" Dependency:   cscope
" """"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
function! Y_SrcNav_FindAllIncludes()
    execute('cs find i '.expand("<cfile>"))
endfunction

" """"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" Function:     Y_SrcNav_FindAllInstancesOfText()
" Description:  Run 'egrep'of token under the cursor
" Dependency:   cscope
" """"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
function! Y_SrcNav_FindAllInstancesOfText()
    execute('cs find t '.expand("<cword>"))
endfunction

" """"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" Function:     Y_SrcNav_EGrepSearch()
" Description:  Search for the word under the cursor using 'egrep'
" Dependency:   cscope, egrep
" """"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
function! Y_SrcNav_EGrepSearch()
    execute('cs find e '.expand("<cword>"))
endfunction

" """"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" Function:     Y_SrcNav_ReInit()
" Description:  Reinit the cscope database
" Dependency:   cscope
" """"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
function! Y_SrcNav_ReInit()
    execute('cs reset')
endfunction

" --------------------------------------------------------------------------------------------------------------------------------------
"
"   YAVIDE SERVER API
"
" --------------------------------------------------------------------------------------------------------------------------------------
" """"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" Function:     Y_ServerStart()
" Description:  Starts Yavide server background service.
" Dependency:
" """"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
function! Y_ServerStart()
python << EOF
from server.yavide_server import yavide_server_run
from multiprocessing import Process

server = Process(target=yavide_server_run, args=(server_queue, vim.eval('v:servername')), name="yavide_server") 
server.daemon = False
server.start()
EOF
endfunction

" """"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" Function:     Y_ServerStartAllServices()
" Description:  Starts all Yavide server background services.
" Dependency:
" """"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
function! Y_ServerStartAllServices()
    for service in g:project_available_services
        if service['enabled']
            call service['start']()
        endif
    endfor
endfunction

" """"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" Function:     Y_ServerStartService()
" Description:  Starts specific Yavide server background services.
" Dependency:
" """"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
function! Y_ServerStartService(id, payload)
python << EOF
server_queue.put([0xF1, vim.eval('a:id'), vim.eval('a:payload')])
EOF
endfunction

" """"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" Function:     Y_ServerSendServiceRequest()
" Description:  Sends request to particular server background service.
" Dependency:
" """"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
function! Y_ServerSendServiceRequest(id, payload)
python << EOF
server_queue.put([0xF2, int(vim.eval('a:id')), vim.eval('a:payload')])
EOF
endfunction

" """"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" Function:     Y_ServerStopAllServices()
" Description:  Stops all Yavide server background services.
" Dependency:
" """"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
function! Y_ServerStopAllServices(subscribe_for_shutdown_callback)
    " Stop background services
    for service in g:project_available_services
        if service['enabled']
            call service['stop'](a:subscribe_for_shutdown_callback)
        endif
    endfor
endfunction

" """"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" Function:     Y_ServerStopService()
" Description:  Stops specific Yavide server backround service.
" Dependency:
" """"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
function! Y_ServerStopService(id, subscribe_for_shutdown_callback)
python << EOF
server_queue.put([0xFE, vim.eval('a:id'), vim.eval('a:subscribe_for_shutdown_callback')])
EOF
endfunction

" """"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" Function:     Y_ServerStop()
" Description:  Stops Yavide server background service.
" Dependency:
" """"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
function! Y_ServerStop()
python << EOF
server_queue.put([0xFF, 0xFF, False])
EOF
endfunction

" --------------------------------------------------------------------------------------------------------------------------------------
"
"   SOURCE CODE MODEL UTILITY FUNCTIONS
"
" --------------------------------------------------------------------------------------------------------------------------------------
" """"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" Function:     Y_SrcCodeModel_CheckTextChangedType()
" Description:  Implements simple heuristics to detect what kind of text change has taken place in current buffer.
"               This is useful if one wants to install handler for 'TextChangedI' events but not necessarily
"               act on each of those because they are triggered rather frequently. This is by no means a perfect
"               implementation but it tries to give good enough approximations. It probably can be improved and specialized further.
"               Returns 0 for a non-interesting change. Otherwise, some value != 0.
" Dependency:
" """"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
function! Y_SrcCodeModel_TextChangedType()

    let l:textChangeType = 0 " no interesting change (i.e. typed in a letter after letter)

python << EOF
import vim

# Uncomment to enable debugging
#import logging
#logging.basicConfig(filename='/tmp/temp', filemode='w', level=logging.INFO)
#logging.info("y_prev_line = '{0}' y_prev_col = '{1}' y_prev_char = '{2}'. curr_line = '{3}' curr_col = '{4}' curr_char = '{5}'".format(vim.eval('s:y_prev_line'), vim.eval('s:y_prev_col'), vim.eval('s:y_prev_char'), curr_line, curr_col, curr_char))

curr_line = int(vim.eval("line('.')"))
curr_col = int(vim.eval("col('.')"))
curr_char = str(vim.eval("getline('.')[col('.')-2]"))

if curr_line > int(vim.eval('s:y_prev_line')):
    vim.command("let l:textChangeType = 1") #logging.info("Switched to next line!")
elif curr_line < int(vim.eval('s:y_prev_line')):
    vim.command("let l:textChangeType = 2") #logging.info("Switched to previous line!")
else:
    if not curr_char.isalnum():
        if str(vim.eval('s:y_prev_char')).isalnum():
            vim.command("let l:textChangeType = 3") #logging.info("Delimiter!")
        else:
            if curr_col > int(vim.eval('s:y_prev_col')): #logging.info("---> '{0}'".format(vim.eval("getline('.')")[curr_col-1:]))
                if len(vim.eval("getline('.')")[curr_col-1:]) > 0:
                    vim.command("let l:textChangeType = 3")
            elif curr_col < int(vim.eval('s:y_prev_col')): #logging.info("<--- '{0}'".format(vim.eval("getline('.')")[:curr_col-1]))
                if len(vim.eval("getline('.')")[curr_col-1:]) > 0:
                    vim.command("let l:textChangeType = 3")

vim.command('let s:y_prev_line = %s' % curr_line)
vim.command('let s:y_prev_col = %s' % curr_col)
vim.command('let s:y_prev_char = "%s"' % curr_char.replace('"', "\"").replace("\\", "\\\\"))

EOF

    return l:textChangeType

endfunction

" --------------------------------------------------------------------------------------------------------------------------------------
"
"   SOURCE CODE MODEL API
"
" --------------------------------------------------------------------------------------------------------------------------------------
" """"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" Function:     Y_SrcCodeModel_Start()
" Description:  Starts the source code model background service.
" Dependency:
" """"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
function! Y_SrcCodeModel_Start()
    " Enable balloon expressions if TypeDeduction service is enabled.
    if g:project_service_src_code_model['services']['type_deduction']['enabled']
        set ballooneval balloonexpr=Y_SrcCodeTypeDeduction_Run()
    endif
    call Y_ServerStartService(g:project_service_src_code_model['id'], [g:project_root_directory, g:project_env_compilation_db_path])
endfunction

function! Y_SrcCodeModel_StartCompleted()
    let g:project_service_src_code_model['started'] = 1
    call Y_SrcCodeIndexer_RunOnDirectory()
endfunction

" """"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" Function:     Y_SrcCodeModel_Stop()
" Description:  Stops the source code model background service.
" Dependency:
" """"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
function! Y_SrcCodeModel_Stop(subscribe_for_shutdown_callback)
    call Y_ServerStopService(g:project_service_src_code_model['id'], a:subscribe_for_shutdown_callback)
endfunction

function! Y_SrcCodeModel_StopCompleted()
    let g:project_service_src_code_model['started'] = 0
endfunction

" """"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" Function:     Y_SrcCodeModel_Run(service_id, args)
" Description:  Runs the specific service within the source code model (super)-service (i.e. syntax highlight, fixit, diagnostics, ...)
" Dependency:
" """"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
function! Y_SrcCodeModel_Run(service_id, args)
    if g:project_service_src_code_model['started']
        call insert(a:args, a:service_id)
        call Y_ServerSendServiceRequest(g:project_service_src_code_model['id'], a:args)
    endif
endfunction

" --------------------------------------------------------------------------------------------------------------------------------------
"
"   SOURCE CODE HIGHLIGHT API
"
" --------------------------------------------------------------------------------------------------------------------------------------
" """"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" Function:     Y_SrcCodeHighlighter_Run()
" Description:  Triggers the source code highlighting for current buffer.
" Dependency:
" """"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
function! Y_SrcCodeHighlighter_Run()
    if g:project_service_src_code_model['services']['semantic_syntax_highlight']['enabled']
        let l:current_buffer = expand('%:p')

        " If buffer contents are modified but not saved, we need to serialize contents of the current buffer into temporary file.
        let l:contents_filename = l:current_buffer
        if getbufvar(bufnr('%'), '&modified')
            let l:contents_filename = '/tmp/tmp_' . expand('%:t') 
            call Y_Utils_SerializeCurrentBufferContents(l:contents_filename)
        endif
        call Y_SrcCodeModel_Run(g:project_service_src_code_model['services']['semantic_syntax_highlight']['id'], [l:contents_filename, l:current_buffer])
    endif
endfunction

" """"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" Function:     Y_SrcCodeHighlighter_Apply()
" Description:  Apply the results of source code highlighting for given filename.
" Dependency:
" """"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
function! Y_SrcCodeHighlighter_Apply(filename, syntax_file)
    let l:current_buffer = expand('%:p')
    if l:current_buffer == a:filename
        " Apply the syntax highlighting rules
        execute('source '.a:syntax_file)

        " Following command is a quick hack to apply the new syntax for
        " the given buffer. I haven't found any other more viable way to do it 
        " while keeping it fast & low on resources,
        execute(':redrawstatus')
    endif
endfunction

" --------------------------------------------------------------------------------------------------------------------------------------
"
"   SOURCE CODE DIAGNOSTICS API
"
" --------------------------------------------------------------------------------------------------------------------------------------
" """"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" Function:     Y_SrcCodeDiagnostics_Run()
" Description:  Triggers the source code diagnostics for current buffer.
" Dependency:
" """"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
function! Y_SrcCodeDiagnostics_Run()
    if g:project_service_src_code_model['services']['diagnostics']['enabled']
        let l:current_buffer = expand('%:p')

        " If buffer contents are modified but not saved, we need to serialize contents of the current buffer into temporary file.
        let l:contents_filename = l:current_buffer
        if getbufvar(bufnr('%'), '&modified')
            let l:contents_filename = '/tmp/tmp_' . expand('%:t') 
            call Y_Utils_SerializeCurrentBufferContents(l:contents_filename)
        endif
        call Y_SrcCodeModel_Run(g:project_service_src_code_model['services']['diagnostics']['id'], [l:contents_filename, l:current_buffer])
    endif
endfunction

" """"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" Function:     Y_SrcCodeDiagnostics_Apply()
" Description:  Populates the quickfix window with source code diagnostics.
" Dependency:
" """"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
function! Y_SrcCodeDiagnostics_Apply(diagnostics)
    call setloclist(0, a:diagnostics, 'r')
    redraw
endfunction

" --------------------------------------------------------------------------------------------------------------------------------------
"
"   SOURCE CODE TYPE DEDUCTION API
"
" --------------------------------------------------------------------------------------------------------------------------------------
function! Y_SrcCodeTypeDeduction_Run()
    if g:project_service_src_code_model['services']['type_deduction']['enabled']
        " Execute requests only on non-special, ordinary buffers. I.e. ignore NERD_Tree, Tagbar, quickfix and alike.
        " In case of non-ordinary buffers, buffer may not even exist on a disk and triggering the service does not
        " any make sense then.
        if getbufvar(v:beval_bufnr, "&buftype") == ''
            let l:current_buffer = fnamemodify(bufname(v:beval_bufnr), ':p')

            " If buffer contents are modified but not saved, we need to serialize contents of the current buffer into temporary file.
            let l:contents_filename = l:current_buffer
            if getbufvar(bufnr('%'), '&modified')
                let l:contents_filename = '/tmp/tmp_' . expand('%:t') 
                call Y_Utils_SerializeCurrentBufferContents(l:contents_filename)
            endif
            call Y_SrcCodeModel_Run(g:project_service_src_code_model['services']['type_deduction']['id'], [l:contents_filename, l:current_buffer, v:beval_lnum, v:beval_col])
        endif
    endif
    return ''
endfunction

function! Y_SrcCodeTypeDeduction_Apply(deducted_type)
    if exists('*balloon_show')
        if a:deducted_type != ''
            call balloon_show(a:deducted_type)
        endif
    else
        echo a:deducted_type
    endif
endfunction


" --------------------------------------------------------------------------------------------------------------------------------------
"
"   SOURCE CODE NAVIGATION API
"
" --------------------------------------------------------------------------------------------------------------------------------------
" """"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" Function:     Y_SrcCodeNavigation_GoToDefinition()
" Description:  Jumps to the definition of a symbol under the cursor.
" Dependency:
" """"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
function! Y_SrcCodeNavigation_GoToDefinition()
    if g:project_service_src_code_model['services']['go_to_definition']['enabled']
        let l:current_buffer = expand('%:p')

        " If buffer contents are modified but not saved, we need to serialize contents of the current buffer into temporary file.
        let l:contents_filename = l:current_buffer
        if getbufvar(bufnr('%'), '&modified')
            let l:contents_filename = '/tmp/tmp_' . expand('%:t') 
            call Y_Utils_SerializeCurrentBufferContents(l:contents_filename)
        endif
        call Y_SrcCodeModel_Run(g:project_service_src_code_model['services']['go_to_definition']['id'], [l:contents_filename, l:current_buffer, line('.'), col('.')])
    endif
endfunction

" """"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" Function:     Y_SrcCodeNavigation_GoToDefinitionCompleted()
" Description:  Jumps to the definition found.
" Dependency:
" """"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
function! Y_SrcCodeNavigation_GoToDefinitionCompleted(filename, line, column)
    if a:filename != ''
        if expand('%:p') != a:filename
            execute('edit ' . a:filename)
        endif
        call cursor(a:line, a:column)
    endif
endfunction

" """"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" Function:     Y_SrcCodeNavigation_GoToInclude()
" Description:  Fetches the filename which include directive corresponds to on the given (current) line.
" Dependency:
" """"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
function! Y_SrcCodeNavigation_GoToInclude()
    if g:project_service_src_code_model['services']['go_to_include']['enabled']
        let l:current_buffer = expand('%:p')

        " If buffer contents are modified but not saved, we need to serialize contents of the current buffer into temporary file.
        let l:contents_filename = l:current_buffer
        if getbufvar(bufnr('%'), '&modified')
            let l:contents_filename = '/tmp/tmp_' . expand('%:t') 
            call Y_Utils_SerializeCurrentBufferContents(l:contents_filename)
        endif
        call Y_SrcCodeModel_Run(g:project_service_src_code_model['services']['go_to_include']['id'], [l:contents_filename, l:current_buffer, line('.')])
    endif
endfunction

" """"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" Function:     Y_SrcCodeNavigation_GoToIncludeCompleted()
" Description:  Opens the filename which corresponds to the include directive.
" Dependency:
" """"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
function! Y_SrcCodeNavigation_GoToIncludeCompleted(filename)
    if a:filename != ''
        execute('edit ' . a:filename)
    endif
endfunction

" --------------------------------------------------------------------------------------------------------------------------------------
"
"   STATIC ANALYSIS API
" 
" --------------------------------------------------------------------------------------------------------------------------------------
" """"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" Function:     Y_Analyzer_RunCppCheck()
" Description:  Runs the 'cppcheck' on given path
" Dependency:   cppcheck
" """"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
function! Y_Analyzer_RunCppCheck(path, ...)
    let additional_args = ''
    if a:0 != 0
        let additional_args = a:1
        let i = 2
        while i <= a:0
            execute "let additional_args = additional_args . \" \" . a:" . i
            let i = i + 1
        endwhile
    endif

    let mp = &makeprg
    let &makeprg = 'cppcheck --enable=all --force --quiet --template=gcc ' . additional_args . ' ' . a:path
    exec "make!"
    let &makeprg = mp
endfunction

" """"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" Function:     Y_Analyzer_RunClangChecker()
" Description:  Runs the 'clang' static analysis on given path
" Dependency:   clang
" """"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
function! Y_Analyzer_RunClangChecker(path, ...)
    let analysis = '-analyzer-store=region -analyzer-opt-analyze-nested-blocks -analyzer-eagerly-assume -analyzer-checker=core -analyzer-checker=unix -analyzer-checker=deadcode -analyzer-checker=cplusplus -analyzer-checker=security.insecureAPI.UncheckedReturn -analyzer-checker=security.insecureAPI.getpw -analyzer-checker=security.insecureAPI.gets -analyzer-checker=security.insecureAPI.mktemp -analyzer-checker=security.insecureAPI.mkstemp -analyzer-checker=security.insecureAPI.vfork -analyzer-output plist'
    let mp = &makeprg
    let &makeprg = 'clang++ -cc1 -analyze -triple arm-none-linux-eabi ' . analysis
    exec "make!"
    let makeprg = &mp
endfunction


" --------------------------------------------------------------------------------------------------------------------------------------
"
"   BUILD MANAGEMENT API
" 
" --------------------------------------------------------------------------------------------------------------------------------------
" """"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" Function:     Y_ProjectBuilder_Start()
" Description:  Starts the project builder background service.
" Dependency:
" """"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
function! Y_ProjectBuilder_Start()
    let args = [g:project_root_directory, g:project_env_build_command]
    call Y_ServerStartService(g:project_service_project_builder['id'], args)
endfunction

function! Y_ProjectBuilder_StartCompleted()
    let g:project_service_project_builder['started'] = 1
endfunction

" """"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" Function:     Y_ProjectBuilder_Stop()
" Description:  Stops the project builder background service.
" Dependency:
" """"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
function! Y_ProjectBuilder_Stop(subscribe_for_shutdown_callback)
    call Y_ServerStopService(g:project_service_project_builder['id'], a:subscribe_for_shutdown_callback)
endfunction

function! Y_ProjectBuilder_StopCompleted()
    let g:project_service_project_builder['started'] = 0
endfunction

" """"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" Function:     Y_ProjectBuilder_Run()
" Description:  Triggers the build for current project.
" Dependency:
" """"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
function! Y_ProjectBuilder_Run(...)
    if g:project_service_project_builder['started']
        let args = [g:project_env_build_command]
        if a:0 != 0
            let args = a:1
            let i = 2
            while i <= a:0
                execute "let args = args . \" \" . a:" . i
                let i = i + 1
            endwhile
        endif
        call setqflist([])
        call Y_ServerSendServiceRequest(g:project_service_project_builder['id'], args)
    endif
endfunction

" """"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" Function:     Y_ProjectBuilder_Apply()
" Description:  Apply the results of source code highlighting for given filename.
" Dependency:
" """"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
function! Y_ProjectBuilder_Apply(filename)
    execute('cgetfile '.a:filename)
    execute('copen')
    redraw
endfunction

" --------------------------------------------------------------------------------------------------------------------------------------
"
"   CLANG-TIDY API
"
" --------------------------------------------------------------------------------------------------------------------------------------
" """"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" Function:     Y_ClangTidy_Start()
" Description:  Starts the clang-tidy background service.
" Dependency:
" """"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
function! Y_ClangTidy_Start()
    let l:configFile = g:project_root_directory . '/' . g:project_env_clang_tidy_config
    call Y_ServerStartService(g:project_service_clang_tidy_checker['id'], [l:configFile, g:project_env_compilation_db_path])
endfunction

function! Y_ClangTidy_StartCompleted()
    let g:project_service_clang_tidy_checker['started'] = 1
endfunction

" """"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" Function:     Y_ClangTidy_Stop()
" Description:  Stops the clang-tidy background service.
" Dependency:
" """"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
function! Y_ClangTidy_Stop(subscribe_for_shutdown_callback)
    call Y_ServerStopService(g:project_service_clang_tidy_checker['id'], a:subscribe_for_shutdown_callback)
endfunction

function! Y_ClangTidy_StopCompleted()
    let g:project_service_clang_tidy_checker['started'] = 0
endfunction

" """"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" Function:     Y_ClangTidy_Run()
" Description:  Triggers the build for current project.
" Dependency:
" """"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
function! Y_ClangTidy_Run(apply_fixes)
    if g:project_service_clang_tidy_checker['started']
        if filereadable(g:project_root_directory . '/' . g:project_env_clang_tidy_config)
            let l:current_buffer = expand('%:p')
            call Y_ServerSendServiceRequest(g:project_service_clang_tidy_checker['id'], [l:current_buffer, a:apply_fixes])
        endif
    endif
endfunction

" """"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" Function:     Y_ClangTidy_Apply()
" Description:  Display the results of clang-tidy.
" Dependency:
" """"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
function! Y_ClangTidy_Apply(clang_tidy_results_filename)
    execute('cgetfile '.a:clang_tidy_results_filename)
    execute('copen')
    redraw
endfunction

" --------------------------------------------------------------------------------------------------------------------------------------
"
"   SOURCE CODE FORMATTER API
" 
" --------------------------------------------------------------------------------------------------------------------------------------
" """"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" Function:     Y_SrcCodeFormatter_Start()
" Description:  Starts the source code formatting background service.
" Dependency:
" """"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
function! Y_SrcCodeFormatter_Start()
    let l:configFile = g:project_root_directory . '/' . g:project_env_src_code_format_config
    call Y_ServerStartService(g:project_service_src_code_formatter['id'], l:configFile)
endfunction

function! Y_SrcCodeFormatter_StartCompleted()
    let g:project_service_src_code_formatter['started'] = 1
endfunction

" """"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" Function:     Y_SrcCodeFormatter_Stop()
" Description:  Stops the source code formatting background service.
" Dependency:
" """"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
function! Y_SrcCodeFormatter_Stop(subscribe_for_shutdown_callback)
    call Y_ServerStopService(g:project_service_src_code_formatter['id'], a:subscribe_for_shutdown_callback)
endfunction

function! Y_SrcCodeFormatter_StopCompleted()
    let g:project_service_src_code_formatter['started'] = 0
endfunction

" """"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" Function:     Y_SrcCodeFormatter_Run()
" Description:  Triggers the formatting on current buffer.
" Dependency:
" """"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
function! Y_SrcCodeFormatter_Run()
    if g:project_service_src_code_formatter['started']
        if filereadable(g:project_root_directory . '/' . g:project_env_src_code_format_config)
            let l:current_buffer = expand('%:p')
            call Y_ServerSendServiceRequest(g:project_service_src_code_formatter['id'], l:current_buffer)
        endif
    endif
endfunction

" """"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" Function:     Y_SrcCodeFormatter_Apply()
" Description:  Apply the results of source code formatting for given filename.
" Dependency:
" """"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
function! Y_SrcCodeFormatter_Apply(filename)
    let l:current_buffer = expand('%:p')
    if l:current_buffer == a:filename
        execute('e')
    endif
endfunction


" --------------------------------------------------------------------------------------------------------------------------------------
"
"   SOURCE CODE INDEXER API
"
" --------------------------------------------------------------------------------------------------------------------------------------
" """"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" Function:     Y_SrcCodeIndexer_RunOnSingleFile()
" Description:  Runs indexer on a single file.
" Dependency:
" """"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
function! Y_SrcCodeIndexer_RunOnSingleFile()
    if g:project_service_src_code_model['services']['indexer']['enabled']
        let l:current_buffer = expand('%:p')

        " If buffer contents are modified but not saved, we need to serialize contents of the current buffer into temporary file.
        let l:contents_filename = l:current_buffer
        if getbufvar(bufnr('%'), '&modified')
            let l:contents_filename = '/tmp/tmp_' . expand('%:t') 
            call Y_Utils_SerializeCurrentBufferContents(l:contents_filename)
        endif
        call Y_SrcCodeModel_Run(g:project_service_src_code_model['services']['indexer']['id'], [0x0, l:contents_filename, l:current_buffer])
    endif
endfunction

" """"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" Function:     Y_SrcCodeIndexer_RunOnSingleFileCompleted()
" Description:  Running indexer on a single file completed.
" Dependency:
" """"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
function! Y_SrcCodeIndexer_RunOnSingleFileCompleted()
endfunction

" """"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" Function:     Y_SrcCodeIndexer_RunOnDirectory()
" Description:  Runs indexer on a whole directory.
" Dependency:
" """"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
function! Y_SrcCodeIndexer_RunOnDirectory()
    if g:project_service_src_code_model['services']['indexer']['enabled']
        echomsg 'Indexing on ' . g:project_root_directory . ' started ... It may take a while if it is run for the first time.'
        call Y_SrcCodeModel_Run(g:project_service_src_code_model['services']['indexer']['id'], [0x1])
    endif
endfunction

" """"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" Function:     Y_SrcCodeIndexer_RunOnDirectoryCompleted()
" Description:  Running indexer on a directory completed.
" Dependency:
" """"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
function! Y_SrcCodeIndexer_RunOnDirectoryCompleted()
    echomsg 'Indexing run on ' . g:project_root_directory . ' completed.'
endfunction

" """"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" Function:     Y_SrcCodeIndexer_DropSingleFile()
" Description:  Drops index for given file from the indexer.
" Dependency:
" """"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
function! Y_SrcCodeIndexer_DropSingleFile(filename)
    if g:project_service_src_code_model['services']['indexer']['enabled']
        call Y_SrcCodeModel_Run(g:project_service_src_code_model['services']['indexer']['id'], [0x2, a:filename])
    endif
endfunction

" """"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" Function:     Y_SrcCodeIndexer_DropSingleFileCompleted()
" Description:  Dropping single file from indexing results completed.
" Dependency:
" """"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
function! Y_SrcCodeIndexer_DropSingleFileCompleted()
endfunction

" """"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" Function:     Y_SrcCodeIndexer_DropAll()
" Description:  Drops all of the indices from the indexer.
" Dependency:
" """"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
function! Y_SrcCodeIndexer_DropAll()
    if g:project_service_src_code_model['services']['indexer']['enabled']
        call Y_SrcCodeModel_Run(g:project_service_src_code_model['services']['indexer']['id'], [0x3, v:true])
    endif
endfunction

" """"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" Function:     Y_SrcCodeIndexer_DropAllCompleted()
" Description:  Dropping all indices from indexing results completed.
" Dependency:
" """"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
function! Y_SrcCodeIndexer_DropAllCompleted()
endfunction

" """"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" Function:     Y_SrcCodeIndexer_DropAllAndRunOnDirectory()
" Description:  Drops the index database and runs indexer again (aka reindexing operation)
" Dependency:
" """"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
function! Y_SrcCodeIndexer_DropAllAndRunOnDirectory()
    if g:project_service_src_code_model['services']['indexer']['enabled']
        call Y_SrcCodeModel_Run(g:project_service_src_code_model['services']['indexer']['id'], [0x3, v:true])
        call Y_SrcCodeModel_Run(g:project_service_src_code_model['services']['indexer']['id'], [0x1])
    endif
endfunction

" """"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" Function:     Y_SrcCodeIndexer_FindAllReferences()
" Description:  Finds project-wide references of a symbol under the cursor.
" Dependency:
" """"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
function! Y_SrcCodeIndexer_FindAllReferences()
    if g:project_service_src_code_model['services']['indexer']['enabled']
        call Y_SrcCodeModel_Run(g:project_service_src_code_model['services']['indexer']['id'], [0x10, expand('%:p'), line('.'), col('.')])
    endif
endfunction

function! Y_SrcCodeIndexer_FindAllReferencesCompleted(references)
python << EOF
import vim
with open(vim.eval('a:references'), 'r') as f:
    vim.eval("setqflist([" + f.read() + "], 'r')")
EOF
    execute('copen')
    redraw
endfunction

" --------------------------------------------------------------------------------------------------------------------------------------
"
"   LAYOUT MANAGEMENT API
"
" --------------------------------------------------------------------------------------------------------------------------------------
" """"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" Function:     Y_Layout_Refresh()
" Description:  Setups the default layout
" Dependency:   NERDTree, Tagbar
" """"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
function! Y_Layout_Refresh()
    if g:project_loaded == 1
        execute('NERDTree ' . g:project_root_directory)
        execute('TagbarOpen')
        call setqflist([])
        execute('copen')
    endif
endfunction

