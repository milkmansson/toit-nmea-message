// Copyright (C) 2025 Toit contributors.
// Use of this source code is governed by a MIT-style license that can be found
// in the LICENSE file.

import io
import io show LITTLE-ENDIAN

class NmeaParser:
  static UBX-MAGIC-BYTE_ ::= 0xb5
  static NMEA-MAGIC-BYTE_ ::= 0x24
  static AIS-MAGIC-BYTE_ ::= 0x21

  // The NMEA standard states the size should not be > 82, however in practice,
  // allegedly this is exceeded regularly.
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

  // Talker ID for any proprietary NMEA messages:
  static PROPRIETARY ::= "P"   // Chars following P represent manufacturer.

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

  /* More: not yet implemented
  static DHV ::= "DHV" // Describes receiver speed.
  static ANT ::= "ANT" // Antenna Information.
  static LPS ::= "LPS" // Leap Second Information.
  static UTC ::= "UTC" // Receiver status, simplified information for leap second correction.
  static INS ::= "INS" // Inertial Navigation System (INS) information.
  */

  // Type Registry:
  registry_/Map := {
    Rmc.ID: :: | talker payload | Rmc.private_ talker payload,
    Gsa.ID: :: | talker payload | Gsa.private_ talker payload,
    Gsv.ID: :: | talker payload | Gsv.private_ talker payload,
    Vtg.ID: :: | talker payload | Vtg.private_ talker payload,
    Txt.ID: :: | talker payload | Txt.private_ talker payload,
    Gga.ID: :: | talker payload | Gga.private_ talker payload,
    Zda.ID: :: | talker payload | Zda.private_ talker payload,
    Gll.ID: :: | talker payload | Gll.private_ talker payload,
    Gns.ID: :: | talker payload | Gns.private_ talker payload,
    Gbs.ID: :: | talker payload | Gbs.private_ talker payload,
    Mss.ID: :: | talker payload | Mss.private_ talker payload,
    Gst.ID: :: | talker payload | Gst.private_ talker payload,
    Vlw.ID: :: | talker payload | Vlw.private_ talker payload,
    Rlm.ID: :: | talker payload | Rlm.private_ talker payload,
  }

  constructor --proprietary-messages/Map?=null:
    if proprietary-messages: add proprietary-messages

  from-reader io-reader/io.Reader -> NmeaMessage:
    if (io-reader.peek-byte 0) != NMEA-MAGIC-BYTE_:
      throw "$INVALID-NMEA-MESSAGE_: sentence first char not \$"

    sentence/string ::= io-reader.read-line
    return from-string sentence

  from-string sentence/string --ignore-checksum/bool=false --show-checksum/bool=false -> NmeaMessage:
    if sentence[0] != '$':
      throw "$INVALID-NMEA-MESSAGE_: sentence first char not \$"

    if not sentence.contains-only-ascii:
      throw "$INVALID-NMEA-MESSAGE_: sentence not completely ascii"

    if not ignore-checksum and not validate-checksum_ sentence --show=show-checksum:
      throw "$INVALID-NMEA-MESSAGE_: sentence checksum invalid"

    cs-delimiter := sentence.index-of CHECKSUM-DELIMITER_ --last
    end := cs-delimiter == -1 ? sentence.size : cs-delimiter

    // Ensure a comma exists and a meaningful header.
    first-comma/int := sentence.index-of DELIMITER_
    if first-comma < 4 or first-comma == -1:
      throw "$INVALID-NMEA-MESSAGE_: malformed header/body "
    second-comma/int := sentence.index-of DELIMITER_ (first-comma + 1)
    if second-comma == -1:
      throw "$INVALID-NMEA-MESSAGE_: malformed header/body (second comma)"

    type/string := sentence[1..first-comma].to-ascii-upper
    id/string := ?

    // Looks for sentences $..XXXX,
    id = type[2..]
    if registry_.contains id:
      return registry_[id].call type[0..2] (sentence[1..end].split DELIMITER_)

    // Looks for Type 1 sentences $PXXXX, message ID goes to first comma:
    id = type[1..]
    if registry_.contains id:
      return registry_[id].call type[0..1] (sentence[1..end].split DELIMITER_)

    // Looks for Type-2 sentences $PXXXX,XX, message ID goes to second comma:
    type = sentence[1..second-comma].to-ascii-upper
    id = type[0..]
    if registry_.contains id:
      return registry_[id].call type[0..1] (sentence[1..end].split DELIMITER_)

    throw "$INVALID-NMEA-MESSAGE_: Unknown message type '$id'"

  /**
  Validates the message is valid against it's checksum.
  */
  static validate-checksum_ sentence/string --show/bool=false -> bool:
    cs-delimiter := sentence.index-of CHECKSUM-DELIMITER_ --last

    // If checksum is missing, return a pass. (Having no CS is allowed in the spec).
    if cs-delimiter == -1 : return true

    // Get the text being checksummed [$..*] (exclusive).
    message-text := sentence[1..cs-delimiter]

    // Retrieve text after the * and parse as hex.
    message-checksum/int? := int.parse (sentence[(cs-delimiter+1)..]) --radix=16 --if-error=: null
    calculated-checksum := compute-checksum_ message-text

    // If not debugging return (quickly).
    equal/bool := message-checksum == calculated-checksum
    if not show: return equal

    // Debugging path:
    if equal:
      print "$sentence has correct checksum."
      return true

    print "$sentence should have checksum 0x$(%02x calculated-checksum)."
    return false

  /**
  NMEA checksum is XOR of all characters between $ and * (exclusive).
  */
  static compute-checksum_ data/string -> int:
    checksum := 0
    data.do: | next |
      checksum ^= next
    return checksum

  /**
  Converts GNSS native forms of Lat/Long to methematical form.

  Most GNSS devices will natively use degrees-minutes N/S|E/W.  However, maps
    math libraries typically want a single floating point number.  The number
    will be -90 <= x <= 90, with with North = +ve, South = -ve and East = +ve,
    West = -ve.
  */
  static dm-to-degrees value/float hemisphere/string -> float:
    hemisphere-values := ["N","S","E","W"]
    assert: hemisphere-values.contains hemisphere
    degrees := (value / 100).floor
    minutes := value - (degrees * 100)
    math-degrees := degrees + (minutes / 60.0)

    if hemisphere == "S" or hemisphere == "W":
      math-degrees = -math-degrees
    return math-degrees

  /**
  Adds the message types (and their approprate constructors) from extensions.
  */
  add input-map/Map -> none:
    input-map.keys.do: | id |
      registry_[id] = input-map[id]

  /**
  Shows the content of the NMEA message registry.  (For troubleshooting purposes.)

  To show message types known in registry: `registry.keys`
  To count message types in registry: `registry.size`
    */
  registry -> Map:
    return registry_


