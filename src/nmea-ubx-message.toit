import io
import io show LITTLE-ENDIAN
import reader as old-reader
import .nmea-message


class NmeaUbxParser:
  // Talker IDs:
  static PROPRIETARY ::= "P" // Proprietary type, sole supported in this library.

  // Message IDs:
  static PUBX00 ::= "CAS00" // Save config to flash.
