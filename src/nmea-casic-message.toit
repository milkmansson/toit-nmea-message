// Copyright (C) 2025 Toit contributors.
// Use of this source code is governed by a MIT-style license that can be found
// in the LICENSE file.

import .nmea-message

/**
CASIC GNSS priprietary NMEA message extension for the NMEA Parser.

CASIC receivers using the NMEA Protocol support proprietary NMEA messages,
  prefixed with 'P', in the form `$PCASxx`.

Support for the CASIC Standard Interface Protocol (CSIP) binary protocol is
  provided by a separate driver.  (See https://pkg.toit.io/.)
*/

class NmeaCasicParser:
  static MESSAGES/Map := {
  //  "P$Cas00.ID": :: | talker payload | Cas00.private_ payload,  // No messages of this type are emitted.
    "P$Cas01.ID": :: | talker payload | Cas01.private_ payload,
    "P$Cas02.ID": :: | talker payload | Cas02.private_ payload,
    "P$Cas03.ID": :: | talker payload | Cas03.private_ payload,
    "P$Cas04.ID": :: | talker payload | Cas04.private_ payload,
    "P$Cas05.ID": :: | talker payload | Cas05.private_ payload,
    "P$Cas06.ID": :: | talker payload | Cas06.private_ payload,
    "P$Cas10.ID": :: | talker payload | Cas10.private_ payload,
    //"P$Cas12.ID": :: | talker payload | Cas12.private_ payload,
    //"P$Cas15.ID": :: | talker payload | Cas15.private_ payload,
    //"P$Cas20.ID": :: | talker payload | Cas20.private_ payload,
    "P$Cas60.ID": :: | talker payload | Cas60.private_ payload,
  }

/**
CAS00: Save current configuration in flash.

Device will remember the configuration for as long as the on-board battery
  lasts.  (Configurationa and ephemeris data are both lost when the charge on
  the battery depletes.)  Configurations will save on the onboard flash if this
  message is sent to the device.
*/
class Cas00 extends NmeaMessage:
  static ID ::= "CAS00"

  constructor:
    super.private_ "P" ID ["P$ID"]

  // No Private constructor, no messages of this type are emitted.


/**
CAS02: Set Baud Rate.
*/
class Cas01 extends NmeaMessage:
  static ID ::= "CAS01"

  static BAUD-4800 ::= 0   // 4800 bps
  static BAUD-9600 ::= 1   // 9600 bps
  static BAUD-19200 ::= 2  // 19200 bps
  static BAUD-38400 ::= 3  // 38400 bps
  static BAUD-57600 ::= 4  // 57600 bps
  static BAUD-115200 ::= 5 // 115200 bps
  static BAUD-LOOKUP_ ::= {
    BAUD-4800: 4800,
    BAUD-9600: 9600,
    BAUD-19200: 19200,
    BAUD-38400: 38400,
    BAUD-57600: 57600,
    BAUD-115200: 115200,
  }

  // Baud rate list (Ascending order).
  static BAUDS_ ::= [4800, 9600, 19200, 38400, 57600, 115200]

  // Baud rate to device enum/lookup.
  static BAUD-CODE_ ::= {
    4800: BAUD-4800,
    9600: BAUD-9600,
    19200: BAUD-19200,
    38400: BAUD-38400,
    57600: BAUD-57600,
    115200: BAUD-115200,
  }

  constructor.set baudrate/int:
    nearest := nearest-baud_ baudrate
    if nearest != baudrate: print "Clamping baudrate to nearest: $nearest baud"
    super.private_ "P" ID ["P$ID", BAUD-CODE_[nearest]]

  /** Not expected - leaving here until test of this function. */
  constructor.private_ payload/List:
    super.private_  "P" ID payload

  /** Returns the nearest supported baud rate.  */
  static nearest-baud_ baud/int -> int:
    if baud <= BAUDS_[0]: return BAUDS_[0]
    if baud >= BAUDS_[BAUDS_.size - 1]: return BAUDS_[BAUDS_.size - 1]

    best/int := BAUDS_[0]
    best-diff/int := (baud - best).abs
    BAUDS_.do: | candidate |
      diff/int := (baud - candidate).abs
      if diff < best-diff:
        best = candidate
        best-diff = diff
    return best

  stringify -> string:
    return  "$super: baudrate:$BAUD-LOOKUP_[payload_[1]]"

