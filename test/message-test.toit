// Copyright (C) 2025 Toit contributors.
// Use of this source code is governed by a MIT-style license that can be found
// in the LICENSE file.

import nmea-message

/**
Some good and broken messages to test the parser against.
*/

// GOOD

// Minimal NMEA.
MINIMAL-GLL := "\$GPGLL,4916.45,N,12311.12,W,225444,A,*1D"

// Short: Basic RMC.
SHORT-RMC := "\$GPRMC,225446,A,4916.45,N,12311.12,W,000.5,054.7,191194,020.3,E*68"

// Medium: GGA - Altitude and fix info.
MEDIUM-GGA := "\$GPGGA,123519,4807.038,N,01131.000,E,1,08,0.9,545.4,M,46.9,M,,*47"

// Medium: VTG - Velocity Only.
MEDIUM-VTG := "\$GPVTG,054.7,T,034.4,M,005.5,N,010.2,K*48"

// Medium Long: ZDA Date and time.
LONG-ZDA := "\$GPZDA,201530.00,04,07,2002,00,00*60"

// Long: GSV Multipart #1.
LONG-GSV-1 := "\$GPGSV,3,1,11,07,79,048,42,08,62,308,45,10,51,176,43,13,32,092,41*71"
// Long: GSV Multipart #2.
LONG-GSV-2 := "\$GPGSV,3,2,11,15,21,315,39,18,18,270,37,20,12,020,35,23,09,180,33*77"
// Long: GSV Multipart #3.
LONG-GSV-3 := "\$GPGSV,3,3,11,27,05,045,30,30,02,120,28,32,01,250,25*43"

// Long: Proprietary UBX Nav Solution.
LONG-PUBX00 := "\$PUBX,00,123519,4807.038,N,01131.000,E,545.4,G3,2.5,3.1,0.0,0.0,0.0,08,0.9,0.0*5B"

// Long: Proprietary UBX Satellite Status.
LONG-PUBX03 := "\$PUBX,03,05,07,79,048,42,08,62,308,45,10,51,176,43,13,32,092,41,15,21,315,39,18,18,270,37*18"

// Weird but valid.
WEIRD-1 := "\$GPRMC,123519,A,,,,,,230394,,*08"

// Lowercase talker: rarely seen, but valid according to the spec.
WEIRD-2 := "\$gprmc,225446,A,4916.45,N,12311.12,W,000.5,054.7,191194,020.3,E*48"

// BAD:

// Single bit checksum error:
bad-rmc := "\$GPRMC,225446,A,4916.45,N,12311.12,W,000.5,054.7,191194,020.3,E*69"

// PUBX with Bad Checksum:
bad-cks := "\$PUBX,00,123519,4807.038,N,01131.000,E,545.4,G3,2.5,3.1,0.0,0.0,0.0,08,0.9,0.0*00"

// Truncated Sentence:
bad-trunc-1 := "\$GPGGA,123519,4807.038,N,01131.000,E,1,08,0.9"

// Truncated after *
bad-trunc-2 := "\$GPVTG,054.7,T,034.4,M,005.5,N,010.2,K*"

// Garbage before valid sentence:
bad-garbage-1 := "xyz123!!!\$GPRMC,225446,A,4916.45,N,12311.12,W,000.5,054.7,191194,020.3,E*68"

// Binary junk prefix
bad-garbage-2 := "\x00\xFF\x13\x7E\$GPGLL,4916.45,N,12311.12,W,225444,A,*1D"

// Valid prefix, invalid body
bad-body := "\$GPXYZ,1,2,3,4,5*3B"

// PUBX with unknown subid
bad-subid := "\$PUBX,99,foo,bar,baz*2C"

// Multipart but no other part arrives
bad-no-siblings := "\$GPGSV,3,1,11,07,79,048,42*5E"

// GSV with parts out of order
bad-out-of-order-1 := "\$GPGSV,3,2,11,15,21,315,39*5A"
bad-out-of-order-2 := "\$GPGSV,3,1,11,07,79,048,42*5E"
bad-out-of-order-3 := "\$GPGSV,3,3,11,27,05,045,30*51"

// Sentence split across reads
//$GPRMC,225446,A,4916.
//45,N,12311.12,W,000.5,054.7,191194,020.3,E*68

// Split right after $
//noise noise noise$
//GPGGA,123519,4807.038,N,01131.000,E,1,08,0.9,545.4,M,46.9,M,,*47

// UBX collision test
//\xb5b$GPRMC,225446,A,4916.45,N,12311.12,W,000.5,054.7,191194,020.3,E*68

// Partial UBX header, no message
//\xb5


GOOD-LIST ::= {
  MINIMAL-GLL,
  SHORT-RMC,
  MEDIUM-GGA,
  MEDIUM-VTG,
  LONG-ZDA,
  LONG-GSV-1,
  LONG-GSV-2,
  LONG-GSV-3,
  WEIRD-1,
  WEIRD-2,
  LONG-PUBX03,
  LONG-PUBX00,
}

BAD-LIST ::= {
  MINIMAL-GLL,
  SHORT-RMC,
  MEDIUM-GGA,
  MEDIUM-VTG,
  LONG-ZDA,
  LONG-GSV-1,
  LONG-GSV-2,
  LONG-GSV-3,
  WEIRD-1,
  WEIRD-2,
  LONG-PUBX03,
  LONG-PUBX00,
}

main:
  parser := nmea-message.NmeaParser
  GOOD-LIST.do:
    print " - Doing $it"
    test-message := parser.from-string it
    print test-message
