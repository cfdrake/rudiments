-- rudiments
-- percussion synthesizer
--
-- playfair style sequencer
--
-- E1 select
-- E2 density
-- E3 length
-- K2 reset phase
-- K3 start/stop
--
-- K1 = ALT
-- ALT-E1 = bpm
-- ALT+K3 = randomize all voices

-- TODO: Add velocity, ...

engine.name = "Rudiments"

local last = 0

local voice_count = 8

function setup_params()
  for i = 1,voice_count do
    -- OSC
    params:add_separator()
    params:add_control("shape" .. i, "osc " .. i .. " shape", controlspec.new(0, 1, 'lin', 1, 0, ''))
    params:set_action("shape" .. i, function(x) engine.shape(x, i) end)

    params:add_control("freq" .. i, "osc " .. i .. " freq", controlspec.new(20, 10000, 'lin', 1, 120, 'hz'))
    params:set_action("freq" .. i, function(x) engine.freq(x, i) end)

    -- ENV
    params:add_control("decay" .. i, "env " .. i .. " decay", controlspec.new(0.05, 1, 'lin', 0.01, 0.2, 'sec'))
    params:set_action("decay" .. i, function(x) engine.decay(x, i) end)

    params:add_control("sweep" .. i, "env " .. i .. " sweep", controlspec.new(0, 2000, 'lin', 1, 100, ''))
    params:set_action("sweep" .. i, function(x) engine.sweep(x, i) end)

    -- TODO: Sweep direction sounds a little wonky right now...

    -- LFO
    params:add_control("lfoFreq" .. i, "lfo " .. i .. " freq", controlspec.new(1, 1000, 'lin', 1, 1, 'hz'))
    params:set_action("lfoFreq" .. i, function(x) engine.lfoFreq(x, i) end)

    params:add_control("lfoShape" .. i, "lfo " .. i .. " shape", controlspec.new(0, 1, 'lin', 1, 0, ''))
    params:set_action("lfoShape" .. i, function(x) engine.lfoShape(x, i) end)

    params:add_control("lfoSweep" .. i, "lfo " .. i .. " sweep", controlspec.new(0, 2000, 'lin', 1, 0, ''))
    params:set_action("lfoSweep" .. i, function(x) engine.lfoSweep(x, i) end)
  end
end

function setup_midi()
  m = midi.connect()

  m.event = function(data)
    local d = midi.to_msg(data)

    if d.type == "note_on" then
      note = d.note % 12

      if note > 7 then
        return
      end

      index = math.min(math.max(0, note), 7) + 1
      trigger(index)
    end
  end
end

function trigger(i)
  last = i
  engine.trigger(i)
end

function randomize()
  for i = 1,voice_count do
    params:set("shape" .. i, math.random(0, 1))
    params:set("freq" .. i, math.random(20, 10000))
    params:set("decay" .. i, math.random())
    params:set("sweep" .. i, math.random(0, 2000))
    params:set("lfoFreq" .. i, math.random(1, 1000))
    params:set("lfoShape" .. i, math.random(0, 1))
    params:set("lfoSweep" .. i, math.random(0, 2000))
  end
end

-- sequencer section

er = require 'er'

local BeatClock = require 'beatclock'

local clk = BeatClock.new()
local clk_midi = midi.connect()
clk_midi.event = clk.process_midi

local reset = false
local running = true
local track_edit = 1
local current_pattern = 0
local current_pset = 0

local track = {}
for i=1,4 do
  track[i] = {
    k = 0,
    n = 9 - i,
    pos = 1,
    s = {}
  }
end

local pattern = {}
for i=1,112 do
  pattern[i] = {
    data = 0,
    k = {},
    n = {}
  }
  for x=1,4 do
    pattern[i].k[x] = 0
    pattern[i].n[x] = 0
  end
end

local function reer(i)
  if track[i].k == 0 then
    for n=1,32 do track[i].s[n] = false end
  else
    track[i].s = er.gen(track[i].k,track[i].n)
  end
end

local function trig()
  for i=1,4 do
    if track[i].s[track[i].pos] then
      trigger(i)
    end
  end
end

function init()
  setup_params()
  setup_midi()
  randomize()
  for i=1,4 do reer(i) end

  screen.line_width(1)

  clk.on_step = step
  clk.on_select_internal = function() clk:start() end
  clk.on_select_external = reset_pattern

  clk:add_clock_params()

  params:default()

  rudiments_load()

  clk:start()
end

function reset_pattern()
  reset = true
  clk:reset()
end

function step()
  if reset then
    for i=1,4 do track[i].pos = 1 end
    reset = false
  else
    for i=1,4 do track[i].pos = (track[i].pos % track[i].n) + 1 end
  end
  trig()
  redraw()
end

key1_hold = false
function key(n,z)
  if n==1 and z==1 then
    key1_hold = true
  elseif n==1 and z==0 then
    key1_hold = false
  elseif n==2 and z==1 then reset_pattern()
  elseif n==3 and z==1 then
    if key1_hold then
      randomize()
    elseif running then
      clk:stop()
      running = false
    else
      clk:start()
      running = true
    end
  end
  redraw()
end

function enc(n,d)
  if n==1 then
    if key1_hold then
      params:delta("bpm", d)
    else
      track_edit = util.clamp(track_edit+d,1,4)
    end
  elseif n == 2 then
    track[track_edit].k = util.clamp(track[track_edit].k+d,0,track[track_edit].n)
  elseif n==3 then
    track[track_edit].n = util.clamp(track[track_edit].n+d,1,32)
    track[track_edit].k = util.clamp(track[track_edit].k,0,track[track_edit].n)
  end
  reer(track_edit)
  redraw()
end

function redraw()
  screen.aa(0)
  screen.clear()
  screen.move(0,10)
  screen.level(4)
  if params:get("clock") == 1 then
    screen.text(params:get("bpm"))
  else
    for i=1,clk.beat+1 do
       screen.rect(i*2,1,1,2)
    end
    screen.fill()
  end
  for i=1,4 do
    screen.level((i == track_edit) and 15 or 4)
    screen.move(5, i*10 + 10)
    screen.text_center(track[i].k)
    screen.move(20,i*10 + 10)
    screen.text_center(track[i].n)

    for x=1,track[i].n do
      screen.level((track[i].pos==x and not reset) and 15 or 2)
      screen.move(x*3 + 30, i*10 + 10)
      if track[i].s[x] then
        screen.line_rel(0,-8)
      else
        screen.line_rel(0,-2)
      end
      screen.stroke()
    end
  end
  screen.update()
end

function rudiments_save()
  -- todo, should persist voice settings?
  local fd=io.open(norns.state.data .. "rudiments.data","w+")
  io.output(fd)
  for i=1,112 do
    io.write(pattern[i].data .. "\n")
    for x=1,4 do
      io.write(pattern[i].k[x] .. "\n")
      io.write(pattern[i].n[x] .. "\n")
    end
  end
  io.close(fd)
end

function rudiments_load()
  local fd=io.open(norns.state.data .. "rudiments.data","r")
  if fd then
    print("found datafile")
    io.input(fd)
    for i=1,112 do
      pattern[i].data = tonumber(io.read())
      for x=1,4 do
        pattern[i].k[x] = tonumber(io.read())
        pattern[i].n[x] = tonumber(io.read())
      end
    end
    io.close(fd)
  end
end

cleanup = function()
  rudiments_save()
end
