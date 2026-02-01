import io
import io show LITTLE-ENDIAN
import reader as old-reader

class NmeaParser:
  static UBX-MAGIC-BYTE_ ::= 0xb5
  static NMEA-MAGIC-BYTE_ ::= 0x24
  static AIS-MAGIC-BYTE_ ::= 0x21

  static MAX-MESSAGE-SIZE_ ::= 82
  static INVALID-NMEA-MESSAGE_ ::= "INVALID NMEA MESSAGE"
  static DELIMITER_/string ::= ","
  static CHECKSUM-DELIMITER_/string ::= "*"

  // Constellation Talker IDs:
  static GPS ::= "GP"
  static GLONASS ::= "GL"
  static GALILEO ::= "GA"
  static BEIDOU1 ::= "GB"
  static BEIDOU2 ::= "BD"
  static COMBINED ::= "GN"  // Combined GNSS (multi-constellation).

  // AIS Talker IDs:
  static AIS ::= "AI"	    // AIS (Automatic Identification System).
  static AIS-BASE ::= "AB"	// AIS base station.
  static AIS-DEP ::= "AD"   // AIS dependent station.

  // Other Talker IDs:
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
    BEIDOU1: "Beidou",
    BEIDOU2: "Beidou",
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
  static PUBX ::= "Ublox"      // u-blox proprietary.
  static PGRME ::= "Garmin"    // Garmin proprietary.
  static PCAS ::= "Casic"      // Casic proprietary.

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

  // More:
  static DHV ::= "DHV" // Describes receiver speed.
  static ANT ::= "ANT" // Antenna Information.
  static LPS ::= "LPS" // Leap Second Information.
  static UTC ::= "UTC" // Receiver status, simplified information for leap second correction.
  static GST ::= "GST" // Measurement accuracy details for receiver pseudoranges.
  static INS ::= "INS" // Inertial Navigation System (INS) information.

  // Query
  static QUERY ::= "Q"

  // Type Registry:
  registry/Map := {:}

  constructor:
    // Build the registry and register all the types:
    registry[RMC] = (:: | talker id payload |
      Rmc.private_ talker id payload)
    registry[GSA] = (:: | talker id payload |
      Gsa.private_ talker id payload)
    registry[GSV] = (:: | talker id payload |
      Gsv.private_ talker id payload)
    registry[VTG] = (:: | talker id payload |
      Vtg.private_ talker id payload)
    registry[TXT] = (:: | talker id payload |
      Txt.private_ talker id payload)
    registry[GGA] = (:: | talker id payload |
      Gga.private_ talker id payload)
    registry[ZDA] = (:: | talker id payload |
      Zda.private_ talker id payload)
    registry[GLL] = (:: | talker id payload |
      Gll.private_ talker id payload)

  from-reader reader/old-reader.Reader:
    io-reader/io.Reader := reader is io.Reader ? reader as io.Reader : io.Reader.adapt reader

    if (io-reader.peek-byte 0) != NMEA-MAGIC-BYTE_:
      throw "$INVALID-NMEA-MESSAGE_: sentence first char not \$"

    // Get full the packet (no size information provided) and verify length limits.
    // Perhaps switch to .read-string --max-size for security?
    sentence/string ::= io-reader.read-line

    // Unsure about this one.  SiRF encodes binary data in its NMEA (allegedly).
    if not sentence.contains-only-ascii:
      throw "$INVALID-NMEA-MESSAGE_: sentence not completely ascii"

    // Other checks done this way as they are checks that can be done after
    // message modification.
    if not is-valid-sentence_ sentence:
      throw "$INVALID-NMEA-MESSAGE_: sentence invalid"

    cs-delimiter := sentence.index-of CHECKSUM-DELIMITER_ --last
    end := cs-delimiter == -1 ? sentence.size : cs-delimiter

    // Ensure a comma exists and a meaningful header.
    first-comma/int := sentence.index-of DELIMITER_
    second-comma/int := sentence.index-of DELIMITER_ (first-comma + 1)
    if first-comma < 4 or first-comma == -1 or second-comma == -1:
      throw "$INVALID-NMEA-MESSAGE_: malformed header/body"

    // Type-1 message IDs - types (Casic, Garmin) whose message IDs are held in
    // the first field only. (eg, Message ID definition goes to first comma.)
    type-1/string := sentence[1..first-comma]
    // Type-2 message IDs - types (UBX, SRF) whose message ID also uses the
    // next field. (eg, Message ID definition goes to second comma.)
    type-2/string := sentence[1..second-comma]

    talker/string := ?
    id/string := ?
    if type-1[0..1] == "P":
      // Type 1 Message handling:
      talker = type-1[0..1]
      id = type-1[1..]
      if registry.contains id:
        return registry[id].call talker id (sentence[1..end].split DELIMITER_)

      // Message is a P, but must be type 2: message ID information goes to second comma.

      id2 := type-2[1..]
      if registry.contains id2:
        return registry[id2].call talker id2 (sentence[1..end].split DELIMITER_)

      throw "Unknown proprietary message type '$id' or '$id2'"

    else:
      // Message must be an NMEA native message:
      talker = type-1[0..2]
      id = type-1[2..]

      if registry.contains id:
        return registry[id].call talker id (sentence[1..end].split DELIMITER_)
      else:
        throw "Unknown message type $id"


  static is-valid-sentence_ sentence/string -> bool:
    // Check the payload length.
    if sentence.size > MAX-MESSAGE-SIZE_:
      print "message too long"
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
  NMEA checksum is XOR of all characters between $ and * (exclusive).
  */
  static compute-checksum_ data/string -> int:
    checksum := 0
    data.do: | next |
      checksum ^= next
    return checksum

  /**
  Adds the dictionary of message types (and their approprate constructors) from
    extension classes.
  */
  add input-map/Map -> none:
    input-map.keys.do: | id |
      registry[id] = input-map[id]

  message-count -> int:
    return registry.size


