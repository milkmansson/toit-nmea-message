# Toit Library for NMEA 0183 parsing for GNSS messages
This Toit library is to add support for NMEA 0183 messages sent by most GNSS
modules, such as the Ublox NEO *M, SiRF, and ATGM336H-5N devices.  It is
designed to be extensible, in order to add proprietary NMEA message types.
Several libraries of proprietary NMEA message types are supplied in the package,
as well as opportunities for user-supplied message types.

> [!INFORMATION]
> This parser is designed for use with the generic
> [GNSS driver](https://github.com/milkmansson/toit-gnss-driver).  Please see
> this project for implementation examples.

## What is NMEA 0183?
NMEA 0183 is a long-standing text-based communication standard defined by the
National Marine Electronics Association (NMEA), for exchanging navigation and
sensor data between devices.  It specifies an ASCII, line-oriented message
format that are typically transmitted over serial links.  Messages (often called
sentences) are identified by a talker ID and a sentence formatter (for example,
position, time, velocity, or satellite status).  Although originally designed
for marine GPS receivers, NMEA 0183 is now widely used by GNSS modules across
many platforms and remains a de-facto interface for accessing positioning,
timing, and satellite information.  The latest version of the standard, 4.30,
was [published](https://www.nmea.org/uploads/1/4/0/7/140761515/nmea_0183_v430_press_release.pdf)
on 5 Jan 2024.

> [!WARNING]
> NMEA-0183 provides many other message types for other purposes.  For example,
> "SafetyNet Vessel in distress information" (SMV), Search and Rescue
> capabilities (RLM) are valid NMEA 0183 messages, but not related to GNSS, and
> are not implementd as they are not expected to be emitted from GNSS devices.
>
> Despite not being implemented, this pasrser could be extended to support
> these types if/when use cases appear.

### NMEA Versions:
What matters is the version of NMEA that is output from the device - many
devices are not user upgradeable.  To give an idea, if your device supports the
following, the (minimum) NMEA version that the device speaks will
likely be:
- GPS/SBAS: NMEA 2.3+
- GLONASS: NMEA 2.3+
- BeiDou: Only NMEA version 4.10 and later have support for Beidou.
- Galileo: (Officially) Only since NMEA version 4.11.
- QZSS: Only NMEA version 4.11 and later have support for QZSS.

Updates to NMEA versions typically either add new fields to the end of existing
sentences, stop putting data into existing fields, or change the meaning of some
outputs.  To illustrate, the main differences between NMEA 2.2 and 2.3/4.0 are:
- The item of positioning mode (Mode) is no longer included in GLL, RMC and VTG
sentences.
- For the positioning quality (FS) field in the GGA sentence, 1 is used for both
dead reckoning and normal positioning.

Aside from the additional systems supported, NMEA 4.1 adds some fields based on 4.0:
- Adding a `systemId` field to the GSA message.
- Adding a `signalId` field to the GSV message.
- Adding a `navStatus` field to the RMC message.

For reasons associated with these points, this driver:
- Stores the entire sentence per message, even if the driver doesn't naturally
provide access via a specific method for the required information.  This (raw)
data can be accessed using `.raw` on all message types.  This is a view to the
data payload, and an interesting field in the message can be accessed using
`message.raw[xx]`.
- Before a fix is ready, data may not be available for a field in a given
message.  (This is also possible if NMEA version dictates support for a field
is removed, or if a device doesn't provide that data.)  If there is no data in
a field in a given message, output will be `null` for numeric fields, or ""
(empty string) for string fields.

## What is NMEA 2000?  Why not use this instead?
For comparison, NMEA 2000 is a modern marine standard (also defined by the NMEA)
that uses a CAN-bus–based, binary message protocol to exchange navigation/sensor
data between devices on a shared network.  Unlike NMEA 0183, which is a
text-based, point-to-point serial format, NMEA 2000 is packetized, multi-drop,
higher bandwidth, and designed for robust system integration.  Conceptually it
carries same information as NMEA 0183, but in a structured binary form rather
than pseudo-human-readable sentences.  It has largely replaced NMEA 0183 for
onboard marine networking, while NMEA 0183 remains common at the edges of
systems (simple GPS modules, legacy devices, low-cost sensors).

## What is a binary parser? Why not use that instead?
Using the binary parser for the specific device is completely possible. To
compare, NMEA is:
- human-readable
- lossy
- slow
- designed for interoperability, not completeness

Even with proprietary/vendor extensions, NMEA provides:
- position / velocity / time
- fix quality
- limited satellite info
- some diagnostics

NMEA does not reliably provide:
- raw measurements (pseudorange, carrier phase)
- precise timing data
- detailed receiver state
- power / RF diagnostics
- configuration introspection
- high-rate output (>10 Hz without pain)

Binary protocols provide:
- full receiver state
- precise time
- raw measurements
- rich satellite info
- configuration control
- high-rate binary data
- deterministic framing
- full capabilities as provided by the manufacturer.

Binary protocols exist because NMEA on its own was insufficient for _applied_
GNSS solutions.  That said, NMEA may well be sufficient for many hobbyist cases
that do not need full capability.  Cheaper simpler devices also may not have a
full featured binary protocol of their own.  In addition, factory configurations
in many devices have a set of NMEA messages automatically sent by default.

In most cases, a device requires either vendor proprietary NMEA commands for any
kind of configuration (the purpose of this package) or a full binary protocol
implementation.  Binary implementations may not exist for your device.  Search
on the [Toit package registry](http://pkg.toit.io).

## Example Use cases


## Usage
> [!TIP]
> An issue that can arise with GNSS devices is having all message types
> enabled, for all satellite types - then combined with the often used default
> of a 9600 bps serial connection.  This can be too heavy a load for the low
> baudrate.  In these cases, configuration is requied to either reduce the
> message load, or, increase the baudrate.

### Lat/Lon output
According to the NMEA standard, latitude and longitude are output in the format
**degrees, minutes and (decimal) fractions of minutes**. To convert to degrees and
fractions of degrees, or degrees, minutes, seconds and fractions of seconds, the
minutes and fractional minutes parts need to be converted.  The main NmeaParser
library contains a helper function for conversion to degrees/fractions of
degrees:
```Toit
// Create parser object:
nmea-parser := NmeaParser

// For this exercise, take a GGA string with lat and lon in it:
gga-message-string := "\$GPGGA,144158.00,0927.68263,N,10002.64614,E,2,08,0.84,7.9,M,-23.9,M,,0000*7A"

// Parse the GGA string into a message object:
gga-message/Gga := (nmea-parser.from-string gga-message-string) as Gga

// Use the converter:
lat-degrees/float := NmeaParser.dm-to-degrees gga-message.latitude gga-message.latitude-n
lon-degrees/float := NmeaParser.dm-to-degrees gga-message.longitude gga-message.longitude-e

// Print to show differences:
print "Latitude:  $gga-message.latitude($gga-message.latitude-n) = $lat-degrees"
print "Longitude: $gga-message.longitude($gga-message.longitude-e) = $lon-degrees"

// results in:
// Latitude:  927.68263000000001739(N) = 9.4613771666666668381
// Longitude: 10002.646140000000742(E) = 100.0441023333333419
```
(This example uses a static text message to demonstrate the conversion.  Under
normal circumstances the driver would obtain the GGA messages from the GNSS
device.)

### Multipart messages
All messages have the function `is-multipart`.  This is false by default, but is
set to true for messages that have multiple parts.  If `is-multipart` is true,
the function `message-part` will return a two member list: `message-part[0]`
returns the message's own number, and `message-part[1]` will return the total
number of expected messages.

### Proprietary NMEA messages
The NMEA standard supports proprietary messages. This NMEA parser accomodates a
baseline of NMEA sentences.  Proprietary messages (identified by the talker code
`P` followed by some vendor specific identifier characters) can be added to the
parser registry, using the extensions provided with this package, and/or
user created extensions.

> [!IMPORTANT]
> In order to not have one sprawling parser supporting many devices when a
> project would usually only have one GNSS device physically attached,
> proprietary parser libraries are provided as extensions.

Example: Initialise the library, add the extension for UBX proprietary messages.
Display the difference of recognised messages, before and after adding the
extension:
```Toit
// Initial setup omitted, see Examples.
nmea-parser := NmeaParser
print "Base NmeaMessage count:  $nmea-parser.registry.size"
print "Supported Messages:      $nmea-parser.registry.keys"

// Add UBX messages to active NMEA parser/registry.
nmea-parser.add NmeaUbxParser.MESSAGES
print "+UBX message count:      $nmea-parser.registry.size"
print "+UBX Supported Messages: $nmea-parser.registry.keys"
```
In this way, the code used for all supported devices does not need to be
imported/downloaded to the ESP32 when using just one device type.

### NMEA message libraries:
| Identifier | Vendor/Protocol | Import library | Modules |
| - | - | -  | - |
| `$nnxxx`   | NMEA 0183 standard   | `nmea-message` | Base parser/library, with common message types.  Many/most modules support these NMEA messages.  |
| `$PCASxx`  | CASIC (proprietary)  | `nmea-casic-message` | - ATGM336H <br> - AT6558 Silicon |
| `$PUBX,xx` | uBlox (proprietary)  | `nmea-ubx-message` | - Ubx NEO M6,M7,etc <br> - Other UBX Compatible |
| `$PGRMx`   | Garmin (proprietary) | `nmea-grm-message` | untested |
| `$PSRFxx`  | SiRF (proprietary)   | `nmea-srf-message` | untested |


> [!WARNING]
> The driver aims to have the widest capability.  For example, if you have a
> clone device that supports fewer options, the driver will not know and will
> likely allow options that your device may not support.  (eg, this
> package may allow a baud rate in a configuration message that your device
> does not allow.)  Check your datasheet when coding configurations.

## Caveats
Driver initially developed using
- ATGM336H 5N-31 C92310, a GPS/SBAS/QZSS/GLONASS/Beidou based device.  Supports
8 NMEA message types (GGA,GLL,GSA,GSV,RMC,VTG,ZDA,TXT) and has up to 12
(depending on firmware) proprietary types.  It supports the CASIC binary message
format.
- Ublox NEO 7M, a GPS/QZSS/GLONASS device. Supports 16 NMEA messages and 5
proprietary NMEA messages, alongside UBX's proprietary binary message format.
- Other types of devices have had less testing so far.  Please log an
[issue](./issues) for assistance in adding more.

## Links:
I found the following links extremely useful whilst creating this:
- https://www.nmea.org/nmea-0183.html
- https://gpsd.gitlab.io/gpsd/NMEA.html
- https://cgit.osmocom.org/osmo-e1-hardware/plain/hardware/icE1usb/components

## Credits
This work is an implementation which uses the same core techniques as used in
the Toit [ubx-message](https://github.com/toitware/ubx-message) parser.
