// Copyright (C) 2025 Toit Contributors. All rights reserved.
// Use of this source code is governed by a MIT-style license that can be found
// in the LICENSE file.

import serial
import io
import io show LITTLE-ENDIAN
import log
import monitor

/**
Generic, parser-agnostic driver for GNSS devices.

The driver is wire-protocol aware but parser-agnostic.  Users register one or
  more parsers using $add-parser, keyed on the magic byte sequence that
  identifies each protocol on the wire (e.g. `$` for NMEA, `0xb5 0x62` for UBX).
  When the adapter sees one of those magic sequences at the head of the stream,
  it calls the matching parse lambda to consume one complete frame and returns
  the resulting message.

For protocols the user does not want to parse but should be skipped cleanly
  (so that embedded data bytes are not misread as the start of another frame),
  use $add-skip to register a magic byte sequence as skip-only.

The driver ships with built-in skip routines for NMEA, AIS, UBX, and CASIC
  framings.  These are used automatically when a parser or skip is registered
  for one of those known magic sequences.  For any other protocol the user can
  supply a custom skip lambda via the `--skip` parameter on $add-parser.

Example: registering an NMEA parser only.
```
parser := NmeaParser
driver := Gnss-driver reader writer
driver.add-parser #[0x24]: | r | parser.from-reader r
```

Example: registering NMEA and UBX parsers together.
```
nmea-parser := NmeaParser
ubx-parser := UbxParser
driver := Gnss-driver reader writer
driver.add-parser #[0x24]:       | r | nmea-parser.from-reader r
driver.add-parser #[0xb5, 0x62]: | r | ubx-parser.from-reader r
```

Example: registering NMEA and asking the driver to cleanly skip UBX frames
  without parsing them.
```
parser := NmeaParser
driver := Gnss-driver reader writer
driver.add-parser #[0x24]: | r | parser.from-reader r
driver.add-skip #[0xb5, 0x62]
```

Messages returned by the parse lambdas are expected to expose the following
  duck-typed methods, used by the driver for poll/dispatch logic:
  - `id -> string`           Identifier used for poll matching and lambda dispatch.
  - `full-name -> string`    Used as the key in $latest-message.
  - `is-multipart -> bool`   Multipart messages are not supported by $send-poll-message.
  - `poll-reply-ids -> List?` Expected reply IDs when this message is a poll.
  - `to-string -> string`    Wire representation, used by $send-message.
*/
class Gnss-driver:
  static POLL-TIMEOUT_ ::= Duration --s=5

  // Latches/Mutexes for managing and acknowledging commands.
  message-mutex_ := monitor.Mutex  // Used to ensure one command at once.

  // Stores the latch if polling and waiting for an expected response.
  poll-latch_/monitor.Latch? := null

  // List of message IDs interesting to a given poll message.  Mutex ensures
  // only one poll message is processed at a time.
  pending-polls_/List := []

  // Logger for the driver.
  logger_/log.Logger

  // Container for the message receiver task.
  runner_/Task? := null

  // The adapter that owns the reader/writer and frame dispatch.
  adapter_/Adapter_

  // Map to contain the most recent message of every given type.
  latest-message/Map := {:}

  // Collection of Lambdas for handling messages.
  message-type-lambdas_/Map := {:}

  /**
  Creates a new driver object.

  Create an $io.Reader from a $serial.Device, and provide as $reader.  Similarly,
    create an $io.Writer from a $serial.Device, and provide as $writer.

  After construction, register one or more parsers via $add-parser before
    expecting any messages.  If no parsers are registered, $next-message will
    block waiting for a parseable frame indefinitely.
  */
  constructor
      reader/io.Reader
      writer/io.Writer
      logger/log.Logger=log.default:
    logger_ = logger.with-name "gnss-driver"
    adapter_ = Adapter_ reader writer logger_

    // Starts the task that listens for incoming messages.
    run

  /**
  Registers a parse $lambda for the given $magic byte sequence.

  When the adapter sees $magic at the head of the stream, $lambda is called
    with the underlying $io.Reader.  The lambda must consume exactly one
    complete frame from the reader and return the parsed message (any type).

  If $skip is provided, it is used as the skip routine when a parse fails
    or when the magic later transitions to skip-only.  If $skip is null, the
    driver looks up a built-in skip routine for $magic; if none exists, a
    one-byte fallback is used and a warning is logged once.
  */
  add-parser magic/ByteArray lambda/Lambda --skip/Lambda?=null -> none:
    adapter_.add-parser_ magic lambda --skip=skip

  /**
  Registers $magic as a skip-only protocol.

  When the adapter sees $magic at the head of the stream, the corresponding
    skip routine is called to consume one complete frame, but no message is
    returned to the caller.  The frame is silently discarded.

  If $skip is provided, it is used.  Otherwise the driver looks up a built-in
    skip routine for $magic; if none exists, a one-byte fallback is used and
    a warning is logged once.
  */
  add-skip magic/ByteArray --skip/Lambda?=null -> none:
    adapter_.add-skip_ magic --skip=skip

  /**
  Removes any parser or skip registration for $magic.
  */
  remove-handler magic/ByteArray -> none:
    adapter_.remove-handler_ magic

  /**
  Starts the message receiver task.

  Does not return until the task has started, preventing further code execution
    until received messages are guaranteed to be seen.  (If this does not wait,
    first incoming message replies may be missed in the few msec the task is
    starting.)
  */
  run -> none:
    assert: not runner_
    adapter_.flush
    start-latch := monitor.Latch
    // Start the message parser task to parse messages as they arrive.
    runner_ = task::
      start-latch.set true
      while true:
        message := adapter_.next-message
        if message == null: continue.while  // Skipped frame; keep reading.

        // Resolve any pending poll waiting for this message type.
        if pending-polls_.contains message.id and poll-latch_:
          pending-polls_.remove message.id
          poll-latch_.set message
        else:
          // Check if there is a lambda for this message type and if so, do it.
          if message-type-lambdas_.contains message.id:
            message-type-lambdas_[message.id].call message
          else:
            // Print the message only if no lambda.
            // This driver is for debugging/testing, but can be a bit noisy if
            // testing a lambda for a message type.
            logger_.debug "RECV  ->" --tags={"message": message}

        // Store latest version of messages for other handlers to use.
        latest-message[message.full-name] = message

    start-latch.get
    logger_.debug "message receiver started"

  /**
  Stops the message receiver task and shuts down the adapter.
  */
  close -> none:
    if runner_:
      runner_.cancel
      runner_ = null

  /** Sends a raw byte array to the device, for debug purposes. */
  send-byte-array bytes/ByteArray -> none:
    logger_.debug "SEND  <-" --tags={"bytes": bytes}
    message-mutex_.do:
      adapter_.send-packet bytes

  /** Sends a user created message to the device, for debug purposes. */
  send-message message/any -> none:
    logger_.debug "SEND  <-" --tags={"message": message}
    message-mutex_.do:
      adapter_.send-message message.to-string

  /** Sends a user created string to the device, for debug purposes. */
  send-sentence message/string -> none:
    logger_.debug "SEND  <-" --tags={"message": message}
    message-mutex_.do:
      adapter_.send-packet message.to-byte-array

  /**
  Sends a poll message.

  Handles logic of success and failure messages, waits for the required message
    while not blocking other message traffic being handled by the driver.  Note
    that new/custom message types being sent may require latch handling to avoid
    always being handled via the $POLL-TIMEOUT_ timeout path, and to catch the
    relevant message that matches the command.

  A poll for a message has it returned before supplying to any registered
    lambdas for that type.  To poll for a message and just have the respective
    lambda handle it - use $send-message instead.
  */
  send-poll-message message/any -> any:
    response := message

    if message.is-multipart:
      throw "Function doesn't yet handle multipart for poll messages."

    message-mutex_.do:
      // Reset the latch to prevent stray ACK/NAK getting used.
      poll-latch_ = monitor.Latch

      // Catch if poll has no defined return types.
      if message.poll-reply-ids.size == 0:
        logger_.error "poll without poll-reply-ids" --tags={"message":"$(message)"}
        throw "poll without poll-reply-ids"

      // Set expected return types for the message runner.
      pending-polls_ = message.poll-reply-ids

      // Send and wait for the latch.
      duration := Duration.ZERO
      logger_.debug "SEND  <-" --tags={"message": message}
      exception := catch:
        with-timeout POLL-TIMEOUT_:
          duration = Duration.of:
            adapter_.send-message message.to-string
            response = poll-latch_.get

      logger_.debug "POLL  ->" --tags={"message": response.full-name, "duration": duration}

      // Wipe latch & poll waiting list now we're not using it.
      poll-latch_ = null
      pending-polls_ = []

      // Sleep a moment.
      sleep --ms=50

      // Bail on an exception.
      if exception:
        logger_.error "Command timed out. " --tags={"message": message, "duration": duration}
        return null

    // Supply poll return message to the caller.
    return response

  /**
  Registers a Lambda against a message type.

  If a lambda is registered for a message type, the lambda $function will be
    called with the message each time the matching message type is received.
  */
  register-message-lambda message-id/string function/Lambda? -> none:
    if not function:
      if message-type-lambdas_.contains message-id:
        message-type-lambdas_.remove message-id
      return
    message-type-lambdas_[message-id] = function