/**
CAS02: Set positioning update rate.
*/
class Cas02 extends NmeaMessage:
  static ID ::= "CAS02"

  static OUTPUT-02HZ ::= 5000 // Update rate 0.2Hz, 1 message per 5 seconds.
  static OUTPUT-1HZ ::= 1000 // Update rate 1Hz, Output per second 1.
  static OUTPUT-2HZ ::= 500  // Update rate 2Hz, Output per second 2.
  static OUTPUT-4HZ ::= 250  // Update rate 4Hz, Output per second 4.
  static OUTPUT-5HZ ::= 200  // Update rate 5Hz, Output per second 5.
  static OUTPUT-10HZ ::= 100 // Update rate 10Hz, Output per second 10.
  static OUTPUT-RATE-LOOKUP_ ::= {
    OUTPUT-02HZ: 0.2,
    OUTPUT-1HZ: 1.0,
    OUTPUT-2HZ: 2.0,
    OUTPUT-4HZ: 4.0,
    OUTPUT-5HZ: 5.0,
    OUTPUT-10HZ: 10.0,
  }

  constructor.set rate/int:
    assert: OUTPUT-RATE-LOOKUP_.contains rate
    super.private_ "P" ID ["P$ID", rate]

  /** Not expected - leaving here until test of this function. */
  constructor.private_ payload/List:
    super.private_  "P" ID payload

  stringify -> string:
    return  "$super: rate:$OUTPUT-RATE-LOOKUP_[payload_[1]]"

/**
CAS03: Configures specific messages are output or not.

Values control how many iterations of the standard output timing (set in $Cas02)
  it takes before one of the configured sentence types are output. Some devices
  only support 0 and 1 (0 = disable, 1 = 1 message per cycle).  Other devices
  allow higher numbers allowing for fewer of specific message types to be sent.
  (0 = disable, 6 = 1 message per 6 cycles).  Additionally later softwares have
  additional fields.  (These are shown in the Toitdocs.)

Message type supports v3.6 or v4.2 specification. Simply specifying any of the
  v4.2 fields (DHV, LPS, UTC, GST, or TIM) will create the message in v4.2
  format.
*/
class Cas03 extends NmeaMessage:
  static ID ::= "CAS03"
  static PAYLOAD-SIZE-36_ ::= 9
  static PAYLOAD-SIZE-42_ ::= 19

  // Fields for v3.6 specification:
  static TYPE-GGA ::= 1
  static TYPE-GLL ::= 2
  static TYPE-GSA ::= 3
  static TYPE-GSV ::= 4
  static TYPE-RMC ::= 5
  static TYPE-VTG ::= 6
  static TYPE-ZDA ::= 7
  static TYPE-TXT ::= 8

  // Additional fields for v4.2 specification:
  static TYPE-DHV ::= 9
  static TYPE-LPS ::= 10
  static TYPE-UTC ::= 13
  static TYPE-GST ::= 14
  static TYPE-TIM ::= 18

  static TYPE-LOOKUP_ ::= {
    TYPE-GGA: "GGA",
    TYPE-GLL: "GLL",
    TYPE-GSA: "GSA",
    TYPE-GSV: "GSV",
    TYPE-RMC: "RMC",
    TYPE-VTG: "VTG",
    TYPE-ZDA: "ZDA",
    TYPE-TXT: "TXT",
    TYPE-DHV: "DHV",
    TYPE-LPS: "LPS",
    TYPE-UTC: "UTC",
    TYPE-GST: "GST",
    TYPE-TIM: "TIM",
  }

  constructor.set
      --gga/int?=null
      --gll/int?=null
      --gsa/int?=null
      --gsv/int?=null
      --rmc/int?=null
      --vtg/int?=null
      --zda/int?=null
      --txt/int?=null

      --dhv/int?=null
      --lps/int?=null
      --utc/int?=null
      --gst/int?=null
      --tim/int?=null:
    payload-size := dhv or lps or utc or gst or tim ? PAYLOAD-SIZE-42_ : PAYLOAD-SIZE-36_
    super.private_ "P" ID (List payload-size)
    payload_[0] = "P$ID"
    payload_[TYPE-GGA] = gga or ""
    payload_[TYPE-GLL] = gll or ""
    payload_[TYPE-GSA] = gsa or ""
    payload_[TYPE-GSV] = gsv or ""
    payload_[TYPE-RMC] = rmc or ""
    payload_[TYPE-VTG] = vtg or ""
    payload_[TYPE-ZDA] = zda or ""
    payload_[TYPE-TXT] = txt or ""

    if is-extended:
      payload_[TYPE-DHV] = dhv or ""
      payload_[TYPE-LPS] = lps or ""
      payload_[TYPE-UTC] = utc or ""
      payload_[TYPE-GST] = gst or ""
      payload_[TYPE-TIM] = tim or ""

  constructor.private_ payload/List:
    assert: payload.size == PAYLOAD-SIZE-36_ or payload.size == PAYLOAD-SIZE-42_
    super.private_  "P" ID payload

  gga-rate -> int: return payload_[TYPE-GGA]
  gll-rate -> int: return payload_[TYPE-GLL]
  gsa-rate -> int: return payload_[TYPE-GSA]
  gsv-rate -> int: return payload_[TYPE-GSV]
  rmc-rate -> int: return payload_[TYPE-RMC]
  vtg-rate -> int: return payload_[TYPE-VTG]
  zda-rate -> int: return payload_[TYPE-ZDA]
  ant-rate -> int: return payload_[TYPE-TXT]
  dhv-rate -> int?: return is-extended ? payload_[TYPE-DHV] : ""
  lps-rate -> int?: return is-extended ? payload_[TYPE-LPS] : ""
  utc-rate -> int?: return is-extended ? payload_[TYPE-UTC] : ""
  gst-rate -> int?: return is-extended ? payload_[TYPE-GST] : ""
  tim-rate -> int?: return is-extended ? payload_[TYPE-TIM] : ""

  is-extended -> bool:
    return payload_.size == PAYLOAD-SIZE-42_

  stringify -> string:
    out := List 0
    TYPE-LOOKUP_.keys.do: | key |
      if key < payload_.size:
        if (payload_[key] != ""):
          out.add "$TYPE-LOOKUP_[key]:$payload_[key])"
    return  "$super: enabled|$(out.join "|" )"

