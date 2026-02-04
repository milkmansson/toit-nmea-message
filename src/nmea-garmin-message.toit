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
    "P$Grmf.ID": :: | talker payload | Grmf.private_ payload,
    "P$Grme.ID": :: | talker payload | Grme.private_ payload,
  }

/**
GRMF:  Position/navigation solution.
*/
class Grmf extends NmeaMessage:
  static ID ::= "GRMF"

  constructor:
    super.private_ "P" ["P$ID"]

  /** Not expected - leaving here until test of this function. */
  constructor.private_ payload/List:
    super.private_  "P" payload

/**
GRME: Time/clock information.
*/
class Grme extends NmeaMessage:
  static ID ::= "GRME"

  constructor:
    super.private_ "P" ["P$ID"]

  /** Not expected - leaving here until test of this function. */
  constructor.private_ payload/List:
    super.private_  "P" payload
