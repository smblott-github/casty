#!/usr/bin/env coffee

fs = require "fs"
player = require("chromecast-player")()
args = process.argv[2..]
opts = address: "chromecast-kitchen"

unlessError = (callback) -> (err, args...) ->
  if err
    console.error err.toString()
    process.exit 1
  callback args...

[chromecast_kitchen, chromecast_bedroom, chromecast_living, chromecast_studio] =
  ["chromecast-kitchen", "chromecast-bedroom", "chromecast-living", "chromecast-studio"]

aliases =
   kitchen: chromecast_kitchen
   k: chromecast_kitchen
   bedroom: chromecast_bedroom
   b: chromecast_bedroom
   living:  chromecast_living
   l: chromecast_living
   studio:  chromecast_studio
   s:  chromecast_studio

if 0 < args.length and args[0] of aliases
  opts.address = aliases[args.shift()]

if args.length == 0
  fs.readFile "/etc/radio-url.txt", unlessError (data) ->
    media =
      path: data.toString()
      type: "audio/mpeg"

    player.launch media, unlessError (p) ->
      p.once "playing", ->
        console.log "Sundtek Radio (playing)"
        process.exit 0

else
  showVolume = (volume) ->
    message = "#{Math.round volume.level * 100}"
    message += " (muted)" if volume.muted
    console.log message
    process.exit()

  setVolume = (p, level) ->
    p.setVolume Math.max(0.0, Math.min 1.0, level), unlessError showVolume

  handlers =
    volume: (p, ctx, args) ->
      if args.length == 0
        p.getVolume unlessError showVolume
      else
        setVolume p, (parseInt args.shift()) / 100.0

    louder: (p, ctx, args) ->
      p.getVolume unlessError (volume) ->
        setVolume p, volume.level + volume.stepInterval

    LOUDER: (p, ctx, args) ->
      p.getVolume unlessError (volume) ->
        setVolume p, volume.level + 3 * volume.stepInterval

    quieter: (p, ctx, args) ->
      p.getVolume unlessError (volume) ->
        setVolume p, volume.level - volume.stepInterval

    QUIETER: (p, ctx, args) ->
      p.getVolume unlessError (volume) ->
        setVolume p, volume.level - 3 * volume.stepInterval

    mute: (p, ctx, args) ->
      p.getVolume unlessError (volume) ->
        mute = (if volume.muted then p.unmute else p.mute).bind p
        mute unlessError showVolume

    stop: (p, ctx, args) ->
      p.stop unlessError (status) ->
        console.log status.playerState.toLowerCase()
        process.exit()

  handlers.vol = handlers.volume
  handlers.loud = handlers.louder
  handlers.quiet = handlers.quieter
  handlers.up = handlers.louder
  handlers.down = handlers.quieter
  handlers.off = handlers.stop

  player.attach opts, unlessError (p, ctx) ->
    if args[0] of handlers
      handler = args.shift()
      handlers[handler] p, ctx, args
    else
      console.error "invalid command: #{args[0]}"
      process.exit 1

