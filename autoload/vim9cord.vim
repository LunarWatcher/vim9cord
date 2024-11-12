vim9script

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
    g:Vim9cordSocketLocation = "unix:" .. $XDG_RUNTIME_DIR .. "/discord-ipc-0"

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
    echom "Global callback:" msg
enddef

def CloseChannel(channel: any)
    g:Vim9cordConnected = 0
    g:Vim9cordSock = 0
enddef

def ConnectSock(): bool
    # Kill the existing socket before trying to reconnect
    if exists("g:Vim9cordSock") && g:Vim9cordSock != 0
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
        # Discord not online; the socket will fail quietly
        return false
    endtry

    # Handshake
    var json = json_encode({
        "v": 1,
        "client_id": g:Vim9cordAppID
    })
    SockSendHeader(len(json), 0)
    g:Vim9cordSock->ch_sendraw(json)

    # This has to be readblob
    var response = DecodeResponse(
        g:Vim9cordSock->ch_readblob()
    )
    if response["op"] == 1 && json_decode(response["body"])["evt"] == "READY"
        g:Vim9cordConnected = 1
    else
        echom "Failed to connect to Discord (but socket exists):" response
        return false
    endif

    return true
    
enddef

def GenNonce(n: number): string
  var ret = ""
  for i in range(n)
    var c = nr2char(char2nr('a') + (rand() % 26))
    ret ..= c
  endfor
  return ret
enddef

def ToLittleEndian(n: number): list<number>
    return [
        n % 256,
        n / 256 % 256,
        n / 65536 % 256,
        n / 16777216 % 256
    ]
enddef

def FromLittleEndian(num: blob): number
    return num[0] + num[1] * 256 + num[2] * 65536 + num[3] * 16777216
enddef

def Blob2Str(blob: blob): string
    var str = ""
    for byte in blob
        str ..= nr2char(byte)
    endfor

    return str
enddef

def DecodeResponse(raw: blob): dict<any>
    var op = FromLittleEndian(raw[0 : 3])
    var len = FromLittleEndian(raw[4 : 7])

    var body = Blob2Str(raw[8 : 8 + len])
    return {
        "op": op,
        "len": len,
        "body": body
    }
enddef

def SockSendHeader(payloadLength: number, op: number = OP_FRAME)

    var payload = list2blob(ToLittleEndian(op)->extend(ToLittleEndian(payloadLength)))
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
        "nonce": GenNonce(32)
    })
    # echom json

    SockSendHeader(json->len())
    g:Vim9cordSock->ch_sendraw(json)
enddef


export def UpdateStatus()
    # Socket doesn't exist; abort
    if !filewritable(StripPrefix(g:Vim9cordSocketLocation))
        return
    endif

    if !exists("g:Vim9cordConnected") || g:Vim9cordConnected == 0
        if ConnectSock() == false
            return
        endif
    endif

    # The previous statement is not a guarantee Vim9cordConnected == 1
    if g:Vim9cordConnected
        SockSend("SET_ACTIVITY", {
            "activity": {
                "details": "Content goes here",
                "state": "Content goes here too :)",
                "timestamps": {
                    "start": g:Vim9cordStartTime
                },
                "assets": {
                    "large_image": "vim",
                    "large_text": "Vim - the greatest editor of all time"
                }
            }
        })
    endif

enddef
