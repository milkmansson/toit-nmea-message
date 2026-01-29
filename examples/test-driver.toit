// Copyright (C) 2025 Toit Contributors. All rights reserved.
// Use of this source code is governed by a MIT-style license that can be found
// in the LICENSE file.

import serial
import io
import io
import log
import monitor
import reader as old-reader
import serial

import nmea-message


/**
Driver for u-blox GNSS devices.

Originally developed for the Max M8 GPS module.
*/

class Driver:

  static UBX-MAGIC-BYTE_ ::= 0xb5
  static NMEA-MAGIC-BYTE_ ::= 0x24
  static AIS-MAGIC-BYTE_ ::= 0x21

  // NMEA Helpers while a protocol specific parser doesn't exist.
  // See $disable-nmea-messages.
  static NMEA-CLASS-ID_ := 0xF0
  static NMEA-MESSAGE-IDS_ := {
    "GGA": 0x00,
    "GLL": 0x01,
    "GSA": 0x02,
    "GSV": 0x03,
    "RMC": 0x04,
    "VTG": 0x05,
    "GRS": 0x06,
    "GST": 0x07,
    "ZDA": 0x08,
    "GBS": 0x09,
    "DTM": 0x0A,
  }

  // Latches/Mutexes for managing and acknowledging commands
  waiters-latch_ := []             // Stores latches for all users until fix.
  waiters-mutex_ := monitor.Mutex  // Prevent race when $waiters_ is read/written.
  command-mutex_ := monitor.Mutex  // Used to ensure one command at once.
  command-latch_ := monitor.Latch  // Used to ensure cfg gets the result.

  // Loggers - one for driver, and separate one for UBX device sourced messages.
  logger_/log.Logger := ?
  msg-debug_ := false

  // Container for the message receiver task.
  runner_/Task? := null

  // Objects for return data.
  adapter_/Adapter_ := ?

  // Map to contain the most recent message of every given type.
  latest-message/Map := {:}

  /**
  Creates a new driver object.

  The $reader should be an $io.Reader, but $old-reader.Reader objects are
    still supported for backwards compatibility. Support for $old-reader.Reader
    is deprecated and will be removed in a future release.
  Use $Reader to create an $io.Reader from a $serial.Device.

  The $writer should be an $io.Writer, but "old-style" writers are still
    supported for backwards compatibility. Support for "old-style" writers is
    deprecated and will be removed in a future release.
  Use $Writer to create an $io.Writer from a $serial.Device.

  When starting the driver with defaults, the driver subscribes to the messages
    required to find location and time.  For advanced users looking to prevent
    the default operation, and create subscriptions/messge handlers, etc,
    themselves, specify `--no-auto-run` on the constructor.  In this case,
    users must set required configurations (via $send-message-cfg), subscribe
    to desired message types (via $send-set-message-rate), and then start
    the message receiver task ($run) manually.
  */

  constructor reader writer logger=log.default
      --auto-run/bool=true
      --force-protocol-version/string?=null
      --hw-reset/bool=false
      --sw-reset/bool=false
      --message-debug/bool=false:
    logger_ = logger.with-name "nmea-driver"
    msg-debug_ = message-debug

    if reader is old-reader.Reader:
      reader = io.Reader.adapt reader

    if writer is not io.Writer:
      writer = io.Writer.adapt writer

    adapter_ = Adapter_ reader writer logger

    if auto-run:
      // Start message receiver task (and wait for it to start).
      run


  /**
  Starts the message receiver task.

  The $run command returns only when the task has started.  This ensures the
    message receiver is ready before any messages are sent that would otherwise
    cause code to block permanently without the corresponding ACK/NAK being
    received.
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
          if msg-debug_: logger_.debug "RECV  ->" --tags={"message" : message}

          // Store latest version of messages for other handlers to use.
          latest-message[message.full-name] = message


          else:
            //logger_.debug  "Driver received UNHANDLED message type: $message"
            logger_.debug "$message"

    start-latch.get
    logger_.debug "message receiver started" --tags={"ms": duration.in-ms}

  /**
  Resets the driver.

  Reset should be called when the message receiver is not actively running,
    otherwise some messages will be lost.  (Losing a message may or may not be
    a problem depending on the use case.)

  Set $mode to 1 (default) "Controlled Software Reset" restart the software
    but fix and satellite information is not lost. Set $mode to 4 for a hardware
    restart via watchdog after a shutdown (loses fix and tracking information).
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
  send-raw-byte-array bytes/ByteArray -> none:
    logger_.debug "sending raw bytearray: $bytes"
    if msg-debug_: logger_.debug "SEND  <-" --tags={"bytes" : bytes}
    command-mutex_.do:
      adapter_.send-packet bytes


  /** Send a user created message to the device, for debug purposes. */
  send-raw-message message/any -> none:
    logger_.debug "sending custom message: $message"
    if msg-debug_: logger_.debug "SEND  <-" --tags={"message" : message}
    command-mutex_.do:
      adapter_.send-packet message.to-byte-array

  /**
  Sends message, and waits for the response.

  Handles logic of success and failure messages, while not blocking other
    message traffic being handled by the driver.  Note that new/custom message
    types being sent may require latch handling to avoid always being handled
    via the $COMMAND-TIMEOUT-MS_ timeout path, and to catch the relevant message
    that matches the command.
  */
  send-message message/NmeaMessage --return-immediately/bool=false -> ubx-message.Message?:
    response := message
    command-mutex_.do:
      if return-immediately:
        if msg-debug_: logger_.debug "SEND  <-" --tags={"message" : message}
        adapter_.send-packet message.to-byte-array
        return null

      // Reset the latch to prevent stray ACK/NAK getting used.
      command-latch_ = monitor.Latch

      // todo: try/finally.
      // todo: determine if/how we should convert to semphore.
      duration := Duration.ZERO
      if msg-debug_: logger_.debug "SEND  <-" --tags={"message" : message}
      exception := catch:
        with-timeout --ms=COMMAND-TIMEOUT-MS_:
          duration = Duration.of:
            adapter_.send-packet message.to-byte-array
            response = command-latch_.get

      // Set latch to null if we're not using it.
      command-latch_ = null

      // Sleep a moment
      sleep --ms=50

      if exception:
        logger_.error "Command timed out. " --tags={"message":"$(message)", "ms":duration.in-ms}
        return null

    // Lets have the return message supplied back to the caller to determine
    // what to do with it.
    return response


