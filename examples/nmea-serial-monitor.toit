// Copyright (C) 2025 Toit contributors.
// Use of this source code is governed by a MIT-style license that can be found
// in the LICENSE file.

import gpio
import i2c
import uart
import io

import nmea-message show *
import nmea-message.gnss-driver show *
import nmea-message.nmea-casic-message show *

/**
Print driver start message, and let the driver's own tasks run and
  simply display incoming messages.
*/

TX-PIN := gpio.Pin 7
RX-PIN := gpio.Pin 6
BAUD   := 9600
//BAUD   := 38400
//BAUD   := 115200

main:
  // Assemble parser.
  nmea-parser := NmeaParser
  print "Base NmeaMessage count:  $nmea-parser.registry.size"

  // Open serial communication and start driver.
  print "Opening on $BAUD"
  port := uart.Port --tx=TX-PIN --rx=RX-PIN --baud-rate=BAUD
  driver := Gnss-driver port.in port.out
  driver.add-parser #[0x24] (:: | r | nmea-parser.from-reader r)

  print "Driver started..."