abstract class NmeaMessage:
  static ID ::= "NONE"
  talker/string := ""
  id/string := ""
  payload/List := []

  constructor.private_ .talker/string .id/string .payload/List:

  /** If this message is a poll. */
  is-poll -> bool:
    return id == ID

  /** If this message is multipart. */
  is-multipart -> bool:
    return false

  /** Multipart message number. */
  message-part -> List:
    return [1, 1]

  /** See $super. */
  stringify -> string:
    return "NMEA-$talker-$id"

  /** Full Message Name. */
  full-name -> string:
    return "NMEA-$talker-$id"

  /** Provides access to raw data in all fields (parsed or not). */
  raw -> List:
    return payload

  /** Used to create the ASCII sentence for sending on the wire. */
  to-string -> string:
    outstring := payload.join ","
    checksum := NmeaParser.compute-checksum_ outstring
    checksum-string := "$(%02x checksum)".to-ascii-upper
    return "\$$outstring*$checksum-string"

class Txt extends NmeaMessage:
  static ID ::= NmeaParser.TXT
  talker/string := ?

  static ERROR ::= 0   // Error information.
  static WARN ::= 1    // Warning message.
  static NOTICE ::= 2  // Notification information;
  static USER ::= 7    // User information.
  static TYPE-LOOKUP_ ::= {
    ERROR: "Error",
    WARN: "Warn",
    NOTICE: "Notice",
    USER: "User"
  }

  constructor.private_ .talker/string id/string payload/List:
    super.private_  talker id payload

  is-multipart -> bool:
    return (int.parse payload[1]) >= 2

  message-part -> List:
    return [int.parse payload[2], int.parse payload[1]]

  type -> int:
    return int.parse payload[3]

  text -> string:
    return payload[4]

  stringify -> string:
    if is-multipart:
      return  "$super: $message-part $TYPE-LOOKUP_[type]|$text"
    return  "$super: $TYPE-LOOKUP_[type]|$text"

