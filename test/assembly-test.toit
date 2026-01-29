import nmea-message.nmea-message show *
import nmea-message.nmea-casic-message show *
import nmea-message.nmea-ubx-message show *

main:
  nmea-parser := NmeaParser
  print "Base NmeaMessage count:       $nmea-parser.message-count"

  nmea-parser.add NmeaCasicParser.messages
  print "Base+Casic Message count:     $nmea-parser.message-count"

  nmea-parser.add NmeaUbxParser.messages
  print "Base+Casic+Ubx message count: $nmea-parser.message-count"
