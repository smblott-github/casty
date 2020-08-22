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

[chromecast_kitchen, chromecast_bedroom, chromecast_living, chromecast_studio, chromecast_office] =
  ["chromecast-kitchen-speaker", "chromecast-bedroom", "chromecast-living", "chromecast-studio-speaker", "chromecast-office"]

aliases =
   kitchen: chromecast_kitchen
   k:       chromecast_kitchen
   bedroom: chromecast_bedroom
   b:       chromecast_bedroom
   living:  chromecast_living
   l:       chromecast_living
   studio:  chromecast_studio
   s:       chromecast_studio
   yoga:    chromecast_studio
   y:       chromecast_studio
   office:  chromecast_office
   o:       chromecast_office

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

stations =
  r4:
    name: "BBC Radio 4"
    url: "http://a.files.bbci.co.uk/media/live/manifesto/audio/simulcast/hls/nonuk/sbr_vlow/llnw/bbc_radio_fourfm.m3u8"
  r5:
    name: "BBC Radio 5 Live"
    url: "http://a.files.bbci.co.uk/media/live/manifesto/audio/simulcast/hls/nonuk/sbr_vlow/llnw/bbc_radio_five_live.m3u8"
  ws:
    name: "BBC World Service"
    url: "http://a.files.bbci.co.uk/media/live/manifesto/audio/simulcast/hls/nonuk/sbr_vlow/llnw/bbc_world_service.m3u8"
  rr1:
    name: "RTE Radio 1"
    url: "http://av.rasset.ie/av/live/radio/radio1.m3u"
  cfm:
    name: "Classic FM"
    # url: "http://media-ice.musicradio.com:80/ClassicFM"
    url: "http://media-ice.musicradio.com:80/ClassicFMMP3"
  tr:
    name: "Times Radio"
    url: "http://timesradio.wireless.radio/stream?ref=rf"
  ufm:
    name: "UFM/DSB-R100 Radio"
    url: "http://192.168.3.12:8088/sundtek"

if 0 < args.length and args[0] of stations
  station = stations[args[0]]
  args.shift()
else
  station = stations["r4"]
  station = stations["ufm"]

launchRadio = (callback) ->
  media =
    path: station.url
    streamType: "LIVE"
    autoplay: true

  extend media, opts

  player.launch media, unlessError (p) ->
    p.once "playing", ({playerState})->
      console.log "#{station.name} (#{playerState.toLowerCase()})"
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

