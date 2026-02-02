// Copyright (C) 2025 Toit contributors.
// Use of this source code is governed by a MIT-style license that can be found
// in the LICENSE file.

import .nmea-message

/**
Garmin GNSS priprietary NMEA message extension for the NMEA Parser.

Garmin receivers using the NMEA Protocol support proprietary NMEA messages,
  prefixed with 'P', in the form `$PGRMxx`.  Additonal numbers are added to
  identify the message type.
*/

class NmeaGarminParser:
  static MESSAGES/Map := {
    "P$Grmf.ID": :: | talker id payload | Grmf.private_ talker id payload,
    "P$Grme.ID": :: | talker id payload | Grme.private_ talker id payload,
  }

/**
GRMF:  Position/navigation solution.
*/
class Grmf extends NmeaMessage:
  static ID ::= "GRMF"
  talker/string := "P"

  constructor:
    super.private_ talker ID ["$talker$ID"]

  /** Not expected - leaving here until test of this function. */
  constructor.private_ .talker/string id/string payload/List:
    super.private_  talker id payload

/**
GRME: Time/clock information.
*/
class Grme extends NmeaMessage:
  static ID ::= "GRME"
  talker/string := "P"

  constructor:
    super.private_ talker ID ["$talker$ID"]

  /** Not expected - leaving here until test of this function. */
  constructor.private_ .talker/string id/string payload/List:
    super.private_  talker id payload
