-- flin
--
-- cyclic poly-rhythm music box
--
-- originally by tehn
-- adapted for iii by evnoj

-- midi note velocity
vel = 127

-- up to 16 banks
note_bank = 1 -- initial bank
note_banks = {}
note_banks[1] = { 2, 4, 5, 7, 9, 11, 12, 14, 16, 17, 19, 21, 23, 24, 26, 28, }
-- ascending fourths
note_banks[2] = { 24, 29, 34, 39, 44, 49, 54, 59, 64, 69, 74, 79, 84, 89, 94, 99, }
-- ascending fifths
note_banks[3] = { 12, 19, 26, 33, 40, 47, 54, 61, 68, 75, 82, 89, 96, 103, 110, 117, }

-- up to 16 banks
chan_bank = 1 -- initial bank
chan_banks = {}
chan_banks[1] = { 1, 1, 1, 1, 1, 1, 1, 1, 1,  1,  1,  1,  1,  1,  1,  1, }
chan_banks[2] = { 2, 2, 2, 2, 2, 2, 2, 2, 2,  2,  2,  2,  2,  2,  2,  2, }
chan_banks[3] = { 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, }

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

local function draw_col(col)
  local x = col.x
  local y = col.pos

  for i=0,col.len-1 do
    grid_led(x, y - i, 15)
  end
end

local function redraw()
  grid_led_all(0)

  if config_page then
    grid_led(note_bank, 2, 15)
    grid_led(transpose + 1, 3, 15)
    grid_led(3 + octave, 4, 15)
    grid_led(chan_bank, 5, 15)
  else
    for _,col in pairs(running_cols) do
      draw_col(col)
    end
  end

  grid_refresh()
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

local function change_chan_bank(n)
  if not chan_banks[n] then
    print("no channel bank at index "..n)
    return
  end

  chan_bank = n
  chans = chan_banks[n]

  for x,col in pairs(cols) do
    if col.on then
      note_off(col)
      col.ch = chans[x]
      note_on(col)
    else
      col.ch = chans[x]
    end
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

grid = function(x,y,z)
  if config_page then
    if z == 1 then
      if y == 2 then
        change_note_bank(x)
      elseif y == 3 and x <= 12 then
        change_transpose(x - 1)
      elseif y == 4 and x <= 5 then
        change_octave(x - 3)
      elseif y == 5 then
        change_chan_bank(x)
      elseif y == grid_height and x == 1 then -- exit config page
        config_page = false
      end
    end
  else
    if y == grid_height then
      if z == 1 then
        if x == 1 and cols[16].keys.div.z == 1 and not cols[16].keys.len.y then
          config_page = true
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

tick = function()
  for _,col in pairs(running_cols) do
    tick_col(col)
    -- if not config_page then
    --   grid_led_all(0)
    --   draw_col(col)
    --   grid_refresh()
    -- end
  end

  redraw()
end

midi_rx = function(d1,d2,d3,d4)
  if d1==8 and d2==240 then
    ticks = ((ticks + 1) % 12)
    if ticks == 0 and midi_clock_in then tick() end
  else
    -- ps("midi_rx %d %d %d %d",d1,d2,d3,d4)
  end
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

  for n,bank in pairs(chan_banks) do
    for i,chan in ipairs(bank) do
      if not (1 <= chan and chan <= 16) then
        print("init error: channel bank "..n.." chan "..i.." has value "..chan..", allowed range 1-16")
        return
      end
    end
  end

  grid_height = grid_size_y()
  height = grid_height * 2
  config_page = false
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
    col.ch = chan_banks[chan_bank][i]
    col.vel = vel
    col.on = false
    col.keys = {}
    col.keys.div = {}
    col.keys.len = {}

    cols[i] = col
  end

  if not midi_clock_in then
  	-- 150ms per step
  	metro.new(tick, 50)
  end
end

init()
