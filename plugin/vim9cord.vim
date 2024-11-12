vim9script

import autoload "vim9cord.vim" as vc

vc.Init()

augroup vim9cord
    au!
    au BufWinEnter * vc.UpdateStatus()
augroup end
