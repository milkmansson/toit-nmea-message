import nmea-message.nmea-message show *
import nmea-message.nmea-casic-message show *
import nmea-message.nmea-ubx-message show *

main:
  nmea-parser := NmeaParser
  print "started: $nmea-parser.message-count"

  nmea-parser.add NmeaCasicParser.messages
  print "now: $nmea-parser.message-count"

  nmea-parser.add NmeaUbxParser.messages
  print "now: $nmea-parser.message-count"
