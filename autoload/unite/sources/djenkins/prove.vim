let s:source = {
            \ 'name': 'djenkins/prove',
            \ 'hooks': {},
            \ 'variables': {
            \       'prove_command': 'prove',
            \       'jenkins_server': g:unite_source_djenkins_jenkins_server,
            \   },
            \ }

function! s:source.hooks.on_init(args, context) "{{{
    let project_name = get(a:args, 0, '')
    let build_id = get(a:args, 1, '')

    let a:context.source__project_name = project_name
    let a:context.source__build_id = build_id
endfunction

function! s:source.gather_candidates(args, context)
    let vars = unite#get_source_variables(a:context)

    let res = webapi#http#get(printf(
                \ '%s/job/%s/%s/consoleText',
                \ vars.jenkins_server,
                \ a:context.source__project_name,
                \ a:context.source__build_id
                \ ))
    let prove_result = filter(split(res.content, "\n"), "v:val =~ '(Wstat:'")

    let _ = []
    for line in prove_result
        let idx = stridx(line, ' ')
        let file = line[:idx-1]

        call add(_, file)
    endfor
    let a:context.source__fail_tests = copy(_)

    return []
endfunction

function! s:source.async_gather_candidates(args, context)
    if len(a:context.source__fail_tests) == 0
        let a:context.is_async = 1;
        return []
    endif
    let vars = unite#get_source_variables(a:context)
    let test_file = remove(a:context.source__fail_tests, 0)

    let cmd = printf("%s %s", vars.prove_command, test_file)
    call unite#print_source_message(cmd, s:source.name)
    let cmd_result = split(system(cmd), "\n")
    if cmd_result[-1] =~ "FAIL"
        let test_result = "FAIL"
    else
        let test_result = "PASS"
    endif

    return [{
                \ 'word': printf('[%s] %s', test_result, test_file),
                \ 'source': s:souce.name,
                \ 'kind': 'jump_list',
                \ 'action__path': test_file,
                \ }]
endfunction

function! unite#sources#djenkins#prove#define()
    return s:source
endfunction
