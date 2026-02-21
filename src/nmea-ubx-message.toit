// Copyright (C) 2025 Toit contributors.
// Use of this source code is governed by a MIT-style license that can be found
// in the LICENSE file.

import .nmea-message

/**
uBlox GNSS priprietary NMEA message extension for the NMEA Parser.

Ublox receivers using the NMEA Protocol support proprietary NMEA messages,
  prefixed with 'P', in the form `$PUBX,xx`.  Contrary to some other vendor
  messages, in uBlox messages, the first cell after the proprietary name is the
  message type identifier.

Support for the binary UBX protocol is given in a different driver.
*/

class NmeaUbxParser:
  static MESSAGES/Map := {
    "P$Ubx00.ID": :: | talker payload | Ubx00.private_ payload,
    "P$Ubx03.ID": :: | talker payload | Ubx03.private_ payload,
    "P$Ubx04.ID": :: | talker payload | Ubx04.private_ payload,
    // P$UBX,40 cannot be polled for and is not emitted. (Use .set constructor.)
    // P$UBX,41 cannot be polled for and is not emitted. (Use .set constructor.)
  }


/**
PUBX00: uBlox position/navigation solution.
*/
class Ubx00 extends NmeaMessage:
  static ID ::= "UBX,00"

  static STATUS-NO-FIX ::= "NF"
  static STATUS-DEAD-RECKONING ::= "DR"
  static STATUS-STANDALONE-2D ::= "G2"
  static STATUS-STANDALONE-3D ::= "G3"
  static STATUS-DIFFERENTIAL-2D ::= "D2"
  static STATUS-DIFFERENTIAL-3D ::= "D3"
  static STATUS-COMBINED-GPS-DR ::= "RK"
  static STATUS-TIME-ONLY ::= "TT"
  static STATUS-LOOKUP_ ::= {
    STATUS-NO-FIX: "No Fix",
    STATUS-DEAD-RECKONING: "Dead Reckoning",
    STATUS-STANDALONE-2D: "Standalone 2D",
    STATUS-STANDALONE-3D: "Standalone 3D",
    STATUS-DIFFERENTIAL-2D: "Differential 2D",
    STATUS-DIFFERENTIAL-3D: "Differential 3D",
    STATUS-COMBINED-GPS-DR: "Combined GPS Dead Reckoning",
    STATUS-TIME-ONLY: "Time Only",
  }

  /** Message content asks the receiver for a UBX00 with data. */
  constructor.poll:
    super.private_ "P" ID ["PUBX","00"]

  /** Not expected - leaving here until test of this function. */
  constructor.private_ payload/List:
    super.private_ "P" ID payload

  /** Whether this message is a poll message. */
  is-poll -> bool:
    return payload_.size < 3

  /**
  Returns UTC timestamp of the message.

  It is provided in the message for use as a comparative reference to other
    messages.  The message does not contain the date, and therefore cannot be
    used to set the system time, or create a time object.  Use RMC, ZDA
    or PUBX,04 for this.
  */
  timestamp -> string?:
    if payload_[2] == "": return null
    return payload_[2]

  latitude -> float:
    return float.parse payload_[3]

  latitude-n -> string:
    return payload_[4]

  longitude -> float:
    return float.parse payload_[5]

  longitude-e -> string:
    return payload_[6]

  altitude -> float:
    return float.parse payload_[7]

  nav-status -> string:
    return payload_[8]

  h-accuracy -> float:
    return float.parse payload_[9]

  v-accuracy -> float:
    return float.parse payload_[10]

  speed-over-ground -> float:
    return float.parse payload_[11] --if-error=: 0.0

  course-over-ground -> float:
    return float.parse payload_[12] --if-error=: 0.0

  vertical-velocity -> float:
    return float.parse payload_[13] --if-error=: 0.0

  h-dop -> float:
    return float.parse payload_[15] --if-error=: 0.0

  v-dop -> float:
    return float.parse payload_[16] --if-error=: 0.0

  t-dop -> float:
    return float.parse payload_[17] --if-error=: 0.0

  num-svs -> int:
    return int.parse payload_[18] --if-error=: 0

  stringify -> string:
    if is-poll:
      return "$super: poll"
    list := []
    list.add "lat:$latitude($latitude-n)"
    list.add "lon:$longitude($longitude-e)"
    list.add "accuracy:$(%0.3f h-accuracy)/$(%0.3f v-accuracy)"
    return  "$super: $(list.join "|")"


