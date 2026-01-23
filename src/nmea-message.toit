import io
import io show LITTLE-ENDIAN
import reader as old-reader


class Nmea-message:
  static MAX-MESSAGE-SIZE_ ::= 82
  static NMEA-MAGIC-BYTE_ ::= 0x24
  static INVALID-NMEA-MESSAGE_ ::= "INVALID NMEA MESSAGE"
  static DELIMITER_/string ::= ","
  static CHECKSUM-DELIMITER_/string ::= "*"

  // Talker IDs:
  static GPS ::= "GP"
  static GLONASS ::= "GL"
  static GALILEO ::= "GA"
  static BEIDOU ::= "GB"
  static COMBINED ::= "GN"  // Combined GNSS (multi-constellation).

  // AIS:
  static AIS ::= "AI"	    // AIS (Automatic Identification System).
  static AIS-BASE ::= "AB"	// AIS base station.
  static AIS-DEP ::= "AD"   // AIS dependent station.

  // Other Talkers:
  static INT-INST ::= "II"     // Integrated Instrumentation.
  static INT-NAV ::= "IN"      // Integrated Navigation.
  static HEADING ::= "HC"      // Heading sensor (compass).
  static SOUNDER ::= "SD"      // Sounder (depth).
  static SPEED-LOG ::= "VW"    // Speed log (water speed).
  static WEATHER-INST ::= "WI" // Weather instruments.
  static PROPRIETARY ::= "P"   // Proprietary, following chars represent manufacturer.

  static TALKER-LOOKUP_ ::= {
    GPS: "GPS",
    GLONASS: "Glonass",
    GALILEO: "Galileo",
    BEIDOU: "Beidou",
    COMBINED: "COMBINED",
    AIS: "AIS",
    AIS-BASE: "AIS Base Station",
    AIS-DEP: "AIS Dependent Station",
    INT-INST: "Integrated Instrumentation",
    INT-NAV: "Integrated Navigation",
    HEADING: "Heading sensor (compass)",
    SOUNDER: "Sounder (depth)",
    SPEED-LOG: "Speed log (water speed)",
    WEATHER-INST: "Weather instruments",
    PROPRIETARY: "Proprietary"
  }


  // (Known) Proprietary Talkers:
  static PUBX ::= "Ublox"      // u-blox proprietary
  static PGRME ::= "Garmin"    // Garmin proprietary
  static PCAS ::= "Casic"      // Casic proprietary


  // Message Formats (IDs):
  static RMC ::= "RMC" // Time, date, lat/lon, speed over ground, course over ground, status.
  static GGA ::= "GGA" // Fix data (time, lat/lon, fix quality, number of sats used, HDOP, altitude, geoid separation).
  static VTG ::= "VTG" // Course and speed over ground (true/magnetic track + speed in knots/km/h).
  static GLL ::= "GLL" // Geographic position (lat/lon + time + status).  Also possible from RMC/GGA.
  static ZDA ::= "ZDA" // Date & time + local zone offset. Also possible from RMC.

  // Fix quality/DOP/satellites:
  static GSA ::= "GSA" // DOP + active satellites used + fix type (2D/3D).
  static GSV ::= "GSV" // Satellites in view (PRNs + elevation/azimuth/SNR, split across multiple messages).

  // Information:
  static GNS ::= "GNS" // GNSS fix data variant (like GGA but for multi-constellation. Some modules output this instead of GGA).
  static TXT ::= "TXT" // Text/status messages (firmware info, warnings, antenna status, etc).

  talker/string := ?
  id/string := ?
  payload/List := ?

  constructor talker/string id/string payload/List:
    if id == Nmea-message.RMC:
      return Rmc.private_ talker id payload
    if id == Nmea-message.GSA:
      return Gsa.private_ talker id payload
    if id == Nmea-message.GSV:
      return Gsv.private_ talker id payload
    if id == Nmea-message.VTG:
      return Vtg.private_ talker id payload
    if id == Nmea-message.TXT:
      return Txt.private_ talker id payload
    if id == Nmea-message.GGA:
      return Gga.private_ talker id payload
    if id == Nmea-message.ZDA:
      return Zda.private_ talker id payload
    if id == Nmea-message.GLL:
      return Gll.private_ talker id payload

    else:
      print "NMEA sentence type not known to driver: [$talker] [$id] $payload"
      unreachable

  constructor.private_ .talker/string .id/string .payload/List:

  constructor.from-reader reader/old-reader.Reader:
    io-reader/io.Reader := reader is io.Reader ? reader as io.Reader : io.Reader.adapt reader

    if (io-reader.peek-byte 0) != NMEA-MAGIC-BYTE_:
      throw INVALID-NMEA-MESSAGE_

    // Get full the packet (no size information provided) and verify length limits.
    // Perhaps switch to .read-string --max-size for security?
    sentence/string ::= io-reader.read-line

    if not sentence.contains-only-ascii:
      throw INVALID-NMEA-MESSAGE_

    if not is-valid-sentence_ sentence:
      throw INVALID-NMEA-MESSAGE_

    first-comma/int := sentence.index-of DELIMITER_
    if first-comma < 4 or first-comma == -1 :
      throw INVALID-NMEA-MESSAGE_

    type/string := sentence[1..first-comma]

    // Remove delimiter
    data := sentence
    cs-delimiter := sentence.index-of CHECKSUM-DELIMITER_ --last
    if cs-delimiter != -1:
      data = sentence[..cs-delimiter]

    // First: Proprietary type
    if type[0] == 'P':
      return Nmea-message "P" type[1..] (data.split DELIMITER_)

    // Second: First two characters are talker
    return Nmea-message type[0..2] type[2..] (data.split DELIMITER_)


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

  static compute-checksum_ data/string -> int:
    checksum := 0
    data.do: | next |
      checksum ^= next
    return checksum

  /** The message type name in full UBX-* format. */
  full-name -> string:
    return "NMEA-$talker-$id"

  /** Is this message multipart? */
  multipart -> bool:
    return false

  part-message -> List:
    return [1, 1]

  /** See $super. */
  stringify -> string:
    return full-name