/**
Frame dispatcher.  Owns the wire-level reader/writer and a registry of
  per-protocol parse and skip lambdas keyed on magic byte sequences.

Not intended for direct use; access via $Gnss-driver.
*/
class Adapter_:
  static STREAM-DELAY_ ::= Duration --ms=1

  // Built-in skip routines for well-known protocols.  Looked up on registration
  // when no explicit skip is supplied.
  static BUILT-IN-SKIPS_/Map ::= {
    #[0x24]:       :: | r/io.Reader | skip-line-framed_ r,            // NMEA  '$'
    #[0x21]:       :: | r/io.Reader | skip-line-framed_ r,            // AIS   '!'
    #[0xb5, 0x62]: :: | r/io.Reader | skip-ubx-frame_ r,              // UBX
    #[0xba, 0xce]: :: | r/io.Reader | skip-casic-frame_ r,            // CASIC
  }

  logger_/log.Logger
  reader_/io.Reader
  writer_/io.Writer

  // Map from magic ByteArray to {"parse": Lambda?, "skip": Lambda}.
  // A null parse means skip-only.
  handlers_/Map := {:}

  // Maximum length across all registered magics, recomputed on add/remove.
  // Used to size each peek so the longest matching magic always wins.
  max-magic-len_/int := 0

  // Tracks magics that have already triggered a "no skip routine" warning,
  // so we don't flood the log on every frame of an unknown protocol.
  warned-magics_/Set := {}

  constructor .reader_ .writer_ logger/log.Logger=log.default:
    logger_ = logger.with-name "adapter"

  /** Registers a parse handler.  See $Gnss-driver.add-parser. */
  add-parser_ magic/ByteArray lambda/Lambda --skip/Lambda?=null -> none:
    skip-fn := skip ? skip : (BUILT-IN-SKIPS_.get magic)
    if not skip-fn:
      // Fallback: skip one byte at a time.  Warn once.
      if not warned-magics_.contains magic:
        logger_.warn "no skip routine for magic; using one-byte fallback"
            --tags={"magic": magic}
        warned-magics_.add magic
      skip-fn = :: | r/io.Reader | r.skip 1
    handlers_[magic] = {"parse": lambda, "skip": skip-fn}
    recompute-max-magic_

  /** Registers a skip-only handler.  See $Gnss-driver.add-skip. */
  add-skip_ magic/ByteArray --skip/Lambda?=null -> none:
    skip-fn := skip ? skip : (BUILT-IN-SKIPS_.get magic)
    if not skip-fn:
      if not warned-magics_.contains magic:
        logger_.warn "no skip routine for magic; using one-byte fallback"
            --tags={"magic": magic}
        warned-magics_.add magic
      skip-fn = :: | r/io.Reader | r.skip 1
    handlers_[magic] = {"parse": null, "skip": skip-fn}
    recompute-max-magic_

  /** Removes a registered handler. */
  remove-handler_ magic/ByteArray -> none:
    handlers_.remove magic --if-absent=: return
    recompute-max-magic_

  recompute-max-magic_ -> none:
    m := 0
    handlers_.keys.do: | k/ByteArray | if k.size > m: m = k.size
    max-magic-len_ = m

  reset --mode/int=1 -> none:
    wait-until-receiver-available_ --timeout=(Duration --s=3)
    sleep --ms=50
    flush

  /** Sends bytes, as is. */
  send-packet bytes/ByteArray -> none:
    writer_.write bytes
    sleep STREAM-DELAY_

  /** Sends a string, with optional CRLF. */
  send-message message/any --crlf=true -> none:
    writer_.write message.to-byte-array
    if crlf: writer_.write #[0x0d, 0x0a]
    sleep STREAM-DELAY_

  /**
  Reads the next message from the stream.

  Walks the stream looking for a registered magic byte sequence.  When one is
    found, the matching parse lambda is called to consume and return the frame.
    Skip-only handlers consume their frame and return null (caller should loop).

  If the head of the stream matches no registered magic, one byte is skipped
    and the search continues.
  */
  next-message -> any:
    while true:
      if max-magic-len_ == 0:
        // Nothing registered — caller probably forgot add-parser.  Avoid a
        // tight spin: read one byte and discard.
        reader_.skip 1
        continue.while

      peek ::= reader_.peek-bytes max-magic-len_

      // Find the longest magic that matches at the current position.
      best-magic/ByteArray? := null
      handlers_.keys.do: | magic/ByteArray |
        if peek.size >= magic.size and (matches-prefix_ peek magic):
          if not best-magic or magic.size > best-magic.size:
            best-magic = magic

      if best-magic:
        entry/Map := handlers_[best-magic]
        parse-fn/Lambda? := entry["parse"]
        skip-fn/Lambda := entry["skip"]
        if parse-fn:
          e := catch: return parse-fn.call reader_
          // Parse failed — skip the frame cleanly so we don't crawl through
          // its body byte-by-byte looking for false magic matches.
          logger_.warn "error parsing frame; skipping"
              --tags={"error": e, "magic": best-magic}
          se := catch: skip-fn.call reader_
          if se:
            // Skip itself failed (e.g. truncated frame).  Advance one byte
            // and continue.
            logger_.warn "skip routine failed; advancing one byte"
                --tags={"error": se, "magic": best-magic}
            reader_.skip 1
        else:
          // Skip-only registration.
          se := catch: skip-fn.call reader_
          if se:
            logger_.warn "skip routine failed; advancing one byte"
                --tags={"error": se, "magic": best-magic}
            reader_.skip 1
        continue.while

      // No magic matched.  Advance one byte.
      reader_.skip 1

  /** Returns true if $haystack starts with $needle. */
  static matches-prefix_ haystack/ByteArray needle/ByteArray -> bool:
    needle.size.repeat: | i |
      if haystack[i] != needle[i]: return false
    return true

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

  /** Consumes all data from the device before continuing (without blocking). */
  flush -> none:
    while true:
      e := catch:
        with-timeout --ms=0:
          reader_.read
      if e: return

  // ---------------------------------------------------------------------------
  // Built-in skip routines.
  // ---------------------------------------------------------------------------

  /**
  Skips a line-framed frame (NMEA, AIS).

  Reads up to and including the next LF (0x0a), consuming the entire line.
    The leading magic byte is consumed as part of the line.
  */
  static skip-line-framed_ reader/io.Reader -> none:
    reader.read-line

  /**
  Skips a UBX binary frame.

  UBX frame layout:
    sync(2) + class(1) + id(1) + length(2, little-endian) + payload(length) + checksum(2)

  Total bytes to consume = 6 + length + 2.
  */
  static skip-ubx-frame_ reader/io.Reader -> none:
    header ::= reader.read-bytes 6
    length ::= LITTLE-ENDIAN.uint16 header 4
    reader.skip length + 2

  /**
  Skips a CASIC binary frame.

  CASIC frame layout (assumed, verify against device documentation if used):
    sync(2) + length(2, little-endian) + class(1) + id(1) + payload(length) + checksum(4)

  Total bytes to consume = 4 + 2 + length + 4.
  */
  static skip-casic-frame_ reader/io.Reader -> none:
    header ::= reader.read-bytes 4
    length ::= LITTLE-ENDIAN.uint16 header 2
    reader.skip 2 + length + 4


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