class Adapter_:
  static STREAM-DELAY_ ::= Duration --ms=1

  // Hardcode these here for now:
  static UBX-MAGIC-BYTE_ ::= 0xb5
  static NMEA-MAGIC-BYTE_ ::= 0x24
  static AIS-MAGIC-BYTE_ ::= 0x21

  logger_/log.Logger
  reader_/io.Reader
  writer_/io.Writer

  constructor .reader_ .writer_ .logger_:

  flush -> none:
    // Flush all data up to this point.
    wait-until-receiver-available_

  reset --mode/int=1 -> none:
    wait-until-receiver-available_
    // Reset and reload configuration (cold boot + reboot of processes).
    //send-packet (ubx-message.CfgRst --reset-mode=mode).to-byte-array
    // Wait for the reload to take effect, before flushing stale data.
    // This was tested with 10ms, so using 50ms.
    sleep --ms=50
    flush

  send-packet bytes/ByteArray -> none:
    writer_.write bytes
    sleep STREAM-DELAY_

  send-ubx message/ubx-message.Message -> none:
    writer_.write message.to-byte-array
    sleep STREAM-DELAY_

  next-message -> any: //ubx-message.Message:
    while true:
      peek ::= reader_.peek-byte 0
      if peek == UBX-MAGIC-BYTE_: // UBX protocol
        e := catch: return ubx-message.Message.from-reader reader_
        log.warn "error parsing ubx message" --tags={"error": e}
      if peek == NMEA-MAGIC-BYTE_: // NMEA protocol
        //return Nmea-message.from-reader reader_
        e := catch: return Nmea-message.from-reader reader_
        log.warn "error parsing nmea message" --tags={"error": e}

      // Go to next byte.
      reader_.skip 1

  wait-until-receiver-available_:
    // Block until we can read from the device.
    first ::= reader_.read

    // Consume all data from the device before continuing (without blocking).
    while true:
      e := catch:
        with-timeout --ms=0:
          reader_.read
      if e: return

/*
class gopher_:
  open/bool           // use in message parser - only do 'gopher processing' if open
  desired-types/List  // acceptable types as responses (default being ACK/NAK and the request type)
  maximum-number/int  // in case we are expecting a fixed/max number of response messages
  maximum-time/Duration    // maximum duration before closing the request
  maximum-timeout/Duration // maximum duration since last acceptable packet
  messages/List       // messages collected by the gopher to pass back

  constructor:
    open = false
    desired-types = []
*/


/**
Helper class to create a writer from a $serial.Device. Can be used when connecting
  to the GNSS chip using I2C or SPI.
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
Helper class to create an $io.Reader from a $serial.Device. Can be used when connecting
  to the GNSS chip using I2C or SPI.
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
