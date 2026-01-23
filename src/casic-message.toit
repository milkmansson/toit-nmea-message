import io
import io show LITTLE-ENDIAN
import reader as old-reader

/**
CASIC GNSS priprietary NMEA message Parser.

CASIC receivers using the NMEA Protocol can support proprietary NMEA messages,
  for example PCASxx.

Support for the binary CASIC Standard Interface Protocol (CSIP) is provided by
  a separate driver.  (See https://pkg.toit.io/.)
*/

class Casic-message:
  static MAX-MESSAGE-SIZE_ ::= 82
  static NMEA-MAGIC-BYTE_ ::= 0x24  // $ Character.
  static INVALID-CASIC-MESSAGE_ ::= "INVALID CASIC MESSAGE"
  static DELIMITER_/string ::= ","
  static CHECKSUM-DELIMITER_/string ::= "*"

  talker/string := "P"
  id/string := ?
  payload/List := ?

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

  constructor talker/string id/string payload/List:
    if id == Casic-message.CAS03:
      return Cas03.private_ talker id payload
    else:
      print "CASIC: sentence type not known to driver: [$talker] [$id]"
      unreachable

  constructor.private_ .talker/string .id/string .payload/List:

  constructor.from-reader reader/old-reader.Reader:
    io-reader/io.Reader := reader is io.Reader ? reader as io.Reader : io.Reader.adapt reader

    if (io-reader.peek-byte 0) != NMEA-MAGIC-BYTE_:
      throw INVALID-CASIC-MESSAGE_

    // Get full the packet (no size information provided) and verify length limits.
    // Perhaps switch to .read-string --max-size for security?
    sentence/string ::= io-reader.read-line

    if not sentence.contains-only-ascii:
      throw INVALID-CASIC-MESSAGE_

    if not is-valid-sentence_ sentence:
      throw INVALID-CASIC-MESSAGE_

    first-comma/int := sentence.index-of DELIMITER_
    if first-comma < 4 or first-comma == -1 :
      throw INVALID-CASIC-MESSAGE_

    type/string := sentence[1..first-comma]

    // Remove delimiter
    data := sentence
    cs-delimiter := sentence.index-of CHECKSUM-DELIMITER_ --last
    if cs-delimiter != -1:
      data = sentence[..cs-delimiter]

    // First: Proprietary type
    if type[0] == 'P':
      return Casic-message "P" type[1..] (data.split DELIMITER_)

    // Second: First two characters are talker
    return Casic-message type[0..2] type[2..] (data.split DELIMITER_)

  static is-valid-sentence_ sentence/string -> bool:
    // Check the payload length.
    if not 0 <= sentence.size <= MAX-MESSAGE-SIZE_:
      return false
      //throw "$INVALID-NMEA-MESSAGE_: invalid size"

    // Check checksum.
    cs-delimiter := sentence.index-of CHECKSUM-DELIMITER_ --last
    if cs-delimiter == -1 :
      // checksum missing (allowed in spec)
      return true

    message := sentence[1..cs-delimiter]
    checksum := int.parse (sentence[(cs-delimiter+1)..])  --radix=16

    if (compute-checksum_ message) != checksum:
      return false
    return true
  /**
  Checksum is XOR of all characters between $ and * (exclusive).
  */
  static compute-checksum_ data/string -> int:
    checksum := 0
    data.do: | next |
      checksum ^= next
    return checksum

  /** The message type name in full format. */
  full-name -> string:
    return "CASIC-$talker-$id"

  /** Is this message multipart? */
  is-multipart -> bool:
    return false

  message-part -> List:
    return [1, 1]

  /** See $super. */
  stringify -> string:
    return full-name

  /**
  Used by the driver when sending the message to the device.
  */
  to-string -> string:
    outstring := payload.join ","
    checksum := Casic-message.compute-checksum_ outstring
    return "$outstring*$checksum"

/**
CAS00: Save current configuration in flash.
*/
class Cas00 extends Casic-message:
  static ID ::= Casic-message.CAS00
  talker/string := "P"

  constructor:
    super.private_ talker ID ["\$$talker$ID"]

  /** Not expected - leaving here until test of this function. */
  constructor.private_ .talker/string id/string payload/List:
    super.private_  talker id payload

/**
CAS02: Set Baud Rate.
*/
class Cas01 extends Casic-message:
  static ID ::= Casic-message.CAS01
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

  constructor --baudrate/int:
    assert: BAUD-LOOKUP_.contains baudrate
    super.private_ talker ID ["\$$talker$ID", baudrate]

  /** Not expected - leaving here until test of this function. */
  constructor.private_ .talker/string id/string payload/List:
    super.private_  talker id payload

/**
CAS02: Set positioning update rate.
*/
class Cas02 extends Casic-message:
  static ID ::= Casic-message.CAS02
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

  constructor rate/int:
    assert: OUTPUT-RATE-LOOKUP_.contains rate
    super.private_ talker ID ["\$$talker$ID", rate]

  /** Not expected - leaving here until test of this function. */
  constructor.private_ .talker/string id/string payload/List:
    super.private_  talker id payload

  stringify -> string:
    return  "$super: rate:$OUTPUT-RATE-LOOKUP_[payload[1]]"

