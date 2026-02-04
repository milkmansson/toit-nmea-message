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
    "P$Ubx00.ID": :: | talker payload | Ubx00.private_ payload,
    "P$Ubx03.ID": :: | talker payload | Ubx03.private_ payload,
    "P$Ubx04.ID": :: | talker payload | Ubx04.private_ payload,
  }


/**
PUBX00: uBlox position/navigation solution.
*/
class Ubx00 extends NmeaMessage:
  static ID ::= "UBX,00"

  static STATUS-NO-FIX ::= "NF"
  static STATUS-DEAD-RECKONING ::= "DR"
  static STATUS-STANDALONE-2D ::= "G2"
  static STATUS-STANDALONE-3D ::= "G3"
  static STATUS-DIFFERENTIAL-2D ::= "D2"
  static STATUS-DIFFERENTIAL-3D ::= "D3"
  static STATUS-COMBINED-GPS-DR ::= "RK"
  static STATUS-TIME-ONLY ::= "TT"
  static STATUS-LOOKUP_ ::= {
    STATUS-NO-FIX: "No Fix",
    STATUS-DEAD-RECKONING: "Dead Reckoning",
    STATUS-STANDALONE-2D: "Standalone 2D",
    STATUS-STANDALONE-3D: "Standalone 3D",
    STATUS-DIFFERENTIAL-2D: "Differential 2D",
    STATUS-DIFFERENTIAL-3D: "Differential 3D",
    STATUS-COMBINED-GPS-DR: "Combined GPS Dead Reckoning",
    STATUS-TIME-ONLY: "Time Only",
  }

  /** Message content asks the receiver for a UBX00 with data. */
  constructor.poll:
    super.private_ "P" ["PUBX","$ID"]

  /** Not expected - leaving here until test of this function. */
  constructor.private_ payload/List:
    super.private_ "P" payload

  is-poll -> bool:
    return payload_.size < 3

  /**
  Returns UTC timestamp of the message.

  It is provided in the message for use as a comparative reference to other
    messages.  The message does not contain the date, and therefore cannot be
    used to set the system time, or create a time object.  Use RMC, ZDA
    or PUBX,04 for this.
  */
  timestamp -> string?:
    if payload_[2] == "": return null
    return payload_[2]

  latitude -> float:
    return float.parse payload_[3]

  latitude-n -> string:
    return payload_[4]

  longitude -> float:
    return float.parse payload_[5]

  longitude-e -> string:
    return payload_[6]

  altitude -> float:
    return float.parse payload_[7]

  nav-status -> string:
    return payload_[8]

  h-accuracy -> float:
    return float.parse payload_[9]

  v-accuracy -> float:
    return float.parse payload_[10]

  speed-over-ground -> float:
    return float.parse payload_[11] --if-error=: 0.0

  course-over-ground -> float:
    return float.parse payload_[12] --if-error=: 0.0

  vertical-velocity -> float:
    return float.parse payload_[13] --if-error=: 0.0

  num-svs -> int:
    return int.parse payload_[18] --if-error=: 0

  stringify -> string:
    if is-poll:
      return "$super: poll"
    return  "$super: "


/**
PUBX03: Contains satellite status information.
*/
class Ubx03 extends NmeaMessage:
  static ID ::= "UBX,03"

  /** Message content asks the receiver for a UBX03 with data. */
  constructor.poll:
    super.private_ "P" ["PUBX","03"]

  constructor.private_ payload/List:
    super.private_ "P" payload

  is-poll -> bool:
    return payload_.size < 3

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
  static ID ::= "UBX,04"

  /** Not expected - leaving here until test of this function. */
  constructor.private_ payload/List:
    super.private_  "P" payload


/**
PUBX40: RATE. Set NMEA message output rates etc.
*/
class Ubx40 extends NmeaMessage:
  static ID ::= "UBX,40"

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
    fields[0] = "PUBX"
    fields[1] = "40"
    fields[2] = "$type"  // todo: put a guard on this to an NMEA type?
    fields[FIELD-DDC_] = ddc-rate ? ddc-rate : ""
    fields[FIELD-UART1_] = uart1-rate ? uart1-rate : ""
    fields[FIELD-UART2_] = uart2-rate ? uart2-rate : ""
    fields[FIELD-USB_] = usb-rate ? usb-rate : ""
    fields[FIELD-SPI_] = spi-rate ? spi-rate : ""
    fields[8] = "0"
    super.private_ "P" fields

  constructor.private_ payload/List:
    super.private_  "P" payload

  type -> string:
    return payload_[2]

  stringify -> string:
    list := []
    FIELD-LOOKUP_.keys.do:
      if payload_[it] == 1: list += FIELD-LOOKUP_[it]
    return  "$super: msgid:$type|$(list.join ",")"
