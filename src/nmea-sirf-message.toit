import io
import reader as old-reader
import .nmea-message

/**
Placeholder structure for SiRF vendor proprietary message types.
*/

class NmeaSrfParser:
  // Talker IDs:
  static PROPRIETARY ::= "P" // Proprietary type, sole supported in this library.

  // Message IDs:
  static PSRF151 ::= "PSRF151" // Position/navigation solution.
  static PSRF154 ::= "PSRF154" // Time/clock information.

  // Match Length:
  static MATCH-LENGTH ::= 8    // Match 8 chars to match these messages.

  static messages -> Map:
    message-map := {:}
    message-map[PSRF151] = (:: | talker id payload |
      Srf151.private_ PROPRIETARY id payload)
    message-map[PSRF154] = (:: | talker id payload |
      Srf154.private_ PROPRIETARY id payload)
    return message-map


/**
PSRF151: Navigation Parameters (Position/velocity/fix).
*/
class Srf151 extends NmeaMessage:
  static ID ::= NmeaSrfParser.PUBX00
  talker/string := "PSRF"

  constructor:
    super.private_ talker ID ["\$$talker","$ID"]

  /** Not expected - leaving here until test of this function. */
  constructor.private_ .talker/string id/string payload/List:
    super.private_  talker id payload


/**
PSRF154: Time & date information.
*/
class Srf154 extends NmeaMessage:
  static ID ::= NmeaSrfParser.PUBX04
  talker/string := "PSRF"

  constructor:
    super.private_ talker ID ["\$$talker","$ID"]

  /** Not expected - leaving here until test of this function. */
  constructor.private_ .talker/string id/string payload/List:
    super.private_  talker id payload
