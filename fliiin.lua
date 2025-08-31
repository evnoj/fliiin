-- flin
--
-- cyclic poly-rhythm music box
--
-- originally by tehn
-- adapted for iii by evnoj

-- midi note velocity
vel = 127
default_clock_mode = "auto" -- "auto", "internal", or "midi"
default_internal_bpm = 120 -- 2-198, MUST BE EVEN (config UI only supports even internal bpms)

-- up to 16 banks
note_bank = 1 -- initial bank
note_banks = {}
note_banks[1] = { 2, 4, 5, 7, 9, 11, 12, 14, 16, 17, 19, 21, 23, 24, 26, 28, }
note_banks[4] = { 38, 40, 41, 43, 45, 47, 48, 50, 52, 53, 55, 57, 59, 60, 62, 64, }
-- ascending fourths
note_banks[2] = { 24, 29, 34, 39, 44, 49, 54, 59, 64, 69, 74, 79, 84, 89, 94, 99, }
-- ascending fifths
note_banks[3] = { 12, 19, 26, 33, 40, 47, 54, 61, 68, 75, 82, 89, 96, 103, 110, 117, }

-- the midi channels the columns output on at startup
-- configurable at runtime, but no on device preset saving yet
chans = { 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, }
-- chans = { 1, 1, 1, 1, 1, 1, 1, 1, 1,  1,  1,  1,  1,  1,  1,  1, }

local function draw_col(col)
  local x = col.x
  local y = col.pos

  for i=0,col.len-1 do
    grid_led(x, y - i, 15)
  end
end

local function redraw()
  grid_led_all(0)

  if config_page.active then
    grid_led(note_bank, 2, 15)

    for i=1,12 do
      grid_led(i, 3, 2)
    end
    grid_led(transpose + 1, 3, 15)

    for i=0,2 do
      grid_led(14+i, 3, i+1)
    end
    grid_led(15 + octave, 3, 15)

    grid_led(config_page.ch_col_select, 4, 15)
    grid_led(cols[config_page.ch_col_select].ch, 5, 15)

    local level = 15
    for i=0,4 do
      grid_led(12 + i, 6, i+1)
    end
    if clock.source == "internal" then
      grid_led(12 + clock.internal_divider, 6, 15)
    else
      grid_led(12 + clock.midi_divider, 6, 15)
      level = 6
    end
    for i=1,10 do
      grid_led(i, 6, 3)
      grid_led(i, 7, 1)
    end
    grid_led(clock.coarse, 6, level)
    grid_led(clock.fine, 7, level)

    if clock.mode == "auto" then
      grid_led(16, 7, 15)
      if clock.source == "internal" then
        grid_led(14, 7, 2)
      elseif clock.source == "midi" then
        grid_led(15, 7, 2)
      end
    elseif clock.mode == "internal" then
      grid_led(14, 7, 15)
    elseif clock.mode == "midi" then
      grid_led(15, 7, 15)
    end
  else
    for _,col in pairs(running_cols) do
      draw_col(col)
    end
  end

  grid_refresh()
end

local function note_on(col)
  midi_note_on(col.note + transpose + 12 * octave, col.vel, col.ch)
end

local function note_off(col)
  midi_note_off(col.note + transpose + 12 * octave, col.vel, col.ch)
end

local function tick_col(col)
  col.div_tick = (col.div_tick + 1) % col.div

  if col.div_tick == 0 then
    col.pos = (col.pos + 1) % height
  end

  if col.pos - col.len <= 0 then
    if not col.on then
      note_on(col)
      col.on = true
    end
  else
    if col.on then
      note_off(col)
      col.on = false
    end
  end
end

local function stop_col(col)
  if col.on then
    note_off(col)
  end

  col.on = false
  running_cols[col.x] = nil
end

local function start_col(col, div, len)
  if running_cols[col.x] then
    stop_col(col)
  end
  col.div = div
  col.len = len
  col.div_tick = div-1
  col.pos = height
  col.keys.div.y = nil
  col.keys.len.y = nil
  running_cols[col.x] = col
end

local function tick()
  -- print("tick")
  for _,col in pairs(running_cols) do
    tick_col(col)
  end

  if not config_page.active then
    redraw()
  end
end

local function internal_tick()
  tick()

  if clock.dirty then
    start_internal_ticker(bpm_to_ms(clock.internal_bpm))
    clock.dirty = false
  end
end

local function midi_tick()
  tick()
end

local function start_internal_ticker(time)
  metro.stop(clock.ticker)
  clock.internal_ticker_ms = math.floor(time / clock.internal_calculated_time_div)
  clock.ticker = metro.new(internal_tick, clock.internal_ticker_ms)
end

local function start_midi_ticker(time)
  metro.stop(clock.ticker)
  clock.midi_ticker_ms = math.floor(time / clock.midi_calculated_time_div)
  clock.ticker = metro.new(midi_tick, clock.midi_ticker_ms, 4*2^(clock.midi_divider))
end

local function reset_cols(cols)
  for x,col in pairs(cols) do
    col.pos = height
    col.div_tick = col.div-1
  end

  redraw()
end

