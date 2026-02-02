// Copyright (C) 2025 Toit contributors.
// Use of this source code is governed by a MIT-style license that can be found
// in the LICENSE file.

import .nmea-message

/**
SiRF GNSS priprietary NMEA message extension for the NMEA Parser.

SiRF receivers using the NMEA Protocol support proprietary NMEA messages,
  prefixed with 'P', in the form `$PSRFxx`.
*/

class NmeaSrfParser:
  static MESSAGES/Map := {
    "P$Srf151.ID": :: | talker id payload | Srf151.private_ talker id payload,
    "P$Srf154.ID": :: | talker id payload | Srf154.private_ talker id payload,
  }

/**
PSRF151: Navigation Parameters (Position/velocity/fix).
*/
class Srf151 extends NmeaMessage:
  static ID ::= "SRF151"

  constructor:
    super.private_ "P" ID ["P$ID"]

  /** Not expected - leaving here until test of this function. */
  constructor.private_ talker/string id/string payload/List:
    // NOTE: SRF proprietary messages always use talker "P".
    super.private_  "P" ID payload


/**
PSRF154: Time & date information.
*/
class Srf154 extends NmeaMessage:
  static ID ::= "SRF154"

  constructor:
    super.private_ "P" ID ["P$ID"]

  /** Not expected - leaving here until test of this function. */
  constructor.private_ talker/string id/string payload/List:
    // NOTE: SRF proprietary messages always use talker "P".
    super.private_  "P" ID payload