abstract class NmeaMessage:
  static ID ::= "NONE"

  talker/string
  id_/string
  payload_/List
  is-valid_/bool := false

  //** Creates a standard poll for MSS from the specified talker id. */
  // May remove because not all derivative message types allow polling.
  //constructor.poll --.talker=NmeaParser.GPS:
  //  id_ = "Q"
  //  payload_ = ["$(talker)Q",ID]

  constructor.private_ .talker/string id/string .payload_/List:
    id_ = id.replace "," ""

  /**
  Whether any cell of the message is empty (making the whole message incomplete).
  */
  validate_ fields/List?=null -> none:
    is-valid_ = true
    if not fields:
      if (payload_.any: it == ""):
        is-valid_ = false
    else:
      fields.do: | cell |
        if payload_[cell] == "":
          is-valid_ = false
          return

  id -> string:
    return id_

  /** Whether this message is a poll. */
  is-poll -> bool:
    return payload_.size <= 2

  /**
  Whether this message is valid.

  Some messages will have empty fields when there is no fix.  In those cases,
    Data returned will be `null` as 0 is often a valid value.  For each child
    message definition, this function needs to be adjusted to suit its message
    content.  Some messages return fix information, some must be examined to
    see if fields are blank.

  In many circumstances this function can be tested instead of individually
    checking if each field is null.
  */
  is-valid -> bool:
    return is-valid_

  /** Whether this message is multipart. */
  is-multipart -> bool:
    return false

  /**
  Multipart message number.

  If message is multipart, $message-part[0] is this messages number, of a total
    of $message-part[1] messages.  Defaults to [1,1] as by default, messages
    are complete, and therefore do not have multiple parts.
  */
  message-part -> List:
    return [1, 1]

  /** See $super. */
  stringify -> string:
    return "NMEA-$talker-$id_"

  /** Full Message Name. */
  full-name -> string:
    return "NMEA-$talker-$id_"

  /** Provides access to raw data in all fields (parsed or not). */
  raw -> List:
    return payload_

  /** Used to create the ASCII sentence for sending on the wire. */
  to-string -> string:
    outstring := payload_.join ","
    checksum := NmeaParser.compute-checksum_ outstring
    checksum-string := "$(%02x checksum)".to-ascii-upper
    return "\$$outstring*$checksum-string"

