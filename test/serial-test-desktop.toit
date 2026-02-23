import uart

/** Echo serial input to serial monitor. */

DEVICE := "COM19" // Windows
//DEVICE := "/dev/ttyACM0" // Linux (example)
BAUD   := 9600

main:
  port := uart.Port DEVICE --baud-rate=BAUD
  while true:
    print port.in.read.to-string
