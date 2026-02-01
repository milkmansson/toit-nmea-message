import .nmea-message

/**
Garmin GNSS priprietary NMEA message extension for the NMEA Parser.

Garmin receivers using the NMEA Protocol support proprietary NMEA messages,
  prefixed with 'P', in the form `$PGRMxx`.  Aadditonal letters are added to
  identify the message type.
*/

class NmeaGarminParser:
  // Talker IDs:
  static PROPRIETARY ::= "P" // Proprietary type, sole supported in this library.

  // Message IDs:
  static GRMF ::= "GRMF" // Position/navigation solution.
  static GRME ::= "GRME" // Time/clock information.

  static messages -> Map:
    message-map := {:}
    message-map[GRMF] = (:: | talker id payload |
      Grmf.private_ PROPRIETARY id payload)
    message-map[GRME] = (:: | talker id payload |
      Grme.private_ PROPRIETARY id payload)
    return message-map


/**
GRMF:  Position/navigation solution.
*/
class Grmf extends NmeaMessage:
  static ID ::= NmeaGarminParser.GRMF
  talker/string := NmeaGarminParser.PROPRIETARY

  constructor:
    super.private_ talker ID ["$talker$ID"]

  /** Not expected - leaving here until test of this function. */
  constructor.private_ .talker/string id/string payload/List:
    super.private_  talker id payload


/**
GRME: Time/clock information.
*/
class Grme extends NmeaMessage:
  static ID ::= NmeaGarminParser.GRME
  talker/string := NmeaGarminParser.PROPRIETARY

  constructor:
    super.private_ talker ID ["$talker$ID"]

  /** Not expected - leaving here until test of this function. */
  constructor.private_ .talker/string id/string payload/List:
    super.private_  talker id payload
