vim9script

export def GetActivity(): string
    var outActivity: string
    for [activity, filetypes] in items(g:Vim9cordActivityMaps)
        if filetypes->index(&ft) >= 0
            outActivity = g:Vim9cordActivities[activity]
        endif
    endfor

    if outActivity is null_string
        outActivity = g:Vim9cordActivities["fallback"]
    endif

    if outActivity->stridx("%s") >= 0
        return printf(outActivity, &ft)
    endif

    return outActivity
enddef