/**
CAS04: Set Mode.

The mask can be any combination of GPS/BDS/GLONASS OR'd together, for example,
  (GPS | BDS | GLONASS) which would be 7.
*/
class Cas04 extends NmeaMessage:
  static ID ::= "CAS04"

  static GPS     ::= 0b00001
  static BDS     ::= 0b00010
  static GLONASS ::= 0b00100
  static GALILEO ::= 0b01000
  static QZSS    ::= 0b10000
  static TYPE-LOOKUP_ ::= {
    GPS: "GPS",
    BDS: "BDS",
    GLONASS: "GLONASS",
    GALILEO: "Galileo",
    QZSS: "QZSS",
  }

  constructor.set --mask/int:
    assert: 0 <= mask <= 31
    super.private_ "P" ID ["P$ID", mask]

  /** Not expected - leaving here until test of this function. */
  constructor.private_ payload/List:
    super.private_  "P" ID payload

  is-gps-enabled -> bool:
    return (payload_[1] & GPS) != 0

  is-bds-enabled -> bool:
    return (payload_[1] & BDS) != 0

  is-glonass-enabled -> bool:
    return (payload_[1] & GLONASS) != 0

  stringify -> string:
    out-list := []
    TYPE-LOOKUP_.keys.do:
      if (payload_[1] & it) != 0:
        out-list.add TYPE-LOOKUP_[it]
    return  "$super: enabled:$(out-list.join ",")"


/**
CAS05: Protocol type selection.

There are many types of protocols for multi-mode navigation receivers, and the
data protocol standards are also more, this receiver product can support
multiple protocols (Optional). (Datasheet)

Values:
- $NMEA-41-STRICT: NMEA 4.1+ compatible output
- $MIXED-GNSS: BDS/GPS dual-mode, compatible with NMEA 2.3+/4.0 (default)
- $LEGACY-GPS-ONLY: GPS-only, compatible with NMEA 2.2
*/
class Cas05 extends NmeaMessage:
  static ID ::= "CAS05"

  static NMEA-41-STRICT ::= 2
  static MIXED-GNSS ::= 5
  static LEGACY-GPS-ONLY ::= 9
  static MODE-LOOKUP_ ::= {
    NMEA-41-STRICT: "NMEA 4.1 Strict",
    MIXED-GNSS: "Mixed GNSS",
    LEGACY-GPS-ONLY: "GPS Only",
  }

  constructor.set --mode/int:
    assert: MODE-LOOKUP_.contains mode
    super.private_ "P" ID ["P$ID", mode]

  /** Not expected - leaving here until test of this function. */
  constructor.private_ payload/List:
    super.private_  "P" ID payload

  stringify -> string:
    return  "$super: mode:$(MODE-LOOKUP_[payload_[1]])"


