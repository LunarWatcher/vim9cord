vim9script

import autoload "vim9cord.vim" as vc

vc.Init()

command! -nargs=0 Vim9cordReconnect vc.Reconnect()
command! -nargs=0 Vim9cordDisconnect vc.Disconnect()
command! -nargs=0 Vim9cordToggle vc.Toggle()

augroup vim9cord
    au!
    au BufEnter * vc.UpdateStatus()
    au BufWinEnter * vc.UpdateStatus()
augroup end
