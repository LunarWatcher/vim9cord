vim9script

import autoload "vim9cord.vim" as vc

vc.Init()

command! -nargs=0 Vim9cordReconnect vc.UpdateStatus()

augroup vim9cord
    au!
    au BufWinEnter * vc.UpdateStatus()
augroup end