class Txt extends Nmea-message:
  static ID ::= Nmea-message.TXT
  talker/string := ?

  constructor.private_ .talker/string id/string payload/List:
    super.private_  talker id payload

  stringify -> string:
    return  "$super: $(payload[2..].join ",")"


/**
GGA: Global Positioning System Fixed Data.
*/
class Gga extends Nmea-message:
  static ID ::= Nmea-message.GGA
  talker/string := ?

  constructor.private_ .talker/string id/string payload/List:
    super.private_  talker id payload

  utc-string -> string:
    return payload[1]

  latitude -> float:
    //print "[$payload[2]]"
    return float.parse payload[2]

  latitude-n -> string:
    return payload[3]

  longitude -> float:
    return float.parse payload[4]

  longitude-e -> string:
    return payload[5]

  is-fix-valid -> bool:
    return payload[6] == 1

  /** Number of satellites in the message. */
  satellite-count -> int:
    return int.parse payload[7]

  /** Altitude */
  altitude -> float:
    return float.parse payload[9]

  altitude-unit -> string:
    return payload[10]

  /** Geoidal Height */
  geoidal-height -> float:
    return float.parse payload[11]

  geoidal-height-unit -> string:
    return payload[12]

  stringify -> string:
    return  "$super: lat:$latitude($latitude-n)|long:$longitude($longitude-e)"

/**
ZDA: Time and Date
*/
class Zda extends Nmea-message:
  static ID ::= Nmea-message.ZDA
  talker/string := ?

  constructor.private_ .talker/string id/string payload/List:
    super.private_  talker id payload

  lz-hours -> int:
    return int.parse payload[5]

  lz-minutes -> int:
    return int.parse payload[6]

  time -> Time:
    return Time.utc
      --year=(int.parse payload[4])
      --month=(int.parse payload[3])
      --day=(int.parse payload[2])
      --h=(int.parse (payload[1])[0..2])
      --m=(int.parse (payload[1])[2..4])
      --s=(int.parse (payload[1])[4..6])
      --ms=(int.parse (payload[1])[7..])

  stringify -> string:
    return  "$super: $time+$(%02b lz-hours):$(%02b lz-minutes)"

