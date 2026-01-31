// Copyright (C) 2025 Toit contributors.
// Use of this source code is governed by a MIT-style license that can be found
// in the LICENSE file.

import gpio
import i2c
import uart
import io

import .driver show *
import nmea-message show *
import nmea-message.nmea-casic-message show *

TX-PIN := gpio.Pin 7
RX-PIN := gpio.Pin 6
BAUD   := 9600
//BAUD   := 38400
//BAUD   := 115200

main:
  // Assemble parser.
  nmea-parser := NmeaParser
  print "Base NmeaMessage count:  $nmea-parser.message-count"

  // Add Casic elements to NMEA parser/registry.
  nmea-parser.add NmeaCasicParser.messages
  print "+Casic message count:    $nmea-parser.message-count"

  // Open serial communication and start driver.
  print "Opening on $BAUD"
  port := uart.Port --tx=TX-PIN --rx=RX-PIN --baud-rate=BAUD
  driver := Driver port.in port.out nmea-parser

  print "Driver started..."
  rate-message := Cas03.poll --rmc=1 --gsv=0

  driver.send-message rate-message