/**
TXT: Text/status messages (firmware info, warnings, antenna status, etc).

Message is always emitted with the first cells showing multipart data (even if
  this message is comprised of only one part).  Following cell is a "severity"
  reference.
*/
class Txt extends NmeaMessage:
  static ID ::= "TXT"

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

  constructor.private_ talker/string payload/List:
    super.private_ talker ID payload
    is-valid_ = true

  is-multipart -> bool:
    return (int.parse payload_[1]) >= 2

  message-part -> List:
    return [int.parse payload_[2], int.parse payload_[1]]

  type -> int:
    return int.parse payload_[3]

  text -> string:
    return payload_[4]

  stringify -> string:
    if is-multipart:
      return  "$super: $message-part $TYPE-LOOKUP_[type]|$text"
    return  "$super: $TYPE-LOOKUP_[type]|$text"

/**
GGA: GPS fix data.

Includes lat/lon, fix quality, number of sats used, HDOP, altitude, geoid
  separation, timestamp (utc string timestamp), etc.
*/
class Gga extends NmeaMessage:
  static ID ::= "GGA"

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

  /** Creates a standard poll for GGA from the specified talker id. */
  constructor.poll --talker=NmeaParser.GPS:
    super.private_ talker "Q" ["$(talker)Q",ID]

  constructor.private_ talker/string payload/List:
    super.private_ talker ID payload
    is-valid_ = is-fix-valid

  timestamp -> string:
    return payload_[1]

  /**
  Latitude, in DDMM.MMMMM format. ($latitude-n for N/S.)
  */
  latitude -> float?:
    return float.parse payload_[2] --if-error=: null

  latitude-n -> string:
    return payload_[3]

  /**
  Longitude, in DDDMM.MMMMM format. ($longitude-e for E/W.)
  */
  longitude -> float?:
    return float.parse payload_[4] --if-error=: null

  longitude-e -> string:
    return payload_[5]

  fix-quality -> int?:
    return int.parse payload_[6] --if-error=: null

  is-fix-valid -> bool:
    return fix-quality > QUALITY-NO-FIX

  /** Number of satellites in the message. */
  satellite-count -> int?:
    return int.parse payload_[7] --if-error=: null

  /** Altitude */
  altitude -> float?:
    return float.parse payload_[9] --if-error=: null

  altitude-unit -> string:
    return payload_[10]

  /** Geoidal Height */
  geoidal-height -> float?:
    return float.parse payload_[11] --if-error=: null

  geoidal-height-unit -> string:
    return payload_[12]

  stringify -> string:
    if not is-fix-valid:
      return  "$super: fix:$QUALITY-LOOKUP_[fix-quality]"
    return  "$super: lat:$latitude($latitude-n)|long:$longitude($longitude-e)"

/**
ZDA: Date & time + local zone offset. (Some data also visible from RMC.)
*/
class Zda extends NmeaMessage:
  static ID ::= "ZDA"

  static half := Duration --ms=500
  static one  := Duration --s=1

  received-time/Time? := null
  is-valid_ := false

  /** Creates a standard poll for ZDA from the specified talker id. */
  constructor.poll --talker=NmeaParser.GPS:
    super.private_ talker "Q" ["$(talker)Q",ID]

  constructor.private_ talker/string payload/List:
    received-time = Time.now
    super.private_ talker ID payload
    validate_

  lz-hours -> int:
    return int.parse payload_[5]

  lz-minutes -> int:
    return int.parse payload_[6]

  system-time-offset -> Duration?:
    if not is-valid: return null
    if not received-time: return null
    gps-time := time
    if not gps-time: return null

    // Raw offset: GPS time - receive timestamp.
    offset := received-time.to gps-time

    // Wrap offset to the nearest representation within +/- 0.5 seconds.
    if offset < -half:
      offset += one
    else if offset > half:
      offset -= one

    return offset

  /** Time provided by GNSS. */
  time -> Time?:
    if not is-valid: return null

    t := payload_[1]  // Will be: "hhmmss", or "hhmmss.ss", or "hhmmss.sss"
    h := int.parse t[0..2]
    m := int.parse t[2..4]
    s := int.parse t[4..6]

    ms := 0
    dot-pos := t.index-of "."
    if dot-pos != -1:
      frac := t[dot-pos + 1..]
      // keep digits only, up to 3
      if frac.size > 3: frac = frac[0..3]
      // scale to milliseconds
      if frac.size == 1: ms = (int.parse frac) * 100
      else if frac.size == 2: ms = (int.parse frac) * 10
      else if frac.size == 3: ms = (int.parse frac)

    return Time.utc
      --year=(int.parse payload_[4])
      --month=(int.parse payload_[3])
      --day=(int.parse payload_[2])
      --h=h
      --m=m
      --s=s
      --ms=ms

  stringify -> string:
    if is-poll:
      return "$super: poll"
    if not is-valid:
      return "$super: time invalid"
    return  "$super: $time+$(%02b lz-hours):$(%02b lz-minutes)"

