// Copyright (C) 2025 Toit contributors.
// Use of this source code is governed by a MIT-style license that can be found
// in the LICENSE file.

import nmea-message show *

/**
Example of converting GNSS native forms of Lat/Long to methematical form.

Most GNSS devices will natively use degrees-minutes N/S|E/W.  However, maps
  math libraries typically want a single floating point number.  The number
  will be -90 <= x <= 90, with with North = +ve, South = -ve and East = +ve,
  West = -ve.

Exmaple shows conversion of a static GGA message.
*/

main:
  nmea-parser := NmeaParser

  gga-message-string := "\$GPGGA,144158.00,0927.68263,N,10002.64614,E,2,08,0.84,7.9,M,-23.9,M,,0000*7A"
  gga-message/Gga := (nmea-parser.from-string gga-message-string) as Gga

  lat-degrees/float := NmeaParser.dm-to-degrees gga-message.latitude gga-message.latitude-n
  lon-degrees/float := NmeaParser.dm-to-degrees gga-message.longitude gga-message.longitude-e

  print "Latitude: $gga-message.latitude($gga-message.latitude-n) = $lat-degrees"
  print "Longitude: $gga-message.longitude($gga-message.longitude-e) = $lon-degrees"
