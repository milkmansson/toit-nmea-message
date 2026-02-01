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
  static UBX00 ::= "UBX,00" // Position/navigation solution.
  static UBX04 ::= "UBX,04" // Time/clock information.

  static messages -> Map:
    message-map := {:}
    message-map[UBX00] = (:: | talker id payload |
      Ubx00.private_ PROPRIETARY id payload)
    message-map[UBX04] = (:: | talker id payload |
      Ubx04.private_ PROPRIETARY id payload)
    return message-map


/**
PUBX00: uBlox position/navigation solution.
*/
class Ubx00 extends NmeaMessage:
  static ID ::= NmeaUbxParser.UBX00
  talker/string := NmeaUbxParser.PROPRIETARY

  constructor:
    super.private_ talker ID ["$(talker)UBX","$ID"]

  /** Not expected - leaving here until test of this function. */
  constructor.private_ .talker/string id/string payload/List:
    super.private_  talker id payload


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
