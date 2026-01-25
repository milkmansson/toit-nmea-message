// GOOD

// Minimal NMEA:
$GPGLL,4916.45,N,12311.12,W,225444,A,*1D

// Short: Basic RMC:
$GPRMC,225446,A,4916.45,N,12311.12,W,000.5,054.7,191194,020.3,E*68

// Medium: GGA - Altitude and fix info:
$GPGGA,123519,4807.038,N,01131.000,E,1,08,0.9,545.4,M,46.9,M,,*47

// Medium: VTG - Velocity Only
$GPVTG,054.7,T,034.4,M,005.5,N,010.2,K*48

// Medium Long: ZDA Date and time
$GPZDA,201530.00,04,07,2002,00,00*60

// Long: GSV Multipart #1
$GPGSV,3,1,11,07,79,048,42,08,62,308,45,10,51,176,43,13,32,092,41*7E
// Long: GSV Multipart #2
$GPGSV,3,2,11,15,21,315,39,18,18,270,37,20,12,020,35,23,09,180,33*7C
// Long: GSV Multipart #3
$GPGSV,3,3,11,27,05,045,30,30,02,120,28,32,01,250,25*4A

// Long: Proprietary UBX Nav Solution
$PUBX,00,123519,4807.038,N,01131.000,E,545.4,G3,2.5,3.1,0.0,0.0,0.0,08,0.9,0.0*59

// Long: Proprietary UBX Satellite Status
$PUBX,03,05,07,79,048,42,08,62,308,45,10,51,176,43,13,32,092,41,15,21,315,39,18,18,270,37*2F

// Weird but valid
$GPRMC,123519,A,,,,,,230394,,*1C

// Lowercase talker: rarely seen
$gprmc,225446,A,4916.45,N,12311.12,W,000.5,054.7,191194,020.3,E*68




// BAD: 

// Single bit checksum error:
$GPRMC,225446,A,4916.45,N,12311.12,W,000.5,054.7,191194,020.3,E*69

// PUBX with Bad Checksum:
$PUBX,00,123519,4807.038,N,01131.000,E,545.4,G3,2.5,3.1,0.0,0.0,0.0,08,0.9,0.0*00

// Truncated Sentence:
$GPGGA,123519,4807.038,N,01131.000,E,1,08,0.9

// Truncated after *
$GPVTG,054.7,T,034.4,M,005.5,N,010.2,K*

// Garbage before valid sentence:
xyz123!!!$GPRMC,225446,A,4916.45,N,12311.12,W,000.5,054.7,191194,020.3,E*68

// Binary junk prefix
\x00\xFF\x13\x7E$GPGLL,4916.45,N,12311.12,W,225444,A,*1D

// Valid prefix, invalid body
$GPXYZ,1,2,3,4,5*3B

// PUBX with unknown subid
$PUBX,99,foo,bar,baz*2C

// Multipart but no other part arrives
$GPGSV,3,1,11,07,79,048,42*5E

// GSV with parts out of order
$GPGSV,3,2,11,15,21,315,39*5A
$GPGSV,3,1,11,07,79,048,42*5E
$GPGSV,3,3,11,27,05,045,30*51

// Sentence split across reads
$GPRMC,225446,A,4916.
45,N,12311.12,W,000.5,054.7,191194,020.3,E*68

// Split right after $
noise noise noise$
GPGGA,123519,4807.038,N,01131.000,E,1,08,0.9,545.4,M,46.9,M,,*47

// UBX collision test
\xb5b$GPRMC,225446,A,4916.45,N,12311.12,W,000.5,054.7,191194,020.3,E*68

// Partial UBX header
\xb5





