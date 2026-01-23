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
> capabilities (RLM), and other non GNSS related message types are not yet
> implemented.

## What is NMEA 2000?  Why not use this instead?
For comparison, NMEA 2000 is a modern marine networking standard (also defined
by the NMEA) that uses a CAN-bus–based, binary message protocol to exchange
navigation and sensor data between devices on a shared network. Unlike NMEA
0183, which is a text-based, point-to-point serial format, NMEA 2000 is
packetized, multi-drop, higher bandwidth, and designed for robust system
integration; conceptually it carries much of the same information as NMEA 0183,
but in a structured binary form rather than human-readable sentences.  It has
largely replaced NMEA 0183 for onboard marine networking, while NMEA 0183
remains common at the edges of systems (simple GPS modules, legacy devices,
low-cost sensors).

## Usage
> [!TIP]
> The main issues that arise with cheap GNSS devices is having all message types
> for all satellite types enabled, with the often used default of 9600 bps
> Serial connection.  This can be too heavy a load for the default 9600 bps
> baudrate, so often, configuration is requied.

### Message support
This NMEA parser is designed to have any/all possible NMEA sentences (message
types) added.  The standard provides the facility for proprietary message types
to be added.  These can be identified by the initial character `P`, such as this
CASIC message for increasing baud rate to 115200 bps:
```Toit
$PCAS01,5*19
```
The NMEA standard supports proprietary messages.  In this case, support for these is provided by additional parser libraries.  The driver for the device is expected to identify the message and pass it to the correct parser:
- `$P` prefix, and `CAS` identifies the CASIC parser.
- In this case the message type is `01` and the data `5`.
- The `*19` is the checksum (an XOR of the characters before the `*`)

Using this method, a device supporting say, UBX and NMEA messages, could have
these libraries implemented, and a ATGM336H driver could have the NMEA and CASIC
parsers implemented.

## Caveats
Driver initially developed using ATGM336H 5N-31 C92310, a GNSS+GPS+BD based device.

## Links:
I found the following links extremely useful whilst creating this:
- https://www.nmea.org/nmea-0183.html
- https://gpsd.gitlab.io/gpsd/NMEA.html

## Credits
This work is an implementation which uses the same core techniques as used in
the Toit [ubx-message](https://github.com/toitware/ubx-message) parser.  UBX is
a proprietary, but widely used protocol.