/**
VTG: Course Over Ground and Ground Speed
*/
class Vtg extends Nmea-message:
  static ID ::= Nmea-message.VTG
  talker/string := ?

  constructor.private_ .talker/string id/string payload/List:
    super.private_  talker id payload

  true-course -> float:
    //print "PARSING $payload[1]"
    return float.parse payload[1]

  speed-kmh -> float:
    //print "KMH PARSING $payload"
    return float.parse payload[5]

  speed-kts -> float:
    //print "KMH PARSING $payload[7]"
    return float.parse payload[7]

  positioning-mode -> string:
    return payload[9]

  stringify -> string:
    return  "$super: kmh:$(%0.0f speed-kmh)|kts:$(%0.0f speed-kts)|mode:$positioning-mode|course:$(%0.3f true-course)"

class Rmc extends Nmea-message:
  static ID ::= Nmea-message.RMC
  talker/string := ?

  static SAFE ::= "S"
  static CAUTION ::= "C"
  static UNSAFE ::= "U"
  static NOT-VALID ::= "V"

  static NAV-STATUS-LOOKUP_ ::= {
    SAFE: "Safe",
    CAUTION: "Caution",
    UNSAFE: "Unsafe",
    NOT-VALID: "Not Valid"
  }

  constructor.private_ .talker/string id/string payload/List:
    super.private_  talker id payload

  utc-string -> string:
    return payload[1]

  latitude -> float:
    return float.parse payload[2]

  latitude-n -> string:
    return payload[3]

  longitude -> float:
    return float.parse payload[4]

  longitude-e -> string:
    return payload[5]

  speed-kmh -> float:
    return float.parse payload[6]

  speed-kts -> float:
    return float.parse payload[7]

  positioning-mode -> string:
    return payload[11]

  nav-status -> string:
    return payload[12]

  time -> Time:
    return Time.utc
      --year=(int.parse (payload[9])[4..6])
      --month=(int.parse (payload[9])[2..4])
      --day=(int.parse (payload[9])[0..2])
      --h=(int.parse (payload[1])[0..2])
      --m=(int.parse (payload[1])[2..4])
      --s=(int.parse (payload[1])[4..6])
      --ms=(int.parse (payload[1])[7..])

  stringify -> string:
    if nav-status == "V":
      return "$super: $(NAV-STATUS-LOOKUP_[nav-status])"
    return  "$super: status:$nav-status|mode:$positioning-mode|$time|....."


class Gll extends Nmea-message:
  static ID ::= Nmea-message.GLL
  talker/string := ?

  static DATA-VALID ::= "A"
  static DATA-INVALID ::= "V"

  static NAV-STATUS-LOOKUP_ ::= {
    DATA-VALID: "Data Valid",
    DATA-INVALID: "Data Invalid"
  }

  static POSITION-MODE-AUTONOMOUS ::= "A"
  static POSITION-MODE-DATA-INVALID ::= "V"

  static POSITION-MODE-LOOKUP_ ::= {
    POSITION-MODE-AUTONOMOUS: "Autonomous",
    POSITION-MODE-DATA-INVALID: "Data Invalid"
  }

  constructor.private_ .talker/string id/string payload/List:
    super.private_  talker id payload

  latitude -> float:
    return float.parse payload[1]

  latitude-n -> string:
    return payload[2]

  longitude -> float:
    return float.parse payload[3]

  longitude-e -> string:
    return payload[4]

  nav-status -> string:
    return payload[6]

  positioning-mode -> string:
    return payload[7]

  stringify -> string:
    if nav-status == "V":
      return "$super: $(NAV-STATUS-LOOKUP_[nav-status])"
    return  "$super: status:$NAV-STATUS-LOOKUP_[nav-status]|mode:$POSITION-MODE-LOOKUP_[positioning-mode]|....."

