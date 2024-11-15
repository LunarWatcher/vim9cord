vim9script

import autoload "vim9cord/Utils.vim" as utils

var OP_HANDSHAKE = 0
var OP_FRAME = 1
var OP_CLOSE = 2
var OP_PING = 3
var OP_PONG = 4

export def Init()
    if !has("linux")
        return
    endif

    # If multiple OSes are supported, this is where the socket location needs
    # to be changed to support whatever else
    #
    # This if statement is redundant, but left for future compatibility
    # reasons
    if has("linux")
        g:Vim9cordSocketLocation = "unix:" .. $XDG_RUNTIME_DIR .. "/discord-ipc-0"
    endif

    if !exists("g:Vim9cordShowLang")
        g:Vim9cordShowLang = 1
    endif
    if !exists("g:Vim9cordShowWorkspace")
        g:Vim9cordShowWorkspace = 0
    endif
    if !exists("g:Vim9cordAppID")
        g:Vim9cordAppID = "1305581900370280550"
    endif

    g:Vim9cordStartTime = strftime("%s")->str2nr()

enddef

def StripPrefix(path: string): string

    if path->stridx("unix:") >= 0
        return path[5 : ]
    endif
    return path
enddef

def SockCallback(channel: any, msg: string)
    # This has to be readblob
    var response = utils.DecodeResponse(
       utils.Str2Blob(msg)
    )
    # echom "Received" msg response
    var json = json_decode(response["body"])
    if response["op"] == 1 && json["cmd"] == "DISPATCH"
        if json["evt"] == "READY"
            # echom "Connected to Discord"
            g:Vim9cordConnected = 1
            UpdateStatus()
        endif
    endif
enddef

def CloseChannel(channel: any)
    g:Vim9cordConnected = 0
    g:Vim9cordSock = 0
enddef

def ConnectSock()
    # Kill the existing socket before trying to reconnect
    if exists("g:Vim9cordSock") && type(g:Vim9cordSock) != v:t_number
        ch_close(g:Vim9cordSock)
    endif
    try
        g:Vim9cordSock = ch_open(g:Vim9cordSocketLocation, {
            "mode": "raw",
            "noblock": true,
            "callback": SockCallback,
            "close_cb": CloseChannel,
            "timeout": 300
        })
    catch
        # Discord not online; the socket will fail quietly due to the
        # try-catch
        return
    endtry

    # Handshake
    var json = json_encode({
        "v": 1,
        "client_id": g:Vim9cordAppID
    })
    SockSendHeader(len(json), 0)
    # I'm not sure if this needs a timeout or not, but better error recovery
    # systems may be needed here
    g:Vim9cordSock->ch_sendraw(json)
enddef


def SockSendHeader(payloadLength: number, op: number = OP_FRAME)

    var payload = list2blob(utils.ToLittleEndian(op)->extend(utils.ToLittleEndian(payloadLength)))
    # echom payload
    g:Vim9cordSock->ch_sendraw(
        payload
    )
enddef

def SockSend(cmd: string, extraArgs: dict<any>)
    var json = json_encode({
        "cmd": cmd,
        "args": {
            "pid": getpid()
        }->extend(extraArgs),
        "nonce": utils.GenNonce(32)
    })
    # echom json

    SockSendHeader(json->len())
    g:Vim9cordSock->ch_sendraw(json)
enddef

def GetDetailsAndState(): dict<any>
    var out = {}
    if g:Vim9cordShowWorkspace == 1
        out["details"] = "Workspace: " .. fnamemodify(getcwd(), ":t")
    endif
    if g:Vim9cordShowLang == 1
        var ft = &ft
        # TODO: separate file types from certain special buffers, so there can
        # be stuff like "browsing for files" and shit
        if ft != ""
            out["state"] = "Editing a " .. ft .. " file"
        endif
    endif
    # echom out
    return out
enddef

export def UpdateStatus()
    # Socket doesn't exist; abort
    if !filewritable(StripPrefix(g:Vim9cordSocketLocation))
        return
    endif

    # TODO: use ch_status
    if !exists("g:Vim9cordConnected") || g:Vim9cordConnected == 0
        # The socket needs to connect, which happens async
        ConnectSock()
        return
    endif

    # The previous statement is not a guarantee Vim9cordConnected == 1
    if g:Vim9cordConnected
        SockSend("SET_ACTIVITY", {
            "activity": {
                "timestamps": {
                    "start": g:Vim9cordStartTime
                },
                "assets": {
                    "large_image": "vim",
                    "large_text": "Vim - the greatest editor of all time"
                }
            }->extend(GetDetailsAndState())
        })
    endif

enddef
