// Copyright (C) 2025 Toit contributors.
// Use of this source code is governed by a MIT-style license that can be found
// in the LICENSE file.

import .nmea-message

/**
uBlox GNSS priprietary NMEA message extension for the NMEA Parser.

Ublox receivers using the NMEA Protocol support proprietary NMEA messages,
  prefixed with 'P', in the form `$PUBX,xx`.  Contrary to some other vendor
  messages, in uBlox messages, the first cell after the proprietary name is the
  message type identifier.

Support for the binary UBX protocol is given in a different driver.
*/

class NmeaUbxParser:
  static MESSAGES/Map := {
    Ubx00.ID: :: | talker id payload | Ubx00.private_ talker id payload,
    Ubx04.ID: :: | talker id payload | Ubx04.private_ talker id payload,
  }


/**
PUBX00: uBlox position/navigation solution.
*/
class Ubx00 extends NmeaMessage:
  static ID ::= "00"
  talker/string := "P"

  static STATUS-NO-FIX ::= "NF"
  static STATUS-DEAD-RECKONING ::= "DR"
  static STATUS-STANDALONE-2D ::= "G2"
  static STATUS-STANDALONE-3D ::= "G3"
  static STATUS-DIFFERENTIAL-2D ::= "D2"
  static STATUS-DIFFERENTIAL-3D ::= "D3"
  static STATUS-COMBINED-GPS-DR ::= "RK"
  static STATUS-TIME-ONLY ::= "TT"

  /** Message content asks the receiver for a UBX00 with data. */
  constructor.poll:
    super.private_ talker ID ["$(talker)UBX","$ID"]

  /** Not expected - leaving here until test of this function. */
  constructor.private_ .talker/string id/string payload/List:
    super.private_ talker id payload

  is-poll -> bool:
    return payload.size < 3

  /**
  Time for use as a comparative reference to other messages.

  Time misses date, and therefore is not absolute.  Use RMC or ZDA for this.
  */
  time -> Time:
    return Time.epoch
      --h=(int.parse (payload[2])[0..2])
      --m=(int.parse (payload[2])[2..4])
      --s=(int.parse (payload[2])[4..6])
      --ms=(int.parse (payload[2])[7..])

  latitude -> float:
    return float.parse payload[3]

  latitude-n -> string:
    return payload[4]

  longitude -> float:
    return float.parse payload[5]

  longitude-e -> string:
    return payload[6]

  altitude -> float:
    return float.parse payload[7]

  nav-status -> string:
    return payload[8]

  h-accuracy -> float:
    return float.parse payload[9]

  v-accuracy -> float:
    return float.parse payload[10]

  speed-over-ground -> float:
    return float.parse payload[11] --if-error=: 0.0

  course-over-ground -> float:
    return float.parse payload[12] --if-error=: 0.0

  vertical-velocity -> float:
    return float.parse payload[13] --if-error=: 0.0


  num-svs -> int:
    return int.parse payload[18] --if-error=: 0

  stringify -> string:
    if is-poll:
      return "$super: poll"
    return  "$super: "


/**
PUBX04: Time/clock information.

Gives information on precise time, logging, synchronization, and PPS alignment.
  It is much better than standard NMEA time fields in that it is both
  more accurate, and fully featured (clock validity, leap second data, etc).
*/
class Ubx04 extends NmeaMessage:
  static ID ::= "04"
  talker/string := "P"

  constructor:
    super.private_ talker ID ["$(talker)UBX","$ID"]

  /** Not expected - leaving here until test of this function. */
  constructor.private_ .talker/string id/string payload/List:
    super.private_  talker id payload


/**
PUBX40: RATE. Set NMEA message output rates etc.
*/
class Ubx40 extends NmeaMessage:
  static ID ::= "40"
  talker/string := "P"

  static FIELD-DDC_ ::= 3
  static FIELD-UART1_ ::= 4
  static FIELD-UART2_ ::= 5
  static FIELD-USB_ ::= 6
  static FIELD-SPI_ ::= 7
  static FIELD-LOOKUP_ ::= {
    FIELD-DDC_: "DDC",
    FIELD-UART1_: "UART1",
    FIELD-UART2_: "UART2",
    FIELD-USB_: "USB",
    FIELD-SPI_: "SPI"
  }

  constructor.set type/string
      --ddc-rate/int?=null
      --uart1-rate/int?=null
      --uart2-rate/int?=null
      --usb-rate/int?=null
      --spi-rate/int?=null:
    fields := List 9
    fields[0] = "$(talker)UBX"
    fields[1] = "$ID"
    fields[2] = "$type"
    fields[FIELD-DDC_] = ddc-rate ? ddc-rate : ""
    fields[FIELD-UART1_] = uart1-rate ? uart1-rate : ""
    fields[FIELD-UART2_] = uart2-rate ? uart2-rate : ""
    fields[FIELD-USB_] = usb-rate ? usb-rate : ""
    fields[FIELD-SPI_] = spi-rate ? spi-rate : ""
    fields[8] = "0"
    super.private_ talker ID fields

  /** Not expected - leaving here until test of this function. */
  constructor.private_ .talker/string id/string payload/List:
    super.private_  talker id payload

  type -> string:
    return payload[2]

  stringify -> string:
    list := []
    FIELD-LOOKUP_.keys.do:
      if payload[it] == 1: list += FIELD-LOOKUP_[it]
    return  "$super: msgid:$type|$(list.join ",")"
