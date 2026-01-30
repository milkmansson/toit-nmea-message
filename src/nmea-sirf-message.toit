import .nmea-message

/**
SiRF GNSS priprietary NMEA message extension for the NMEA Parser.

SiRF receivers using the NMEA Protocol support proprietary NMEA messages,
  prefixed with 'P', in the form `$PSRF,xx`.  Contrary to some other vendor
  messages, the first cell after the proprietary name is the message type
  identifier.
*/

class NmeaSrfParser:
  // Talker IDs:
  static PROPRIETARY ::= "P" // Proprietary type, sole supported in this library.

  // Message IDs:
  static SRF151 ::= "SRF,151" // Position/navigation solution.
  static SRF154 ::= "SRF,154" // Time/clock information.

  static messages -> Map:
    message-map := {:}
    message-map[SRF151] = (:: | talker id payload |
      Srf151.private_ PROPRIETARY id payload)
    message-map[SRF154] = (:: | talker id payload |
      Srf154.private_ PROPRIETARY id payload)
    return message-map


/**
PSRF151: Navigation Parameters (Position/velocity/fix).
*/
class Srf151 extends NmeaMessage:
  static ID ::= NmeaSrfParser.SRF151
  talker/string := NmeaSrfParser.PROPRIETARY

  constructor:
    super.private_ talker ID ["\$P$talker","$ID"]

  /** Not expected - leaving here until test of this function. */
  constructor.private_ .talker/string id/string payload/List:
    super.private_  talker id payload


/**
PSRF154: Time & date information.
*/
class Srf154 extends NmeaMessage:
  static ID ::= NmeaSrfParser.SRF154
  talker/string := NmeaSrfParser.PROPRIETARY

  constructor:
    super.private_ talker ID ["\$P$talker","$ID"]

  /** Not expected - leaving here until test of this function. */
  constructor.private_ .talker/string id/string payload/List:
    super.private_  talker id payload
