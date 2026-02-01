import .nmea-message

/**
CASIC GNSS priprietary NMEA message extension for the NMEA Parser.

CASIC receivers using the NMEA Protocol support proprietary NMEA messages,
  prefixed with 'P', in the form `$PCASxx`.

Support for the CASIC Standard Interface Protocol (CSIP) binary protocol is
  provided by a separate driver.  (See https://pkg.toit.io/.)
*/

class NmeaCasicParser:
  // Talker IDs:
  static PROPRIETARY ::= "P" // Proprietary type, sole supported in this library.

  // Message IDs:
  static CAS00 ::= "CAS00" // Save config to flash.
  static CAS01 ::= "CAS01" // Baud Rate.
  static CAS02 ::= "CAS02" // Fix Rate.
  static CAS03 ::= "CAS03" // Sentence Types.
  static CAS04 ::= "CAS04" // Constellations.
  static CAS05 ::= "CAS05" // NMEA protocol type selection.
  static CAS06 ::= "CAS06" // Query module type information.
  static CAS10 ::= "CAS10" // Self restart.
  static CAS12 ::= "CAS12" // Low power mode.
  static CAS15 ::= "CAS15" // Satellite Types.
  static CAS20 ::= "CAS20" // Online upgrade.
  static CAS60 ::= "CAS60" // Time Information.

  static messages -> Map:
    message-map := {:}
    message-map[CAS00] = (:: | talker id payload |
      Cas00.private_ PROPRIETARY id payload)
    message-map[CAS01] = (:: | talker id payload |
      Cas01.private_ PROPRIETARY id payload)
    message-map[CAS02] = (:: | talker id payload |
      Cas02.private_ PROPRIETARY id payload)
    message-map[CAS03] = (:: | talker id payload |
      Cas03.private_ PROPRIETARY id payload)
    message-map[CAS04] = (:: | talker id payload |
      Cas04.private_ PROPRIETARY id payload)
    message-map[CAS05] = (:: | talker id payload |
      Cas05.private_ PROPRIETARY id payload)
    message-map[CAS06] = (:: | talker id payload |
      Cas06.private_ PROPRIETARY id payload)
    message-map[CAS10] = (:: | talker id payload |
      Cas10.private_ PROPRIETARY id payload)
//    message-map[CAS12] = (:: | talker id payload |
//      Cas12.private_ PROPRIETARY id payload)
//    message-map[CAS15] = (:: | talker id payload |
//      Cas15.private_ PROPRIETARY id payload)
//    message-map[CAS20] = (:: | talker id payload |
//      Cas20.private_ PROPRIETARY id payload)
    message-map[CAS60] = (:: | talker id payload |
      Cas60.private_ PROPRIETARY id payload)
    return message-map

/**
CAS00: Save current configuration in flash.
*/
class Cas00 extends NmeaMessage:
  static ID ::= NmeaCasicParser.CAS00
  talker/string := "P"

  constructor:
    super.private_ talker ID ["$talker$ID"]

  /** Not expected - leaving here until test of this function. */
  constructor.private_ .talker/string id/string payload/List:
    super.private_  talker id payload

/**
CAS02: Set Baud Rate.
*/
class Cas01 extends NmeaMessage:
  static ID ::= NmeaCasicParser.CAS01
  talker/string := "P"

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
    BAUD-115200: 115200 }

  constructor.set baudrate/int:
    assert: BAUD-LOOKUP_.contains baudrate
    super.private_ talker ID ["$talker$ID", baudrate]

  /** Not expected - leaving here until test of this function. */
  constructor.private_ .talker/string id/string payload/List:
    super.private_  talker id payload

/**
CAS02: Set positioning update rate.
*/
class Cas02 extends NmeaMessage:
  static ID ::= NmeaCasicParser.CAS02
  talker/string := "P"

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
    OUTPUT-10HZ: 10.0}

  constructor.set rate/int:
    assert: OUTPUT-RATE-LOOKUP_.contains rate
    super.private_ talker ID ["$talker$ID", rate]

  /** Not expected - leaving here until test of this function. */
  constructor.private_ .talker/string id/string payload/List:
    super.private_  talker id payload

  stringify -> string:
    return  "$super: rate:$OUTPUT-RATE-LOOKUP_[payload[1]]"

