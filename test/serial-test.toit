import uart

DEVICE := "COM19"
BAUD   := 9600

main:
  port := uart.Port DEVICE --baud-rate=BAUD
  while true:
    print port.in.read.to-string
