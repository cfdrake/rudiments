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
nb = include("lib/nb/lib/nb")
mutil = require 'musicutil'
seq = require 'sequins'
local last = 0
rudiments_track_count = 8
local pitch_step_count = 4
local BeatClock = require 'beatclock'
local clk = BeatClock.new()
local all_midi = midi.connect()
local pitch_view_enable = false
last_note = {0, 0, 0, 0, 0, 0, 0, 0}
local note_trig_flag = {false, false, false, false, false, false, false, false}
key1_hold = false

-- grid initialization
col_11_flag = 0
g = grid.connect()

g:refresh()
for i=1,8 do
  g:led(1,i,1)
  g:led(2,i,1)
  g:led(3,i,6)
  g:led(4,i,6)
  g:led(5,i,1)
  g:led(6,i,1)
  g:led(7,i,6)
  g:led(8,i,6)
  g:led(9,i,1)
  g:led(10,i,1)  
  g:led(11,i,1)  
  g:led(12,i,0)  
  g:led(13,i,0)  
  g:led(14,i,0)
  g:led(15,i,0)    
  g:led(16,i,2)
end

grid_LED_seq = {}
track_pitch_seq = {}
track_pitch_pos = {}

for i = 1, rudiments_track_count do
  track_pitch_pos[i] = seq{12, 13, 14, 15} -- grid position in pitch sequence
end

-- sequencer initialization
er = require 'er' -- euclidean rhythm!
local reset = false
local running = true
local track_edit = 1
local current_pattern = 0
local current_pset = 0
-- let's prebake some strings so we don't have to spend time concatenating them
t_density = {"density1", "density2", "density3", "density4", "density5", "density6", "density7", "density8"}
t_length = {"length1", "length2", "length3", "length4", "length5", "length6", "length7", "length8"}
t_pitch = {"pitch1", "pitch2", "pitch3", "pitch4", "pitch5", "pitch6", "pitch7", "pitch8"}
nb_voices = {"nb_1", "nb_2", "nb_3", "nb_4","nb_5", "nb_6", "nb_7", "nb_8"}
track = {}
pitch_offset_number = 0

for i=1,rudiments_track_count do
  -- TODO: I've replaced track[i].k and track[i].n with density and length params accessible via norns menu
  -- I need to replace the rest of this, it used to have k = 0 and n = 9 - i in this table
  track[i] = {
    pos = 1, -- position in trigger sequence
    s = {} -- trigger TRUE or FALSE
  }
end

-- functions
function density_check(i)
  params:set(t_density[i], util.clamp(params:get(t_density[i]), 0, params:get(t_length[i])) )
  reer(i)
  redraw()
end

function setup_params()
  for i = 1,rudiments_track_count do
    -- OSC
    params:add_separator("Engine " .. i, i)

    -- Length, Density, Pitch Params
    params:add_number(t_length[i], "length " .. i, 1, 32, rudiments_track_count - i + 1)
    params:add_number(t_density[i], "density " .. i, 0, 32, 0)
    params:add_number(t_pitch[i], "pitch ".. i, 0, 127, 60)
    params:set_action(t_length[i], function(x)
      density_check(i)
    end)
    params:set_action(t_density[i], function(x)
      density_check(i)
    end)

    params:add_option("shape" .. i, "osc " .. i .. " shape", {"square", "triangle"})
    params:set_action("shape" .. i, function(x) engine.shape(x-1, i) end)
    -- params:add_control("freq" .. i, "osc " .. i .. " freq", controlspec.new(20, 10000, 'lin', 1, 120, 'hz'))
    -- params:set_action("freq" .. i, function(x) engine.freq(x, i) end) -- old freq param, using midi notes instead now

    -- ENV
    params:add_control("decay" .. i, "env " .. i .. " decay", controlspec.new(0.05, 1, 'lin', 0.01, 0.2, 'sec'))
    params:set_action("decay" .. i, function(x) engine.decay(x, i) end)
    params:add_control("sweep" .. i, "env " .. i .. " sweep", controlspec.new(0, 2000, 'lin', 1, 100, ''))
    params:set_action("sweep" .. i, function(x) engine.sweep(x, i) end)

    -- LFO
    params:add_control("lfoFreq" .. i, "lfo " .. i .. " freq", controlspec.new(1, 1000, 'lin', 1, 1, 'hz'))
    params:set_action("lfoFreq" .. i, function(x) engine.lfoFreq(x, i) end)
    params:add_option("lfoShape" .. i, "lfo " .. i .. " shape", {"square", "triangle"})
    params:set_action("lfoShape" .. i, function(x) engine.lfoShape(x-1, i) end)
    params:add_control("lfoSweep" .. i, "lfo " .. i .. " sweep", controlspec.new(0, 2000, 'lin', 1, 0, ''))
    params:set_action("lfoSweep" .. i, function(x) engine.lfoSweep(x, i) end)
  end
