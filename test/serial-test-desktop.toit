import uart

/** Echo serial input to serial monitor. */

DEVICE := "COM11"
//DEVICE := "\\\\.\\COM3"
//DEVICE := "COM19" // Windows
//DEVICE := "/dev/ttyACM0" // Linux (example)
BAUD   := 9600
//BAUD   := 115200

main:
  port := uart.Port DEVICE --baud-rate=BAUD //--parity=0 //--data-bits=8
  //  --stop-bits=uart.Port.STOP-BITS-1

  //port.set-control-flag uart.HostPort.CONTROL-FLAG-DTR true
  //port.set-control-flag uart.HostPort.CONTROL-FLAG-RTS true
  //port.set-control-flag uart.HostPort.CONTROL-FLAG-LE  true

  while true:
    print port.in.read.to-string
    sleep --ms=1

  /*
  while true:
    data := port.in.read  // or port.in.read; same underlying behavior in this file
    if data and data.size > 0:
      print data.to-string
    else:
      // Polling backoff so we don't spin.
      sleep --ms=10
  */
