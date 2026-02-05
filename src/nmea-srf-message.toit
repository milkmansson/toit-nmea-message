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
    "P$Srf151.ID": :: | talker payload | Srf151.private_ payload,
    "P$Srf154.ID": :: | talker payload | Srf154.private_ payload,
  }

/**
PSRF151: Navigation Parameters (Position/velocity/fix).
*/
class Srf151 extends NmeaMessage:
  static ID ::= "SRF151"

  constructor:
    super.private_ "P" ["P$ID"]

  constructor.private_ payload/List:
    super.private_  "P" payload


/**
PSRF154: Time & date information.
*/
class Srf154 extends NmeaMessage:
  static ID ::= "SRF154"

  constructor.private_ payload/List:
    super.private_  "P" payload


/**
PSRF105: Development Data on/off.

Enables development data information to troubleshoot commands being rejected.
  Invalid commands generate debug information that can be used to determine the
  source of the command rejection.
*/
class Srf105 extends NmeaMessage:
  static ID ::= "SRF154"

  constructor.set --on/bool=false:
    debug-value := on ? 1 : 0
    super.private_ "P" ["P$ID", debug-value]

  constructor.private_ payload/List:
    super.private_  "P" payload

  debug -> bool:
    return payload_[1] == 1

  stringify -> string:
    return  "$super: debug:$(debug)"
