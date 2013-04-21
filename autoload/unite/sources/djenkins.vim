call unite#util#set_default('g:unite_source_djenkins_jenkins_server', 'https://ci.jenkins-ci.org')
call unite#util#set_default('g:unite_source_djenkins_build_source', 'djenkins/prove')

let s:source = {
            \ 'name': 'djenkins',
            \ 'hooks': {},
            \ 'variables': {
            \       'jenkins_server': g:unite_source_djenkins_jenkins_server,
            \   },
            \ }

let s:cache = []

function! s:source.gather_candidates(args, context)
    let vars = unite#get_source_variables(a:context)

    if len(s:cache) == 0
        let res = webapi#http#get(printf(
                    \ '%s/api/json',
                    \ vars.jenkins_server
                    \ ))

        let jenkins_data = webapi#json#decode(res.content)
        let project_list = jenkins_data.jobs
        let s:cache = copy(project_list)
    else
        let project_list = copy(s:cache)
    endif

    return map(project_list, '{
    \   "word": v:val.name,
    \   "source": s:source.name,
    \   "kind": "source",
    \   "action__source_name": "djenkins/project",
    \   "action__source_args": [v:val.name],
    \ }')
endfunction

call unite#define_source(s:source)