end

function setup_midi()
  all_midi.event = function(data)
    clk:process_midi(data)
  end
end



function randomize()
  for i = 1,rudiments_track_count do
    params:set(t_pitch[i], math.floor(math.random()*80+20))
    params:set("shape" .. i, math.random(1, 2))
    params:set("decay" .. i, math.random())
    params:set("sweep" .. i, math.random(0, 2000))
    params:set("lfoFreq" .. i, math.random(1, 1000))
    params:set("lfoShape" .. i, math.random(1, 2))
    params:set("lfoSweep" .. i, math.random(0, 2000))
  end
end

g.key = function(x,y,z)
  if z == 1 then

    -- track operations
    if x == 1 then
      -- ZERO DENSITY
      params:set(t_density[y], 0)
      density_check(y)

    elseif x == 2 then
      -- MORE DENSITY
      params:set(t_density[y], params:get(t_density[y]) + 1) -- add 1
      density_check(y)

    elseif x == 3 then
      -- TRACK LENGTH SET TO 0
      params:set(t_length[y], 1)
      params:set(t_density[y], util.clamp(params:get(t_density[y]), 0, params:get(t_length[y])))
      density_check(y)

    elseif x == 4 then
      -- MORE TRACK LENGTH
      params:set(t_length[y], util.clamp(params:get(t_length[y])+1, 1, 32))
      density_check(y)
      
    -- synth ops  
    elseif x == 5 then 
      -- OSC LOWER
      params:set(t_pitch[y], util.clamp(params:get(t_pitch[y]) - 1, 0, 127))

    elseif x == 6 then 
      -- OSC HIGHER
      params:set(t_pitch[y], util.clamp(params:get(t_pitch[y]) + 1, 0, 127))
      
    elseif x == 7 then
      -- ENV DECAY LOWER
      params:set("decay" .. y, util.clamp(params:get("decay" .. y)*0.9,0.01,1))
      params:set("sweep" .. y, math.random(0,2000))

      -- drumcrow = "amp_cycle"
      local player = params:lookup_param(nb_voices[y]):get_player()
      desc = player:describe()
      if string.find(desc.name, "drumcrow") then
        p_num = string.sub(desc.name, 10, 10)
        p_name = "drumcrow_amp_cycle_"..p_num
        params:set(p_name, util.clamp(params:get(p_name)*1.15, 0.1, 500))

      -- emplaitress = "decay"
      elseif string.find(desc.name, "emplait") then
        p_num = string.sub(desc.name, 9, 9)
        p_name = "plaits_decay_"..p_num
        params:set(p_name, util.clamp(params:get(p_name)-0.05, 0, 1))

      -- nb_rudiments, "rudiments_decay"
      elseif string.find(desc.name, "rudiments") then
        p_num = string.sub(desc.name, 11, 11)
        p_name = "rudiments_decay_"..p_num
        params:set(p_name, util.clamp(params:get(p_name)*0.9,0.05,1))

      -- oilcan, "oilcan carrier release"
      elseif string.find(desc.name, "Oilcan") then
        p_num = string.sub(params:string(nb_voices[y]), 8, 8) -- uhhh oilcan name isn't numbered for some reason, get the string directly from nb param
        for timbre = 1,7 do
          p_name = "oilcan_car_rel_"..timbre.."_"..p_num
          params:set(p_name, util.clamp(params:get(p_name)*0.9,0.01,3)) 
        end

      -- doubledecker, "doubledecker_amp_release_1" "doubledecker_amp_release_2"
      elseif string.find(desc.name, "doubledecker") then
        p_name = "doubledecker_amp_release_1"
        params:set(p_name, util.clamp(params:get(p_name)*0.9, 0, 8))
        p_name = "doubledecker_amp_release_2"
        params:set(p_name, util.clamp(params:get(p_name)*0.9, 0, 8))

      end

    elseif x == 8 then
      -- ENV DECAY HIGHER
      params:set("decay" .. y, util.clamp(params:get("decay" .. y)*1.1,0.01,1))
      params:set("sweep" .. y, math.random(0,2000))

      -- drumcrow = "amp_cycle"
      local player = params:lookup_param(nb_voices[y]):get_player()
      desc = player:describe()
      if string.find(desc.name, "drumcrow") then
        p_num = string.sub(desc.name, 10, 10)
        p_name = "drumcrow_amp_cycle_"..p_num
        params:set(p_name, util.clamp(params:get(p_name)*0.85, 0, 500))

      -- emplaitress = "decay"
      elseif string.find(desc.name, "emplait") then
        p_num = string.sub(desc.name, 9, 9)
        p_name = "plaits_decay_"..p_num
        params:set(p_name, util.clamp(params:get(p_name)+0.05, 0, 1))

      -- nb_rudiments, "rudiments_decay"
      elseif string.find(desc.name, "rudiments") then
        p_num = string.sub(desc.name, 11, 11)
        p_name = "rudiments_decay_"..p_num
        params:set(p_name, util.clamp(params:get(p_name)*1.1,0.05,1))

      -- oilcan, "oilcan carrier release"
      elseif string.find(desc.name, "Oilcan") then
        p_num = string.sub(params:string(nb_voices[y]), 8, 8) -- uhhh oilcan name isn't numbered for some reason, get the string directly from nb param
        for timbre = 1,7 do
          p_name = "oilcan_car_rel_"..timbre.."_" .. p_num
          params:set(p_name, util.clamp(params:get(p_name)*1.1,0.01,3)) 
        end

      -- doubledecker, "doubledecker_amp_release_1" "doubledecker_amp_release_2"
      elseif string.find(desc.name, "doubledecker") then
        p_name = "doubledecker_amp_release_1"
        params:set(p_name, util.clamp(params:get(p_name)*1.1, 0, 8))
        p_name = "doubledecker_amp_release_2"
        params:set(p_name, util.clamp(params:get(p_name)*1.1, 0, 8))

      end
      
    elseif x == 9 then
      -- LFO FREQ LOWER
      params:set("lfoFreq" .. y, util.clamp(params:get("lfoFreq" .. y)*0.95,1,1000))
      params:set("lfoSweep" .. y, math.random(0,2000))

      -- drumcrow = "pw"
      local player = params:lookup_param(nb_voices[y]):get_player()
      desc = player:describe()
      if string.find(desc.name, "drumcrow") then
        p_num = string.sub(desc.name, 10, 10)
        p_name = "drumcrow_pw_"..p_num
        params:set(p_name, util.clamp(params:get(p_name)-0.05, -1, 1))

      -- emplaitress = "harmonics"
      elseif string.find(desc.name, "emplait") then
        p_num = string.sub(desc.name, 9, 9)
        p_name = "plaits_harmonics_"..p_num
        params:set(p_name, util.clamp(params:get(p_name)-0.05, 0, 1))

      -- nb_rudiments
      elseif string.find(desc.name, "rudiments") then
        p_num = string.sub(desc.name, 11, 11)
        p_name = "rudiments_lfoFreq_"..p_num
        params:set(p_name, util.clamp(params:get(p_name)*0.9,1,1000)) 
        p_name = "rudiments_lfoSweep_"..p_num
        params:set(p_name, util.clamp(params:get(p_name)*0.9,1,2000)) 
      
      -- oilcan, modulation release decrease
      elseif string.find(desc.name, "Oilcan") then
        p_num = string.sub(params:string(nb_voices[y]), 8, 8)
        for timbre = 1,7 do
          p_name = "oilcan_mod_rel_"..timbre.."_" .. p_num
          params:set(p_name, util.clamp(params:get(p_name)*0.9,0.1,200)) 
        end

      -- doubledecker, "doubledecker_brilliance"
      elseif string.find(desc.name, "doubledecker") then
        p_name = "doubledecker_brilliance"
        params:set(p_name, util.clamp(params:get(p_name)-0.05, -1, 1))


      end
      
    elseif x == 10 then
      -- LFO FREQ HIGHER
      params:set("lfoFreq" .. y, util.clamp(params:get("lfoFreq" .. y)*1.05,1,1000))
      params:set("lfoSweep" .. y, math.random(0,2000))

      -- drumcrow = "pw"
      local player = params:lookup_param(nb_voices[y]):get_player()
      desc = player:describe()
      if string.find(desc.name, "drumcrow") then
        p_num = string.sub(desc.name, 10, 10)
        p_name = "drumcrow_pw_"..p_num
        params:set(p_name, util.clamp(params:get(p_name)+0.05, -1, 1))

      -- emplaitress = "harmonics"
      elseif string.find(desc.name, "emplait") then
        p_num = string.sub(desc.name, 9, 9)
        p_name = "plaits_harmonics_"..p_num
        params:set(p_name, util.clamp(params:get(p_name)+0.05, 0, 1))

      -- nb_rudiments, increase both lfoFreq and lfoShape
      elseif string.find(desc.name, "rudiments") then
        p_num = string.sub(desc.name, 11, 11)
        p_name = "rudiments_lfoFreq_"..p_num
        params:set(p_name, util.clamp(params:get(p_name)*1.1,1,1000))         
        p_name = "rudiments_lfoSweep_"..p_num
        params:set(p_name, util.clamp(params:get(p_name)*1.1,1,2000)) 

      -- oilcan, modulation release increase
      elseif string.find(desc.name, "Oilcan") then
        p_num = string.sub(params:string(nb_voices[y]), 8, 8)
        for timbre = 1,7 do -- there are 7 timbres for oilcan
          p_name = "oilcan_mod_rel_"..timbre.."_" .. p_num
          params:set(p_name, util.clamp(params:get(p_name)*1.1,0.1,200)) 
        end

      -- doubledecker, "doubledecker_brilliance"
      elseif string.find(desc.name, "doubledecker") then
        p_name = "doubledecker_brilliance"
        params:set(p_name, util.clamp(params:get(p_name)+0.05, -1, 1))

      end

    elseif x == 11 then
      -- ON/OFF Switch, unique behavior for each nb voice

      local player = params:lookup_param(nb_voices[y]):get_player()
      desc = player:describe()
      if col_11_flag == 0 then
        -- drumcrow = "pw2" = random
        if string.find(desc.name, "drumcrow") then
          p_num = string.sub(desc.name, 10, 10)
          params:set("drumcrow_bit_"..p_num, 1)
          params:set("drumcrow_lfo_bit_"..p_num, 1.7)
          params:set("drumcrow_amp_bit_"..p_num, 1)
          
        -- emplaitress = "fm_mod" = 1
        elseif string.find(desc.name, "emplait") then
          p_num = string.sub(desc.name, 9, 9)
          params:set("plaits_fm_mod_"..p_num, 0.9)

        -- nb_rudiments, set osc shape to 1
        elseif string.find(desc.name, "rudiments") then
          p_num = string.sub(desc.name, 11, 11) -- length of name + 2
          params:set("rudiments_shape_" .. p_num, 1)      

        -- oilcan, add 1 to note, midi note selects timbre on oilcan
        elseif string.find(desc.name, "Oilcan") then
          if params:get(t_pitch[y]) <= 126 and params:get(t_pitch[y]) >= 0 then -- max midi note 126 to add 1 to, min midi note is 0
            params:set(t_pitch[y], params:get(t_pitch[y]) + 1)
          end

        -- doubledecker, "pitch ratio 2" increment with wrapping
        elseif string.find(desc.name, "doubledecker") then
          p_name = "doubledecker_pitch_ratio_2"
          params:set(p_name, util.wrap(params:get(p_name)+1, 1, 9))

        end

        col_11_flag = 1
        g:led(x,y,15)
        g:refresh()
      else
        -- drumcrow = "pw2" = 0
        if string.find(desc.name, "drumcrow") then
          p_num = string.sub(desc.name, 10, 10)
          params:set("drumcrow_bit_"..p_num, 0)
          params:set("drumcrow_lfo_bit_"..p_num, 0)
          params:set("drumcrow_amp_bit_"..p_num, 0)

        -- emplaitress = "fm_mod" = 0
        elseif string.find(desc.name, "emplait") then
          p_num = string.sub(desc.name, 9, 9)
          params:set("plaits_fm_mod_"..p_num, 0)

        -- nb_rudiments, set osc shape to 0
        elseif string.find(desc.name, "rudiments") then
          p_num = string.sub(desc.name, 11, 11) -- length of name + 2
          params:set("rudiments_shape_" .. p_num, 0)

        -- oilcan, subtract 1 from note, midi note selects timbre on oilcan
        elseif string.find(desc.name, "Oilcan") then
          if params:get(t_pitch[y]) <= 127 and params:get(t_pitch[y]) >= 1 then -- max midi note 127, min midi note to sub from is 1
            params:set(t_pitch[y], params:get(t_pitch[y]) - 1)
          end

        -- doubledecker, "pitch ratio 2" increment with wrapping
        elseif string.find(desc.name, "doubledecker") then
          p_name = "doubledecker_pitch_ratio_2"
          params:set(p_name, util.wrap(params:get(p_name)+1, 1, 9))

        end

        col_11_flag = 0
        g:led(x,y,1)
        g:refresh()
      end

    elseif x == 12 or x == 13 or x == 14 or x == 15 then
      g:led(x, y, grid_LED_seq[x][y]()) -- inc LED brightness
      track_pitch_seq[x][y]() -- inc pitch offset for square
      g:refresh()

    elseif x == 16 then
      -- RANDOMIZE ALL
      if params:get("internal_ON_OFF") == 2 then
        params:set(t_pitch[y], math.floor(math.random()*80+20))
        params:set("shape" .. y, math.random(1, 2))
        params:set("decay" .. y, math.random())
        params:set("sweep" .. y, math.random(0, 2000))
        params:set("lfoFreq" .. y, math.random(1, 1000))
        params:set("lfoShape" .. y, math.random(1, 2))
        params:set("lfoSweep" .. y, math.random(0, 2000))
      end

      local player = params:lookup_param(nb_voices[y]):get_player()
      desc = player:describe()

      -- drumcrow
      if string.find(desc.name, "drumcrow") then
        p_num = string.sub(desc.name, 10, 10) -- length of name + 2
        params:set("drumcrow_amp_cycle_"..p_num, math.random() * 35 + 0.1)
        params:set("drumcrow_pw_"..p_num, math.random() * 2 - 1)
        params:set("drumcrow_pw2_"..p_num, math.random() * 20 - 10)
        -- randomize nb midi note
        params:set(t_pitch[y], math.floor(math.random()*80+20))

      -- emplaitress
      elseif string.find(desc.name, "emplait") then
        p_num = string.sub(desc.name, 9, 9) -- length of name + 2
        params:set("plaits_decay_"..p_num, math.random()*0.8)
        params:set("plaits_harmonics_"..p_num, math.random()*0.8)
        params:set("plaits_timbre_"..p_num, math.random()*0.8)
        params:set("plaits_morph_"..p_num, math.random()*0.8)
        -- randomize nb midi note
        params:set(t_pitch[y], math.floor(math.random()*80+20))

      -- nb_rudiments
      elseif string.find(desc.name, "rudiments") then
        p_num = string.sub(desc.name, 11, 11) -- length of name + 2
        -- everything except osc shape, set that with col 11
        params:set("rudiments_freq_" .. p_num, math.random(20, 10000))
        params:set("rudiments_decay_" .. p_num, math.random())
        params:set("rudiments_sweep_" .. p_num, math.random(0, 2000))
        params:set("rudiments_lfoFreq_" .. p_num, math.random(1, 1000))
        params:set("rudiments_lfoShape_" .. p_num, math.random(0, 1))
        params:set("rudiments_lfoSweep_" .. p_num, math.random(0, 2000))
        -- randomize nb midi note
        params:set(t_pitch[y], math.floor(math.random()*80+20))

      -- oilcan      
      elseif string.find(desc.name, "Oilcan") then
        p_num = string.sub(params:string(nb_voices[y]), 8, 8)
        -- each player of oilcan has 7 timbres
        -- "oilcan_mod_ratio_1_3" example of parameter name where 1 is timbre (1-7) 3 is player (1-4?)
        -- I think randomize all timbres sounds like a plan
        for timbre = 1,7 do
          params:set("oilcan_freq_"..timbre.."_" .. p_num, 600*math.random()^2 + 5) -- freq
          params:set("oilcan_sweep_time_"..timbre.."_" .. p_num, math.random()*2.5) -- sweep time
          params:set("oilcan_sweep_ix_"..timbre.."_" .. p_num, math.random()*0.6 - 0.3) -- sweep index
          params:set("oilcan_car_rel_"..timbre.."_" .. p_num, math.random()) -- carrier release
          params:set("oilcan_mod_rel_"..timbre.."_" .. p_num, math.random()*100) -- modulator release
          params:set("oilcan_mod_ix_"..timbre.."_" .. p_num, math.random()*0.25) -- modulator level
          params:set("oilcan_mod_ratio_"..timbre.."_" .. p_num, 10*math.random()^2) -- modulator ratio
          params:set("oilcan_fb_"..timbre.."_" .. p_num, math.random()*1.5) -- feedback
          params:set("oilcan_fold_"..timbre.."_" .. p_num, math.random()^2*15) -- fold
        end

      -- doubledecker
      elseif string.find(desc.name, "doubledecker") then
        params:set("doubledecker_brilliance", math.random()*2 - 1)
        params:set("doubledecker_amp_release_1", math.random()*3)
        params:set("doubledecker_amp_release_2", math.random()*3)
        params:set("doubledecker_portomento", math.random()*0.25)
        params:set("doubledecker_lp_freq_1", math.random()*1500 + 100)
        params:set("doubledecker_lp_freq_2", math.random()*1500 + 100)
        params:set("doubledecker_lp_res_1", math.random()*0.9)
        params:set("doubledecker_lp_res_2", math.random()*0.9)
        params:set("doubledecker_hp_freq_1", math.random()*1500 + 20)
        params:set("doubledecker_hp_freq_2", math.random()*1500 + 20)
        params:set("doubledecker_hp_res_1", math.random()*0.9)
        params:set("doubledecker_hp_res_2", math.random()*0.9)
        params:set("doubledecker_filter_init_1", math.random()*2-1)
        params:set("doubledecker_filter_init_2", math.random()*2-1)
        params:set("doubledecker_filter_attack_level_1", math.random()*2-1)
        params:set("doubledecker_filter_attack_level_2", math.random()*2-1)

      end
      g:led(x,y,math.random(1,15))
      g:refresh()
    end
  end