/**
VTG: Course Over Ground and Ground Speed (true/magnetic track + speed in knots/km/h).
*/
class Vtg extends NmeaMessage:
  static ID ::= "VTG"

  static POS-MODE-AUTONOMOUS ::= "A"
  static POS-MODE-ESTIMATION ::= "E"
  static POS-MODE-INVALID-DATA ::= "N"
  static POS-MODE-DIFFERENTIAL ::= "D"
  static POS-MODE-MANUAL ::= "M"
  static POS-MODE-SIMULATOR ::= "S"
  static POS-MODE-LOOKUP_ ::= {
    POS-MODE-AUTONOMOUS: "Autonomous",
    POS-MODE-ESTIMATION: "Estimation",
    POS-MODE-INVALID-DATA: "Data Invalid",
    POS-MODE-DIFFERENTIAL: "Differential",
    POS-MODE-SIMULATOR: "Simulator",
    POS-MODE-MANUAL: "Manual"
  }

  /** Creates a standard poll for VTG from the specified talker id. */
  constructor.poll --talker=NmeaParser.GPS:
    super.private_ talker "Q" ["$(talker)Q",ID]

  constructor.private_ talker/string payload/List:
    super.private_ talker ID payload
    validate_ [1, 5, 7]

  true-course -> float?:
    return float.parse payload_[1] --if-error=: null

  magnetic-course -> float?:
    return float.parse payload_[3] --if-error=: null

  speed-kts -> float?:
    return float.parse payload_[5] --if-error=: null

  speed-kmh -> float?:
    return float.parse payload_[7] --if-error=: null

  /** Value in NMEA v2.3 or later. */
  positioning-mode -> string?:
    if payload_.size >= 10:
      return payload_[9]
    return null

  stringify -> string:
    if not positioning-mode:
      return  "$super: mode:NOT PROVIDED"
    if positioning-mode == POS-MODE-INVALID-DATA or positioning-mode == POS-MODE-MANUAL:
      return  "$super: mode:$POS-MODE-LOOKUP_[positioning-mode]"
    return  "$super: mode:$POS-MODE-LOOKUP_[positioning-mode]|kmh:$(%0.0f speed-kmh)|kts:$(%0.0f speed-kts)|course:$(%0.3f true-course)"

/**
RMC: Time, date, time (UTC string timestamp), lat/lon, speed over ground, course over ground, status.
*/
class Rmc extends NmeaMessage:
  static ID ::= "RMC"

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

  /** Creates a standard poll for RMC from the specified talker id. */
  constructor.poll --talker=NmeaParser.GPS:
    super.private_ talker "Q" ["$(talker)Q",ID]

  constructor.private_ talker/string payload/List:
    super.private_ talker ID payload
    validate_

  /**
  Returns UTC timestamp of the message.

  It is provided in the message for use as a comparative reference to other
    messages.  The message does not contain the date, and therefore cannot be
    used to set the system time, or create a time object.  Use RMC, ZDA for this.
  */
  timestamp -> string?:
    if payload_[1] == "": return null
    return payload_[1]

  status -> string:
    return payload_[2]

  latitude -> float?:
    return float.parse payload_[3] --if-error=: null

  latitude-n -> string:
    return payload_[4]

  longitude -> float?:
    return float.parse payload_[5] --if-error=: null

  longitude-e -> string:
    return payload_[6]

  speed-kts -> float?:
    return float.parse payload_[7] --if-error=: null

  /** Course Over Ground. */
  course -> float?:
    return float.parse payload_[8] --if-error=: null

  positioning-mode -> string?:
    if payload_.size >= 13 and payload_[12] != "":
      return payload_[12]
    return null

  time -> Time:
    year := payload_[9] != "" ? (int.parse (payload_[9])[4..6]) : 0
    month := payload_[9] != "" ? (int.parse (payload_[9])[2..4]) : 0
    day := payload_[9] != "" ? (int.parse (payload_[9])[0..2]) : 0
    hour := int.parse (payload_[1])[0..2]
    minute := int.parse (payload_[1])[2..4]
    second := int.parse (payload_[1])[4..6]
    ms := (payload_[1].index-of ".") > -1 ? (int.parse payload_[1][7..]) : 0
    return Time.utc
      --year=year
      --month=month
      --day=day
      --h=hour
      --m=minute
      --s=second
      --ms=ms

  stringify -> string:
    output := ["$super: status:$(STATUS-LOOKUP_[status])"]
    if status == "V": return output[0]
    if positioning-mode != null: output.add "mode:$(POS-MODE-LOOKUP_[positioning-mode])"
    output.add "time:$time"
    return output.join "|"

