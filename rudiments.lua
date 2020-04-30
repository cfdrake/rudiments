-- rudiments
-- percussion synthesizer

-- TODO: Add velocity, sequencer, ...

engine.name = "Rudiments"

local last = 0

function init()
  setup_params()
  setup_midi()
  randomize()
end

function setup_params()
  for i = 1,8 do
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

function enc(n, d)
  return
end

function key(n, z)
  if n == 3 and z == 1 then
    print('randomize')
    randomize()
  end
end

function redraw()
  screen.clear()
  
  screen.move(50, 50)
  screen.font_face(1)
  screen.font_size(50)
  screen.aa(1)
  screen.level(15)
  
  if last > 0 then
    screen.text(last)
  end
  
  screen.update()
end

function trigger(i)
  last = i
  engine.trigger(i)
  redraw()
end

function randomize()
  for i = 1,8 do
    params:set("shape" .. i, math.random(0, 1))
    params:set("freq" .. i, math.random(20, 10000))
    params:set("decay" .. i, math.random())
    params:set("sweep" .. i, math.random(0, 2000))
    params:set("lfoFreq" .. i, math.random(1, 1000))
    params:set("lfoShape" .. i, math.random(0, 1))
    params:set("lfoSweep" .. i, math.random(0, 2000))
  end
end