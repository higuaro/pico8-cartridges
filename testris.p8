pico-8 cartridge // http://www.pico-8.com
version 18
__lua__
----------------------------------------
-- Constants
----------------------------------------
SCR_W = 128
SCR_H = 128
HLF_W = 64
HLF_H = 64

BTN_LEFT = 0
BTN_RIGHT = 1
BTN_UP = 2
BTN_DOWN = 3

CPU = 'c'
HUMAN = 'h'
-- actions buttons B A
BTN_B = 4
BTN_A = 5

-- math constants
-- infinity
oo = 32767

-- game constants
ROWS = 13
COLS = 8
BLK = 8
HLF_BLK = 4

COLOURS = { 12, 10, 8, 15, 11, 14, 7 }
NUM_COLOURS = #COLOURS

-- sprite index for the ghost block
GHOST_BLK = 8

-- sprite index for the flashed block
FLASH_BLK = 9

NO_FLASH_ROW = 0
FLASH_ROW_IN_NEXT_FRAME = 1
FLASH_ROW_IN_THIS_FRAME = 2

-- wallkicks
--[[
 what are wallkicks?
 https://harddrop.com/wiki/SRS#Wall_Kicks

 contrary to the Super Rotation System - SRS
 the first 4 kicks are going to be
 for basic ←↑→↓ shifts
]]--
BASIC_WALLKICKS = {
 -- basic ←↑→↓ wallkicks for all pieces, except I
 { {0,0}, {0,-1}, {-1,0}, {0,1}, {1,0} },
 -- basic ←↑→↓ wallkicks for I
 { {0,0}, {0,-1}, {-1,0}, {0,1}, {1,0}, {0,-2}, {-2,0}, {0,2}, {2,0} }
}
SRS_WALLKICKS = {
 {
-- SRS wallkicks for all pieces, except I
--{{ 0,+1}, {-1,+1}, {+2, 0}, {+2,+1} }, -- R -> 0 -- dyn generated on _init
  {{ 0,-1}, { 1,-1}, {-2, 0}, {-2,-1} }, -- 0 -> R
--{{ 0,-1}, {+1,-1}, {-2, 0}, {-2,-1} }, -- 2 -> R -- "
  {{ 0, 1}, {-1, 1}, { 2, 0}, { 2, 1} }, -- R -> 2
--{{ 0,-1}, {-1,-1}, {+2, 0}, {+2,-1} }, -- L -> 2 -- "
  {{ 0, 1}, { 1, 1}, {-2, 0}, {-2, 1} }, -- 2 -> L
--{{+1, 0}, {+1,+1}, { 0,-2}, {-2,+1} }, -- 0 -> L -- "
  {{-1, 0}, {-1,-1}, { 0, 2}, { 2,-1} }  -- L -> 0
 },
-- SRS wallkicks for I
 {
--{ {0,+2}, {0,-1}, {+1,+2}, {-2,-1} }, -- R -> 0 -- dyn generated on _init
  { {0,-2}, {0, 1}, {-1,-2}, { 2, 1} }, -- 0 -> R
--{ {0,+1}, {0,-2}, {-2,+1}, {+1,-2} }, -- 2 -> R -- "
  { {0,-1}, {0, 2}, { 2,-1}, {-1, 2} }, -- R -> 2
--{ {0,-2}, {0,+1}, {-1,-2}, {+2,+1} }, -- L -> 2 -- "
  { {0, 2}, {0,-1}, { 1, 2}, {-2,-1} }, -- 2 -> L
--{ {0,-1}, {0,+2}, {+2,-1}, {-1,+2} }  -- 0 -> L -- "
  { {0, 1}, {0,-2}, {-2, 1}, { 1,-2} }  -- L -> 0
 }
}