end


-- sequencer section

function reer(i)
  if params:get(t_density[i]) == 0 then
    for n=1,32 do
      track[i].s[n] = false
    end
  else
    track[i].s = er.gen(params:get(t_density[i]), params:get(t_length[i]))
  end
end

local function trig()
  for i=1,rudiments_track_count do
    if track[i].s[track[i].pos] then
      if params:get("internal_accents") == 2 then
        params:set("lfoShape" .. i, math.random(1, 2))
      end
      if note_trig_flag[i] then
        trigger_note_off(i) -- turn off previous note
      end
      trigger(i)
      g:led(1,i,15) -- high brightness trigger on square 1

      for j = 1,4 do
        g:led(j + 11, i, grid_LED_seq[j+11][i]:peek()) -- set grid LED values
      end
      g:led(track_pitch_pos[i]:peek(), i, 15) -- highlight the pitch sequence square that we're at

    else
      if note_trig_flag[i] then
        trigger_note_off(i) -- turn off previous note
      end
      g:led(1,i,1) -- turn off square 1

    end
    g:led(16,i,math.random(1,15)) -- always randomize the random button
    g:refresh()

  end
end

function trigger(i)
  last = i
  col = track_pitch_pos[i]() -- increment pitch sequence position on trigger
  last_note[i] = params:get(t_pitch[i]) + track_pitch_seq[col][i]:peek() -- get pitch offset from grid square
  if params:get("internal_ON_OFF") == 2 then
    engine.freq(mutil.note_num_to_freq(last_note[i]), i) -- current freq to midi, add offset, midi to freq, set engine freq
    engine.trigger(i) -- triggers internal rudiments SC engine
  end
  -- trigger nb voice
  local player = params:lookup_param(nb_voices[i]):get_player()
  player:play_note(util.clamp(last_note[i], 0, 127), 5, params:get("nb_note_length"))
  note_trig_flag[i] = true
