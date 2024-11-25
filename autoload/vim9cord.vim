vim9script

import autoload "vim9cord/Utils.vim" as utils
import autoload "vim9cord/Activity.vim" as activity

const OP_HANDSHAKE = 0
const OP_FRAME = 1
const OP_CLOSE = 2
const OP_PING = 3
const OP_PONG = 4

export def Init()
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
    if !exists("g:Vim9cordShowAltDetails")
        g:Vim9cordShowAltDetails = !g:Vim9cordShowWorkspace
    endif
    if !exists("g:Vim9cordAppID")
        g:Vim9cordAppID = "1305581900370280550"
    endif
    if !exists("g:Vim9cordEnabled")
        g:Vim9cordEnabled = 1
    endif

    if !exists("g:Vim9cordButtons")
        g:Vim9cordButtons = [{"label": "Vim9cord", "url": "https://github.com/LunarWatcher/vim9cord"}]
    endif

    # Used to prevent updating the start time when reloading config
    if !exists("g:Vim9cordStartTime")
        g:Vim9cordStartTime = strftime("%s")->str2nr()
    endif

    if !exists("g:Vim9cordActivities")
        g:Vim9cordActivities = {
            "fallback": "Editing a %s file",
            "filetree": "Browsing for files",
            "docs": "Writing documentation",
            "start": "Opening Vim"
        }
    endif

    if !exists("g:Vim9cordActivityMaps")
        g:Vim9cordActivityMaps = {
            "filetree": ["fern", "nerdtree", "vimfiler", "netrw"],
            "docs": ["help", "markdown"],
            "start": ["startify"]
        }
    endif

    if !exists("g:Vim9cordAltDetails")
        g:Vim9cordAltDetails = '<esc>:wqa!'
    endif

enddef

export def AddActivities(activities: dict<any>)
    Init()

    g:Vim9cordActivities->extend(activities)
enddef

export def AddActivityMaps(scopes: dict<any>)
    Init()

    for [scope, filetypes] in items(scopes)
        if g:Vim9cordActivityMaps->has_key(scope)
            g:Vim9cordActivityMaps[scope]->extend(filetypes)
        else
            g:Vim9cordActivityMaps[scope] = filetypes
        endif
        var src = copy(g:Vim9cordActivityMaps[scope])
        g:Vim9cordActivityMaps[scope] = uniq(src)
    endfor
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
            g:Vim9cordConnected = 1
            SetActivity()
        endif
    endif
enddef

def CloseChannel(channel: any)
    g:Vim9cordConnected = 0
    g:Vim9cordSock = 0
    g:__Vim9cordLastFt = "___undefined___"
enddef

# Sends an ident header. `mode` must be OP_HANDSHAKE or OP_CLOSE. 
# Both HANDSHAKE and CLOSE send the same payload, so this just wraps the data
# for both
def SendIdentHeader(mode: number)
    var json = json_encode({
        "v": 1,
        "client_id": g:Vim9cordAppID
    })
    SockSendHeader(len(json), mode)
    # I'm not sure if this needs a timeout or not, but better error recovery
    # systems may be needed here
    if mode == OP_CLOSE
        g:Vim9cordSock->ch_sendraw(json, {"timeout": 1000})
    else
        g:Vim9cordSock->ch_sendraw(json)
    endif
enddef

def ConnectSock()
    if !g:Vim9cordEnabled
        return
    endif
    # Kill the existing socket before trying to reconnect
    if utils.IsConnected(get(g:, "Vim9cordSock", 0))
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
    SendIdentHeader(OP_HANDSHAKE)
enddef


def SockSendHeader(payloadLength: number, op: number = OP_FRAME)
    # echo "Sending" op

    # The header format is documented somewhere, but I don't remember where.
    # Messages are in the format
    # [little endian operation number; 4 bytes][little endian message length;
    # 4 bytes][plain-text message*, len(message) == the second param]
    # 
    # *: Technically json, but it's still encoded as plain text
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
    if g:Vim9cordShowWorkspace
        out["details"] = "Workspace: " .. fnamemodify(getcwd(), ":t")
    elseif g:Vim9cordShowAltDetails
        out["details"] = g:Vim9cordAltDetails
    endif
    if g:Vim9cordShowLang
        var ft = &ft
        # TODO: separate file types from certain special buffers, so there can
        # be stuff like "browsing for files" and shit
        if ft != ""
            #out["state"] = "Editing a " .. ft .. " file"
            out["state"] = activity.GetActivity()
        endif
    endif
    # echom out
    return out
