# Toit Library for NMEA 0183 parsing for GNSS messages
This Toit library is to add support for NMEA 0183 messages sent by GNSS modules,
such the Ublox NEO *M and ATGM336H-5N devices.

## What is NMEA 0183?
NMEA 0183 is a long-standing text-based communication standard defined by the
National Marine Electronics Association (NMEA), for exchanging navigation and sensor
data between devices.  It specifies an ASCII, line-oriented message
format that are typically transmitted over serial links.  Messages (often called
sentences) are identified by a talker ID and a sentence formatter (for example,
position, time, velocity, or satellite status).  Although originally designed
for marine GPS receivers, NMEA 0183 is now widely used by GNSS modules across
many platforms and remains a de-facto interface for accessing positioning,
timing, and satellite information.  The latest version of the standard, 4.30,
was [published](https://www.nmea.org/uploads/1/4/0/7/140761515/nmea_0183_v430_press_release.pdf)
on 5 Jan 2024.

> [!WARNING]
> NMEA-0183 provides many other message types for other purposes. For example,
> "SafetyNet Vessel in distress information" (SMV), Search and Rescue
> capabilities (RLM), and other non GNSS related message types are not expected
> from GNSS devices and currently not implemented.

### NMEA Versions:
- BeiDou and Galileo: Only NMEA version 4.10 and later have support for these systems.
- QZSS: Only NMEA version 4.11 and later have support for this system.

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

## NMEA vs device binary parsers
NMEA is:
- human-readable
- lossy
- slow
- designed for interoperability, not completeness

Even with proprietary/vendor extensions, NMEA only provides:
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

Binary protocols exist because NMEA on its own was insufficient for applied
GNSS solutions.  It may be sufficient for many hobbyist cases that do not need
full capability, or for cheaper devices that do not have a full binary support
of their own.  In many devices, factory configurations have a set of NMEA
messages automatically sent by default.

## Example Use cases


## Usage
> [!TIP]
> An issue can arise with GNSS devices is initially having all message types
> enabled, for all satellite types - then combined with the often used default
> of a 9600 bps serial connection.  This can be too heavy a load for the low
> baudrate.  In these cases, configuration is requied to either reduce the
> message load, or, increase the baudrate.

### Multipart messages
All messages have the function `is-multipart`.  This is false by default, but is
set to true for messages that have multiple parts.  If `is-multipart` is true,
the function `message-part` will return a two member list: `message-part[0]`
returns the message's own number, and `message-part[1]` will return the total
number of expected messages.

### Proprietary messages in NMEA
The NMEA standard supports proprietary messages. This NMEA parser is designed to
accomodate the NMEA baseline, for any/all possible NMEA sentences.  Proprietary
messages can be identified by the talker code `P`, followed by some vendor
specific identifier characters and message identifiers, until the first comma.

> [!IMPORTANT]
> In order to not have one sprawling parser supporting many devices when a
> project would usually only have one GNSS device physically attached,
> proprietary parser libraries are provided separately.  Whilst some of the
> code may be similar between them, they are designed not to be dependent on
> eachother.

Example: A CASIC message for setting the baud rate to 115200 bps looks like this:
```Toit
$PCAS01,5*19
```

In this case, support for is provided by `toit-casic-message` parser library.
The main driver for the device is expected to identify messages starting with
`$PCAS`, and pass them to `toit-casic-message`.  Remaining messages starting
with `$` can be passed to the NMEA library, `toit-nmea-message`.

Using this method, a device supporting say, both UBX and NMEA messages, could
have just the `ubx-message` and `nmea-message` libraries implemented, and a
ATGM336H driver can have the `nmea-message` and `casic-message` parsers
implemented.

### NMEA message libraries:
| Identifier | Vendor/Protocol | Library | Example Modules |
| - | - | - | - |
| `$nnxxx`  | NMEA 0183 standard   | `toit-nmea-message` <br> *This driver* | Many/most modules  |
| `$PCASxx` | CASIC (proprietary)  | `toit-casic-nmea-message` | - ATGM336H <br> - AT6558 Silicon |
| `$PUBX`   | uBlox (proprietary)  | in development | untested |
| `$PGRME`  | Garmin (proprietary) | in-development | untested |
| `$PSRF`   | SiRF (proprietary)   | in-development | untested |


> [!WARNING]
> The driver aims to have the widest capability.  For example, if you have a
> clone device that supports smaller ranges, the driver may have options
> available that the device may not practically support, for example, a smaller
> set of update speeds, or lower baud rates.  Check your datasheet when coding
> configurations.

## Caveats
Driver initially developed using ATGM336H 5N-31 C92310, a GNSS+GPS+BD based
device.  It supports only 6 NMEA message types (GGA,GLL,GSA,GSV,RMC,
VTG,ZDA,TXT), but supports CASIC proprietary NMEA messages for configuration,
and the CASIC binary message format.
Other types of devices have had less testing so far.  Please log an
[issue](./issues) for assistance in adding more.

## Links:
I found the following links extremely useful whilst creating this:
- https://www.nmea.org/nmea-0183.html
- https://gpsd.gitlab.io/gpsd/NMEA.html
- https://cgit.osmocom.org/osmo-e1-hardware/plain/hardware/icE1usb/components

## Credits
This work is an implementation which uses the same core techniques as used in
the Toit [ubx-message](https://github.com/toitware/ubx-message) parser.