end

function trigger_note_off(i)
  -- call this first to release previous note, then call trigger to increment to new note
  note_trig_flag[i] = false
  local player = params:lookup_param(nb_voices[i]):get_player()
  player:note_off(util.clamp(last_note[i], 0, 127))
end

function init()
  nb.voice_count = 1
  nb:init()
  nb:add_param(nb_voices[1], nb_voices[1])
  nb:add_param(nb_voices[2], nb_voices[2])
  nb:add_param(nb_voices[3], nb_voices[3])
  nb:add_param(nb_voices[4], nb_voices[4])
  nb:add_param(nb_voices[5], nb_voices[5])
  nb:add_param(nb_voices[6], nb_voices[6])
  nb:add_param(nb_voices[7], nb_voices[7])
  nb:add_param(nb_voices[8], nb_voices[8])
  nb:add_player_params()

  params:add_control("nb_note_length", "NB Note Length", controlspec.new(0, 10, 'lin', 0.1, 1, '')) 
  params:add_option("internal_ON_OFF", "Internal: Engine", {"OFF", "ON"}, 2)
  params:add_option("internal_accents", "Internal: Accents", {"OFF", "ON"}, 2)
  params:add_separator("Internal Engine", "Internal Engine")
  clk:add_clock_params()
  setup_params()
  setup_midi()
  randomize()
  track_notes = {60, 60, 60, 60, 60, 60, 60, 60} -- set default note to 60 after randomize()
  
  for i=1,rudiments_track_count do reer(i) end

  screen.line_width(1)

  clk.on_step = step
  clk.on_select_internal = function() clk:start() end
  clk.on_select_external = reset_pattern
  params:default()
  clk:start()

  -- ...was having trouble initializing these arrays??? idk???
  for x = 12,15 do -- grid columns 
    grid_LED_seq[x] = {}
    track_pitch_seq[x] = {}
  end
  for x = 12,15 do -- grid columns 
    for y = 1,8 do -- grid rows
      grid_LED_seq[x][y] = seq{0, 1, 5, 9} -- grid square LED brightness
      track_pitch_seq[x][y] = seq{0, 5, 7, 12} -- grid square pitch offsets
      g:led(x, y, grid_LED_seq[x][y]())
      track_pitch_seq[x][y]()
      g:refresh()
    end
  end