local function change_note_bank(n)
  if not note_banks[n] then
    print("no note bank at index "..n)
    return
  end

  note_bank = n
  notes = note_banks[n]

  for x,col in pairs(cols) do
    if col.on then
      note_off(col)
      col.note = notes[x]
      note_on(col)
    else
      col.note = notes[x]
    end
  end
end

local function change_chan(x, chan)
  if running_cols[x] and running_cols[x].on then
    local col = running_cols[x]
    note_off(col)
    col.ch = chan
    note_on(col)
  else
    cols[x].ch = chan
  end
end

local function change_transpose(t)
  local prev_t = transpose
  transpose = t

  for x,col in pairs(running_cols) do
    if col.on then
      midi_note_off(col.note + prev_t + 12 * octave, col.vel, col.ch)
      note_on(col)
    end
  end
end

local function change_octave(oct)
  local prev_oct = octave
  octave = oct

  for x,col in pairs(running_cols) do
    if col.on then
      midi_note_off(col.note + transpose + 12 * prev_oct, col.vel, col.ch)
      note_on(col)
    end
  end
end

local function bpm_to_ms(bpm)
  return math.floor(60 / bpm / 16 * 1000)
end

local function avg(t)
  local sum = 0
  local n = #t

  for i=1,n do
    sum = sum + t[i]
  end

  return sum / n
end

-- given time in ms of a 16th note, return the bpm
local function sixteenth_to_bpm(ms)
  local bpm = 60000 / (ms * 4)
  return math.floor(bpm * 100) / 100
end

-- utility to help with user-defined default internal bpm
local function bpm_to_coarse_fine(bpm)
  if bpm % 2 ~= 0 or bpm < 2 or 198 < bpm then
    error("bpm must be even integer in range 2-198, was "..bpm, 2)
  end

  local coarse = math.floor(bpm/20)
  local fine =  math.floor((bpm - coarse*20) / 2)

  return coarse+1,fine+1
end

local function midi_sync(d1,d2,d3,d4)
  clock.midi_received = true

  if d1==8 and d2==240 then
    local ticks = clock.midi_div_ticks
    ticks = ((ticks + 1) % 24)
    clock.midi_div_ticks = ticks

    -- midi is 24 ppq, track tempo every 16th note
    if ticks % 6 == 0 then
      local current_time = get_time()

      if clock.midi_clock_last_time then
        local elapsed_time = current_time - clock.midi_clock_last_time
        table.insert(clock.midi_clock_times, 1, elapsed_time)
        clock.midi_clock_times[5] = nil
      end

      clock.midi_clock_last_time = current_time
    end

    -- sync internal ticker every quarter note
    if ticks == 0 then
      metro.stop(clock.ticker)

      local sixteenth_ms = avg(clock.midi_clock_times)
      clock.midi_bpm = sixteenth_to_bpm(sixteenth_ms)

      start_midi_ticker(sixteenth_ms/4)
    end
  else
    -- ps("midi_rx %d %d %d %d",d1,d2,d3,d4)
  end
end

local function midi_ignore(d1,d2,d3,d4)
  
end

local function midi_await(d1,d2,d3,d4)
  if d1==8 and d2==240 then
    clock.source = "midi"
    update_clock(clock)

    if config_page.active then
      redraw()
    end
  end

end

local function midi_timeout_check()
  if clock.midi_received == false and clock.mode == "auto" then
    clock.source="internal"
    update_clock(clock)

    if config_page.active then
      redraw()
    end
  else
    clock.midi_received = false
  end
end

function update_clock(clock)
  if clock.mode == "auto" then
    if clock.source == "midi" then
      if not clock.midi_timeout_check then
        clock.midi_timeout_check = metro.new(midi_timeout_check, 3000)
      end

      midi_rx = midi_sync
    else
      midi_rx = midi_await
    end
  elseif clock.mode == "internal" then
    clock.source = "internal"
    midi_rx = midi_ignore
  elseif clock.mode == "midi" then
    clock.source = "midi"
  end

  if clock.source == "internal" then
    local bpm =  0 + 20 * (clock.coarse - 1) + 2 * (clock.fine - 1)

    if not clock.internal_bpm then -- first internal clock since startup
      clock.internal_bpm = bpm
      clock.dirty = false
      start_internal_ticker(bpm_to_ms(bpm))
    elseif clock.midi_clock_times then -- switching to internal clock from midi
      clock.midi_clock_times = nil -- indicates not following midi clock
      clock.internal_bpm = bpm
      clock.dirty = false
      start_internal_ticker(bpm_to_ms(bpm))
    elseif clock.internal_ticker_ms ~= math.floor(bpm_to_ms(bpm) / clock.internal_calculated_time_div) then
      clock.internal_bpm = bpm
      clock.dirty = true
    end
  elseif clock.source == "midi" then
    clock.internal_bpm = nil
    -- switching to midi clock from internal clock (or startup on midi clock)
    if not clock.midi_clock_times then
      clock.midi_clock_times = {}
      clock.midi_clock_last_time = nil
      start_midi_ticker(bpm_to_ms(clock.midi_bpm))
    end

    midi_rx = midi_sync
  end
end

