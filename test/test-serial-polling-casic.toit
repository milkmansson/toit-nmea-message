// Copyright (C) 2025 Toit contributors.
// Use of this source code is governed by a MIT-style license that can be found
// in the LICENSE file.

import gpio
import uart

import .driver show *
import nmea-message show *
import nmea-message.nmea-casic-message show *

TX-PIN := gpio.Pin 7
RX-PIN := gpio.Pin 6
BAUD   := 9600
//BAUD   := 38400
//BAUD   := 115200

/*
Text output for the readme:

[nmea-driver] DEBUG: SEND  <- {message: $PCAS10,3*1F}
[nmea-driver] DEBUG: RECV  -> {message: NMEA-GP-TXT: Notice|MA=CASIC}
[nmea-driver] DEBUG: RECV  -> {message: NMEA-GP-TXT: Notice|IC=AT6558F-5N-32-1C580900}
[nmea-driver] DEBUG: RECV  -> {message: NMEA-GP-TXT: Notice|SW=URANUS5}
[nmea-driver] DEBUG: RECV  -> {message: NMEA-GP-TXT: Notice|TB=2020-03-26}
[nmea-driver] DEBUG: RECV  -> {message: NMEA-GP-TXT: Notice|MO=GB}

*/

main:
  // Assemble parser.
  nmea-parser := NmeaParser
  print "Base NmeaMessage count:  $nmea-parser.registry.size"

  // Add Casic elements to NMEA parser/registry.
  nmea-parser.add NmeaCasicParser.MESSAGES
  print "+Casic message count:    $nmea-parser.registry.size"

  // Open serial communication and start driver.
  print "Opening on $BAUD..."
  port := uart.Port --tx=TX-PIN --rx=RX-PIN --baud-rate=BAUD
  print "Starting driver..."
  driver := Driver port.in port.out nmea-parser
  print "Driver started..."

  print "Sending factory reset..."
  factory-reset := Cas10.set Cas10.START-FACTORY
  driver.send-message factory-reset
  sleep --ms=500

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
