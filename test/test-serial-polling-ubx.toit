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

  /*
  // Leave one going to know that the device is still there...
  print "Stopping message noise..."
  types-message := Cas03.set --rmc=9 --gsv=0 --gsa=0 --vtg=0 --zda=0 --txt=0 --gll=0 --gga=0
  driver.send-message types-message
  sleep --ms=250

  print "Sending output rate poll..."
  rate-message := Cas02.set Cas02.OUTPUT-1HZ
  driver.send-message rate-message
  sleep --ms=250

  print "Sending Firmware poll..."
  info-firmware-message := Cas06.set Cas06.INFO-FIRMWARE
  driver.send-message info-firmware-message
  sleep --ms=250

  print "Sending hardware poll..."
  info-hardware-message := Cas06.set Cas06.INFO-HARDWARE
  driver.send-message info-hardware-message
  sleep --ms=250

  print "Sending mode poll..."
  info-mode-message := Cas06.set Cas06.INFO-MODE
  driver.send-message info-mode-message
  sleep --ms=250

  print "Sending customer information poll..."
  info-customer-message := Cas06.set Cas06.INFO-CUSTOMER
  driver.send-message info-customer-message
  sleep --ms=250

  print "Sending upgrade code poll..."
  info-upgrade-message := Cas06.set Cas06.INFO-UPGRADE-CODE
  driver.send-message info-upgrade-message
  sleep --ms=250


  //  poll := Cas06.poll
  //  driver.send-message poll

  //  gga-poll := Gga.poll
  //  driver.send-message gga-poll

  */
