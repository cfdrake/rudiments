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

engine.name = "Rudiments"

local last = 0

local voice_count = 8

local accents = 1

local BeatClock = require 'beatclock'

local clk = BeatClock.new()
local all_midi = midi.connect()


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
  all_midi.event = function(data)
    clk:process_midi(data)
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

-- grid section

g = grid.connect()

-- show mapped buttons
-- TODO: some sort of visual feedback
for i=1,8 do

  g:led(1,i,1)
  g:led(2,i,1)
  g:led(3,i,3)
  g:led(4,i,3)
  g:led(5,i,1)
  g:led(6,i,1)
  g:led(7,i,3)
  g:led(8,i,3)
  g:led(9,i,5)
  g:led(10,i,5)
  
  g:led(15,i,2)

end
g:refresh()


g.key = function(x,y,z)
  if z == 1 then

    -- track operations
    if x == 1 then
      -- CLEAR TRACK
      track[y].k = 0
      reer(y)
      redraw()      
    elseif x == 2 then
      -- MORE DENSITY
      track[y].k = util.clamp(track[y].k+1,0,track[y].n)
      reer(y)
      redraw()

    elseif x == 3 then
      -- LESS TRACK LENGTH
      track[y].n = 1
      -- track[y].n = util.clamp(track[y].n-1,1,32)
      track[y].k = util.clamp(track[y].k,0,track[y].n)
      reer(y)
      redraw()
    elseif x == 4 then
      -- MORE TRACK LENGTH
      track[y].n = util.clamp(track[y].n+1,1,32)
      track[y].k = util.clamp(track[y].k,0,track[y].n)
      reer(y)
      redraw()
      
    -- synth ops  
    elseif x == 5 then 
      -- OSC LOWER
      params:set("freq" .. y, util.clamp(params:get("freq" .. y)*0.9,20,10000))
    elseif x == 6 then 
      -- OSC HIGHER
      params:set("freq" .. y, util.clamp(params:get("freq" .. y)*1.1,20,10000))
      
    elseif x == 7 then
      -- ENV DECAY
      params:set("decay" .. y, util.clamp(params:get("decay" .. y)*0.9,0.01,1))
      params:set("sweep" .. y, math.random(0,2000))
    elseif x == 8 then
      -- ENV DECAY
      params:set("decay" .. y, util.clamp(params:get("decay" .. y)*1.1,0.01,1))
      params:set("sweep" .. y, math.random(0,2000))

      
    elseif x == 9 then
      -- LFO FREQ
      params:set("lfoFreq" .. y, util.clamp(params:get("lfoFreq" .. y)*0.95,1,1000))
      -- params:set("lfoShape" .. y, math.random(0, 1))
      params:set("lfoSweep" .. y, math.random(0,2000))
      
    elseif x == 10 then
      -- LFO FREQ
      params:set("lfoFreq" .. y, util.clamp(params:get("lfoFreq" .. y)*1.05,1,1000))
      -- params:set("lfoShape" .. y, math.random(0, 1))
      params:set("lfoSweep" .. y, math.random(0,2000))


    elseif x == 15 then
      -- RANDOMIZE ALL
      params:set("shape" .. y, math.random(0, 1))
      params:set("freq" .. y, math.random(20, 10000))
      params:set("decay" .. y, math.random())
      params:set("sweep" .. y, math.random(0, 2000))
      params:set("lfoFreq" .. y, math.random(1, 1000))
      params:set("lfoShape" .. y, math.random(0, 1))
      params:set("lfoSweep" .. y, math.random(0, 2000))
      



    end
  end
end


-- sequencer section

er = require 'er'

local reset = false
local running = true
local track_edit = 1
local current_pattern = 0
local current_pset = 0

track = {}
for i=1,voice_count do
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
  for x=1,voice_count do
    pattern[i].k[x] = 0
    pattern[i].n[x] = 0
  end
end

function reer(i)
  if track[i].k == 0 then
    for n=1,32 do track[i].s[n] = false end
  else
    track[i].s = er.gen(track[i].k,track[i].n)
  end
end

local function trig()
  for i=1,voice_count do
    if track[i].s[track[i].pos] then
      if accents==1 then
        params:set("lfoShape" .. i, math.random(0, 1))
      end
      trigger(i)
      g:led(1,i,15)
    else
      g:led(1,i,1)
    end
    g:refresh()
  end
end

function init()
  params:add_separator()
  clk:add_clock_params()
  setup_params()
  setup_midi()
  randomize()
  
  for i=1,voice_count do reer(i) end

  screen.line_width(1)

  clk.on_step = step
  clk.on_select_internal = function() clk:start() end
  clk.on_select_external = reset_pattern

  params:default()

  clk:start()
end

function reset_pattern()
  reset = true
  clk:reset()
end

function step()
  if reset then
    for i=1,voice_count do track[i].pos = 1 end
    reset = false
  else
    for i=1,voice_count do track[i].pos = (track[i].pos % track[i].n) + 1 end
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
      track_edit = util.clamp(track_edit+d,1,voice_count)
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

  for i=1,voice_count do
    screen.level((i == track_edit) and 15 or 4)
    screen.move(5, i*8)
    screen.text_center(track[i].k)
    screen.move(20,i*8)
    screen.text_center(track[i].n)

    for x=1,track[i].n do
      screen.level((track[i].pos==x and not reset) and 15 or 2)
      screen.move(x*3 + 30, i*8)
      
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
