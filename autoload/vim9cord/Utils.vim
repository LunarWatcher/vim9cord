vim9script

export def GenNonce(n: number): string
  var ret = ""
  for i in range(n)
    var c = nr2char(char2nr('a') + (rand() % 26))
    ret ..= c
  endfor
  return ret
enddef

export def ToLittleEndian(n: number): list<number>
    return [
        n % 256,
        n / 256 % 256,
        n / 65536 % 256,
        n / 16777216 % 256
    ]
enddef

export def FromLittleEndian(num: blob): number
    return num[0] + num[1] * 256 + num[2] * 65536 + num[3] * 16777216
enddef

export def Blob2Str(blob: blob): string
    var str = ""
    for byte in blob
        str ..= nr2char(byte)
    endfor

    return str
enddef

export def Str2Blob(str: string): blob
    var blob = 0z

    # Vim strings don't support null bytes, so they're converted to 0x0A,
    # a zero-width control character. This needs to be handled separately for
    # the header, where 0x0A is functionally guaranteed to be 0x00.
    # This may misfire for certain lengths, but the length is really a noop
    # anyway. Only the output is important most of the time, and the output
    # _is_ well-formed.
    var header = list2blob(str2list(str[0 : 7]))
    for ch in header
        if ch != 0x0A
            blob[len(blob)] = ch
        else
            blob += 0z00
        endif
    endfor

    blob += list2blob(str2list(str[8 : ]))

    return blob
enddef

export def DecodeResponse(raw: blob): dict<any>
    # echom raw
    var op = FromLittleEndian(raw[0 : 3])
    var len = FromLittleEndian(raw[4 : 7])

    if op > 100
        echoerr "An error occurred when parsing the little endian values. Expected a low value, found" op
    endif

    var body = Blob2Str(raw[8 : 8 + len])
    return {
        "op": op,
        "len": len,
        "body": body
    }
enddef

export def IsConnected(sock: any): bool
    return (type(sock) == v:t_channel 
        && ch_status(sock) == "open"
    )
enddef
