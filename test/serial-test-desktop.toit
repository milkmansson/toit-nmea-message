import uart

/** Echo serial input to serial monitor. */

DEVICE := "COM5"
//DEVICE := "\\\\.\\COM3"
//DEVICE := "COM19" // Windows
//DEVICE := "/dev/ttyACM0" // Linux (example)
BAUD   := 9600
//BAUD   := 115200


safe-decode data/ByteArray -> string:
  e := catch: return data.to-string
  // Only reached on invalid UTF-8 — walk and replace.
  result := ByteArray data.size
  i := 0
  out := 0
  while i < data.size:
    b := data[i]
    seq-len/int := 0
    if b & 0x80 == 0:         seq-len = 1
    else if b & 0xE0 == 0xC0: seq-len = 2
    else if b & 0xF0 == 0xE0: seq-len = 3
    else if b & 0xF8 == 0xF0: seq-len = 4
    else:
      result[out++] = '_'
      i++
      continue

    valid := true
    if i + seq-len > data.size:
      valid = false
    else:
      (seq-len - 1).repeat: |j|
        if data[i + 1 + j] & 0xC0 != 0x80: valid = false

    if valid:
      seq-len.repeat: result[out++] = data[i++]
    else:
      result[out++] = '_'
      i++

  return result[0..out].to-string

main:
  port := uart.Port DEVICE --baud-rate=BAUD
  while true:
    print (safe-decode port.in.read)
    sleep --ms=1

/*
main:
  port := uart.Port DEVICE --baud-rate=BAUD
  while true:
    print port.in.read.to-string
    sleep --ms=1
*/

//--parity=0 //--data-bits=8
  //  --stop-bits=uart.Port.STOP-BITS-1

  //port.set-control-flag uart.HostPort.CONTROL-FLAG-DTR true
  //port.set-control-flag uart.HostPort.CONTROL-FLAG-RTS true
  //port.set-control-flag uart.HostPort.CONTROL-FLAG-LE  true



  /*
  while true:
    data := port.in.read  // or port.in.read; same underlying behavior in this file
    if data and data.size > 0:
      print data.to-string
    else:
      // Polling backoff so we don't spin.
      sleep --ms=10
  */