/**
PUBX03: Contains satellite status information.
*/
class Ubx03 extends NmeaMessage:
  static ID ::= "UBX,03"
  satellites_/List := []

  /** Message content asks the receiver for a UBX03 with data. */
  constructor.poll:
    super.private_ "P" ID ["PUBX","03"]

  constructor.private_ payload/List:
    super.private_ "P" ID payload
    satellites_ = satellite-ids
    if payload_.size < (num-svs * 6) + 3:
      throw "not enough fields for this many sattelites"

  /** Whether this message is a poll message. */
  is-poll -> bool:
    return payload_.size < 3

  /** Number of satellites tracked. */
  num-svs -> int:
    return int.parse payload_[2] --if-error=: 0

  /** List of tracked satellites. */
  satellite-ids -> List:
    svs := num-svs
    if num-svs < 1:
      return []
    sats := List num-svs
    num-svs.repeat: | entry |
      ref := 3 + (entry * 6)
      //print "$entry $ref"
      sats[entry] = payload_[ref]
    return sats

  /** Status of a tracked satellite. */
  satellite-status satellite/int -> string:
    if satellites_.contains satellite:
      entry := satellites_.index-of satellite
      ref := 4 + (entry * 6)
      return payload_[ref]
    return ""

  /** Azimuth of a tracked satellite. */
  satellite-azimuth satellite/int -> float?:
    if satellites_.contains satellite:
      entry := satellites_.index-of satellite
      ref := 5 + (entry * 6)
      return float.parse payload_[ref] --if-error=: null
    return null

  /** Elevation of a tracked satellite. */
  satellite-elevation satellite/int -> float?:
    if satellites_.contains satellite:
      entry := satellites_.index-of satellite
      ref := 6 + (entry * 6)
      return float.parse payload_[ref]  --if-error=: null
    return null

  /** Signal Strength of a tracked satellite. */
  satellite-cno satellite/int -> float?:
    if satellites_.contains satellite:
      entry := satellites_.index-of satellite
      ref := 7 + (entry * 6)
      return float.parse payload_[ref]  --if-error=: null
    return null

  /** Lock time of a tracked satellite. */
  satellite-lock satellite/int -> float?:
    satellites := satellite-ids
    if satellites.contains satellite:
      entry := satellites.index-of satellite
      ref := 8 + (entry * 6)
      return float.parse payload_[ref]  --if-error=: null
    return null

  stringify -> string:
    if is-poll:
      return "$super: poll"
    if num-svs == 0:
      return "$super: sats:NONE"
    return  "$super: sats($num-svs):$(satellites_.join ",")"


/**
PUBX04: Time/clock information.

Gives information on precise time, logging, synchronization, and PPS alignment.
  It is much better than standard NMEA time fields in that it is both
  more accurate, and fully featured (clock validity, leap second data, etc).
*/
class Ubx04 extends NmeaMessage:
  static ID ::= "UBX,04"

  constructor.poll:
    super.private_  "P" ID ["PUBX","04"]

  constructor.private_ payload/List:
    super.private_  "P" ID payload

  /** Whether this message is a poll message. */
  is-poll -> bool:
    return payload_.size < 3

  /**
  Returns the UTC time.
  */
  time -> Time?:
    if payload_[3] == "" or payload_[2] == "":
      return null
    return Time.utc
      --year=(int.parse (payload_[3][4..]))
      --month=(int.parse (payload_[3][2..4]))
      --day=(int.parse (payload_[3][0..2]))
      --h=(int.parse (payload_[2])[0..2])
      --m=(int.parse (payload_[2])[2..4])
      --s=(int.parse (payload_[2])[4..6])
      --ms=(int.parse (payload_[2])[7..] --if-error=: 0)

  /**
  Returns the UTC time of week.

  See Receiver documentation for the meaning of this value.  GPS time is sent as
    the number of seconds since the previous sunday midnight.
  */
  time-of-week -> float?:
    return float.parse payload_[4] --if-error=: null

  week-number -> int?:
    return int.parse payload_[5] --if-error=: null

  is-leap-seconds-default -> bool:
    return payload_[6].contains "D" ? true : false

  /**
  Returns the number of leap seconds.

  If the value is the firmware default, $is-leap-seconds-default will be true.
    If $is-leap-seconds-default is false, the valuehas been received from a
    satellite.
  */
  leap-seconds -> int?:
    return int.parse (payload_[6].replace "D" "") --if-error=: null

  /**
  Gives current clock bias.

  Clock Bias is an estimate of far off the receiver’s clock is from the actual
    time given by the satellites.

  If $clock-bias is 'how late am I?' then $clock-drift is 'how fast am I becoming
    later?'
  */
  clock-bias -> int?:
    return int.parse payload_[7] --if-error=: null

  /**
  Gives current clock drift.

  Clock drift is how fast the clock bias is changing.

  If $clock-bias is 'how late am I?' then $clock-drift is 'how fast am I becoming
    later?'
  */
  clock-drift -> float?:
    return float.parse payload_[8] --if-error=: null

  /**
  Returns the Time-Pulse granularity, in ns.

  This is the quantization error of the TIMEPULSE pin.
  */
  time-pulse-granularity -> int?:
    return int.parse payload_[8] --if-error=: null

  stringify -> string:
    if is-poll:
      return "$super: poll"
    list:= ["time:$time"]
    list.add "bias:$clock-bias"
    list.add "drift:$clock-drift"
    return  "$super: $(list.join "|")"