enddef

# This is a semi-redundant internal function primarily meant to avoid checking
# the socket status when setting the activity from the connection callback.
# Basically, this is a workaround to deal with some weird vim internals around
# the socket status and, I'm _pretty_ sure anyway, weird update order shit.
# This is just a call to SockSend with SET_ACTIVITY, and no other checks. This
# should not be used outside SockCallback and UpdateStatus()
def SetActivity()
    var ao = {
        "activity": {
            "timestamps": {
                "start": g:Vim9cordStartTime
            },
            "assets": {
                "large_image": "vim",
                "large_text": "Vim - the greatest editor of all time"
            }
        }->extend(GetDetailsAndState())
    }
    
    if type(g:Vim9cordButtons) == v:t_list
        ao["activity"]["buttons"] = g:Vim9cordButtons
    endif

    SockSend("SET_ACTIVITY", ao)
enddef

export def UpdateStatus()
    # Socket doesn't exist; abort
    if !filewritable(StripPrefix(g:Vim9cordSocketLocation))
        return
    endif

    # Vim9cord disabled; don't update
    if !g:Vim9cordEnabled
        return
    endif

    # TODO: use ch_status
    if (!utils.IsConnected(get(g:, "Vim9cordSock", 0)))
        # The socket needs to connect, which happens async
        ConnectSock()
        return
    endif

    # The previous statement is not a guarantee Vim9cordConnected == 1
    if get(g:, "Vim9cordConnected", 0)
        # Check if an update is needed before actually updating, just to avoid
        # unnecessary data use
        # This may need extra control mechanisms if g:Vim9cordShowLang == 0,
        # but it doesn't really matter. It's not an exact science anyway.
        # This does also open for a bug where g:Vim9cordShowWorkspace == 1,
        # but the update isn't sent. 
        # 
        # I'm going to ignore it though. It's not a huge priority, and this
        # isn't a particularly critical application anyway. It's not like
        # a delay in update is going to matter to anyone
        if (
                # Scenario one; ft is blank, and __Vim9cordLastFt is
                # undefined. This is likely a blank starting buffer. Send an
                # update anyway
                (&ft == "" && !exists("g:__Vim9cordLastFt"))
                # Scenario two: current filetype is not the same as the
                # previous filetype; send an update
                || &ft != get(g:, "__Vim9cordLastFt", "")
                || g:__Vim9cordLastFt == "___undefined___"
        )
            g:__Vim9cordLastFt = &ft
            SetActivity()
        endif
    endif

enddef


# Command interfaces {{{
export def Reconnect()
    Disconnect()
    UpdateStatus()
enddef

export def Disconnect()
    if (utils.IsConnected(get(g:, "Vim9cordSock", 0)))
        SendIdentHeader(OP_CLOSE)
        ch_close(g:Vim9cordSock)
        # |ch_close| states the close callback isn't closed.
        # Let's invoke it manually
        CloseChannel(g:Vim9cordSock)
    endif
enddef

export def Toggle()
    g:Vim9cordEnabled = !get(g:, "Vim9cordEnabled", 1)
    echo (g:Vim9cordEnabled ? "Enabled" : "Disabled") "Vim9cord"
    # Yes, this is lazy. I could selectively pick what to do based on the new
    # state, but why do that when everything is bundled in Reconnect(), and
    # everything is selectively done anyway?
    #
    # If vim9cord was disabled, IsConnected() => false, so Disconnect() is a
    # noop. UpdateStatus reconnects.
    # If vim9cord was enabled, IsConnected() => true, so Disconenct()
    # disconnects. UpdateStatus() is a noop due to the Vim9cordEnabled check
    Reconnect()
enddef

# }}}
