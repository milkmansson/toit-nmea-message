import nmea-message.nmea-message show *
import nmea-message.nmea-casic-message show *
import nmea-message.nmea-ubx-message show *
import nmea-message.nmea-sirf-message show *

main:
  nmea-parser := NmeaParser
  print "Base NmeaMessage count: $nmea-parser.message-count"

  nmea-parser.add NmeaCasicParser.messages
  print "+Casic message count:   $nmea-parser.message-count"

  nmea-parser.add NmeaUbxParser.messages
  print "+Ubx message count:     $nmea-parser.message-count"

  nmea-parser.add NmeaSrfParser.messages
  print "+PSrf message count:    $nmea-parser.message-count"