/**
GLL: Geographic position (lat/lon + time + status).

Some data is also visible in RMC/GGA.
*/
class Gll extends NmeaMessage:
  static ID ::= "GLL"

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

  /** Creates a standard poll for GLL from the specified talker id. */
  constructor.poll --talker=NmeaParser.GPS:
    super.private_ talker "Q" ["$(talker)Q",ID]

  constructor.private_ talker/string payload/List:
    super.private_ talker ID payload
    validate_

  latitude -> float:
    return float.parse payload_[1]

  latitude-n -> string:
    return payload_[2]

  longitude -> float:
    return float.parse payload_[3]

  longitude-e -> string:
    return payload_[4]

  /**
  Returns UTC timestamp of the message.

  It is provided in the message for use as a comparative reference to other
    messages.  The message does not contain the date, and therefore cannot be
    used to set the system time, or create a time object.  Use RMC, ZDA for this.
  */
  timestamp -> string?:
    if payload_[5] == "": return null
    return payload_[5]

  /**
  */
  status -> string:
    return payload_[6]

  /** Positioning Mode. (NMEA2.3 or later.) */
  positioning-mode -> string?:
    if payload_.size >= 8 and payload_[7] != "":
      return payload_[7]
    return null

  stringify -> string:
    output := ["$super: "]
    output.add "status:$(STATUS-LOOKUP_[status])"
    if status == "V": return output.join ""
    if positioning-mode != null: output.add "|mode:$(POSITION-MODE-LOOKUP_[positioning-mode])"
    return output.join ""

/**
GSA: GNSS DOP and Active Satellites used including fix type (2D/3D).

Multiple messages may be reported if multiple systems are used for the current
  fix (GPS, GLONASS, etc), without the message without `multiple` returning
  true. The identifier will follow the convention of other messages, but field
  $system-id will indicate which system the message is providing information
  from.
*/
class Gsa extends NmeaMessage:
  static ID ::= "GSA"

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
  static SYSTEM-LOOKUP_ ::= {
    SYSTEM-ID-UNSPECIFIED: "UNSPECIFIED",
    SYSTEM-ID-GPS: "GPS",
    SYSTEM-ID-SBAS: "SBAS",
    SYSTEM-ID-GLONASS: "GLONASS",
    SYSTEM-ID-QZSS: "QZSS"
  }

  /** Creates a standard poll for GSA from the specified talker id. */
  constructor.poll --talker=NmeaParser.GPS:
    super.private_ talker "Q" ["$(talker)Q",ID]

  constructor.private_ talker/string payload/List:
    super.private_ talker ID payload
    validate_

  operation-mode -> string:
    return payload_[1]

  nav-mode -> int:
    return int.parse payload_[2]

  system-id -> string?:
    if payload_.size >= 19:
      id := int.parse payload_[18] --if-error=: SYSTEM-ID-UNSPECIFIED
      return SYSTEM-LOOKUP_[id]
    else:
      return NmeaParser.TALKER-LOOKUP_[talker]
      //return talker

  p-dop -> float:
    return float.parse payload_[15]

  h-dop -> float:
    return float.parse payload_[16]

  v-dop -> float:
    return float.parse payload_[17]

  /**
  Satellite IDs (SVIDs) used in the calculation.

  Satellite IDs are mapped to a 00-99 value to stay within specification.  PRNs
    (the actual satellite ID) are mapped/tracked differently depending on the
    manufacturer.  Use these values for comparison only, and use manufacturer
    documentation to turn these numbers into PRN's.
  */
  satellites -> List:
    blank-pos := payload_.index-of ""
    end := 15
    if blank-pos > 3:
      end = blank-pos
    return payload_[3..end]

  stringify -> string:
    sats/List := satellites.copy
    sats.remove --all ""
    sats-string/string := sats.size > 0 ? sats.join "," : "NONE"
    return  "$super: $system-id:$sats-string"