/**
GGA: Global Positioning System Fixed Data.
*/
class Gga extends NmeaMessage:
  static ID ::= NmeaParser.GGA
  talker/string := ?

  static QUALITY-NO-FIX ::= 0
  static QUALITY-AUTONOMOUS-GNSS-FIX ::= 1
  static QUALITY-DIFFERENTIAL-GNSS-FIX ::= 2
  static QUALITY-ESTIMATE-GNSS-FIX ::= 6
  static QUALITY-LOOKUP_ ::= {
    QUALITY-NO-FIX: "No Fix",
    QUALITY-AUTONOMOUS-GNSS-FIX: "Autonomous Fix",
    QUALITY-DIFFERENTIAL-GNSS-FIX:  "Differential Fix",
    QUALITY-ESTIMATE-GNSS-FIX: "Estimate/Dead Reckoning Fix",
  }

  constructor.poll:
    talker = NmeaParser.GPS
    msgid := NmeaParser.QUERY
    super.private_  talker msgid ["$talker$msgid",ID]

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

  fix-quality -> int:
    return int.parse payload[6]

  is-fix-valid -> bool:
    return fix-quality > QUALITY-NO-FIX

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
    if not is-fix-valid:
      return  "$super: fix:$QUALITY-LOOKUP_[fix-quality]"
    return  "$super: lat:$latitude($latitude-n)|long:$longitude($longitude-e)"

/**
ZDA: Time and Date
*/
class Zda extends NmeaMessage:
  static ID ::= NmeaParser.ZDA
  talker/string := ?

  constructor.poll:
    talker = NmeaParser.GPS
    msgid := NmeaParser.QUERY
    super.private_  talker msgid ["$talker$msgid",ID]

  constructor.private_ .talker/string id/string payload/List:
    super.private_  talker id payload

  lz-hours -> int:
    return int.parse payload[5]

  lz-minutes -> int:
    //print "parsing '$payload[6]'"
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
class Vtg extends NmeaMessage:
  static ID ::= NmeaParser.VTG
  talker/string := ?

  static POS-MODE-AUTONOMOUS ::= "A"
  static POS-MODE-ESTIMATION ::= "E"
  static POS-MODE-INVALID-DATA ::= "N"
  static POS-MODE-DIFFERENTIAL ::= "D"
  static POS-MODE-MANUAL ::= "M"
  static POS-MODE-SIMULATOR ::= "S"
  static POS-MODE-LOOKUP_ ::= {
    POS-MODE-AUTONOMOUS: "Autonomous",
    POS-MODE-ESTIMATION: "Estimation",
    POS-MODE-INVALID-DATA: "Invalid Data",
    POS-MODE-DIFFERENTIAL: "Differential",
    POS-MODE-SIMULATOR: "Simulator",
    POS-MODE-MANUAL: "Manual"
  }

  constructor.poll:
    talker = NmeaParser.GPS
    msgid := NmeaParser.QUERY
    super.private_  talker msgid ["$talker$msgid",ID]

  constructor.private_ .talker/string id/string payload/List:
    super.private_  talker id payload

  true-course -> float?:
    return float.parse payload[1] --if-error=: 0.0

  magnetic-course -> float:
    return float.parse payload[3] --if-error=: 0.0

  speed-kmh -> float:
    //print "KMH PARSING $payload"
    return float.parse payload[7] --if-error=: 0.0

  speed-kts -> float:
    //print "KMH PARSING $payload[7]"
    return float.parse payload[5] --if-error=: 0.0

  positioning-mode -> string:
    return payload[9]

  stringify -> string:
    if positioning-mode == POS-MODE-INVALID-DATA or positioning-mode == POS-MODE-MANUAL:
      return  "$super: mode:$POS-MODE-LOOKUP_[positioning-mode]"
    return  "$super: mode:$POS-MODE-LOOKUP_[positioning-mode]|kmh:$(%0.0f speed-kmh)|kts:$(%0.0f speed-kts)|course:$(%0.3f true-course)"