/**
CAS03: Configures specific messages are output or not.

Values set against the sentence types control how many ticks of Cas02 happen for
  each message type to be output.

Some devices only support 0 and 1 (0 = disable).  Other devices allow higher
  numbers allowing for fewer of specific message types to be sent.  Additionally
  later softwares have additional fields.  (These are shown in the Toitdocs.)

Message type supports v3.6 or v4.2 specification. Simply specifying any of the
  v4.2 fields (DHV, LPS, UTC, GST, or TIM) will create the message in v4.2
  format.
*/
class Cas03 extends NmeaMessage:
  static ID ::= NmeaCasicParser.CAS03
  static PAYLOAD-SIZE_ ::= 9
  static PAYLOAD-SIZE-EXTENDED_ ::= 19
  talker/string := "P"

  // Fields for v3.6 specification
  static TYPE-GGA ::= 1
  static TYPE-GLL ::= 2
  static TYPE-GSA ::= 3
  static TYPE-GSV ::= 4
  static TYPE-RMC ::= 5
  static TYPE-VTG ::= 6
  static TYPE-ZDA ::= 7
  static TYPE-TXT ::= 8

  // Additional fields for v4.2 specification
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
    payload-size := PAYLOAD-SIZE_
    if dhv or lps or utc or gst or tim:
      payload-size = PAYLOAD-SIZE-EXTENDED_
    super.private_ talker ID (List payload-size)
    payload[0] = "$talker$ID"
    payload[TYPE-GGA] = gga ? gga : ""
    payload[TYPE-GLL] = gll ? gll : ""
    payload[TYPE-GSA] = gsa ? gsa : ""
    payload[TYPE-GSV] = gsv ? gsv : ""
    payload[TYPE-RMC] = rmc ? rmc : ""
    payload[TYPE-VTG] = vtg ? vtg : ""
    payload[TYPE-ZDA] = zda ? zda : ""
    payload[TYPE-TXT] = txt ? txt : ""

    if payload.size == PAYLOAD-SIZE-EXTENDED_:
      payload[TYPE-DHV] = dhv ? dhv : ""
      payload[TYPE-LPS] = lps ? lps : ""
      payload[TYPE-UTC] = utc ? utc : ""
      payload[TYPE-GST] = gst ? gst : ""
      payload[TYPE-TIM] = tim ? tim : ""

  constructor.private_ .talker/string id/string payload/List:
    assert: payload.size == PAYLOAD-SIZE_ or payload.size == PAYLOAD-SIZE-EXTENDED_
    super.private_  talker id payload

  gga-rate -> int: return payload[TYPE-GGA]
  gll-rate -> int: return payload[TYPE-GLL]
  gsa-rate -> int: return payload[TYPE-GSA]
  gsv-rate -> int: return payload[TYPE-GSV]
  rmc-rate -> int: return payload[TYPE-RMC]
  vtg-rate -> int: return payload[TYPE-VTG]
  zda-rate -> int: return payload[TYPE-ZDA]
  ant-rate -> int: return payload[TYPE-TXT]
  dhv-rate -> int?: return is-extended ? payload[TYPE-DHV] : ""
  lps-rate -> int?: return is-extended ? payload[TYPE-LPS] : ""
  utc-rate -> int?: return is-extended ? payload[TYPE-UTC] : ""
  gst-rate -> int?: return is-extended ? payload[TYPE-GST] : ""
  tim-rate -> int?: return is-extended ? payload[TYPE-TIM] : ""

  is-extended -> bool:
    return payload.size == PAYLOAD-SIZE-EXTENDED_

  stringify -> string:
    out := List 0
    TYPE-LOOKUP_.keys.do: | key |
      if key < payload.size:
        if (payload[key] != ""):
          out.add "$TYPE-LOOKUP_[key]:$payload[key])"
    return  "$super: enabled|$(out.join "|" )"