/**
GSV: GNSS Satellites in View.

GSV is not the collection of satellites that are actually used in the math, but
  rather all the satellites that can be heard in RF frequencies.  (See GSA type
  messages for satellites in use/contributing toward position.)  System is given
  in the talker type, not as a field in the message.

There may be a large number of PRNs including elevation/azimuth/SNR data.  The
  information is likely to be split across multiple messages.

Some manufacturers will produce several messages, with different talker ID's to
  show the different satellite constellations.  Other manufacturers will mix
  producing `$GNGSV` messages, with a mapping which can be used to convert to the
  PRN.  Consult your hardware vendor documentation.
*/
class Gsv extends NmeaMessage:
  static ID ::= "GSV"

  /** Creates a standard poll for GSV from the specified talker id. */
  constructor.poll --talker=NmeaParser.GPS:
    super.private_ talker "Q" ["$(talker)Q",ID]

  constructor.private_ talker/string payload/List:
    super.private_ talker ID payload
    validate_

  is-multipart -> bool:
    return true

  message-part -> List:
    return [int.parse payload_[2], int.parse payload_[1]]

  /** Number of SVs in this message. */
  num-svs -> int:
    return (payload_.size - 4) / 4

  /** Number of SVs for this talker (across all messages). */
  total-svs -> int:
    return int.parse payload_[3]

  /**
  A map SV's currently in view.

  Map uses the satellites' PRN as key, with a list containing [Elevation,
    Azimuth, SNR] as data.

  Other messages (eg GSA) map out satellite IDs to a 00-99 value to stay within
    specification.  PRNs (the actual satellite ID) are mapped/tracked
    differently depending on the manufacturer.  Before matching an SV from this
    map, convert SV's from other messages into PRN's using manufacturer
    documentation.
  */
  svs -> Map:
    out-map := {:}
    num-svs.repeat:
      num := 4 + (it * 4)
      prn := int.parse payload_[num]
      elev := float.parse payload_[num + 1] --if-error=(: null)
      az := float.parse payload_[num + 2] --if-error=(: null)
      snr := float.parse payload_[num + 3] --if-error=(: null)
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

/**
GNS: GPS fix data.

Includes timestamp, lat/lon, fix quality, number of sats used, HDOP, altitude, geoid
  separation, etc.

This message type is similar to GGA but used for multi-constellation fixes.
  Some modules will only output GNS, instead of using GGA.
*/
class Gns extends NmeaMessage:
  static ID ::= "GNS"

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

  /** Creates a standard poll for GNS from the specified talker id. */
  constructor.poll --talker=NmeaParser.GPS:
    super.private_ talker "Q" ["$(talker)Q",ID]

  constructor.private_ talker/string payload/List:
    super.private_ talker ID payload
    validate_

  /**
  Returns UTC timestamp of the message.

  It is provided in the message for use as a comparative reference to other
    messages.  The message does not contain the date, and therefore cannot be
    used to set the system time, or create a time object.  Use RMC, ZDA for this.
  */
  timestamp -> string?:
    if payload_[1] == "": return null
    return payload_[1]

  latitude -> float:
    return float.parse payload_[2]

  latitude-n -> string:
    return payload_[3]

  longitude -> float:
    return float.parse payload_[4]

  longitude-e -> string:
    return payload_[5]

  fix-quality -> int:
    return int.parse payload_[6]

  is-fix-valid -> bool:
    return fix-quality > QUALITY-NO-FIX

  /** Number of satellites in the message. */
  satellite-count -> int:
    return int.parse payload_[7]

  /**
  Horizontal Dilution-Of-Precision (DOP).

  If all satellites are clustered together, small timing errors can become
    large position errors.  A high DOP represents satellites clumped together,
    higher is worse.  It is effectively a multiplier on measurement error.
  */
  horizontal-dop -> int:
    return int.parse payload_[8]

  /** Present altitude of the receiver. */
  altitude -> float:
    return float.parse payload_[9]

  /** Geoid separation: difference between geoid and mean sea level. */
  geoidal-separation -> float:
    return float.parse payload_[10]

  /** Age (seconds) of differential corrections (null if DGPS not used). */
  differential-age -> int?:
    return int.parse payload_[11] --if-error=: null

  /** ID of station providing differential corrections (null if DGPS not used). */
  differential-station  -> int?:
    return int.parse payload_[12] --if-error=: null

  stringify -> string:
    if not is-fix-valid:
      return  "$super: fix:$QUALITY-LOOKUP_[fix-quality]"
    return  "$super: lat:$latitude($latitude-n)|long:$longitude($longitude-e)"


