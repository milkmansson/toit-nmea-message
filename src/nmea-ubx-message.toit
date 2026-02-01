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
  // Talker IDs:
  static PROPRIETARY ::= "P" // Proprietary type, sole supported in this library.

  // Message IDs:
  static UBX00 ::= "00" // Position/navigation solution.
  static UBX04 ::= "04" // Time/clock information.
  static UBX40 ::= "40" // Time/clock information.

  static messages -> Map:
    message-map := {:}
    message-map[UBX00] = (:: | talker id payload |
      Ubx00.private_ PROPRIETARY id payload)
    message-map[UBX04] = (:: | talker id payload |
      Ubx04.private_ PROPRIETARY id payload)
    message-map[UBX40] = (:: | talker id payload |
      Ubx40.private_ PROPRIETARY id payload)
    return message-map


/**
PUBX00: uBlox position/navigation solution.
*/
class Ubx00 extends NmeaMessage:
  static ID ::= NmeaUbxParser.UBX00
  talker/string := NmeaUbxParser.PROPRIETARY

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
    super.private_  talker id payload

  is-poll -> bool:
    return payload.size < 3

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
  static ID ::= NmeaUbxParser.UBX04
  talker/string := NmeaUbxParser.PROPRIETARY

  constructor:
    super.private_ talker ID ["$(talker)UBX","$ID"]

  /** Not expected - leaving here until test of this function. */
  constructor.private_ .talker/string id/string payload/List:
    super.private_  talker id payload


/**
PUBX40: RATE. Set NMEA message output rates etc.
*/
class Ubx40 extends NmeaMessage:
  static ID ::= NmeaUbxParser.UBX40
  talker/string := NmeaUbxParser.PROPRIETARY

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
