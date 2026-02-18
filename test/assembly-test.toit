// Copyright (C) 2025 Toit contributors.
// Use of this source code is governed by a MIT-style license that can be found
// in the LICENSE file.

import nmea-message.nmea-message show *
import nmea-message.nmea-casic-message show *
import nmea-message.nmea-ubx-message show *
import nmea-message.nmea-srf-message show *
import nmea-message.nmea-garmin-message show *

main:
  print

  nmea-parser := NmeaParser
  print "Base NmeaMessage count:  $nmea-parser.registry.size"

  nmea-parser.add NmeaCasicParser.MESSAGES
  print "+Casic message count:    $nmea-parser.registry.size"

  nmea-parser.add NmeaUbxParser.MESSAGES
  print "+Ubx   message count:    $nmea-parser.registry.size"

  nmea-parser.add NmeaSrfParser.MESSAGES
  print "+PSrf  message count:    $nmea-parser.registry.size"

  nmea-parser.add NmeaGarminParser.MESSAGES
  print "+PGrm  message count:    $nmea-parser.registry.size"

  print
  print "List of all message types ($nmea-parser.registry.size): "
  nmea-parser.registry.keys.do:
    print " - $it"
