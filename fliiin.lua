-- flin
--
-- cyclic poly-rhythm music box
--
-- originally by tehn
-- adapted for iii by evnoj

grid_height = grid_size_y()
height = grid_height * 2
local notes = { 2, 4, 5, 7, 9, 11, 12, 14, 16, 17, 19, 21, 23, 24, 26, 28 }
local chans = { 2, 4, 5, 7, 9, 11, 12, 14, 16, 17, 19, 21, 23, 24, 26, 28 }

local function tick_col(col)
  col.div_tick = (col.div_tick + 1) % col.div

  if col.div_tick == 0 then
    col.pos = (col.pos + 1) % height
  end

  if col.pos - col.len <= 0 then
    if not col.on then
      -- send midi note on
      col.on = true
    end
  else
    if col.on then
      -- send midi note off
      col.on = false
    end
  end
end

local function draw_col(col)
  local x = col.x
  local y = col.pos

  for i=0,col.len-1 do
    grid_led(x, y - i, 15)
  end
end

local function stop_col(col)
  if col.on then
    -- send midi note off
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

local function redraw()
  grid_led_all(0)

  for _,col in pairs(running_cols) do
    draw_col(col)
  end

  grid_refresh()
end

grid = function(x,y,z)
  if y == grid_height then
    if z == 1 then
      if cols[x].keys.div.y then
        cols[x].keys.div.y = nil
        cols[x].keys.len.y = nil
      elseif running_cols[x] then
        stop_col(running_cols[x])
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

  redraw()
end

tick = function()
  grid_led_all(0)

  for _,col in pairs(running_cols) do
    tick_col(col)
    draw_col(col)
  end

  grid_refresh()
end

midi_rx = function(d1,d2,d3,d4)
	if d1==8 and d2==240 then
		ticks = ((ticks + 1) % 12)
		if ticks == 0 and midi_clock_in then tick() end
	else
		-- ps("midi_rx %d %d %d %d",d1,d2,d3,d4)
	end
end

-- init
cols = {}
running_cols = {}
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
  col.note = notes[i]
  col.ch = chans[i]
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
