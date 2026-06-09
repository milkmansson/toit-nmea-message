// Copyright (C) 2025 Toit contributors.
// Use of this source code is governed by a MIT-style license that can be found
// in the LICENSE file.

import gpio
import uart

import .driver show *
import nmea-message show *
import nmea-message.nmea-casic-message show *

import ema show *
import esp32

TX-PIN := gpio.Pin 7
RX-PIN := gpio.Pin 6
BAUD   := 9600
//BAUD   := 38400
//BAUD   := 115200

/*
This test is to use get time packets out of a CASIC device, and then attempt to
  set and keep the system time updated.
*/

ema/Ema := ?
ema-alpha := 0.842

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

  // Send factory reset in case some other code has been run without power cycle
  print "Sending factory reset..."
  factory-reset := Cas10.set Cas10.START-FACTORY
  driver.send-message factory-reset
  sleep --ms=500

  // Leave one going to know that the device is still there...
  print "Stopping message noise, enabling only clock (ZDA) @1Hz..."
  types-message := Cas03.set --rmc=0 --gsv=0 --gsa=0 --vtg=0 --zda=1 --txt=0 --gll=0 --gga=0
  driver.send-message types-message
  sleep --ms=250

  print "Sending output rate poll..."
  rate-message := Cas02.set Cas02.OUTPUT-1HZ
  driver.send-message rate-message
  sleep --ms=250

  print "Sending Baud Increase..."
  baud-rate := Cas01.set 115200
  driver.send-message baud-rate
  sleep --ms=250
  port.baud-rate = 115200
  sleep --ms=250

  print "Set up EMA"
  ema = Ema ema-alpha

  print "Register lambda for ZDA Message type"
  driver.register-message-lambda "ZDA" :: | message | do-it message



do-it message -> none:
  offset := Duration.ZERO
  correction := Duration.ZERO

  if message.system-time-offset:
    offset = message.system-time-offset
    ema.add message.system-time-offset.in-us
  if ema.average:
    print "- $(Time.now)  - $(Duration --us=ema.average.to-int)"
    //print "- $message.raw"

  if ema.samples % 15 == 0:
    correction = Duration --us=ema.average.to-int
    if correction.abs > (Duration --ms=250):
      ema.reset
      ema.set-alpha 0.602
      print
      print "CORRECTION: $correction"
      esp32.adjust_real_time_clock correction
