# NMEA Examples
These examples using the rudimentary driver library provided with the package.

## Examples index

### `nmea-serial-monitor.toit`
Prints a driver start message, and simply display raw incoming messages.

### `dm-conversion.toit`
Example of converting GNSS native forms of Lat/Long to methematical form.

Most GNSS devices will natively use degrees-minutes N/S|E/W.  However, maps and
math libraries typically want a single floating point number.  The number will
be -90 <= x <= 90, with with North = +ve, South = -ve and East = +ve, West = -ve.