--[[
 tetraminoes:

 if not explicitly defined here then the
 following default values will be assumed:

 rotates = true (the O is the only piece that doesn't rotate)
 size = 3
 wallkicks = 1  -- wallkick table index

]]--
O = {
 rotates = false,
 size = 2,
 -- 11
 -- 11
 blocks = { { {0, 0}, {1, 0}, {0, 1}, {1, 1}} },
}
L = {
 -- 010
 -- 010
 -- 011
 blocks = { {{1, 0}, {1, 1}, {1, 2}, {2, 2}} },
}
J = {
 -- 010
 -- 010
 -- 110
 blocks = { {{1, 0}, {1, 1}, {0, 2}, {1, 2}} },
}
Z = {
 -- 000
 -- 110
 -- 011
 blocks = { {{0, 1}, {1, 1}, {1, 2}, {2, 2}} },
}
S = {
 -- 000
 -- 011
 -- 110
 blocks = { {{1, 1}, {2, 1}, {0, 2}, {1, 2}} },
}
T = {
 -- 000
 -- 111
 -- 010
 blocks = { {{0, 1}, {1, 1}, {2, 1}, {1, 2}} },
}
I = {
 kicks_index = 2,
 size = 4,
 -- 0100
 -- 0100
 -- 0100
 -- 0100
 blocks = { {{1, 0}, {1, 1}, {1, 2}, {1, 3}} },
}

PIECES = { O, L, J, Z, S, T, I }

DOT_LINE_GAP = 3

-- movements
LEFT = -1
RIGHT = 1
DOWN = 2
UP = 0
ROT_L = 3
ROT_R = 4
MOVES = { LEFT, RIGHT, UP, DOWN, ROT_L, ROT_R }

----------------------------------------
-- Globals
----------------------------------------
g_timers = nil

g_players = nil

g_particles = {}

g_frame_counter = 0

-- vertical offset for ghost dotted lines
dot_offset = 0

-- number of active human players
-- (1 for human vs cpu, 2 for human vs human)
g_total_human_players = 1

----------------------------------------
-- Classes
----------------------------------------

----------------------------------------
-- class Scheduler
----------------------------------------
Scheduler = {}
Scheduler.__index = Scheduler

-- constructor
function Scheduler.new()
 local self = setmetatable({}, Scheduler)
 self.last_time = time()
 self.timers = {}
 return self
end

--[[
 Adds a timer

 params:
 -------
 time : int = number of frames before each animation step
 on_step : f(timer) -- function to run on each tick
 [steps : int] = max number of ticks for the timer,
                 omit it to run indefinitely
 [ctx : {}] = additional data to pass to the timer
]]--
function Scheduler:add(time, on_step, steps, ctx)
 add(self.timers, {
  frames = 0,
  time = time,
  ellapsed = 0,
  step = 0,
  steps = steps,
  ctx = ctx and ctx or {},
  step_fn = on_step
 })
 return #self.timers
end

function Scheduler:remove(index)
 del(self.timers, self.timers[index])
end

function Scheduler:set_timeout(index, timeout)
 self.timers[index].time = timeout
end

function Scheduler:reset(index)
 self.timers[index].step = 0
 self.timers[index].ellapsed = 0
end

function Scheduler:update()
 foreach(self.timers, function (timer)
  timer.frames += 1
  if timer.frames >= timer.time then
   timer.step += 1
   timer:step_fn()
   timer.frames -= timer.time
   if timer.steps and timer.step >= timer.steps then
    del(self.timers, timer)
   end
  end
 end)
end

----------------------------------------
-- class RNG (Random Number Gen)
----------------------------------------
RNG = {}
RNG.__index = RNG

-- constructor
function RNG.new(seed)
 local self = setmetatable({}, RNG)
 self.state = seed
 return self
end

--[[
 Produces a random value within [a, b]
 (both inclusive), using the LCG algorithm:
   r_n = (A * r_n-1) mod C
 Values for A and C come from paper:
 "Tables of Linear Congruential Generators of
  Different Sizes and good Lattice Structure"
 (A, C) = (219, 30805)

 params
 ------
 a : int = min value of the range
 b : int = max value of the range
]]--

function RNG:rand(a, b)
 if a == b then return a end
 local s = self.state
 s = (219 * s) % 30805
 self.state = s
 return (s % (b - a + 1)) + a
end

----------------------------------------
-- class Board
----------------------------------------
Board = {}
Board.__index = Board

--[[
 Constructor
]]

function Board.new(player_index)
 local self = setmetatable({}, Board)
 self.index = player_index
 self.x = player_index * HLF_W
 self.blocks = g_array2d(ROWS, COLS)

 -- test board
 self.blocks[8][1] = 1
 self.blocks[8][8] = 2
 self.blocks[9][1] = 1
 self.blocks[9][2] = 1
 self.blocks[9][8] = 2
 self.blocks[10][1] = 3
 self.blocks[10][2] = 3
 self.blocks[10][3] = 3
 self.blocks[10][4] = 3
 self.blocks[10][6] = 3
 self.blocks[10][7] = 3
 self.blocks[10][8] = 3
 self.blocks[11][3] = 3
 self.blocks[11][4] = 3
 self.blocks[11][5] = 3
 self.blocks[11][6] = 3
 self.blocks[11][7] = 3
 self.blocks[11][8] = 3
 self.blocks[12][1] = 3
 self.blocks[12][2] = 3
 self.blocks[12][3] = 3
 self.blocks[12][4] = 3
 self.blocks[12][5] = 3
 self.blocks[12][6] = 3
 self.blocks[12][7] = 3
 self.blocks[13][3] = 3
 self.blocks[13][5] = 3
 self.blocks[13][6] = 3

 -- lines that need to be 'flash'-ed while drawing this Board
 self.flash_rows = {}
 self.combo = 0
 self.tops = self:calc_tops()

 return self
end

function Board:collides(piece)
 local board_blocks = self.blocks
 local piece_blocks = PIECES[piece.index].blocks[piece.rot]
 for i = 1, #piece_blocks do
  local xx = piece.anc_x + piece_blocks[i][1]
  local yy = piece.anc_y + piece_blocks[i][2]
  if xx < 1 or COLS < xx or
     yy < 1 or ROWS < yy or
     board_blocks[yy][xx] != 0
  then
   return true
  end
 end
 return false
end

--[[
 Finds the first available position on the board's top row that fits
 the given piece without applying any wall kicks, while being is
 closest to the center as possible.

 @param piece : Piece = piece to fit at the top of the board
]]--
function Board:find_slot(piece)
 -- below: (initial_board_y = 1) - piece.min_y
 local anc_y = 1 - piece.min_y
 local w = piece.width
 local center = flr((COLS - w) / 2) + 1

 local min_dist, anc_x = oo
 for col = 1, COLS - w do
  local center_dist = abs(center - col)
  local moved_piece = piece:clone()
  moved_piece.anc_x = col - piece.min_x
  moved_piece.anc_y = anc_y
  if center_dist < min_dist and not self:collides(moved_piece) then
   min_dist, anc_x = center_dist, moved_piece.anc_x
  end
 end

 if min_dist == oo then
  return oo, oo
 else
  return anc_x, anc_y
 end
end

function Board:lock_piece(piece)
 foreach(piece.blocks, function (block)
  local x = piece.anc_x + block[1]
  local y = piece.anc_y + block[2]
  self.blocks[y][x] = piece.colour
  self.tops[x] = min(self.tops[x], y)
 end)
end

function Board:calc_tops(from)
 from = from and from or 1
 local tops = {}
 for x = 1, COLS do
  local top = ROWS + 1
  for y = from, ROWS do
   if self.blocks[y][x] != 0 then
    top = y
    break
   end
  end
  add(tops, top)
 end
 return tops
end

function Board:draw()
 local x0 = self.x

 -- board frame
 rect(x0, 0, x0 + COLS * BLK - 1, ROWS * BLK, 5)

  -- first_static_row is the row index from which we use 
  -- the static board drawing routine (the one after drawing the ranges)
 local first_static_row = self.ranges_to_clear 
   and self.ranges_to_clear[1].bottom + 1 
   or 1

 foreach(self.ranges_to_clear, function (range)
  foreach(range.sticky_groups, function (group)
   g_draw_blocks(group.blocks, x0 + group.x, flr(group.y))
  end)
 end)

 local y = (first_static_row - 1) * BLK
 for r = first_static_row, ROWS do
  local x = x0
  for c = 1, COLS do
   local f = self.flash_rows
   local b = (f[r] and f[r] > 1) and FLASH_BLK or self.blocks[r][c]
   if (b != 0) g_draw_block(x, y, b, BLK)
   x += BLK
  end
  y += BLK
 end
end

function Board:update_lines_anim() 
 if self.has_cascade_lines then
  -- delay adjusting the tops once all groups had landed
  self:calc_tops()
  local ranges = self:lines_to_clear()
  self:clear_lines(ranges)
 end

 if not self.ranges_to_clear then return end

 foreach(self.ranges_to_clear, function (range)
  foreach(range.sticky_groups_above, function (group)
   if (group.landed) return 
   group.y = min(group.y + group.vy, group.yf)
   group.vy += 0.98
   -- if the group landed, that is, is in the target row then
   -- lock all the blocks of the group in the board
   if group.y == group.yf then
    foreach(group.blocks, function (blocks)
     local row, col = group.anc_y + blocks[2], group.anc_x + blocks[1]
     self.blocks[row][col] = 0
     self.blocks[row + group.drop_dist][col] = blocks[3]
    end)
    group.landed = true
    self.landed_groups += 1
   end
  end)
 end)

 if self.landed_groups == self.total_groups then
printh('all groups landed '..self.total_groups)
  self.ranges_to_clear = nil
  self.combo += 1
  self.has_cascade_lines = false
 end
end

function Board:lines_to_clear()
 local blocks = self.blocks
 local ranges = {}

 local range_bottom, range_top = 0, 0
 for row = ROWS, 1, -1 do
  local is_line = true
  for col = 1, COLS do
   if blocks[row][col] == 0 then
    is_line = false
    break
   end
  end

  -- if is last row, close the range
  local close_range = row == 1

  if is_line then
   if range_top == 0 then
    range_bottom, range_top = row, row
   elseif cur_range_top == row - 1 then
    -- grow the line range by one line
    range_top = row
   else
    close_range = true
   end
  else
   close_range = true
  end

  if close_range and range_top > 0 then
   --[[ close the range and add the sticky groups above it
   4 |          |
   5 |aaaaaaaaaa| <-- another (2 lines) range
   6 |aaaaaaaaaa|         i
   7 |    i     |      o  i  zz   are the sticky groups
   8 | o  i  zz | <-- oo  i  zzz  above the range 
   9 |oo  i  zzz|
  10 |xxxxxxxxxx| <- range top = 10
  11 |xxxxxxxxxx| 
  12 |xxxxxxxxxx| <- range bottom = 12
  13 |x   x     |
     +----------+
   ]]--
   local sticky_groups_above = -->
     StickyGroup.sticky_groups(row, cur_range_top, blocks)
   local range = -->
     LineRange.new(cur_range_top, cur_range_bottom, sticky_groups_above)
   add(ranges, range)
   cur_range_bottom, cur_range_top = 0, 0
  end
 end
printh('ranges'..to_json(ranges))
 return ranges
end

--[[
 Flash the lines that have to be cleared first, then add
 explosion particles and trigger the sticky groups falling animation
]]--
function Board:start_clear_lines_anim(ranges)
 if #ranges == 0 then return end
 
 -- before adding the animation timer, mark the lines that
 -- need flashing
 self.flash_rows = {}
 foreach(ranges, function (range) 
  for i = range.top, range.bottom do
   self.flash_rows[i] = FLASH_ROW_IN_NEXT_FRAME
  end
 end)

 g_timers:add(1, function (timer)
  -- row flashing animation section
  for i, flash_row_value in pairs(self.flash_rows) do
   self.flash_rows[i] = flash_row_value == FLASH_ROW_IN_THIS_FRAME 
       and FLASH_ROW_IN_NEXT_FRAME
       or FLASH_ROW_IN_THIS_FRAME
  end

  -- after 10 steps devoted to flashing the lines
  if timer.step == 10 then
   -- no more flashing
   self.flash_rows = {}

   local num_sticky_groups = 0
   foreach(ranges, function (range)
    for y = range.top, range.bottom do
     for x = 1, COLS do
      local c = self.combo
      -- clear the block
      self.blocks[y][x] = 0

      -- add explosion particles to each removed block
      local xx, yy = self.x + x * BLK + HLF_BLK, y * BLK - HLF_BLK
      add_particles(
       -- count
       10 + c * 10,
       xx, yy,
       -- make the colour of the particles the same as the piece
       {pget(xx, yy)},
       -- min/max vx
       -1.7, 1.7,
       -- min/max vy
       -2, -4,
       -- min/max acc_x
       0, 0,
       -- min/max acc_y
       0.69, 0.88,
       -- min/max duration
       5, 10 + c * 2,
       -- min/max size
       1, max(1, c)
      )
     end
    end

    -- compute where each sticky group, above this range top line, lands
    local line_tops = self:calc_tops(range.top)
    foreach(range.sticky_groups_above, function (g)
     g.drop_dist = self:drop_dist(g.blocks, g.anc_x, g.anc_y, line_tops)
     -- yf is the final y after landing this set of blocks
     g.yf = g.y + g.drop_dist * BLK

     num_sticky_groups += 1
    end) -- groups
   end) -- ranges

printh('here, #ranges = '..#ranges)
   self.ranges_to_clear = ranges
   self.landed_groups = 0
printh('num_sticky_groups = '..num_sticky_groups)
   self.total_groups = num_sticky_groups
  end
 end, 10)
end

function Board:drop_dist_from_piece(piece, tops)
 return self:drop_dist(piece.blocks, piece.anc_x, piece.anc_y, tops)
end

function Board:drop_dist(blocks, anc_x, anc_y, tops)
 tops = tops and tops or self.tops
 local dist = oo
 foreach(blocks, function (block)
  local x, y = anc_x + block[1], anc_y + block[2]
  dist = min(dist, tops[x] - y - 1)
 end)
 return dist
end

----------------------------------------
-- class LineRange
----------------------------------------
LineRange = {}
LineRange.__index = LineRange

--[[
 Constructor
]]
function LineRange.new(range_top, range_bottom, sticky_groups_above)
 local self = setmetatable({}, LineRange)
 self.top = range_top
 self.bottom = range_bottom
 self.sticky_groups_above = sticky_groups_above
 return self
end

----------------------------------------
-- class StickyGroup
----------------------------------------
StickyGroup = {}
StickyGroup.__index = StickyGroup

--[[
 Given a 'top' and a 'bottom' line, returns a group of connected 
 (stuck together or 'sticky') blocks between 'top' and 'bottom':

3 |=========| <- 'top', usually the index of the line to clear 
4 |         |    there 4 groups of connected (sticky) blocks above 'bottom':
5 |oo   bb c|    o, a, b and c
6 | o aa bb |
7 |=========| <- 'bottom', usually the top of a previous line range 
  |xxxxxxxxx|
7 |=========| <- the bottom of a previous line range

1 |         | <- when top is 1, the top edge of the board is used.
2 |o        |
3 |oo    ii |    there 2 groups of sticky blocks: o and i
4 |oooo   i |
5 |=========| <- bottom

  Each block of the StickyGroup is in the form:

]]--
function StickyGroup.sticky_groups(top, bottom, blocks)
 top -= 2
printh('top = '..top..', bottom = '..bottom)
for i=1, ROWS do
 local sss=''
 for j=1, COLS do
  sss = sss..blocks[i][j]
 end
 printh(sss)
end
 local groups = {}

 if bottom - top == 0 then return groups end
 local visited = g_array2d(ROWS, COLS)

 local o = {-1, 0, 1, 0, -1}

 -- dfs flood-fill to get the sticky connected blocks
 for x = 1, COLS do
  local y = bottom - 1
  if y > 0 and blocks[y][x] != 0 and visited[y][x] == 0 then
   -- for this (x, y) find all connected (stuck together) blocks
   local sticky_blocks = {}
   local min_x, min_y = oo, oo
   local max_x, max_y = 0, 0
   local stack = {{x, y}}
local first = true
   while #stack > 0 do
    local pop = stack[#stack]
    stack[#stack] = nil
    local xx, yy = pop[1], pop[2]
if first then
 printh('node xx, yy = '..xx..','..y)
end
    if blocks[yy][xx] != 0 then
     local off_x = xx - x
     local off_y = yy - bottom
     min_x, min_y = min(min_x, off_x), min(min_y, off_y)
     max_x, max_y = max(max_x, off_x), max(max_y, off_y)
     add(sticky_blocks, {off_x, off_y, blocks[yy][xx]})
    end
    visited[yy][xx] = 1
if first then 
 for ii = 1, ROWS do
  local ss = ''
  for jj = 1, COLS do
   if visited[ii][jj] == 1 then
    ss = ss..'x'
   else
    ss = ss..'.'
   end
  end
  printh(ss)
 end
 printh('----')
end
    for k = 1, 4 do
     local nx, ny = xx + o[k], yy + o[k + 1]
if first then
 printh('child nx, ny ='..nx..','..ny)
 if 1 <= nx and nx <= COLS and 1 <= ny and ny <= ROWS then
  printh('blocks[nx,ny]='..blocks[ny][nx])
 else
  printh('out of bounds')
 end
end
     if 1 <= nx and nx <= COLS and top < ny and ny < bottom 
      and visited[ny][nx] == 0 and blocks[ny][nx] != 0 then
if first then
 printh('pushing nx, ny = '..nx..','..ny)
end
      add(stack, {nx, ny})
     else
      printh('rejected')
     end
    end
   end
if first then
 printh('#sticky_blocks = '..#sticky_blocks)
end
first = false
   if #sticky_blocks > 0 then
    local group = -->
      StickyGroup.new(sticky_blocks, x, bottom, min_x, min_y, max_x, max_y)
    add(groups, group)
   end
  end
 end

 return groups
end

--[[
 Constructor
]]
function StickyGroup.new(blocks, anc_x, anc_y, min_x, min_y, max_x, max_y)
 local self = setmetatable({}, StickyGroup)
  --[[ 
   blocks of each group
   {
     {Δx_o, Δy_o, c_o},
     ...
     {Δx_k, Δy_k, c_k}
   }
   where:
   Δx_i = # of blocks from x: xf = Δx_i * block_size + x
   Δy_i = # of blocks from y: yf = Δy_i * block_size + y
   c_i = block colour (sprite index)
  ]]
 self.blocks = blocks
 -- (anc_x, anc_y) top-left corner board coordinates for this group
 self.anc_x = anc_x
 self.anc_y = anc_y
 -- (x, y) screen x, y position from (0, 0) to start drawing the group
 self.x = (anc_x - 1) * BLK
 self.y = (anc_y - 1) * BLK
 -- indicates whether this group hasn't landed yet
 self.landed = false
 -- initial falling speed (will be affected by gravity),
 self.vy = 0.8
 -- mins and maxs are in terms of cols and rows
 self.mins = {min_x, min_y}
 self.maxs = {max_x, max_y}
 return self
end

----------------------------------------
-- class Piece
----------------------------------------
Piece = {}
Piece.__index = Piece

--[[
 Constructor

 params
 ------
 attributes : {} = {
   1 : int[1..7] = index to use in the PIECE array
   2 : int[1..7] = colour
   3 : int[1..4] = the rotated position of the piece
 }
]]--
function Piece.new(index, colour, rot)
 local self = setmetatable({}, Piece)

 self.index = index
 self.colour = colour

 local piece_data = PIECES[index]

 self:rotate(rot)
 self.blocks = piece_data.blocks[rot]

 self.size = piece_data.size
 self.min_x = piece_data.mins[rot][1]
 self.min_y = piece_data.mins[rot][2]
 self.max_x = piece_data.maxs[rot][1]
 self.max_y = piece_data.maxs[rot][2]
 self.width = self.max_x - self.min_x + 1

 -- position of the piece's top-left corner
 self.anc_x = oo
 self.anc_y = oo
 return self
end

function Piece:rotate(new_rot) 
 self.rot = new_rot
 -- the field 'blocks' is a shortcut ref to the blocks
 -- to prevent always doing PIECES[p.index].blocks[p.rot]
 self.blocks = PIECES[self.index].blocks[new_rot]
end

function Piece:clone()
 local clone = Piece.new(self.index, self.colour, self.rot)
 clone.anc_x = self.anc_x
 clone.anc_y = self.anc_y
 return clone
end

function Piece:draw(screen_x)
 -- screen_y is assumed to be 0 whereas screen_x could be 0 or 64
 -- 64 when drawing on the right side board of the screen
 g_draw_blocks(self.blocks, 
           screen_x + (self.anc_x - 1) * BLK,
           (self.anc_y - 1) * BLK,
           self.colour)
end

----------------------------------------
-- class Piece Generator (Bag of pieces)
----------------------------------------
Bag = {}
Bag.__index = Bag

-- constructor
function Bag.new(rng)
 local self = setmetatable({}, Bag)
 self.rng = rng
 self.bag = {}
 self.n = 0
 self:_refill()
 return self
end

function Bag:_refill()
 local n = #PIECES
 local rng = self.rng
 local bag = self.bag

 self.n = n

 for i = 1, n do
  bag[i] = {
   i, -- tetrominoe index
   rng:rand(1, NUM_COLOURS), -- colour
   rng:rand(1, #PIECES[i].blocks)  -- rotation
  }
 end

 -- Fisher-Yates shuffle algorithm (modern version)
 for i = n, 2, -1 do
  local j = rng:rand(1, i)
  local tmp = bag[i]
  bag[i] = bag[j]
  bag[j] = tmp
 end
end

function Bag:next()
 local n = self.n
 if n == 0 then self:_refill() end
 local attributes = self.bag[n]
 self.bag[n] = nil
 self.n -= 1
 return attributes
end

----------------------------------------
-- class Player --
----------------------------------------
Player = {}
Player.__index = Player

--[[
 Constructor

 params
 ------
 index : int = 0-based index of the player
               from left to right
 type : string['h','c'] = player type: 'h' for human, 'c' for cpu
 gravity_speed : int[0..10] = gravity speed: 0 (slow), 10 (fast)
 timers : Scheduler = .
 seed : int[0..100] = seed for random generators
]]--
function Player.new(index, type, gravity_speed, timers, seed)
 local self = setmetatable({}, Player)

 self.index = index
 self.type = type
 self.timers = timers
 self.id = 'p'..index
 self.game_over = false
 self.rng = RNG.new(seed)
 self.board = Board.new(index)
 self.bag = Bag.new(self.rng)

 self:spawn_piece()

 -- self.next = self.bag:next()

 -- timers
 self.timer_ids = {}

 self.gravity = 20 - gravity_speed
 self.timer_ids['gravity'] = timers:add(self.gravity,
  function (timer)
   self:on_gravity()
  end)

 return self
end

function Player:draw()
 self.board:draw()

 if not self.game_over then
  local piece = self.piece
  if piece then piece:draw(self.board.x) end
 end
end

function Player:update()
 self.board:update_lines_anim()
end

function Player:on_gravity()
 if not self.piece then return end
 -- there is a moment between a new piece and a removed 
 -- piece when p might be empty
 local moved_piece = self.piece:clone()
 moved_piece.anc_y += 1

 if self.board:collides(moved_piece) then
  self.board:lock_piece(self.piece)
  -- todo: check for game over
  -- todo: spawn the next piece (if not game over)
  self.piece = nil
  local ranges = self.board:lines_to_clear()
  self.board:start_clear_lines_anim(ranges)
 else
  self.piece = moved_piece
 end
 -- Check if this player is a CPU and make a move
 if self.type == CPU then
  self:ai_play()
 end
end

function Player:spawn_piece()
 -- TODO restore this line
 --local p = Piece.new(self.bag:next())
 local piece = Piece.new(5, 5, (self.index == 0) and 2 or 1)
 local anc_x, anc_y = self.board:find_slot(piece)
 if anc_x != oo then
  piece.anc_x, piece.anc_y = anc_x, anc_y
  self.piece = piece
 else
  self.game_over = true
  self.piece = nil
 end
end

--[[
 piece rotation states and their values:
 name value description
   O    1   initial state, no rotation
   R    2   one clockwise 90 degress rotation applied
   2    3   180 degress rotation
   L    4   three clockwise 90 degress rotations

 clockwise (cw) 90 deg rotation state transitions:

 name: O         R         2         L
value: 0         1         2         3
     _____     _____     _____     _____
  1 |_|▇|_|   |_|_|_|   |▇|▇|_|   |_|_|▇|
  2 |_|▇|_|   |▇|▇|▇|   |_|▇|_|   |▇|▇|▇|
  3 |_|▇|▇|   |▇|_|_|   |_|▇|_|   |_|_|_|
     1 2 3     1 2 3     1 2 3     1 2 3

 name:  O           R           2           L
value:  0           1           2           3
     _______     _______     _______     _______
  1 |_|▇|_|_|   |_|_|_|_|   |_|_|▇|_|   |_|_|_|_|
  2 |_|▇|_|_|   |▇|▇|▇|▇|   |_|_|▇|_|   |_|_|_|_|
  3 |_|▇|_|_|   |_|_|_|_|   |_|_|▇|_|   |▇|▇|▇|▇|
  4 |_|▇|_|_|   |_|_|_|_|   |_|_|▇|_|   |_|_|_|_|
     1 2 3 4     1 2 3 4     1 2 3 4     1 2 3 4

 wallkicks table: https://harddrop.com/wiki/SRS#Wall_Kicks

     value of 'new_rotation'
           v
 0(1) -> R(2) will use kicks from wallkicks table row #2
 R(2) -> 2(3) from row #4
 2(3) -> L(4) from row #6
 L(4) -> 0(1) from row #8
   ^
 value of 'rotation'

 wallkick_index = 2 * rotation

 counter-clockwise (ccw) 90 deg rotation state transitions:

 0(1) -> L(4) will use kicks from wallkicks table row #7
 L(2) -> 2(3) from row #5
 2(3) -> R(2) from row #3
 R(4) -> 0(1) from row #1

 wallkick_index = 7 - 2 * (rotation - 1) = 9 - 2 * rotation

 params
 ------
  dir : int[-1, 1] = 90 degree rotation direction
                     ccw=-1, cw=1
]]--
function Player:rotate(dir)
 local piece = self.piece
 local piece_data = PIECES[piece.index]
 if not piece_data.rotates then return end

 local new_rot = piece.rot + dir
 if (new_rot < 1) new_rot = 4
 if (new_rot > 4) new_rot = 1

 local kicks = -->
   piece_data.kicks[dir > 0 and (2 * piece.rot) or (9 - 2 * piece.rot)]
 for kick in all(kicks) do
  local xx = piece.anc_x + kick[1]
  local yy = piece.anc_y + kick[2]
  local moved_piece = piece:clone()
  moved_piece:rotate(new_rot)
  moved_piece.anc_x, moved_piece_y = xx, yy
  if not self.board:collides(moved_piece) then
   self.piece = moved_piece
   return
  end
 end
end

function Player:move(button)
 local piece = self.piece
 if piece then
  local board = self.board
  if button == LEFT or button == RIGHT then
   local moved_piece = piece.clone()
   -- LEFT is -1, RIGHT is +1
   moved_piece.anc_x = piece.anc_x + btn
   if not board:collides(moved_piece) then
    self.piece = moved_piece
   end
  elseif button == ROT_R or button == ROT_L then
   self:rotate(button == ROT_R and 1 or -1)
  elseif button == DOWN then
   piece.anc_y += board:drop_dist_from_piece(piece --[[, tops = {} ]])
   self:on_gravity()
  end
 end
end

function Player:ai_play()
 local piece = self.piece
 if not piece then return end

 local board = self.board
 -- min anchor x,y that piece 
 --[[
                   anc_x
                     v___
               | | | | O | |
  left wall -> | | | | OO| |
               | | | |  O| |
                      ---  <- piece b-box
                       ^
                       min_x = 2, max_x = 3

  min_anc_x = -min_x + 1 = -1        max_anc_x = w - max_x + 1
        |     ____                     |            ____ 
        +--> | |O | | | | |            +-->  | | | | |O |
             | |OO| | | | |                  | | | | |OO|
             | | O| | | | |                  | | | | | O|
              ----                                  ----
               ^
  left wall, b-box starts behind left-wall
 ]]--
 local min_anc_x, min_anc_y = -piece.min_x + 1, 1
 local max_anc_x, max_anc_y = COLS - piece.max_x + 1, 1

 for x = min_anc_x, max_anc_x do
  -- printh('x '..x)
  for rot = piece.rot, (piece.rot + 4) % 4 do
   --local board_copy = board:copy()
   local moved_piece = piece:clone()
   moved_piece:rotate(rot)
   moved_piece.anc_x, moved_piece.anc_y = x, min_anc_y
   if not board:collides(moved_piece) then
    piece = moved_piece
    -- simulate dropping
   end
  end 
 end
end

----------------------------------------
-- Global Functions
----------------------------------------

function rand(a, b)
 return a == b and a or (rnd() * (b - a) + a)
end

function dot_vert_line(x, yo, yf, colour)
--[[
 -- dot_offset is global and updated by a timer
 local gap = DOT_LINE_GAP
 local solid = true
 local y = yo
 local yy = y + dot_offset - gap
 while y < yf do
  if solid then
   if yy >= y then
    line(x, y, x, yy, colour)
   end
   solid = false
  else
   solid = true
  end
  y = yy + 1
  yy += gap
  if yy > yf then
   yy = yf
  end
 end
]]--
end

--[[
 Draws a (filled or outlined) single tetrominoe's block.

 @param x : int = screen x coordinate of left/top corder of the block
 @param y : int = screen y coordinate of left/top corder of the block
 @param colour : int = colour of the block, between 1 and NUM_COLOURS
 @param blk_size : int = block's width/height
 @param is_ghost : bool = draws the block's outline, only available
                   for blocks of size BLK, ignored otherwise
]]--
function g_draw_block(x, y, colour, blk_size, is_ghost)
 local bs = blk_size
 if bs == BLK then
  if is_ghost then
  -- ghost block is light gray, swap light gray with the piece colour
   pal(6, colour)
   spr(GHOST_BLK - 1, x, y)
   pal()
  else
   spr(colour - 1, x, y)
  end
 else
  rect(x, y, x + bs, y + bs, colour)
 end
end

function g_draw_blocks(blocks, xo, yo, colour, is_ghost, blk_size)
 local is_ghost = is_ghost and is_ghost or false
 local SIZE = blk_size and blk_size or BLK

 foreach(blocks, function (b)
  g_draw_block(xo + b[1] * SIZE, yo + b[2] * SIZE,
              -- if colour is not given we will assume blocks[3] has a colour index
              colour and colour or b[3],
              SIZE,
              is_ghost)
 end)
end

-- TODO: Remove
function g_contains(l, v)
 for e in all(l) do
  if v == e then return true end
 end
 return false
end

function g_array2d(num_rows, num_cols)
 local a = {}
 for r = 1, num_rows do
  a[r] = {}
  for c = 1, num_cols do
   a[r][c] = 0
  end
 end
 return a
end

function add_particles(count, cx, cy, colours,
 min_vx, max_vx, min_vy, max_vy,
 min_acc_x, max_acc_x, min_acc_y, max_acc_y,
 min_duration, max_duration,
 min_size, max_size)
 local parts = {}
 for c = 1, count do
  --[[
   1 = duration
   2, 3 = x, y
   4, 5 = vx, vy
   6, 7 = acc_x, acc_y
   8, 9 = size, delta size
   10 = colour
  ]]--
  local duration = flr(rand(min_duration, max_duration))
  local size = rand(min_size, max_size)
  add(g_particles, {
   duration,
   -- xo, yo
   cx, cy,
   -- vx, vy
   rand(min_vx, max_vx), rand(min_vy, max_vy),
   -- acc_x, acc_y
   rand(min_acc_x, max_acc_x), rand(min_acc_y, max_acc_y),
   -- size, delta_size
   size, (size - min_size) / duration,
   -- colour
   colours[flr(rand(1, #colours))]
  })
 end
end

----------------------------------------
-- DEBUG Functions
----------------------------------------
-- converts anything to string, even nested tables
function to_json(any, indent)
 if (type(any) ~= 'table') return tostr(any)

 local indent = indent and indent or 0
 local tab = ''
 for i = 1, indent do tab = tab..' ' end
 local str = '{\n'
 local first = true
 for k, v in pairs(any) do
  if (not first) str = str..',\n'
  str = str..tab..' "'..to_json(k)..'":'..to_json(v, indent + 1)
  first = false
 end
 return str..'\n'..tab..'}'
end

function stats()
  local cpu = flr(stat(1) * 100)
  local fps = stat(7)
  local perf = cpu.."% cpu @ "..fps.." fps"
  print(perf, 31, 2, 0)
  print(perf, 30, 1, 7)
end

--[[
 pre-builds all the rotations for each piece
]]--
function _init()
 -----------------------------------
 -- pre-generate all rotations, calculate
 -- mins, maxs and wallkicks for
 -- each piece
 -----------------------------------
 foreach(PIECES, function(piece)
  -- compute the piece's size
  -- size = piece.size != nil ? piece.size : 3
  piece.size = piece.size and piece.size or 3

  -- rotations and wallkicks
  --
  -- rotates = piece.rotates != nil ? piece.rotates : true
  piece.kicks = {}
  local rotates = true
  if (piece.rotates != nil) rotates = piece.rotates
  piece.rotates = rotates

  if rotates then
   -- rotations
   local blocks = piece.blocks[1]
   for _ = 1, 3 do
    local rot = {}
    foreach(blocks, function (blk)
     -- rotation:
     -- 90° rotation = (x, y) -> (-y, x)
     -- x = -y -> SIZE - 1 - y (reflection)
     -- y = x
     add(rot, {piece.size - 1 - blk[2], blk[1]})
    end)
    add(piece.blocks, rot)
    blocks = rot
   end

   -- wallkicks
   -- I = piece.kicks_index != nil ? piece.kicks_index : 1
   local I = piece.kicks_index and piece.kicks_index or 1
   local basic_kicks = BASIC_WALLKICKS[I]
   local srs_kicks = SRS_WALLKICKS[I]

   for i = 1, 8 do
    local wallkicks = {}
    -- all kicks start with the basic offsets
    for k in all(basic_kicks) do
     add(wallkicks, k)
    end
    -- even row indexes are for clockwise rotations kicks,
    -- odd row indexes are for counter-clockwise rotation kicks
    for k in all(srs_kicks[flr((i + 1) / 2)]) do
     -- odd row indexes multiply k by -1
     local sign = (-1) ^ (i % 2)
     add(wallkicks, {sign * k[1], sign * k[2]})
    end
    add(piece.kicks, wallkicks)
   end
  end

  -- mins and maxs
  piece.mins, piece.maxs = {}, {}
  for i = 1, #piece.blocks do
   local min_x, min_y = oo, oo
   local max_x, max_y = 0, 0
   foreach(piece.blocks, function (blk)
    local x, y = blk[1], blk[2]
    min_x, min_y = min(x, min_x), min(y, min_y)
    max_x, max_y = max(x, max_x), max(y, max_y)
   end)
   add(piece.mins, {min_x, min_y})
   add(piece.maxs, {max_x, max_y})
  end
 end)
 -----------------------------------
 g_timers = Scheduler.new()

 -----------------------------------
 -- players configuration
 -----------------------------------
 local seed = abs(flr(rnd() * 1000))

 g_players = {
  Player.new(0, HUMAN, 5, g_timers, seed),
  Player.new(1, CPU, 5, g_timers, seed)
 }
 g_total_human_players = 1

 -- register timers
 -- timers:add('dot-line',
 --  0.05, -- segs
 --  function(timer)
 --   dot_offset = (dot_offset + 1) % (2 * DOT_LINE_GAP)
 --  end
 -- )
end

function _update()
 foreach(g_players, function (player)
  player:update()
 end)

 for p = 1, g_total_human_players do
  local player = g_players[p]
  for m = 1, #MOVES do
   -- btn() uses 0-index for both button and player
   if btn(m - 1, p - 1) then
    player:move(MOVES[m])
   end
  end
 end

 foreach(g_particles, function (p)
  if p[1] <= 0 then
   del(g_particles, p)
   return
  end
  p[1] -= 1    -- duration -= 1
  p[2] += p[4] -- x += vx
  p[3] += p[5] -- y += vy
  p[4] += p[6] -- vx += acc_x
  p[5] += p[7] -- vy += acc_y
  p[8] += p[9] -- size += Δsize
 end)

 g_timers:update()
end

function _draw()
 cls()

 foreach(g_players, Player.draw)

 foreach(g_particles, function (p)
  local x, y, colour = p[2], p[3], p[10]
  local size = flr(p[8])
  if size < 2 then
   pset(x, y, colour)
  elseif size <= 3 then
   rectfill(x, y, x + size - 1, y + size - 1, colour)
  else
   circfill(x, y, size - 1, colour)
  end
 end)

 g_frame_counter = (g_frame_counter + 1) % 65535
end
__gfx__
0cccccc00aaaaaa0088888800afafaf00bbbbbb00eeeeee007777770060606000ffffff000000000000000000000000000000000000000000000000000000000
6cccccc19aaaaaa4e88888829fafafa43bbbbbb58eeeeee26777777500000006ffffffff00000000000000000000000000000000000000000000000000000000
6cccccc19aaaaaa4e88888829afafaf43bbbbbb58eeeeee26777777560000000ffffffff00000000000000000000000000000000000000000000000000000000
6cccccc19aaaaaa4e88888829fafafa43bbbbbb58eeeeee26777777500000006ffffffff00000000000000000000000000000000000000000000000000000000
6cccccc19aaaaaa4e88888829afafaf43bbbbbb58eeeeee26777777560000000ffffffff00000000000000000000000000000000000000000000000000000000
6cccccc19aaaaaa4e88888829fafafa43bbbbbb58eeeeee26777777500000006ffffffff00000000000000000000000000000000000000000000000000000000
6766666197999994e7eeeee29799999437333335878888826766666560000000ffffffff00000000000000000000000000000000000000000000000000000000
01111110044444400222222004444440055555500222222005555550006060600ffffff000000000000000000000000000000000000000000000000000000000
