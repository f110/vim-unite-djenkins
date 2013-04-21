let s:source = {
            \ 'name': 'djenkins/project',
            \ 'hooks': {},
            \ 'syntax': 'uniteSource__dJenkins',
            \ 'variables': {
            \       'jenkins_server': g:unite_source_djenkins_jenkins_server,
            \       'build_source': g:unite_source_djenkins_build_source,
            \   },
            \ }

function! s:source.hooks.on_init(args, context)
    let project_name = get(a:args, 0, '')
    if project_name == ''
        call unite#print_source_error('required project name', s:source.name)
    endif

    let a:context.source__project_name = project_name
    return
endfunction

function! s:source.hooks.on_syntax(args, cocntext)
    syntax match uniteSource__dJenkins_Success /\[SUCCESS]/ contained containedin=uniteSource__dJenkins
    syntax match uniteSource__dJenkins_Success /\[UNSTABLE]/ contained containedin=uniteSource__dJenkins
    syntax match uniteSource__dJenkins_Fail /\[FAILURE]/ contained containedin=uniteSource__dJenkins
    highlight link uniteSource__dJenkins_Fail Error
    highlight link uniteSource__dJenkins_Success Statement
endfunction

function! s:source.gather_candidates(args, context)
    let vars = unite#get_source_variables(a:context)

    let res = webapi#http#get(printf(
                \ '%s/job/%s/api/json',
                \ vars.jenkins_server,
                \ a:context.source__project_name
                \))
    let builds_and_more = webapi#json#decode(res.content)
    let builds = builds_and_more.builds
    let a:context.source__builds = map(builds, 'v:val.number')

    return []
endfunction

function! s:source.async_gather_candidates(args, context)
    if len(a:context.source__builds) == 0
        let a:context.is_async = 0
        call unite#print_source_message('finished', s:source.name)
        return []
    endif
    let vars = unite#get_source_variables(a:context)

    let build_id = remove(a:context.source__builds, 0)
    let build_detail = s:get_build_detail(
                \ vars.jenkins_server,
                \ a:context.source__project_name,
                \ build_id
                \ )

    return [{
                \ 'word': printf('%d.[%s] %s:%s',
                \        build_id,
                \        build_detail.result,
                \        build_detail.repository,
                \        build_detail.branch
                \ ),
                \ 'source': s:source.name,
                \ 'kind': 'source',
                \ 'action__source_name': vars.build_source,
                \ 'action__source_args': [
                \       a:context.source__project_name,
                \       build_id
                \   ]
                \ }]
endfunction

function! s:get_build_detail(jenkins_server, project_name, build_id)
    let res = webapi#http#get(printf(
                \ '%s/job/%s/%s/api/json',
                \ a:jenkins_server,
                \ a:project_name,
                \ a:build_id
                \))
    let jenkins_data = webapi#json#decode(res.content)

    let build_result = 'RUNNING'
    if has_key(jenkins_data, 'result')
        let build_result = jenkins_data.result
    endif

    let builds_by_branch_name = {}
    let repository = 'UNKNOWN'
    for action in jenkins_data.actions
        if has_key(action, 'buildsByBranchName')
            let builds_by_branch_name = action['buildsByBranchName']
            let repository = action.remoteUrls[0]
        endif
    endfor

    let branch = 'UNKNOWN'
    for key in keys(builds_by_branch_name)
        let _ = builds_by_branch_name[key]
        if has_key(_, 'revision')
            let branch = _.revision.branch[0].name
        endif
    endfor

    return {
                \ 'result': build_result,
                \ 'repository': repository,
                \ 'branch': branch,
                \ }
endfunction

call unite#define_source(s:source)
