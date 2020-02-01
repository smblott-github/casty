#!/usr/bin/env coffee

fs = require "fs"
extend = require "extend"
player = require("chromecast-player")()
args = process.argv[2..]
opts = address: "chromecast-kitchen"

stepInterval = 0.02

unlessError = (callback) -> (err, args...) ->
  if err
    console.error err.toString()
    process.exit 1
  callback args...

[chromecast_kitchen, chromecast_bedroom, chromecast_living, chromecast_office] =
  ["chromecast-kitchen-speaker", "chromecast-bedroom", "chromecast-living", "chromecast-office"]

aliases =
   kitchen: chromecast_kitchen
   k: chromecast_kitchen
   bedroom: chromecast_bedroom
   b: chromecast_bedroom
   living:  chromecast_living
   l: chromecast_living
   studio:  chromecast_office
   s:  chromecast_office

if 0 < args.length and args[0] of aliases
  opts.address = aliases[args.shift()]

if args.length == 1 and args[0] in ["play", "dvr"]
  args.shift()

showVolume = (volume) ->
  message = "#{Math.round volume.level * 100}"
  message += " (muted)" if volume.muted
  console.log message
  process.exit()

showStatus = (p) ->
  p.getStatus unlessError (status) ->
    console.log status.playerState.toLowerCase()
    process.exit()

setVolume = (p, level) ->
  p.setVolume Math.max(0.0, Math.min 1.0, level), unlessError showVolume

bbc_radio_4 = "http://a.files.bbci.co.uk/media/live/manifesto/audio/simulcast/hls/nonuk/sbr_vlow/llnw/bbc_radio_fourfm.m3u8"
bbc_radio_5_live = "http://a.files.bbci.co.uk/media/live/manifesto/audio/simulcast/hls/nonuk/sbr_vlow/llnw/bbc_radio_five_live.m3u8"
bbc_world_service = "http://a.files.bbci.co.uk/media/live/manifesto/audio/simulcast/hls/nonuk/sbr_vlow/llnw/bbc_world_service.m3u8"
rte_radio_1 = "http://av.rasset.ie/av/live/radio/radio1.m3u"

if 0 < args.length
  switch args[0]
    when "r4"
      radio_url = bbc_radio_4
      args.shift()
    when "r5"
      radio_url = bbc_radio_5_live
      args.shift()
    when "ws"
      radio_url = bbc_world_service
      args.shift()
    when "rr1"
      radio_url = rte_radio_1
      args.shift()
    else
      radio_url = bbc_radio_4

launchRadio = (callback) ->
  media =
    path: radio_url
    streamType: "LIVE"
    autoplay: true

  extend media, opts

  player.launch media, unlessError (p) ->
    p.once "playing", ({playerState})->
      console.log "Radio (#{playerState.toLowerCase()})"
      callback p

if args.length == 0
  launchRadio (p) -> process.exit 0

else if args.length == 2 and args[0] == "wake"
  args.shift()
  launchRadio (p) ->
    setVolume p, (parseInt args.shift()) / 100.0

else
  handlers =
    volume: (p, ctx, args) ->
      if args.length == 0
        p.getVolume unlessError showVolume
      else
        setVolume p, (parseInt args.shift()) / 100.0

    louder: (p, ctx, args) ->
      p.getVolume unlessError (volume) ->
        setVolume p, volume.level + stepInterval

    LOUDER: (p, ctx, args) ->
      p.getVolume unlessError (volume) ->
        setVolume p, volume.level + 3 * stepInterval

    quieter: (p, ctx, args) ->
      p.getVolume unlessError (volume) ->
        setVolume p, volume.level - stepInterval

    QUIETER: (p, ctx, args) ->
      p.getVolume unlessError (volume) ->
        setVolume p, volume.level - 3 * stepInterval

    mute: (p, ctx, args) ->
      p.getVolume unlessError (volume) ->
        mute = (if volume.muted then p.unmute else p.mute).bind p
        mute unlessError showVolume

    stop: (p, ctx, args) ->
      p.stop unlessError (status) ->
        console.log status.playerState.toLowerCase()
        process.exit()

    pause: (p, ctx, args) ->
      p.getStatus unlessError (status) ->
        state = status.playerState.toLowerCase()
        toggler = (if state == "playing" then p.pause else p.play).bind p
        toggler unlessError -> showStatus p

    status: showStatus

    playing: (p, ctx, args) ->
      p.getStatus unlessError (status) ->
        state = status.playerState.toLowerCase()
        process.exit (if state == "playing" then 0 else 1)

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

