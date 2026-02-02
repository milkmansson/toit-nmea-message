// Copyright (C) 2025 Toit Contributors. All rights reserved.
// Use of this source code is governed by a MIT-style license that can be found
// in the LICENSE file.

import serial
import io
import log
import monitor
import serial

import nmea-message

/**
Generic driver for GNSS devices.

Driver simply sets up an adapter and puts all messages through the NMEA message
  parser, displaying the results.  This driver is a cut down version of the
  https://github.com/toitware/ublox-gnss-driver tailored to this task.
*/

class Driver:

  static COMMAND-TIMEOUT_ ::= Duration --s=5

  // Latches/Mutexes for managing and acknowledging commands
  command-mutex_ := monitor.Mutex  // Used to ensure one command at once.

  // Loggers - one for driver, and separate one for UBX device sourced messages.
  logger_/log.Logger := ?

  // Container for the message receiver task.
  runner_/Task? := null

  // Objects for return data.
  adapter_/Adapter_ := ?

  // Map to contain the most recent message of every given type.
  latest-message/Map := {:}

  /**
  Creates a new driver object.

  Create an $io.Reader from a $serial.Device, and provide as $reader.  Similarly,
    create an $io.Writer from a $serial.Device, and provide as $writer.
  */
  constructor reader/io.Reader writer/io.Writer parser/nmea-message.NmeaParser logger/log.Logger=log.default:
    logger_ = logger.with-name "nmea-driver"
    adapter_ = Adapter_ reader writer parser logger_

    // Starts the task that listens for incoming messages
    run

  /**
  Starts the message receiver task.

  Does not return until the task has started, preventing further code execution
    until recieved messages are guaranteed to be seen.  (If this does not wait,
    first incoming message replies may be missed in the few msec the task is
    starting.)
  */
  run -> none:
    assert: not runner_
    adapter_.flush
    start-latch := monitor.Latch
    duration := Duration.of:
      // Start the message parser task to parse messages as they arrive.
      runner_ = task::
        start-latch.set true
        while true:
          message := adapter_.next-message
          logger_.debug "RECV  ->" --tags={"message" : message}

          // Store latest version of messages for other handlers to use.
          latest-message[message.full-name] = message

    start-latch.get
    logger_.debug "message receiver started" --tags={"ms": duration.in-ms}

  /**
  Resets the driver.
  */
  reset --mode/int=1 -> none:
    logger_.debug "sending reset message (type $mode)"
    adapter_.reset --mode=mode
    sleep --ms=200

  /**
  Stops the message receiver task and shuts down the adapter.
  */
  close -> none:
    if runner_:
      runner_.cancel
      runner_ = null


  /** Send a raw byte array to the device, for debug purposes. */
  send-byte-array bytes/ByteArray -> none:
    logger_.debug "SEND  <-" --tags={"bytes" : bytes}
    command-mutex_.do:
      adapter_.send-packet bytes

  /** Send a user created message to the device, for debug purposes. */
  send-message message/any -> none:
    logger_.debug "SEND  <-" --tags={"message" : message.to-string}
    command-mutex_.do:
      adapter_.send-message message.to-string

  /** Send a user created message to the device, for debug purposes. */
  send-sentence message/string -> none:
    logger_.debug "SEND  <-" --tags={"message" : message}
    command-mutex_.do:
      adapter_.send-packet message.to-byte-array



class Adapter_:
  static STREAM-DELAY_ ::= Duration --ms=1

  // Hardcode these here for now:
  static CASIC-MAGIC-BYTE_ ::= [0xba,0xce]
  static UBX-MAGIC-BYTE_ ::= [0xb5,0x62]
  static NMEA-MAGIC-BYTE_ ::= 0x24
  static AIS-MAGIC-BYTE_ ::= 0x21

  logger_/log.Logger
  reader_/io.Reader
  writer_/io.Writer
  parser_/nmea-message.NmeaParser

  constructor .reader_ .writer_ .parser_ logger/log.Logger=log.default:
    logger_ = logger.with-name "adapter"

  reset --mode/int=1 -> none:
    wait-until-receiver-available_ --timeout=(Duration --s=3)
    sleep --ms=50
    flush

  /** Send bytes, as is. */
  send-packet bytes/ByteArray -> none:
    writer_.write bytes
    sleep STREAM-DELAY_

  /** Send string, with optional CRLF. */
  send-message message/any --crlf=true -> none:
    writer_.write (message.to-byte-array)
    if crlf: writer_.write #[0x0d, 0x0a]
    sleep STREAM-DELAY_

  next-message -> any: //ubx-message.Message:
    while true:
      peek2 ::= reader_.peek-bytes 2
      peek1 ::= peek2[0]

      // Alert if NMEA tests result in the receiver sending binary protocol frames.
      if peek2 == CASIC-MAGIC-BYTE_:
        logger_.warn "got a CASIC frame (ignoring)"
      if peek2 == UBX-MAGIC-BYTE_:
        logger_.warn "got a UBX frame (ignoring)"

      if peek1 == NMEA-MAGIC-BYTE_:
        e := catch: return parser_.from-reader reader_
        logger_.warn "error parsing nmea message" --tags={"error": e}

      // Go to next byte.
      reader_.skip 1

  /**
  Blocks until something comes from the device.

  Timeout after 2 seconds in case device is currently silent.
  */
  wait-until-receiver-available_ --timeout/Duration=(Duration --s=2) -> bool:
    exception := catch:
      with-timeout timeout:
        first ::= reader_.read
    if exception:
      logger_.error "block until read timed out"
      return false
    return true

  /**
  Consumes all data from the device before continuing (without blocking).
  */
  flush -> none:
    while true:
      e := catch:
        with-timeout --ms=0:
          reader_.read
      if e: return

/**
Helper class to create a writer from a $serial.Device. Can be used when
  connecting to the GNSS chip using I2C or SPI.
*/
class Writer extends io.Writer:
  device_/serial.Device

  constructor .device_:

  try-write_ data/io.Data from/int=0 to/int=data.byte-size -> int:
    if from != 0 or to != data.byte-size: data = data.byte-slice from to
    if data is ByteArray:
      device_.write (data as ByteArray)
    else:
      bytes := ByteArray (to - from)
      data.write-to-byte-array bytes --at=0 from to
      device_.write bytes
    return to - from


/**
Helper class to create an $io.Reader from a $serial.Device. Can be used when
  connecting to the GNSS chip using I2C or SPI.
*/
class Reader extends io.Reader:
  static WAIT-BEFORE-NEXT-READ-ATTEMPT_ ::= Duration --ms=5
  static MAX-BUFFER-SIZE_               ::= 64 // bytes
  static AVAILABLE-BYTES-REGISTER_      ::= 0xFD
  static DATA-STREAM-REGISTER_          ::= 0xFF

  registers_ /serial.Registers

  constructor device/serial.Device:
    registers_ = device.registers

  read_ -> ByteArray?:
    while true:
      bytes ::= read__
      if bytes: return bytes
      sleep WAIT-BEFORE-NEXT-READ-ATTEMPT_

  read__ -> ByteArray?:
    available-bytes ::= registers_.read-u16-be AVAILABLE-BYTES-REGISTER_
    if available-bytes == 0:
      return null

    return registers_.read-bytes
      DATA-STREAM-REGISTER_
      min MAX-BUFFER-SIZE_ available-bytes
