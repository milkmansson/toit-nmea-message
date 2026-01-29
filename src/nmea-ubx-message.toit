import io
import reader as old-reader
import .nmea-message

/**
Placeholder structure for PUBX uBlox vendor proprietary message types.
*/

class NmeaUbxParser:
  // Talker IDs:
  static PROPRIETARY ::= "P" // Proprietary type, sole supported in this library.

  // Message IDs:
  static PUBX00 ::= "PUBX00" // Position/navigation solution.
  static PUBX04 ::= "PUBX04" // Time/clock information.

  // Match Length:
  static MATCH-LENGTH ::= 6    // Match 8 chars to match these messages.

  static messages -> Map:
    message-map := {:}
    message-map[PUBX00] = (:: | talker id payload |
      Pubx00.private_ PROPRIETARY id payload)
    message-map[PUBX04] = (:: | talker id payload |
      Pubx04.private_ PROPRIETARY id payload)
    return message-map


/**
PUBX00: uBlox position/navigation solution.
*/
class Pubx00 extends NmeaMessage:
  static ID ::= NmeaUbxParser.PUBX00
  talker/string := "PUBX"

  constructor:
    super.private_ talker ID ["\$$talker","$ID"]

  /** Not expected - leaving here until test of this function. */
  constructor.private_ .talker/string id/string payload/List:
    super.private_  talker id payload


/**
PUBX04: Time/clock information.

Gives information on precise time, logging, synchronization, and PPS alignment.
  It is much better than standard NMEA time fields in that it is both
  more accurate, and fully featured (clock validity, leap second data, etc).
*/
class Pubx04 extends NmeaMessage:
  static ID ::= NmeaUbxParser.PUBX04
  talker/string := "PUBX"

  constructor:
    super.private_ talker ID ["\$$talker","$ID"]

  /** Not expected - leaving here until test of this function. */
  constructor.private_ .talker/string id/string payload/List:
    super.private_  talker id payload