/**
PUBX40: RATE. Set NMEA message output rates etc.

End rate is relative to the event a message is registered on. For example, if
  the rate of a navigation message is set to 2, the message is sent every second
  navigation solution.
*/
class Ubx40 extends NmeaMessage:
  static ID ::= "UBX,40"

  static FIELD-DDC_ ::= 3
  static FIELD-UART1_ ::= 4
  static FIELD-UART2_ ::= 5
  static FIELD-USB_ ::= 6
  static FIELD-SPI_ ::= 7
  static FIELD-LOOKUP_ ::= {
    FIELD-DDC_: "DDC",
    FIELD-UART1_: "UART1",
    FIELD-UART2_: "UART2",
    FIELD-USB_: "USB",
    FIELD-SPI_: "SPI"
  }

  // Cannot be polled for?
  constructor.poll:
    super.private_  "P" ID ["PUBX","40"]

  constructor.set type/string
      --ddc-rate/int?=null
      --uart1-rate/int?=null
      --uart2-rate/int?=null
      --usb-rate/int?=null
      --spi-rate/int?=null:
    fields := List 9
    fields[0] = "PUBX"
    fields[1] = "40"
    fields[2] = "$type"  // todo: put a guard on this to an NMEA type?
    fields[FIELD-DDC_] = ddc-rate ? ddc-rate : ""
    fields[FIELD-UART1_] = uart1-rate ? uart1-rate : ""
    fields[FIELD-UART2_] = uart2-rate ? uart2-rate : ""
    fields[FIELD-USB_] = usb-rate ? usb-rate : ""
    fields[FIELD-SPI_] = spi-rate ? spi-rate : ""
    fields[8] = "0"
    super.private_ "P" ID fields

  constructor.private_ payload/List:
    super.private_  "P" ID payload

  type -> string:
    return payload_[2]

  stringify -> string:
    list := []
    FIELD-LOOKUP_.keys.do:
      if payload_[it] == 1: list += FIELD-LOOKUP_[it]
    return  "$super: msgid:$type|$(list.join ",")"

/**
PUBX41: Set protocols and baud rates.
*/
class Ubx41 extends NmeaMessage:
  static ID ::= "UBX,41"

  static PORT-DDC ::= 0 // I2C
  static PORT-I2C ::= PORT-DDC
  static PORT-UART1 ::= 1
  static PORT-UART2 ::= 2
  static PORT-USB ::= 3
  static PORT-SPI ::= 4
  static PORT-LOOKUP_ ::= {
    PORT-DDC: "DDC",
    PORT-UART1: "UART1",
    PORT-UART2: "UART2",
    PORT-USB: "USB",
    PORT-SPI: "SPI"
  }

  static PROTO-RTCM ::= 0b0100
  static PROTO-NMEA ::= 0b0010
  static PROTO-UBX  ::= 0b0001
  static LOOKUP-PROTO_  ::= {
    PROTO-RTCM: "RTCM",
    PROTO-NMEA: "NMEA",
    PROTO-UBX: "UBX",
  }

  constructor.set port-id/int
      --in-proto=null
      --out-proto=null
      --baud-rate/int?=null
      --auto-baud/bool=false:   // Autobaud not supported on ublox 5.
    assert: PORT-LOOKUP_.contains port-id
    fields := List 7
    fields[0] = "PUBX"
    fields[1] = "41"
    fields[2] = port-id
    fields[3] = in-proto != null ? "$(%04x in-proto)" : ""
    fields[4] = out-proto != null ? "$(%04x out-proto)" : ""
    fields[5] = baud-rate != null ? baud-rate : ""
    fields[6] = auto-baud ? 1 : 0
    super.private_ "P" ID fields

  stringify -> string:
    list := []
    if payload_[2] != "": list.add "port-id:$(payload_[2])"
    if payload_[3] != "": list.add "in-proto:$(payload_[3])"
    if payload_[4] != "": list.add "out-proto:$(payload_[4])"
    if payload_[5] != "": list.add "baud-rate:$(payload_[5])"
    if payload_[6] != "": list.add "auto-baud:$(payload_[6] == 1 ? true : false)"
    return  "$super: $(list.join "|")"