/**
PCAS06: Query information from the device.

Information values:
- $INFO-FIRMWARE: Query firmware version number
- $INFO-HARDWARE: Query hardware model and serial number
- $INFO-MODE: Query the working mode of the multimode receiver
- $INFO-CUSTOMER: Query the customer number of the product
- $INFO-CUSTOMER: Query upgrade code information
*/
class Cas06 extends NmeaMessage:
  static ID ::= "CAS06"

  static INFO-FIRMWARE ::= 0
  static INFO-HARDWARE ::= 1
  static INFO-MODE ::= 2
  static INFO-CUSTOMER ::= 3
  static INFO-UPGRADE-CODE ::= 5
  static INFO-LOOKUP_ ::= {
    INFO-FIRMWARE: "Firmware",
    INFO-HARDWARE: "Hardware",
    INFO-MODE: "Mode",
    INFO-CUSTOMER: "Customer",
    INFO-UPGRADE-CODE: "Upgrade",
  }

  constructor.poll --talker=NmeaParser.GPS:
    super.private_ talker ID ["$(talker)Q",ID]

  constructor.set info-type/int:
    assert: INFO-LOOKUP_.contains info-type
    super.private_ "P" ID ["P$ID", info-type]

  constructor.private_ payload/List:
    super.private_  "P" ID payload

  info-type -> int:
    return int.parse payload_[1]

  stringify -> string:
    return  "$super: info-type:$(INFO-LOOKUP_[info-type])"

/**
CAS10: Restarting the device.
*/
class Cas10 extends NmeaMessage:
  static ID ::= "CAS10"

  static START-HOT      ::= 0  // Use existing configuration in initialization.
  static START-WARM     ::= 1  // Clear the ephemeris without starting initialization.
  static START-COLD     ::= 2  // Start as if powered off.
  static START-FACTORY  ::= 3  // Clear all data in the memory and reset the receiver to the factory default.
  static DISABLE-SERIAL ::= 8  // Disable serial port output. (Opposite of $ENABLE-SERIAL)
  static ENABLE-SERIAL  ::= 9  // Enable serial output. (Opposite of $DISABLE-SERIAL)
  static START-LOOKUP_ ::= {
    START-HOT: "Hot Start",
    START-WARM: "Warm Start",
    START-COLD: "Cold Start",
    START-FACTORY: "Factory Reset",
    DISABLE-SERIAL: "Disable Serial",
    ENABLE-SERIAL: "Enable Serial",
  }

  constructor.set start-type/int:
    assert: START-LOOKUP_.contains start-type
    super.private_ "P" ID ["P$ID", start-type]

  /** Not expected - leaving here until test of this function. */
  constructor.private_ payload/List:
    super.private_  "P" ID payload

  start-type -> int:
    return int.parse payload_[1]

  stringify -> string:
    return  "$super: restart-type:$(START-LOOKUP_[start-type])"

/**
CAS12: Receiver Standby Mode Control.

"5L" low-power modules support this command.
*/
class Cas12 extends NmeaMessage:
  static ID ::= "CAS12"

  constructor.poll --seconds/int:
    assert: 0 < seconds <= 65535
    super.private_ "P" ID ["P$ID", "$seconds"]

  seconds -> int:
    return int.parse payload_[1]

  stringify -> string:
    return  "$super: standby-seconds:$(seconds)"

/**
CAS15: Enabling/Disabling specific satellites.

v5200 or later required.
*/

/**
CAS60: Receiver Time Information

v5302 or later required.
*/
class Cas60 extends NmeaMessage:
  static ID ::= "CAS60"

  /** Not expected - leaving here until test of this function. */
  constructor.private_ payload/List:
    super.private_ "P" ID payload

  time -> Time:
    return Time.utc
      --year=(int.parse (payload_[2][5..9]))
      --month=(int.parse (payload_[2][2..5]))
      --day=(int.parse (payload_[2][0..3]))
      --h=(int.parse (payload_[1])[0..2])
      --m=(int.parse (payload_[1])[2..4])
      --s=(int.parse (payload_[1])[4..6])
      --ms=(int.parse (payload_[1])[7..])

  /** GPS System week number. */
  week-number -> int:
    return int.parse payload_[3]

  /** GPS System seconds of week. */
  tow -> int:
    return int.parse payload_[4]

  /** Whether time, $week-number and $tow are valid time. */
  time-valid -> bool:
    return payload_[5] == "1"

  /** Difference between GPS time and UTC time, leap seconds. */
  leaps-number -> int:
    return int.parse payload_[6]

  /** Whether the leap seconds leaps are valid. */
  leaps-valid -> bool:
    return payload_[7] == "1"
