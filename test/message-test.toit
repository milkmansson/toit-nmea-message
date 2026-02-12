// Copyright (C) 2025 Toit contributors.
// Use of this source code is governed by a MIT-style license that can be found
// in the LICENSE file.

import nmea-message show *
import nmea-message.nmea-ubx-message show *
import expect show *

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
LONG-PUBX03 := "\$PUBX,03,21,5,U,014,29,46,064,6,e,109,02,24,000,11,U,077,29,23,000,12,U,196,23,31,009,13,U,059,58,46,064,15,U,259,84,44,064,18,-,316,04,,000,20,-,046,65,,000,21,U,038,11,30,022,23,U,269,17,20,000,24,U,173,24,25,000,25,U,238,22,24,000,29,U,321,50,41,064,127,e,259,37,,000,128,-,242,67,,000,129,e,226,74,43,064,132,-,216,76,,000,137,e,108,57,42,064,194,U,147,25,30,014,195,U,066,44,34,064,196,-,053,50,16,000*3A"

// Weird but valid.
WEIRD-1 := "\$GPRMC,123519,A,,,,,,230394,,*08"

// Lowercase talker: rarely seen, but valid according to the spec.
WEIRD-2 := "\$gprmc,225446,A,4916.45,N,12311.12,W,000.5,054.7,191194,020.3,E*48" //68

// BAD:

// Single bit checksum error:
BAD-RMC := "\$GPRMC,225446,A,4916.45,N,12311.12,W,000.5,054.7,191194,020.3,E*69"

// PUBX with Bad Checksum:
BAD-CKS := "\$PUBX,00,123519,4807.038,N,01131.000,E,545.4,G3,2.5,3.1,0.0,0.0,0.0,08,0.9,0.0*00"

// Truncated Sentence:
BAD-TRUNC-1 := "\$GPGGA,123519,4807.038,N,01131.000,E,1,08,0.9"

// Truncated after *:
BAD-TRUNC-2 := "\$GPVTG,054.7,T,034.4,M,005.5,N,010.2,K*"

// Garbage before valid sentence:
BAD-GARBAGE-1 := "xyz123!!!\$GPRMC,225446,A,4916.45,N,12311.12,W,000.5,054.7,191194,020.3,E*68"

// Binary junk prefix:
BAD-GARBAGE-2 := "\x00\xFF\x13\x7E\$GPGLL,4916.45,N,12311.12,W,225444,A,*1D"

// Valid talker, invalid message type:
BAD-BODY := "\$GPXYZ,1,2,3,4,5*51" // 3B

// PUBX with unknown subid
BAD-SUBID := "\$PUBX,99,foo,bar,baz*2C"

// Multipart but no other part arrives: Does not throw.
BAD-NO-SIBLINGS := "\$GPGSV,3,1,11,07,79,048,42*48"

// GSV with parts out of order:  Does not throw.
BAD-OUT-OF-ORDER-1 := "\$GPGSV,3,2,11,15,21,315,39*42"
BAD-OUT-OF-ORDER-2 := "\$GPGSV,3,1,11,07,79,048,42*48"
BAD-OUT-OF-ORDER-3 := "\$GPGSV,3,3,11,27,05,045,30*4B"

// Sentence split across reads:
BAD-SPLIT-1-1 := "\$GPRMC,225446,A,4916."
BAD-SPLIT-1-2 := "45,N,12311.12,W,000.5,054.7,191194,020.3,E*68"
GOOD-SPLIT-1  := "$BAD-SPLIT-1-1$BAD-SPLIT-1-2"
BAD-SPLIT-1   := "$BAD-SPLIT-1-1\r\n$BAD-SPLIT-1-2"

// Split right after $:
//noise noise noise$
//GPGGA,123519,4807.038,N,01131.000,E,1,08,0.9,545.4,M,46.9,M,,*47
BAD-SPLIT-2-1 := "\$"
BAD-SPLIT-2-2 := "GPGGA,123519,4807.038,N,01131.000,E,1,08,0.9,545.4,M,46.9,M,,*47"
GOOD-SPLIT-2  := "$BAD-SPLIT-2-1$BAD-SPLIT-2-2"
BAD-SPLIT-2   := "$BAD-SPLIT-2-1\r\n$BAD-SPLIT-2-2"