/**
CAS04: Set Mode.

The mask can be any combination of GPS/BDS/GLONASS OR'd together, for example,
  (GPS | BDS | GLONASS) which would be 7.
*/
class Cas04 extends NmeaMessage:
  static ID ::= NmeaCasicParser.CAS04
  talker/string := "P"

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
    QZSS: "QZSS"
    }

  constructor.set --mask/int:
    assert: 0 <= mask <= 31
    super.private_ talker ID ["$talker$ID", mask]

  /** Not expected - leaving here until test of this function. */
  constructor.private_ .talker/string id/string payload/List:
    super.private_  talker id payload

  is-gps-enabled -> bool:
    return (payload[1] & GPS) != 0

  is-bds-enabled -> bool:
    return (payload[1] & BDS) != 0

  is-glonass-enabled -> bool:
    return (payload[1] & GLONASS) != 0

  stringify -> string:
    out-list := []
    TYPE-LOOKUP_.keys.do:
      if (payload[1] & it) != 0:
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
  static ID ::= NmeaCasicParser.CAS05
  talker/string := "P"

  static NMEA-41-STRICT ::= 2
  static MIXED-GNSS ::= 5
  static LEGACY-GPS-ONLY ::= 9
  static MODE-LOOKUP_ ::= {
    NMEA-41-STRICT: "NMEA 4.1 Strict",
    MIXED-GNSS: "Mixed GNSS",
    LEGACY-GPS-ONLY: "GPS Only"
    }

  constructor.set --mode/int:
    assert: MODE-LOOKUP_.contains mode
    super.private_ talker ID ["$talker$ID", mode]

  /** Not expected - leaving here until test of this function. */
  constructor.private_ .talker/string id/string payload/List:
    super.private_  talker id payload

  stringify -> string:
    return  "$super: mode:$(MODE-LOOKUP_[payload[1]])"


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
  static ID ::= NmeaCasicParser.CAS06
  talker/string := "P"

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
    INFO-UPGRADE-CODE: "Upgrade"}

  constructor.poll:
    talker = NmeaParser.GPS
    msgid := NmeaParser.QUERY
    super.private_  talker msgid ["$talker$msgid",ID]

  constructor.set info-type/int:
    assert: INFO-LOOKUP_.contains info-type
    super.private_ talker ID ["$talker$ID", info-type]

  /** Not expected - leaving here until test of this function. */
  constructor.private_ .talker/string id/string payload/List:
    super.private_  talker id payload

  info-type -> int:
    return int.parse payload[1]

  stringify -> string:
    return  "$super: info-type:$(INFO-LOOKUP_[info-type])"

/**
CAS10: Restarting the device.
*/
class Cas10 extends NmeaMessage:
  static ID ::= NmeaCasicParser.CAS10
  talker/string := "P"

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
    ENABLE-SERIAL: "Enable Serial"}

  constructor.set start-type/int:
    assert: START-LOOKUP_.contains start-type
    super.private_ talker ID ["$talker$ID", start-type]

  /** Not expected - leaving here until test of this function. */
  constructor.private_ .talker/string id/string payload/List:
    super.private_  talker id payload

  start-type -> int:
    return int.parse payload[1]

  stringify -> string:
    return  "$super: restart-type:$(START-LOOKUP_[start-type])"

/**
CAS12: Receiver Standby Mode Control.

"5L" low-power modules support this command.
*/
class Cas12 extends NmeaMessage:
  static ID ::= NmeaCasicParser.CAS12
  talker/string := "P"

  constructor.poll --seconds/int:
    assert: 0 < seconds <= 65535
    super.private_ talker ID ["$talker$ID", "$seconds"]

  seconds -> int:
    return int.parse payload[1]

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
  static ID ::= NmeaCasicParser.CAS60
  talker/string := "P"

  constructor.private_ .talker/string id/string payload/List:
    super.private_  talker id payload

  time -> Time:
    return Time.utc
      --year=(int.parse (payload[2][5..9]))
      --month=(int.parse (payload[2][2..5]))
      --day=(int.parse (payload[2][0..3]))
      --h=(int.parse (payload[1])[0..2])
      --m=(int.parse (payload[1])[2..4])
      --s=(int.parse (payload[1])[4..6])
      --ms=(int.parse (payload[1])[7..])

  /** GPS System week number. */
  week-number -> int:
    return int.parse payload[3]

  /** GPS System seconds of week. */
  tow -> int:
    return int.parse payload[4]

  /** If time, $week-number and $tow are valid time. */
  time-valid -> bool:
    return payload[5] == "1"

  /** Difference between GPS time and UTC time, leap seconds. */
  leaps-number -> int:
    return int.parse payload[6]

  /** If the leap seconds leaps are valid. */
  leaps-valid -> bool:
    return payload[7] == "1"
