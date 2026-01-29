import nmea-message.nmea-message show *
import nmea-message.nmea-casic-message show *

main:
  nmea-parser := Nmea-parser
  print "started: $nmea-parser.message-count"

  nmea-parser.add Casic-nmea-parser.messages
  print "now: $nmea-parser.message-count"
