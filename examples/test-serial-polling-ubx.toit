// Copyright (C) 2025 Toit contributors.
// Use of this source code is governed by a MIT-style license that can be found
// in the LICENSE file.

import gpio
import uart

import nmea-message show *
import nmea-message.gnss-driver show *
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

  // Add Ublox NMEA Message types to parser registry.
  nmea-parser.add NmeaUbxParser.MESSAGES
  print "+Ubx message count:    $nmea-parser.registry.size"

  // Open serial communication and start driver.
  print
  print "Opening on $BAUD..."
  port := uart.Port --tx=TX-PIN --rx=RX-PIN --baud-rate=BAUD
  print "Starting driver..."
  driver := Gnss-driver port.in port.out nmea-parser
  print "Driver started..."

  print
  print "Setting message noise to prove poll waits for correct message..."
  config-gsv := Ubx40.set "GSV" --uart1-rate=1
  driver.send-message config-gsv
  config-gsa := Ubx40.set "GSA" --uart1-rate=1
  driver.send-message config-gsa
  config-rmc := Ubx40.set "RMC" --uart1-rate=1
  driver.send-message config-rmc
  config-vtg := Ubx40.set "VTG" --uart1-rate=1
  driver.send-message config-vtg
  config-gll := Ubx40.set "GLL" --uart1-rate=1
  driver.send-message config-gll
  config-gga := Ubx40.set "GGA" --uart1-rate=1
  driver.send-message config-gga
  sleep --ms=2000

  print
  print "Sending Poll for \$PUBX,00: Navigation Information..."
  nav-info := Ubx00.poll
  nav-info-reply := driver.send-poll-message nav-info
  print nav-info-reply.to-string

  print
  print "Sending Poll for \$PUBX,03: Satellite Information..."
  satellite-info := Ubx03.poll
  satellite-info-reply := driver.send-poll-message satellite-info
  print satellite-info-reply.to-string

  print
  print "Sending Poll for \$PUBX,04: Time and Date..."
  time-date := Ubx04.poll
  time-date-reply := driver.send-poll-message time-date
  print time-date-reply.to-string

  print
  sleep --ms=5000

  print "Quieting message noise again..."
  config-gsv = Ubx40.set "GSV" --uart1-rate=0
  driver.send-message config-gsv
  config-gsa = Ubx40.set "GSA" --uart1-rate=0
  driver.send-message config-gsa
  config-rmc = Ubx40.set "RMC" --uart1-rate=0
  driver.send-message config-rmc
  config-vtg = Ubx40.set "VTG" --uart1-rate=0
  driver.send-message config-vtg
  config-gll = Ubx40.set "GLL" --uart1-rate=0
  driver.send-message config-gll
  config-gga = Ubx40.set "GGA" --uart1-rate=5
  driver.send-message config-gga