/**
GBS: Receiver Autonomous Integrity Monitoring Algorithm (RAIM) results.
  (Fault Detection.)

The fields $err-latitude, errLon and errAlt output the standard deviation of the
  position calculation, using all satellites which pass the RAIM test successfully.

The fields $err-latitude, errLon and errAlt are only output if the RAIM process passed
  successfully (i.e. no or successful edits happened). These fields are never
  output if 4 or fewer satellites are used for the navigation calculation
  (because, in such cases, integrity can not be determined by the receiver
  autonomously).

The fields prob, bias and stdev are only output if at least one satellite
  failed in the RAIM test. If more than one satellites fail the RAIM test, only
  the information for the worst satellite is output in this message.
*/
class Gbs extends NmeaMessage:
  static ID ::= "GBS"

  /** Creates a standard poll for GBS from the specified talker id. */
  constructor.poll --talker=NmeaParser.GPS:
    super.private_ talker "Q" ["$(talker)Q",ID]

  constructor.private_ talker/string payload/List:
    super.private_ talker ID payload
    validate_

  /**
  Returns UTC timestamp of the message.

  It is provided in the message for use as a comparative reference to other
    messages.  The message does not contain the date, and therefore cannot be
    used to set the system time, or create a time object.  Use RMC, ZDA for this.
  */
  timestamp -> string?:
    if payload_[1] == "": return null
    return payload_[1]

  /**
  Expected error in latitude (in meters).

  This value is null if RAIM failed.
  */
  err-latitude -> float?:
    return float.parse payload_[2] --if-error=: null

  /**
  Expected error in longitude (in meters).

  This value is null if RAIM failed.
  */
  err-longitude -> float?:
    return float.parse payload_[3] --if-error=: null

  /**
  Expected error in altitude (in meters).

  This value is null if RAIM failed.
  */
  err-altitude -> float?:
    return float.parse payload_[4] --if-error=: null

  /**
  SVID of most likely failed satellite.

  This value is null if _no_ satellites failed in RAIM testing.

  Satellite IDs (SVIDs) are mapped to a 00-99 value to stay within
    specification.  PRNs (the actual satellite ID) are mapped/tracked
    differently depending on the manufacturer.  Use these values for comparison
    only, and use manufacturer documentation to turn these numbers into PRN's.
  */
  svid -> int?:
    return int.parse payload_[5] --if-error=: null

  /**
  Probability of missed detection.

  This value is null if RAIM passed, or if unsupported.
  */
  probability -> float?:
    return float.parse payload_[6] --if-error=: null

  /**
  Estimate on most likely failed satellite (a priori residual).

  This value is null if RAIM passed, or if unsupported.
  */
  bias -> float?:
    return float.parse payload_[7] --if-error=: null

  /** Standard deviation (in meters).

  This value is null if RAIM passed, or if unsupported.
  */
  standard-deviation -> float?:
    return float.parse payload_[8] --if-error=: null


/**
MSS: MSK Beacon Signal Status.

Report on the status and quality of a DGPS radiobeacon signal.  The message
  exists to support legacy differential GNSS (DGPS/radiobeacon) systems.  Many
  modern GNSS modules either ignore these or implement stubs.
*/
class Mss extends NmeaMessage:
  static ID ::= "MSS"

  /** Creates a standard poll for MSS from the specified talker id. */
  constructor.poll --talker=NmeaParser.GPS:
    super.private_ talker "Q" ["$(talker)Q",ID]

  constructor.private_ talker/string payload/List:
    super.private_ talker ID payload
    validate_

  signal-strength -> float?:
    return float.parse payload_[1] --if-error=: null

  signal-to-noise-ratio -> float?:
    return float.parse payload_[2] --if-error=: null

  beacon-frequency -> float?:
    return float.parse payload_[3] --if-error=: null

  beacon-bit-rate -> int?:
    return int.parse payload_[4] --if-error=: null

  channel-number -> int?:
    return int.parse payload_[5] --if-error=: null

  stringify -> string:
    output := []
    if signal-strength: output.add "signal-strength:$(signal-strength)db"
    if beacon-frequency: output.add "beacon-frequency:$(beacon-frequency)kHz"
    if channel-number: output.add "channel-number:$(channel-number)"
    return  "$super: $(output.join ":")"