end

function reset_pattern()
  reset = true
  clk:reset()
end

function step()
  if reset then
    for i=1,rudiments_track_count do track[i].pos = 1 end
    reset = false
  else
    for i=1,rudiments_track_count do track[i].pos = (track[i].pos % params:get(t_length[i])) + 1 end
  end
  
  trig()
  redraw()
end


function key(n,z) -- n is number 1-3, z is pressed: 1, released: 0
  if     n==1 and z==1 then
    key1_hold = true
  elseif n==1 and z==0 then
    key1_hold = false
  elseif n==2 and z==1 then 
    if key1_hold then
      if pitch_view_enable == true then
        pitch_view_enable = false
      else
        pitch_view_enable = true
      end
    else
      reset_pattern()
    end
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

function enc(n,d) -- number, direction/step?
  redraw_flag = true
  if pitch_view_enable == false then
    if n==1 then -- trigger sequencer view
      if key1_hold then
        params:delta("bpm", d)
      else
        track_edit = util.clamp(track_edit+d,1,rudiments_track_count)
      end
    elseif n == 2 then
      params:set(t_density[track_edit], params:get(t_density[track_edit]) + d)
      redraw_flag = false
    elseif n==3 then
      params:set(t_length[track_edit], params:get(t_length[track_edit]) + d)
      params:set(t_density[track_edit], util.clamp(params:get(t_density[track_edit]), 0, params:get(t_length[track_edit])))
      redraw_flag = false
    end
  else -- pitch sequencer view
    if n==1 then
      track_edit = util.clamp(track_edit+d,1,rudiments_track_count) -- select track
    elseif n == 2 then
      params:set(t_pitch[track_edit], util.clamp(params:get(t_pitch[track_edit]) + d, 0, 127)) -- select pitch
    elseif n == 3 then
      if d < 0 then 
        for x = 12, 15 do
          if math.random() > 0.5 then
            g:led(x, track_edit, grid_LED_seq[x][track_edit]())
            track_pitch_seq[x][track_edit]()
          end
        end
      else
        for x = 12, 15 do
          g:led(x, track_edit, grid_LED_seq[x][track_edit]())
          track_pitch_seq[x][track_edit]()
        end
      end
    end
  end

  if redraw_flag == true then
    reer(track_edit)
    redraw()
  end