grid = function(x,y,z)
  if config_page.active then
    if z == 1 then
      if y == 2 then
        change_note_bank(x)
      elseif y == 3 then
        if x <= 12 then
        change_transpose(x - 1)
        elseif x >= 14 then
          change_octave(x - 15)
        end
      elseif y == 4 then
        config_page.ch_col_select = x
      elseif y == 5 then
        change_chan(config_page.ch_col_select, x)
      elseif y == 6 then
        if x <= 10 then
          if clock.source == "internal" then
            clock.coarse = x
          end
        elseif x >= 12 then
          if clock.source == "internal" then
            clock.internal_divider = x-12
            clock.internal_calculated_time_div = 1/4 * 2^(clock.internal_divider)
          elseif clock.source == "midi" then
            clock.midi_divider = x-12
            clock.midi_calculated_time_div = 1/4 * 2^(clock.midi_divider)
          end
        end

        update_clock(clock)
      elseif y == 7 then
        if x <= 10 then
          if clock.source == "internal" then
            clock.fine = x
          end

          update_clock(clock)
        elseif x >= 14 then
          if x == 14 then
            clock.mode = "internal"
          elseif x == 15 then
            clock.mode = "midi"
          elseif x == 16 then
            clock.mode = "auto"
          end

          update_clock(clock)
        end
      elseif y == grid_height and x == 1 then -- exit config page
        config_page.active = false
      end
    end
  else
    if y == grid_height then
      if z == 1 then
        if x == 1 and cols[16].keys.div.z == 1 and not cols[16].keys.len.y then
          config_page.active = true
          cols[16].keys.div.y = nil
          cols[16].keys.div.z = 0
        elseif x == 16 and cols[1].keys.div.z == 1 and not cols[1].keys.len.y then
          reset_cols(running_cols)
          cols[16].keys.div.y = nil
          cols[16].keys.div.z = 0
        else
          if cols[x].keys.div.y then -- cancelling segment creation
            cols[x].keys.div.y = nil
            cols[x].keys.div.z = 0
            cols[x].keys.len.y = nil
            cols[x].keys.len.z = 0
          elseif running_cols[x] then -- stopping column
            stop_col(running_cols[x])
          end
        end
      end
    else
      local col = cols[x]

      if z == 1 then
        if not col.keys.div.y then
          col.keys.div.y = y
          col.keys.div.z = 1
        elseif not col.keys.len.y then
          col.keys.len.y = y
          col.keys.len.z = 1
        end

        -- config page
        --
      else
        if y == col.keys.div.y then
          col.keys.div.z = 0

          if col.keys.len.y then
            if col.keys.len.z == 0 then -- activate
              if col.keys.len.y == 1 then
                start_col(col, y, y)
              else
                start_col(col, y, col.keys.len.y)
              end
            end
          else
            start_col(col, y, 1)
          end
        elseif y == col.keys.len.y then
          col.keys.len.z = 0

          if col.keys.div.z == 0 then -- activate
            if y == 1 then
              start_col(col, col.keys.div.y, col.keys.div.y)
            else
              start_col(col, col.keys.div.y, y)
            end
          end
        end
      end
    end
  end

  redraw()
end

local function init()
  -- validate note and channel banks
  for n,bank in pairs(note_banks) do
    for i,note in ipairs(bank) do
      if not (0 <= note and note <= 127) then
        print("init error: note bank "..n.." note "..i.." has value "..note..", allowed range 0-127")
        return
      end
    end
  end

  grid_height = grid_size_y()
  height = grid_height * 2
  config_page = {
    active = false,
    ch_col_select = 1
  }
  transpose = 0
  octave = 0
  cols = {}
  running_cols = {}

  -- ex. reference for fields of a column
  local col_ex = {
    x = 1, -- x coord
    pos = 0, -- leading square
    len = 1, -- >=1
    div = 1,
    div_tick = 0,
    note = 1,
    ch = 1,
    on = false,
    keys = {
      div = {},
      len = {
        y = 1,
        z = 1
      }
    },
  }

  for i=1,grid_size_x() do
    local col = {}
    col.x = i
    col.note = note_banks[note_bank][i]
    col.ch = chans[i]
    col.vel = vel
    col.on = false
    col.keys = {}
    col.keys.div = {}
    col.keys.len = {}

    cols[i] = col
  end

  clock ={
    coarse = 1, -- 1-10
    fine = 1, -- 1-10
    mode = default_clock_mode, -- "auto", "internal", "midi"
    internal_divider = 2, -- 0-4, 2 is center, adjacent steps mult/div by 2
    midi_divider = 2,
    midi_div_ticks = 0,
    midi_bpm = 120, -- must be initialized, updated as soon as tempo is calculated
    ticker = 100, -- dummy metro id, must be initialized
  }
  clock.internal_calculated_time_div = 1/4 * 2^(clock.internal_divider)
  clock.midi_calculated_time_div = 1/4 * 2^(clock.midi_divider)

  clock.coarse,clock.fine = bpm_to_coarse_fine(default_internal_bpm)

  if clock.mode == "auto" then
    clock.source = "internal"
  end
  update_clock(clock)
end

init()