/**
CAS03: Set positioning update rate.
*/
class Cas03 extends Casic-message:
  static ID ::= Casic-message.CAS03
  static PAYLOAD-SIZE_ ::= 9
  talker/string := "P"

  static TYPE-GGA ::= 1
  static TYPE-GLL ::= 2
  static TYPE-GSA ::= 3
  static TYPE-GSV ::= 4
  static TYPE-RMC ::= 5
  static TYPE-VTG ::= 6
  static TYPE-ZDA ::= 7
  static TYPE-TXT ::= 8
  static TYPE-LOOKUP_ ::= {
    TYPE-GGA: "GGA",
    TYPE-GLL: "GLL",
    TYPE-GSA: "GSA",
    TYPE-GSV: "GSV",
    TYPE-RMC: "RMC",
    TYPE-VTG: "VTG",
    TYPE-ZDA: "ZDA",
    TYPE-TXT: "TXT",
  }

  constructor
      --GGA=true
      --GLL=true
      --GSA=true
      --GSV=true
      --RMC=true
      --VTG=true
      --ZDA=true
      --TXT=true:
    super.private_ talker ID (List PAYLOAD-SIZE_)
    payload[0] = "\$$talker$ID"
    payload[TYPE-GGA] = GGA ? 1 : 0
    payload[TYPE-GLL] = GLL ? 1 : 0
    payload[TYPE-GSA] = GSA ? 1 : 0
    payload[TYPE-GSV] = GSV ? 1 : 0
    payload[TYPE-RMC] = RMC ? 1 : 0
    payload[TYPE-VTG] = VTG ? 1 : 0
    payload[TYPE-ZDA] = ZDA ? 1 : 0
    payload[TYPE-TXT] = TXT ? 1 : 0

  constructor.private_ .talker/string id/string payload/List:
    assert: payload.size == PAYLOAD-SIZE_
    super.private_  talker id payload

  is-gga-enabled -> bool: return payload[TYPE-GGA] == 1
  is-gll-enabled -> bool: return payload[TYPE-GLL] == 1
  is-gsa-enabled -> bool: return payload[TYPE-GSA] == 1
  is-gsv-enabled -> bool: return payload[TYPE-GSV] == 1
  is-rmc-enabled -> bool: return payload[TYPE-RMC] == 1
  is-vtg-enabled -> bool: return payload[TYPE-VTG] == 1
  is-zda-enabled -> bool: return payload[TYPE-ZDA] == 1
  is-txt-enabled -> bool: return payload[TYPE-TXT] == 1

  stringify -> string:
    out := List 0
    (PAYLOAD-SIZE_ - 1).repeat:
      if payload[it + 1] == 1:
        out.add TYPE-LOOKUP_[it + 1]
    return  "$super: enabled:$(out.join ",")"

/**
CAS04: Set Mode.

The mask can be any combination of GPS/BDS/GLONASS OR'd together, for example,
  (GPS | BDS | GLONASS) which would be 7.
*/
class Cas04 extends Casic-message:
  static ID ::= Casic-message.CAS04
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

  constructor --mask/int:
    assert: 0 <= mask <= 31
    super.private_ talker ID ["\$$talker$ID", mask]

  /** Not expected - leaving here until test of this function. */
  constructor.private_ .talker/string id/string payload/List:
    super.private_  talker id payload

  is-gps-enabled -> bool:
    return (payload[1] & GPS) != 0

  is-bds-enabled -> bool:
    return (payload[1] & BDS) != 0

  is-glonass-enabled -> bool:
    return (payload[1] & BDS) != 0

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
class Cas05 extends Casic-message:
  static ID ::= Casic-message.CAS05
  talker/string := "P"

  static NMEA-41-STRICT ::= 2
  static MIXED-GNSS ::= 5
  static LEGACY-GPS-ONLY ::= 9
  static MODE-LOOKUP_ ::= {
    NMEA-41-STRICT: "NMEA 4.1 Strict",
    MIXED-GNSS: "Mixed GNSS",
    LEGACY-GPS-ONLY: "GPS Only"
    }

  constructor --mode/int:
    assert: MODE-LOOKUP_.contains mode
    super.private_ talker ID ["\$$talker$ID", mode]

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
- 2=Query the working mode of the multimode receiver
- 3=Query the customer number of the product
- 5=Query upgrade code information
*/
class Cas06 extends Casic-message:
  static ID ::= Casic-message.CAS06
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

  constructor --info-type/int:
    assert: INFO-LOOKUP_.contains info-type
    super.private_ talker ID ["\$$talker$ID", info-type]

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
class Cas10 extends Casic-message:
  static ID ::= Casic-message.CAS10
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

  constructor --start-type/int:
    assert: START-LOOKUP_.contains start-type
    super.private_ talker ID ["\$$talker$ID", start-type]

  /** Not expected - leaving here until test of this function. */
  constructor.private_ .talker/string id/string payload/List:
    super.private_  talker id payload

  start-type -> int:
    return int.parse payload[1]

  stringify -> string:
    return  "$super: restart-type:$(START-LOOKUP_[start-type])"

/**
CAS15: Enabling/Disabling specific satellites.

v5200 or later required.
*/

/**
CAS60: Receiver Time Information

v5302 or later required.
*/
class Cas60 extends Casic-message:
  static ID ::= Casic-message.CAS60
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