end

function redraw()
  screen.aa(0)
  screen.clear()

  if pitch_view_enable == false then -- trigger sequencer
    for i=1,rudiments_track_count do
      -- first two numbers and brightness
      screen.level((i == track_edit) and 15 or 4) -- 0 to 15 brightness, 15 if selected with track_edit 1-8
      screen.move(5, i*8) -- move draw cursor, 8, ... , 64
      screen.text_center(params:get(t_density[i]))
      screen.move(20,i*8) -- move draw cursor
      screen.text_center(params:get(t_length[i]))

      -- create sequence and brightness
      -- for x=1,track[i].n do
      for x=1,params:get(t_length[i]) do
        screen.level((track[i].pos==x and not reset) and 15 or 2)
        screen.move(x*3 + 30, i*8) -- move draw cursor
        
        if track[i].s[x] then
          screen.line_rel(0,-8) -- draw line relative to current position
        else
          screen.line_rel(0,-2) -- draw line relative to current position
        end
        
        screen.stroke() -- renders all the stuff drawn
      end
    end
  else -- pitch sequencer
    for i = 1, rudiments_track_count do
      -- first two numbers and brightness
      screen.level((i == track_edit) and 15 or 4) -- 0 to 15 brightness, 15 if selected with track_edit 1-8
      screen.move(5, i*8) -- move draw cursor, 8, ... , 64
      screen.text_center(#track_pitch_pos[i]) -- draw text, length of pitch offset sequence
      screen.move(20,i*8) -- move draw cursor
      screen.text_center(params:get(t_pitch[i])) -- draw text, base note of sequence

      -- create line sequence and brightness
      pitch_pos = track_pitch_pos[i]:peek()
      for x = 12, 15 do
        screen.level((pitch_pos == x and not reset) and 15 or 2)
        screen.move((x-11)*3 + 30, i*8) -- move draw cursor

        pitch_offset = track_pitch_seq[x][i]:peek()
        if     pitch_offset == 0 then
          screen.line_rel(0,-2) -- draw line relative to current position
        elseif pitch_offset == 5 then
          screen.line_rel(0,-4)
        elseif pitch_offset == 7 then
          screen.line_rel(0,-6)
        elseif pitch_offset == 12 then
          screen.line_rel(0,-8)
        else
          screen.line_rel(0,-2) -- shouldn't ever get here
        end
        
        screen.stroke() -- renders all the stuff drawn
      end

    end
  end
  
  screen.update() -- uhhh.... updates the screen with the new render?
end
