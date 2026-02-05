// Copyright (C) 2025 Toit contributors.
// Use of this source code is governed by a MIT-style license that can be found
// in the LICENSE file.

import gpio
import uart

import .driver show *
import nmea-message show *
import nmea-message.nmea-ubx-message show *

TX-PIN := gpio.Pin 6
RX-PIN := gpio.Pin 7
BAUD   := 9600
//BAUD   := 38400
//BAUD   := 115200

main:
  // Assemble parser.
  nmea-parser := NmeaParser
  print "Base NmeaMessage count:  $nmea-parser.registry.size"

  // Add Casic elements to NMEA parser/registry.
  nmea-parser.add NmeaUbxParser.MESSAGES
  print "+Ubx message count:    $nmea-parser.registry.size"

  // Open serial communication and start driver.
  print "Opening on $BAUD..."
  port := uart.Port --tx=TX-PIN --rx=RX-PIN --baud-rate=BAUD
  print "Starting driver..."
  driver := Driver port.in port.out nmea-parser
  print "Driver started..."

  print "Stopping message noise... (1xGGA / 10sec)"
  disable-gsv := Ubx40.set "GSV" --uart1-rate=0
  driver.send-message disable-gsv
  disable-gsa := Ubx40.set "GSA" --uart1-rate=0
  driver.send-message disable-gsa
  disable-rmc := Ubx40.set "RMC" --uart1-rate=0
  driver.send-message disable-rmc
  disable-vtg := Ubx40.set "VTG" --uart1-rate=0
  driver.send-message disable-vtg
  disable-gll := Ubx40.set "GLL" --uart1-rate=0
  driver.send-message disable-gll
  disable-gga := Ubx40.set "GGA" --uart1-rate=10
  driver.send-message disable-gga


  print "Sending Poll for \$PUBX,00: Navigation Information..."
  nav-info := Ubx00.poll
  driver.send-message nav-info

  print "Sending Poll for \$PUBX,03: Satellite Information..."
  satellite-info := Ubx03.poll
  driver.send-message satellite-info

  print "Sending Poll for \$PUBX,04: Time and Date..."
  time-date := Ubx04.poll
  driver.send-message time-date