// UBX collision test
UBX-BYTES := "\xb5\x62"
RMCMSG := "\$GPRMC,225446,A,4916.45,N,12311.12,W,000.5,054.7,191194,020.3,E*68"
UBX-COLLISION := "$UBX-BYTES$RMCMSG"

// Partial UBX header, no message
PARTIAL := "\xb5"


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
  LONG-PUBX00,
  LONG-PUBX03,
}

BAD-LIST ::= {
  BAD-RMC,
  BAD-CKS,
  BAD-TRUNC-1,
  BAD-TRUNC-2,
  BAD-GARBAGE-1,
  BAD-GARBAGE-2,
  BAD-BODY,
  BAD-SUBID,
  BAD-SPLIT-1,
  BAD-SPLIT-2,
  BAD-NO-SIBLINGS,
  BAD-OUT-OF-ORDER-1,
  BAD-OUT-OF-ORDER-2,
  BAD-OUT-OF-ORDER-3,
}

main:
  nmea-parser := NmeaParser
  nmea-parser.add NmeaUbxParser.MESSAGES
  test-message/NmeaMessage? := null

  // Show which messages are in the registry for parsing:
  //print nmea-parser.registry.keys

  GOOD-LIST.do: | line |
    // Test that item parses OK:
    expect-no-throw:
      test-message = nmea-parser.from-string line

    // Test the test sentences convert to a message and then back to a sentence.
    // Includes truncating checksum (message stored as object) and re-computation
    // as message goes back to string format:
    expect-identical line test-message.to-string

  // Doing the bad messages:

  // Bad checksum should throw:
  expect-throw "INVALID NMEA MESSAGE: sentence checksum invalid" :
    test-message = nmea-parser.from-string BAD-RMC

  // Bad checksum should throw:
  expect-throw "INVALID NMEA MESSAGE: sentence checksum invalid" :
    test-message = nmea-parser.from-string BAD-CKS

  // Throw 'bad checksum' if * is present but value is not parseable (eg "").
  expect-throw "INVALID NMEA MESSAGE: sentence checksum invalid" :
    test-message = nmea-parser.from-string BAD-TRUNC-2

  // Throw for first char not being $:
  expect-throw "INVALID NMEA MESSAGE: sentence first char not \$" :
    test-message = nmea-parser.from-string BAD-GARBAGE-1

  // Throw for first char not being $:
  expect-throw "INVALID NMEA MESSAGE: sentence first char not \$" :
    test-message = nmea-parser.from-string BAD-GARBAGE-2

  expect-throw "INVALID NMEA MESSAGE: Unknown message type 'GPXYZ,1'" :
    test-message = nmea-parser.from-string BAD-BODY

  // If multipart message has no siblings, parser does not know and cannot throw:
  expect-no-throw: nmea-parser.from-string BAD-NO-SIBLINGS

  // If multipart message out of order, parser does not know and cannot throw:
  expect-no-throw: nmea-parser.from-string BAD-OUT-OF-ORDER-1
  expect-no-throw: nmea-parser.from-string BAD-OUT-OF-ORDER-2
  expect-no-throw: nmea-parser.from-string BAD-OUT-OF-ORDER-3

  // Validate BAD-SPLIT would be good if it wasn't for the split (eg CKS OK):
  expect-no-throw: nmea-parser.from-string GOOD-SPLIT-1

  // Sentence split across reads means an extra \r\n, means a failed checksum:
  expect-throw "INVALID NMEA MESSAGE: sentence checksum invalid" :
    test-message = nmea-parser.from-string BAD-SPLIT-1

  // Validate BAD-SPLIT would be good if it wasn't for the split (eg CKS OK):
  expect-no-throw: nmea-parser.from-string GOOD-SPLIT-2

  // Sentence split across reads means an extra \r\n, means a failed checksum:
  expect-throw "INVALID NMEA MESSAGE: sentence checksum invalid" :
    test-message = nmea-parser.from-string BAD-SPLIT-2

  // Establish good message before UBX bytes collide:
  expect-no-throw: nmea-parser.from-string RMCMSG

  // Colliding message: Throws because first char is not $.
  expect-throw "INVALID NMEA MESSAGE: sentence first char not \$" :
    test-message = nmea-parser.from-string UBX-COLLISION

  expect-throw "INVALID NMEA MESSAGE: sentence first char not \$" :
    test-message = nmea-parser.from-string PARTIAL

  // Truncated message parses but data onboard is bad.
  test-message = nmea-parser.from-string BAD-TRUNC-1
