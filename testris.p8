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

 rotates = true
 size = 3
 wallkicks = 1  -- wallkick table index

]]--
O = {
 rotates = false,
 size = 2,
 -- 11
 -- 11
 blks = { { {0, 0}, {1, 0}, {0, 1}, {1, 1}} },
}
L = {
 -- 010
 -- 010
 -- 011
 blks = { {{1, 0}, {1, 1}, {1, 2}, {2, 2}} },
}
J = {
 -- 010
 -- 010
 -- 110
 blks = { {{1, 0}, {1, 1}, {0, 2}, {1, 2}} },
}
Z = {
 -- 000
 -- 110
 -- 011
 blks = { {{0, 1}, {1, 1}, {1, 2}, {2, 2}} },
}
S = {
 -- 000
 -- 011
 -- 110
 blks = { {{1, 1}, {2, 1}, {0, 2}, {1, 2}} },
}
T = {
 -- 000
 -- 111
 -- 010
 blks = { {{0, 1}, {1, 1}, {2, 1}, {1, 2}} },
}
I = {
 kicks_index = 2,
 size = 4,
 -- 0100
 -- 0100
 -- 0100
 -- 0100
 blks = { {{1, 0}, {1, 1}, {1, 2}, {1, 3}} },
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
timers = nil

players = nil

particles = {}

frame_counter = 0

-- vertical offset for ghost dotted lines
dot_offset = 0

-- number of active human players
-- (1 for human vs cpu, 2 for human vs human)
human_players = 1

particles = {}
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
 self.blks = array2d(ROWS, COLS)

 -- todo: remove the following test data
 self.blks[8][1] = 1
 self.blks[8][8] = 2
 self.blks[9][1] = 1
 self.blks[9][2] = 1
 self.blks[9][8] = 2
 self.blks[10][1] = 3
 self.blks[10][2] = 3
 self.blks[10][3] = 3
 self.blks[10][4] = 3
 self.blks[10][6] = 3
 self.blks[10][7] = 3
 self.blks[10][8] = 3
 self.blks[11][3] = 3
 self.blks[11][4] = 3
 self.blks[11][5] = 3
 self.blks[11][6] = 3
 self.blks[11][7] = 3
 self.blks[11][8] = 3
 self.blks[12][1] = 3
 self.blks[12][2] = 3
 self.blks[12][3] = 3
 self.blks[12][4] = 3
 self.blks[12][5] = 3
 self.blks[12][6] = 3
 self.blks[12][7] = 3
 self.blks[13][3] = 3
 self.blks[13][5] = 3
 self.blks[13][6] = 3

 -- lines that need to be 'flash'-ed while drawing this Board
 self.flash_rows = {}
 self.combo = 0
 self.tops = self:calc_tops()

 return self
end

--[[
 Finds the first available position
 on the board's top row that fits the given
 piece without applying rotations.

 param
 -----
 piece : Piece = piece to fit at the top of the board
]]--
function Board:find_slot(piece)
 local p = piece

 -- anc_y = (initial_board_y = 1) - piece.min_y
 local anc_y = 1 - p.min_y
 local w = p.width
 local center = flr((COLS - w) / 2) + 1

 local min_d, anc_x = oo
 for col = 1, COLS - w do
  local d = abs(center - col)
  local ax = col - p.min_x
  if d < min_d and
   not collides(self, p.index, p.rot, ax, anc_y)
  then
   min_d, anc_x = d, ax
  end
 end

 if min_d == oo then
  return oo, oo
 else
  return anc_x, anc_y
 end
end

function Board:lock(piece)
 foreach(piece.blks, function (b)
  local x = piece.anc_x + b[1]
  local y = piece.anc_y + b[2]
  self.blks[y][x] = piece.colour
  self.tops[x] = min(self.tops[x], y)
 end)
end

function Board:calc_tops(from)
 from = from and from or 1
 local tops = {}
 for x = 1, COLS do
  local top = ROWS + 1
  for y = from, ROWS do
   if self.blks[y][x] != 0 then
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
 local call_check_lines = false

 -- board frame
 rect(x0, 0,
      x0 + COLS * BLK - 1,
      ROWS * BLK, 5)
 local first_static_row = 1

 if self.ranges_to_clear then
  -- first_static_row is the row index from which we just
  -- to use the static board drawing routine
  first_static_row = self.ranges_to_clear[1].bottom_line + 1

  foreach(self.ranges_to_clear, function (range)
   foreach(range.sticky_groups, function (group)
    draw_blks(group.blks, x0 + group.x, flr(group.y))
    if (group.landed) return
    group.y = min(group.y + group.vy, group.yf)
    group.vy += 0.98
    -- if the group is about to land, that is, is in the last
    -- frame before locking on to the board
    if group.y == group.yf then
     foreach(group.blks, function (blk)
      local row, col = group.anc_y + blk[2], group.anc_x + blk[1]
      self.blks[row][col] = 0
      self.blks[row + group.drop_dist][col] = blk[3]
     end)
     group.landed = true
     self.landed_groups += 1
    end
   end)
  end)

  if self.landed_groups == self.total_groups then
   self.ranges_to_clear = nil
   self.combo += 1
   call_check_lines = true
  end
 end

 local y = (first_static_row - 1) * BLK
 for r = first_static_row, ROWS do
  local x = x0
  for c = 1, COLS do
   local f = self.flash_rows
   local b = (f[r] and f[r] > 1) and FLASH_BLK or self.blks[r][c]
   if (b != 0) draw_blk(x, y, b, BLK)
   x += BLK
  end
  y += BLK
 end

 if call_check_lines then
  -- delay adjusting the tops for once all groups had landed
  self:calc_tops()
  self:check_clear_lines()
 end
end

--[[
 computes a collection of line objects to clear from bottom-top,
 each line object is a range of contiguous cleared lines, of the form:
 {
   1 = line_start (y coord of first line to delete),
   2 = line_end (y coord of last line to delete, line_end <= line_start),
   3 = {
    -- connected set of blocks
    1 = {
      anc_x = x,
      anc_y = range_start,
      -- connected blocks
      blks = {
        {Δx_o, Δy_o, c_o},
        ...
        {Δx_k, Δy_k, c_k}
      }
      mins = { min_x, min_y },
      maxs = { max_x, max_y }
    },
    2 = ...
 }

 Δx_i = connected_block_x - x
 Δy_i = connected_block_y - range_start
 c_i = block colour (sprite index)
]]--
function Board:check_clear_lines()
 -- get the lines ranges and their sticky connections
 local B = self.blks
 local ranges = {}
 -- rows that will need a 'flash' animation
 local flash_rows = self.flash_rows

 local range_bottom, range_top, cur_line = 0, 0, 0
 for row = ROWS, 1, -1 do
  local is_line = true
  for col = 1, COLS do
   if B[row][col] == 0 then
    is_line = false
    break
   end
  end

  flash_rows[row] = 0
  if is_line then
   -- 0 means 'this row doesn't need flash'
   -- 2 means 'FLASH this row in this frame'
   --
   -- 1 is interpreted as 'this row needs flashing, but not on this frame',
   -- not used here but later once the animation is updated
   flash_rows[row] = 2

   if range_bottom == 0 then
    -- mark the start of a (potential) line range
    range_bottom, range_top = row, row
   elseif range_top == row - 1 then
    -- grow the line range by one line
    range_top = row
   else
    -- close and add the range of lines
    add(ranges, {
     range_top,
     range_bottom,
     sticky_groups(row, range_top, B)
    })
    range_bottom, range_top = row, row
   end
  end
 end
 if range_top > 0 then
  add(ranges, {
   top_line = range_top,
   bottom_line = range_bottom,
   sticky_groups = sticky_groups(1, range_top, B)
  })
 end

 if #ranges > 0 then
  -- flash the lines that have to be cleared first, then add
  -- explosion particles and trigger the sticky falling animation
  timers:add(1, function (tmr)
   -- the following changes 2 to 1, 1 to 2 and leaves 0 intact
   for i, v in pairs(flash_rows) do
    flash_rows[i] = v * 2 ^ (3 - 2 * v)
   end

   -- after 10 flash steps
   if tmr.step == 10 then
    local num_sticky_groups = 0
    foreach(ranges, function (range)
     for y = range.top_line, range.bottom_line do
      for x = 1, COLS do
       local c = self.combo
       -- clear the block
       self.blks[y][x] = 0

       -- add explosion particles to each removed block
       local xx, yy = self.x + x * BLK + HLF_BLK, y * BLK - HLF_BLK
       add_particles(
        -- count
        10 + c * 10,
        xx, yy,
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
     local line_tops = self:calc_tops(range.top_line)
     foreach(range.sticky_groups, function (g)
      g.drop_dist = self:drop_dist(g.blks, g.anc_x, g.anc_y, line_tops)
      -- yf is the final y after landing this set of blocks
      g.yf = g.y + g.drop_dist * BLK

      num_sticky_groups += 1
     end) -- groups
    end) -- ranges

    self.ranges_to_clear = ranges
    self.landed_groups = 0
    self.total_groups = num_sticky_groups
   end
  end, 10)

 end
end

function Board:drop_dist(blks, anc_x, anc_y, tops)
 tops = tops and tops or self.tops
 local dist = oo
 foreach(blks, function (blk)
  local x, y = anc_x + blk[1], anc_y + blk[2]
  dist = min(dist, tops[x] - y - 1)
 end)
 return dist
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
function Piece.new(attributes)
 local self = setmetatable({}, Piece)

 local index = attributes[1]
 local colour = attributes[2]
 local rot = attributes[3]

 self.index = index
 self.colour = colour
 self.rot = rot

 local piece = PIECES[index]

 -- shorter/easier to keep a ref to the blocks instead
 -- of always doing PIECES[p.index].blks[p.rot]
 self.blks = piece.blks[rot]

 self.size = piece.size
 self.min_x = piece.mins[rot][1]
 self.min_y = piece.mins[rot][2]
 self.max_x = piece.maxs[rot][1]
 self.max_y = piece.maxs[rot][2]
 self.width = self.max_x - self.min_x + 1

 -- position of the piece's top-left corner
 self.anc_x = oo
 self.anc_y = oo

 return self
end

function Piece:draw(screen_x)
 -- screen_y is assumed to be 0 whereas screen_x could be 0 or 64
 -- 64 when drawing on the right side board of the screen
 draw_blks(self.blks, 
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
 local b = self.bag

 self.n = n

 for i = 1, n do
  b[i] = {
   i, -- tetrominoe index
   rng:rand(1, NUM_COLOURS), -- colour
   rng:rand(1, #PIECES[i].blks)  -- rotation
  }
 end

 -- Fisher-Yates shuffle algorithm (modern version)
 for i = n, 2, -1 do
  local j = rng:rand(1, i)
  local tmp = b[i]
  b[i] = b[j]
  b[j] = tmp
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
  function (tmr)
   self:on_gravity()
  end)

 return self
end

function Player:draw()
 self.board:draw()

 if not self.game_over then
  if self.piece then p:draw(self.board.x) end
 end
end

function Player:on_gravity()
 local b = self.board
 local p = self.piece
 if p then
  if collides(b, p.index, p.rot, p.anc_x, p.anc_y + 1) then
   self.board:lock(p)
   -- todo: check for game over
   -- todo: spawn the next piece (if not game over)
   self.piece = nil
   self.board:check_clear_lines()
  else
   p.anc_y += 1
  end
  -- Check if player is CPU
  if self.type == CPU then
   self:ai_play()
  end
 end
end

function Player:spawn_piece()
 -- todo restore this line
 --local p = Piece.new(self.bag:next())
 local p = Piece.new({5, 5, (self.index == 0) and 2 or 1})
 local anc_x, anc_y = self.board:find_slot(p)
 if anc_x != oo then
  p.anc_x, p.anc_y = anc_x, anc_y
  self.piece = p
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
 local p = self.piece
 local P = PIECES[p.index]
 if (not P.rotates) return

 local new_rot = p.rot + dir
 if (new_rot < 1) new_rot = 4
 if (new_rot > 4) new_rot = 1

 local kicks = P.kicks[dir > 0 and (2 * p.rot) or (9 - 2 * p.rot)]
 for kick in all(kicks) do
  local xx = p.anc_x + kick[1]
  local yy = p.anc_y + kick[2]
  if not collides(self.board, p.index, new_rot, xx, yy) then
   p.rot = new_rot
   p.blks = PIECES[p.index].blks[new_rot]
   p.anc_x, p.anc_y = xx, yy
   return
  end
 end
end

function Player:move(btn)
 local p = self.piece
 if p then
  local b = self.board
  if btn == LEFT or btn == RIGHT then
   -- LEFT is -1, RIGHT is +1
   local anc_x = p.anc_x + btn
   if not collides(b, p.index, p.rot, anc_x, p.anc_y) then
    p.anc_x = anc_x
   end
  elseif btn == ROT_R or btn == ROT_L then
   self:rotate(btn == ROT_R and 1 or -1)
  elseif btn == DOWN then
   p.anc_y += b:drop_dist(p.blks, p.anc_x, p.anc_y)
   self:on_gravity()
  end
 end
end

function Player:ai_play()
 local piece = self.piece
 if piece then
  local board = self.board
  local min_anc_x, min_anc_y = -piece.min_x + 1, 1
  local max_anc_x, max_anc_y = COLS - piece.max_x + 1, 1
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
  for x = min_anc_x, max_anc_x do
   printh('x'..x)
   piece.anc_x = x
   -- piece:draw()
  end
 end
end

----------------------------------------
-- Functions
----------------------------------------
function collides(board, piece_index, rotation, new_anc_x, new_anc_y)
 local B = board.blks
 local b = PIECES[piece_index].blks[rotation]
 for i = 1, #b do
  local xx = new_anc_x + b[i][1]
  local yy = new_anc_y + b[i][2]
  if xx < 1 or COLS < xx or
     yy < 1 or ROWS < yy or
     B[yy][xx] != 0
  then
   return true
  end
 end
 return false
end

function rand(a, b)
 return a == b and a or (rnd() * (b - a) + a)
end

--[[
 returns a group of connected (stuck together or 'sticky') blocks
 between 'top' and 'bottom':

3 |=========| <- top, index of the current cleared line
4 |         |
5 |oo   bb c|  there 4 groups of connected (sticky) blocks above
6 | o aa bb |  'bottom': o, a, b and c
7 |=========| <- bottom, index of the previous cleared top line

 another example:

1 |         | <- top, is 1 in this case because there is
2 |o        |    no current line being cleared
3 |oo    ii |  there 2 groups of sticky blocks: o and i
4 |oooo   i |
5 |=========| <- bottom

 this function returns a list of tables, representing 
 the sticky groups like this:
 {
   anc_x = board column for the bottom-left corner of this group,
   anc_y = board row for the bottom-left corner of this group,
   x = screen x from (0, 0) to start drawing the group,
   y = screen y from (0, 0) to start drawing the group,
   vy = initial falling speed (will be affected by gravity),
   landed = flag indicating this group hasn't landed yet
   -- blocks of each group
   blks = {
     {Δx_o, Δy_o, c_o},
     ...
     {Δx_k, Δy_k, c_k}
   }
   mins = { min_x, min_y },
   maxs = { max_x, max_y }
 }

 where:
 Δx_i = # of blocks from x: xf = Δx_i * block_size + x
 Δy_i = # of blocks from y: yf = Δy_i * block_size + y
 c_i = block colour (sprite index)
]]--
function sticky_groups(top, bottom, B)
 local groups = {}

 if bottom - top - 1 > 0 then
  local visited = array2d(ROWS, COLS)

  local ox = {-1, 0, 1, 0}
  local oy = { 0,-1, 0, 1}

  -- dfs flood-fill to get the sticky connected blocks
  for x = 1, COLS do
   local y = bottom - 1
   if y > 0 and B[y][x] != 0 and visited[y][x] == 0 then
    -- for this (x, y) find all connected (stuck together) blocks
    local sticky_blks = {}
    local min_x, min_y = oo, oo
    local max_x, max_y = 0, 0
    local stack = {{x, y}}
    while #stack > 0 do
     local pop = stack[#stack]
     stack[#stack] = nil
     local xx, yy = pop[1], pop[2]
     if B[yy][xx] != 0 then
      local off_x = xx - x
      local off_y = yy - bottom
      min_x, min_y = min(min_x, off_x), min(min_y, off_y)
      max_x, max_y = max(max_x, off_x), max(max_y, off_y)
      add(sticky_blks, {off_x, off_y, B[yy][xx]})
     end
     visited[yy][xx] = 1
     for k = 1, 4 do
      local nx = xx + ox[k]
      local ny = yy + oy[k]
      if 1 <= nx and nx <= COLS and
       top < ny and ny < bottom and
       visited[ny][nx] == 0 and B[ny][nx] != 0
      then
       add(stack, {nx, ny})
      end
     end
    end
    if #sticky_blks > 0 then
     add(groups, {
      blks = sticky_blks,
      -- (anc_x, anc_y) top-left corner board coordinates for this group
      anc_x = x,
      anc_y = bottom,
      -- (x, y) drawing position origin
      x = (x - 1) * BLK,
      y = (bottom - 1) * BLK,
      vy = 0.8,
      landed = false,
      -- mins and maxs are in terms of cols and rows
      mins = {min_x, min_y},
      maxs = {max_x, max_y}
     })
    end
   end
  end
 end

 return groups
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

 params
 ------
 x : int = screen x coordinate of left/top corder of the block
 y : int = screen y coordinate of left/top corder of the block
 colour : int[1..NUM_COLOURS] = colour of the block
 blk_size : int = block's width/height
 is_ghost : bool = draws the block's outline, only available
                   for blks of size BLK, ignored otherwise
]]--
function draw_blk(x, y, colour, blk_size, is_ghost)
 local bs = blk_size
 if bs == BLK then
  if is_ghost then
  -- ghost block is light gray, swap
  -- light gray with the piece colour
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

function draw_blks(blks, xo, yo, colour, is_ghost, blk_size)
 local is_ghost = is_ghost and is_ghost or false
 local SIZE = blk_size and blk_size or BLK

 foreach(blks, function (b)
  draw_blk(xo + b[1] * SIZE, yo + b[2] * SIZE,
           -- if colour is not given we will assume blks[3] has a colour index
           colour and colour or b[3],
           SIZE,
           is_ghost)
 end)
end

function contains(l, v)
 for e in all(l) do
  if v == e then return true end
 end
 return false
end

function array2d(num_rows, num_cols)
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
  add(particles, {
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
   local blks = piece.blks[1]
   for _ = 1, 3 do
    local rot = {}
    foreach(blks, function (blk)
     -- rotation:
     -- 90° rotation = (x, y) -> (-y, x)
     -- x = -y -> SIZE - 1 - y (reflection)
     -- y = x
     add(rot, {piece.size - 1 - blk[2], blk[1]})
    end)
    add(piece.blks, rot)
    blks = rot
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
  for i = 1, #piece.blks do
   local min_x, min_y = oo, oo
   local max_x, max_y = 0, 0
   foreach(piece.blks, function (blk)
    local x, y = blk[1], blk[2]
    min_x, min_y = min(x, min_x), min(y, min_y)
    max_x, max_y = max(x, max_x), max(y, max_y)
   end)
   add(piece.mins, {min_x, min_y})
   add(piece.maxs, {max_x, max_y})
  end
 end)
 -----------------------------------
--printh(to_json(PIECES))
 timers = Scheduler.new()

 -----------------------------------
 -- players configuration
 -----------------------------------
 local seed = abs(flr(rnd() * 1000))

 players = {
  Player.new(0, HUMAN, 5, timers, seed),
  Player.new(1, CPU, 5, timers, seed)
 }
 human_players = 1

 -- register timers
 -- timers:add('dot-line',
 --  0.05, -- segs
 --  function(tmr)
 --   dot_offset = (dot_offset + 1) % (2 * DOT_LINE_GAP)
 --  end
 -- )
end

function _update()
 for p = 1, human_players do
  local player = players[p]
  for m = 1, #MOVES do
   -- btn() uses 0-index for both button and player
   if btn(m - 1, p - 1) then
    player:move(MOVES[m])
   end
  end
 end

 foreach(particles, function (p)
  if p[1] <= 0 then
   del(particles, p)
   return
  end
  p[1] -= 1    -- duration -= 1
  p[2] += p[4] -- x += vx
  p[3] += p[5] -- y += vy
  p[4] += p[6] -- vx += acc_x
  p[5] += p[7] -- vy += acc_y
  p[8] += p[9] -- size += Δsize
 end)

 timers:update()
end

function _draw()
 cls()

 foreach(players, Player.draw)

 foreach(particles, function (p)
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

 frame_counter = (frame_counter + 1) % 65535
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