class Rmc extends NmeaMessage:
  static ID ::= NmeaParser.RMC
  talker/string := ?

  static STATUS-DATA-VALID ::= "A"
  static STATUS-DATA-INVALID ::= "V"
  static STATUS-LOOKUP_ ::= {
    STATUS-DATA-VALID: "Data Valid",
    STATUS-DATA-INVALID: "Data Invalid"
  }

  static POS-MODE-AUTONOMOUS ::= "A"
  static POS-MODE-ESTIMATION ::= "E"
  static POS-MODE-INVALID-DATA ::= "N"
  static POS-MODE-DIFFERENTIAL ::= "D"
  static POS-MODE-MANUAL ::= "M"
  static POS-MODE-SIMULATOR ::= "S"
  static POS-MODE-LOOKUP_ ::= {
    POS-MODE-AUTONOMOUS: "Autonomous",
    POS-MODE-ESTIMATION: "Estimation",
    POS-MODE-INVALID-DATA: "Invalid Data",
    POS-MODE-DIFFERENTIAL: "Differential",
    POS-MODE-SIMULATOR: "Simulator",
    POS-MODE-MANUAL: "Manual"
  }

  constructor.poll:
    talker = NmeaParser.GPS
    msgid := NmeaParser.QUERY
    super.private_  talker msgid ["$talker$msgid",ID]

  constructor.private_ .talker/string id/string payload/List:
    super.private_  talker id payload

  time-utc -> string:
    return payload[1]

  status -> string:
    return payload[2]

  latitude -> float:
    return float.parse payload[3]

  latitude-n -> string:
    return payload[4]

  longitude -> float:
    return float.parse payload[5]

  longitude-e -> string:
    return payload[6]

  speed-kts -> float:
    return float.parse payload[7] //--if-error=: 0.0

  /** Course Over Ground. */
  course -> float:
    return float.parse payload[8]

  positioning-mode -> string:
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
    if status == STATUS-DATA-INVALID:
      return "$super: status:$(STATUS-LOOKUP_[status])"
    return  "$super: status:$(STATUS-LOOKUP_[status])|mode:$POS-MODE-LOOKUP_[positioning-mode]|$time|....."


class Gll extends NmeaMessage:
  static ID ::= NmeaParser.GLL
  talker/string := ?

  static STATUS-DATA-VALID ::= "A"
  static STATUS-DATA-INVALID ::= "V"
  static STATUS-LOOKUP_ ::= {
    STATUS-DATA-VALID: "Data Valid",
    STATUS-DATA-INVALID: "Data Invalid"
  }

  static FIX-NO-FIX ::= 0          // No fix.
  static FIX-AUTONOMOUS ::= 1      // Autonomous fix.
  static FIX-DIFFERENTIAL ::= 2    // Differential fix.
  static FIX-RTK ::= 4             // RTK fixed.
  static FIX-RTK-FLOAT ::= 5       // RTK float.
  static FIX-DEAD-RECKONING ::= 6  // Estimated/Dead Reckoning Fix.
  static FIX-TYPE-LOOKUP_ ::= {
    FIX-NO-FIX: "No Fix",
    FIX-AUTONOMOUS: "Autonomous Fix",
    FIX-DIFFERENTIAL: "Differential Fix",
    FIX-RTK: "RTK Fixed",
    FIX-RTK-FLOAT: "RTK Float",
    FIX-DEAD-RECKONING: "Dead Reckoning Fix",
  }

  static POSITION-MODE-AUTONOMOUS ::= "A"
  static POSITION-MODE-DATA-INVALID ::= "V"
  static POSITION-MODE-NO-FIX ::= "N"         // No fix.
  static POSITION-MODE-DEAD-RECKONING ::= "E" // Eestimated/dead reckoning fix.
  static POSITION-MODE-DIFFERENTIAL ::= "D"   // Differential GNSS fix.
  static POSITION-MODE-RTK-FLOAT ::= "F"      // RTK float.
  static POSITION-MODE-RTK-FIXED ::= "R"      // RTK fixed.
  static POSITION-MODE-LOOKUP_ ::= {
    POSITION-MODE-AUTONOMOUS: "Autonomous",
    POSITION-MODE-DATA-INVALID: "Data Invalid",
    POSITION-MODE-NO-FIX: "No Fix",
    POSITION-MODE-DEAD-RECKONING: "Dead Reckoning",
    POSITION-MODE-DIFFERENTIAL: "Differential",
    POSITION-MODE-RTK-FLOAT: "RTK Float",
    POSITION-MODE-RTK-FIXED: "RTK Fixed",
  }

  constructor.poll:
    talker = NmeaParser.GPS
    msgid := NmeaParser.QUERY
    super.private_  talker msgid ["$talker$msgid",ID]

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

  //payload 5 is time

  /**
  */
  status -> string:
    return payload[6]

  positioning-mode -> string:
    return payload[7]

  stringify -> string:
    if status == "V":
      return "$super: $(STATUS-LOOKUP_[status])"
    return  "$super: status:$STATUS-LOOKUP_[status]|mode:$POSITION-MODE-LOOKUP_[positioning-mode]|....."

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
class Gsa extends NmeaMessage:
  static ID ::= NmeaParser.GSA
  talker/string := ?

  static OPERATION-MODE-FIXED ::= "M"      // M=2D/3D Fixed
  static OPERATION-AUTO-SWITCHING ::= "A"  // A=2D/3D Auto-Switching
  static OPERATION-MODE-LOOKUP_ ::= {
    OPERATION-MODE-FIXED: "2D/3D Fixed",
    OPERATION-AUTO-SWITCHING: "2D/3D Auto-Switching"
  }

  // For $nav-mode output.
  static FIX-NO-FIX ::= 1
  static FIX-2D-FIX ::= 2
  static FIX-3D-FIX ::= 3
  static FIX-LOOKUP_ ::= {
    FIX-NO-FIX: "No Fix",
    FIX-2D-FIX: "2D Fix",
    FIX-3D-FIX: "3D Fix"
  }

  static SYSTEM-ID-UNSPECIFIED ::= 0
  static SYSTEM-ID-GPS ::= 1
  static SYSTEM-ID-SBAS ::= 2
  static SYSTEM-ID-GLONASS ::= 3
  static SYSTEM-ID-QZSS ::= 4
  static SYSTEM-LOOKUP ::= {
    SYSTEM-ID-UNSPECIFIED: "UNSPECIFIED",
    SYSTEM-ID-GPS: "GPS",
    SYSTEM-ID-SBAS: "SBAS",
    SYSTEM-ID-GLONASS: "GLONASS",
    SYSTEM-ID-QZSS: "QZSS"
  }

  constructor.poll:
    talker = NmeaParser.GPS
    msgid := NmeaParser.QUERY
    super.private_  talker msgid ["$talker$msgid",ID]

  constructor.private_ .talker/string id/string payload/List:
    super.private_  talker id payload

  operation-mode -> string:
    return payload[1]

  nav-mode -> int:
    return int.parse payload[2]

  system-id -> int?:
    if payload.size >= 19:
      return int.parse payload[18] --if-error=: SYSTEM-ID-UNSPECIFIED
    else:
      return NmeaParser.TALKER-LOOKUP_[talker]

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
    sats/List := satellites.copy
    sats.remove --all ""
    return  "$super: $SYSTEM-LOOKUP[system-id]:$sats"