/**
GST: GNSS Pseudo Range Error Statistics.

This message reports statisical information on the quality of the position
  solution.
*/
class Gst extends NmeaMessage:
  static ID ::= "GST"

  /** Creates a standard poll for MSS from the specified talker id. */
  constructor.poll --talker=NmeaParser.GPS:
    super.private_ talker "Q" ["$(talker)Q",ID]

  constructor.private_ talker/string payload/List:
    super.private_ talker ID payload
    validate_

  /**
  Returns UTC timestamp of the message.

  It is provided in the message for use as a comparative reference to other
    messages.  The message does not contain the date, and therefore cannot be
    used to set the system time, or create a time object.  Use RMC, ZDA for this.
  */
  timestamp -> string?:
    if payload_[1] == "": return null
    return payload_[1]

  /**  RMS value of the standard deviation of the ranges (in m). */
  range-rms -> float?:
    return float.parse payload_[2] --if-error=: null

  /**  Standard deviation of semi-major axis (in m), if supported. */
  standard-major -> float?:
    return float.parse payload_[3] --if-error=: null

  /**  Standard deviation of semi-minor axis (in m), if supported. */
  standard-minor -> float?:
    return float.parse payload_[4] --if-error=: null

  /**  Orientation of the semi-major axis (in degrees), if supported. */
  orientation -> float?:
    return float.parse payload_[5] --if-error=: null

  /**  Standard Deviation of the latitude error, if supported. */
  latitude-err-standard-deviation -> float?:
    return float.parse payload_[6] --if-error=: null

  /**  Standard Deviation of the longitude error, if supported. */
  longitude-err-standard-deviation -> float?:
    return float.parse payload_[7] --if-error=: null

  /**  Standard Deviation of the altitude error, if supported. */
  altitude-err-standard-deviation -> float?:
    return float.parse payload_[8] --if-error=: null

/**
xxQ: Polls a standard message from a specific talker.

This is implemented as .poll on all the message types, although presented here
  as a variant for testing and troubleshooting.

Possible talkers as supported by device chipset, but must be one of
  the keys in NmeaParser.TALKER-LOOKUP_.
*/
class PollTalker extends NmeaMessage:
  static ID ::= "Q"

  constructor.poll --talker=NmeaParser.GPS --id/string:
    super.private_ talker ID ["$(talker)Q",id]

  stringify -> string:
    return  "$super: poll:$payload_[1]"


/**
VLW: Dual ground/water distance. (NMEA 4.00 or later)

The distance traveled, relative to the water and over the ground.
*/
class Vlw extends NmeaMessage:
  static ID ::= "VLW"

  /** Creates a standard poll for MSS from the specified talker id. */
  constructor.poll --talker=NmeaParser.GPS:
    super.private_ talker "Q" ["$(talker)Q",ID]

  constructor.private_ talker/string payload/List:
    super.private_ talker ID payload
    validate_

  twd -> float?:
    return float.parse payload_[1] --if-error=: null

  twd-unit -> string?:
    return payload_[2]

  wd -> float?:
    return float.parse payload_[3] --if-error=: null

  wd-unit -> string?:
    return payload_[4]

  tgd -> float?:
    return float.parse payload_[5] --if-error=: null

  tgd-unit -> string:
    return payload_[6]

  gd -> float?:
    return float.parse payload_[7] --if-error=: null

  gd-unit -> string?:
    return payload_[8]

/**
RLM: Return Link Message.

The RLM sentence is used to transfer a Return link message from a Cospas-Sarsat
recognized Return link service provider (RLSP).

The RLM sentence supports communications to an emitting beacon once a distress
  alert has been detected, located and confirmed. The communications may include
  acknowledgement of the alert to the emitting beacon as well as optional text
  messages, and may also include remote beacon configuration and testing.
*/
class Rlm extends NmeaMessage:
  static ID ::= "RLM"

  /** Creates a standard poll for MSS from the specified talker id. */
  constructor.poll --talker=NmeaParser.GPS:
    super.private_ talker "Q" ["$(talker)Q",ID]

  constructor.private_ talker/string payload/List:
    super.private_ talker ID payload
    validate_

  /** Beacon ID, identifies beacon intended to receive this message. */
  beacon -> int?:
    return (int.parse payload_[1] --radix=16 --if-error=: null)

  /**
  Returns UTC timestamp of the message.

  It is provided in the message for use as a comparative reference to other
    messages.  The message does not contain the date, and therefore cannot be
    used to set the system time, or create a time object.  Use RMC, ZDA for this.
  */
  timestamp -> string?:
    if payload_[2] == "": return null
    return payload_[2]

  /**
  Message code field to identify type of RLM Message.

  Service:
  - 0 = Reserved for future RLM services.
  - 1 = Acknowledgement service RLM.
  - 2 = Command service RLM.
  - 3 = Message service RLM.
  - 4-E = Reserved for future RLM services.
  - F = Test service RLM (currently used only by the Galileo program.
  */
  code -> string:
    return payload_[3]

  body -> int:
    return (int.parse payload_[4] --radix=16 --if-error=: null)

  stringify -> string:
    list := []
    list.add "beacon:$(%02x beacon)"
    list.add "timestamp:$(timestamp)"
    list.add "code:$(code)"
    list.add "body:$(%02x body)"
    return  "$super: $(list.join "|")"