/**
GSA: GNSS DOP and Active Satellites.

Multiple messages may be reported if multiple systems are used for the current
  fix (GPS, GLONASS, etc), without the message without `multiple` returning
  true. The identifier will follow the convention of other messages, but field
  $system-id will indicate which system the message is providing information
  from.

Space Vehicle ID's (SVIDs) are numbered as follows:
a. GPS: 01-32
b. SBAS: 33-51 (120 to 138)
c. GLONASS: 65-92 (01 to 28)
d. QZSS: 93-99 (193 to 199)
*/
class Gsa extends Nmea-message:
  static ID ::= Nmea-message.GSA
  talker/string := ?

  static OPERATION-MODE-FIXED ::= "M"      // M=2D/3D Fixed
  static OPERATION-AUTO-SWITCHING ::= "A"  // A=2D/3D Auto-Switching
  static OPERATION-MODE-LOOKUP_ ::= {
    OPERATION-MODE-FIXED: "2D/3D Fixed",
    OPERATION-AUTO-SWITCHING: "2D/3D Auto-Switching"
  }

  static FIX-NO-FIX ::= 1
  static FIX-2D-FIX ::= 2
  static FIX-3D-FIX ::= 3
  static FIX-LOOKUP_ ::= {
    FIX-NO-FIX: "No Fix",
    FIX-2D-FIX: "2D Fix",
    FIX-3D-FIX: "3D Fix"
  }

  static SYSTEM-ID-GPS ::= 1
  static SYSTEM-ID-SBAS ::= 2
  static SYSTEM-ID-GLONASS ::= 3
  static SYSTEM-ID-QZSS ::= 4
  static SYSTEM-LOOKUP ::= {
    SYSTEM-ID-GPS: "GPS",
    SYSTEM-ID-SBAS: "SBAS",
    SYSTEM-ID-GLONASS: "GLONASS",
    SYSTEM-ID-QZSS: "QZSS"
  }

  constructor.private_ .talker/string id/string payload/List:
    super.private_  talker id payload

  operation-mode -> string:
    return payload[1]

  system-id -> int:
    return int.parse payload[18]

  p-dop -> float:
    return float.parse payload[15]

  h-dop -> float:
    return float.parse payload[16]

  v-dop -> float:
    return float.parse payload[17]

  satellites -> List:
    blank-pos := payload.index-of ""
    end := 15
    if blank-pos > 3:
      end = blank-pos
    return payload[3..end]

  stringify -> string:
    return  "$super: $SYSTEM-LOOKUP[system-id]:$satellites"

/**
GSV: GNSS Satellites in View

GSV is not the collection of satellites that are actually used in the math, but
  rather all the satellites that can be heard in RF frequencies.  (See GSA type
  messages for satellites in use.)
*/
class Gsv extends Nmea-message:
  static ID ::= Nmea-message.GSV
  talker/string := ?

  static SYSTEM-ID-GPS ::= 1
  static SYSTEM-ID-SBAS ::= 2
  static SYSTEM-ID-GLONASS ::= 3
  static SYSTEM-ID-QZSS ::= 4
  static SYSTEM-LOOKUP ::= {
    SYSTEM-ID-GPS: "GPS",
    SYSTEM-ID-SBAS: "SBAS",
    SYSTEM-ID-GLONASS: "GLONASS",
    SYSTEM-ID-QZSS: "QZSS"
  }

  constructor.private_ .talker/string id/string payload/List:
    super.private_  talker id payload

  multipart -> bool:
    return true

  part-message -> List:
    return [int.parse payload[2], int.parse payload[1]]

  system-id -> int:
    return int.parse payload[18]

  stringify -> string:
    return  "$super: $SYSTEM-LOOKUP[system-id]:$part-message "
