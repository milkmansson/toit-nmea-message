import nmea-message.nmea-message show *
import nmea-message.nmea-casic-message show *
import nmea-message.nmea-ubx-message show *
import nmea-message.nmea-sirf-message show *
import nmea-message.nmea-garmin-message show *

main:
  print

  nmea-parser := NmeaParser
  print "Base NmeaMessage count:  $nmea-parser.message-count"

  nmea-parser.add NmeaCasicParser.messages
  print "+Casic message count:    $nmea-parser.message-count"

  nmea-parser.add NmeaUbxParser.messages
  print "+Ubx   message count:    $nmea-parser.message-count"

  nmea-parser.add NmeaSrfParser.messages
  print "+PSrf  message count:    $nmea-parser.message-count"

  nmea-parser.add NmeaGarminParser.messages
  print "+PGrm  message count:    $nmea-parser.message-count"

  print
  print "List of all message types ($nmea-parser.message-count): "
  nmea-parser.registry.keys.do:
    print " - $it"