/**
GSV: GNSS Satellites in View

GSV is not the collection of satellites that are actually used in the math, but
  rather all the satellites that can be heard in RF frequencies.  (See GSA type
  messages for satellites in use/contributing toward position.)  System is given
  in the talker type, not as a field in the message.
*/
class Gsv extends NmeaMessage:
  static ID ::= NmeaParser.GSV
  talker/string := ?

  constructor.poll:
    talker = NmeaParser.GPS
    msgid := NmeaParser.QUERY
    super.private_  talker msgid ["$talker$msgid",ID]

  constructor.private_ .talker/string id/string payload/List:
    super.private_  talker id payload

  is-multipart -> bool:
    return true

  message-part -> List:
    return [int.parse payload[2], int.parse payload[1]]

  /** Number of SVs in this message. */
  num-svs -> int:
    return (payload.size - 4) / 4

  /** Number of SVs for this talker (across all messages). */
  total-svs -> int:
    return int.parse payload[3]

  /**
  The SV's in this message.

  Returns a map with the PRN as key, and [Elevation, Azimuth, SNR] as data.
  */
  svs -> Map:
    out-map := {:}
    num-svs.repeat:
      num := 4 + (it * 4)
      prn := int.parse payload[num]
      elev := float.parse payload[num + 1] --if-error=(: null)
      az := float.parse payload[num + 2] --if-error=(: null)
      snr := float.parse payload[num + 3] --if-error=(: null)
      out-map[prn] = [elev, az, snr]
    return out-map

  stringify -> string:
    sv-set := svs.keys.join ","
    n := message-part[0]
    x := message-part[1]
    start := (n - 1) * 4 + 1
    end := n * 4
    if end > total-svs: end = total-svs
    //return  "$super: $NmeaParser.TALKER-LOOKUP_[talker]:$message-part/$total-svs ($sv-set)"
    return "$super: $NmeaParser.TALKER-LOOKUP_[talker]:[$start-$end/$total-svs] ($sv-set)"
