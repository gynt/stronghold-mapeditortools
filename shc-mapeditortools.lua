
-- ///////////////
-- // help text //
-- ///////////////


-- help text is created during start-up and can not be changed without restart (?)
-- TODO: change help text according to new modification system
HELP = [[
This console is used to configure the additional map editor features.

    featureParameter = value        assign a new value to a feature parameter
    return featureParameter         return the current parameter value

As an example:

    MIRROR_MODE = 'horizontal'      sets the mirror to 'horizontal'.
    return MIRROR_MODE              returns the current MIRROR_MODE
    
Parameters are explained like this:

    PARAMETER_NAME -> additional explanation
        possibleValues      additional value explanation
        ...
    
The following features are implemented and currently applied in the order they are mentioned:

    ## Shape Brush ##
    Uses the coordinates of two clicks (the first one does nothing) to create a shape.
    WARNING: Currently only 200 actions are supported. Big shapes, especially when mirrored, reach
             this limit very fast. So do not be surprised if only one half of a shape appears.
             
    BRUSH_SHAPE -> deactivate/activate
        boolean             false or true
             
    BRUSH_SHAPE_SHAPE -> the shape to apply
        "line"              a simple line between two points
        "rect"              rectangle seen from the front; clicks define edges
        "rect45"            rectangle along the diagonals; clicks define edges
        "circle"            a circle; first click sets middle, second border
    
    ## Spray Brush ##
    "Sprays" the current coordinates by displacing them by a random amount.
    
    BRUSH_SPRAY -> deactivate/activate
        boolean             false or true
        
    BRUSH_SPRAY_EXP -> higher values lead to more positions close to the actual brush position
        Integer             whole numbers, should be bigger than 1
    
    BRUSH_SPRAY_SIZE -> max deviation from the actual brush position for both axes
        Integer             whole numbers
    
    BRUSH_SPRAY_INT -> intensity; if random number bigger, skips the draw call
        Float               value between 0 to 1, inclusive

    ## Mirroring ##
    Actions are mirrored around one or two axes.
    Both parameters support the same values, but MIRROR_MODE2 is only active if MIRROR_MODE is also active.
    Setting both to the same value will just apply the same behavior twice.
                            
    MIRROR_MODE and MIRROR_MODE2
        "off"
        "horizontal"
        "vertical"
        "diagonal_x"
        "diagonal_y"
        "point"             mirror around the center of the map

Available commands:
        help                display this help text again
        reload              reload the shc-mapmakerstools.lua file without restarting Stronghold.
        stack               get the current lua stack size
]]



-- /////////////////////
-- // config and data //
-- /////////////////////


-- @TheRedDaemon: Maybe using some config/data table would be beneficial?


-- mirror config
MIRROR_MODE = "off"
MIRROR_MODE2 = "off"


-- brush config
BRUSH_SPRAY = false -- is spray coord modification active
BRUSH_SHAPE = false -- is shape coord modification active


-- spray config
BRUSH_SPRAY_EXP = 3 -- defines how centered the random positions should be (higher -> more centered, should be bigger than 1)
BRUSH_SPRAY_SIZE = 8 -- max spray deviation for both axes
BRUSH_SPRAY_INT = 0.25 -- intensity -> 0 to 1, if random number bigger, skips the draw call


-- shape config
BRUSH_SHAPE_SHAPE = "line" -- shapes: "line", "rect", "rect45", "circle" -- @TheRedDaemon: Not happy about the name. Suggestions?
-- shape data
BRUSH_SHAPE_LAST = {} -- last selected points


-- //////////////////////
-- // helper functions //
-- //////////////////////


-- source: https://stackoverflow.com/a/1252776
function isTableEmpty(t)
  local next = next
  return next(t) == nil
end


--[[
  Apparently there is #, but this only works on array-style tables.
   -> Here good enough, but these functions should work in general.
  O(N) is the most efficient this can get without meta structures (a "count" variable for example)
]]--
-- source: https://stackoverflow.com/a/2705804
function getTableLength(t)
  local count = 0
  for _ in pairs(t) do count = count + 1 end
  return count
end


-- source: https://scriptinghelpers.org/questions/4850/how-do-i-round-numbers-in-lua-answered
-- Note: 0.5 -> 1, -0.5 -> 0
function round(x)
  return x + 0.5 - (x + 0.5) % 1
end


-- find coord duplicates in "coordTable"
-- if "display" true -> prints duplicates
function countCoordDuplicates(coordTable, display)
  if display ~= false and display ~= true then
    display = false -- default
  end
  
  local numberOfDuplicates = 0
  for indexOne, coordOne in ipairs(coordTable) do
    for indexTwo, coordTwo in ipairs(coordTable) do
      -- also ignore the same and previous entries to prevent duplicates of duplicates
      if indexOne < indexTwo and coordOne[1] == coordTwo[1] and coordOne[2] == coordTwo[2] then
        numberOfDuplicates = numberOfDuplicates + 1
      
        if display then
          print("Duplicate found: " ..coordOne[1] ..":" ..coordOne[2])
        end
      end
    end
  end
  return numberOfDuplicates
end



-- ////////////////////////////////////////
-- // brush and mirror support functions //
-- ////////////////////////////////////////


-- // spray brush //


-- generates a random deviation for the spray brush using the size
function randomSprayDeviation(size)
  local rand = round((math.random()^BRUSH_SPRAY_EXP) * size)
  rand = math.random() < 0.5 and -rand or rand -- plus or minus
  return rand
end


-- // shape brush //


-- Fills coordTable with {x,y} int coordinates using Bresenham's line algorithm.
-- According to source, this version does not guarantee a coordinate order. Could be x0, y0 to x1, y1 or vise versa.
-- source: https://en.wikipedia.org/wiki/Bresenham%27s_line_algorithm 
function fillWithLineCoords(x0, y0, x1, y1, coordTable)      
  local dx = math.abs(x1 - x0)
  local sx = x0 < x1 and 1 or -1
  local dy = -math.abs(y1 - y0)
  local sy = y0 < y1 and 1 or -1
  local err = dx + dy  -- error value e_xy
  while true do  -- loop
    table.insert(coordTable, {x0, y0})
    if x0 == x1 and y0 == y1 then break end
    local e2 = 2 * err
    if e2 >= dy then -- e_xy+e_x > 0
        err = err + dy
        x0 = x0 + sx
    end
    if e2 <= dx then -- e_xy+e_y < 0
        err = err + dx
        y0 = y0 + sy
    end
  end
end


-- create coords in such a way that the player sees a rectangle
-- used weird own function, maybe change to four "fillWithLineCoords" one day
function fillWithRectCoords(x0, y0, x1, y1, coordTable)
  local xDiff = x1 - x0
  local yDiff = y1 - y0
  local stepsSide = (xDiff - yDiff) / 2
  local stepsDown = (xDiff + yDiff) / 2

  -- prevent duplicates (could also use line algorithm instead?)
  if stepsSide == 0 or stepsDown == 0 then
    local isDownLine = stepsSide == 0
    local steps = isDownLine and stepsDown or stepsSide
    for i = 0, steps, 0 < steps and 1 or -1 do
      if isDownLine then
        table.insert(coordTable, {x0 + i, y0 + i})
      else
        table.insert(coordTable, {x0 + i, y0 - i})
      end
    end
    return
  end

  for i = 0, stepsSide, 0 < stepsSide and 1 or -1 do
    table.insert(coordTable, {x0 + i, y0 - i})
    table.insert(coordTable, {x1 - i, y1 + i})
  end

  local ySign = 0 < stepsDown and 1 or -1
  for i = 0 + ySign, stepsDown - ySign + ySign * (stepsDown % 1 ~= 0 and 1 or 0), ySign do
    table.insert(coordTable, {x0 + i, y0 + i})
    table.insert(coordTable, {x1 - i, y1 - i})
  end
end


-- create coords in such a way that the player sees a rectangle rotated by 45 degree
function fillWithRect45Coords(x0, y0, x1, y1, coordTable)
  -- prevent duplicates (could also use line algorithm instead?)
  if x0 == x1 or y0 == y1 then
    local xLine = x0 == x1
    local startPos = xLine and y0 or x0
    local endPos = xLine and y1 or x1
    for i = startPos, endPos, startPos < endPos and 1 or -1 do
      if xLine then
        table.insert(coordTable, {x0, i})
      else
        table.insert(coordTable, {i, y0})
      end
    end
    return
  end

  for i = x0, x1, x0 < x1 and 1 or -1 do
    table.insert(coordTable, {i, y0})
    table.insert(coordTable, {i, y1})
  end
  
  local ySign = y0 < y1 and 1 or -1
  for i = y0 + ySign, y1 - ySign, ySign do -- skip edges set by run over x
    table.insert(coordTable, {x0, i})
    table.insert(coordTable, {x1, i})
  end
end


--[[
-- as long as there is a limit on the input actions, this function does not make much sense

-- create coords in such a way that the player sees a filled rectangle rotated by 45 degree
function fillWithFilledRect45Coords(x0, y0, x1, y1, coordTable)  
  for i = x0, x1, x0 < x1 and 1 or -1 do
    for j = y0, y1, y0 < y1 and 1 or -1 do
      table.insert(coordTable, {i, j})
    end
  end
end
]]--


--[[
  function used to draw a circle using Mid-Point Circle Drawing Algorithm
  source: https://www.geeksforgeeks.org/mid-point-circle-drawing-algorithm/
  
  Note (from TheRedDaemon):
    - originally used Bresenham’s Algorithm (source: https://www.geeksforgeeks.org/bresenhams-circle-drawing-algorithm/)
    - but it produced duplicates I was unable to remove
]]--
function fillWithCircleCoords(x_centre, y_centre, xr, yr, coordTable)
  local r = round(math.sqrt((x_centre - xr)^2 + (y_centre - yr)^2))
  local x = r
  local y = 0
    
  -- Slightly changed for SHC, since it produced duplicates and wrong output:
  -- Printing the initial points on the axes after translation
  table.insert(coordTable, {r + x_centre, y_centre})
  if r > 0 then --When radius is zero only a single point will be printed
    table.insert(coordTable, {-r + x_centre, y_centre})
    table.insert(coordTable, {x_centre, r + y_centre})
    table.insert(coordTable, {x_centre, -r + y_centre})
  end
    
  -- Initializing the value of P
  local P = 1 - r
  while x > y do 
    y = y + 1
    
    if P <= 0 then -- Mid-point is inside or on the perimeter
      P = P + 2 * y + 1     
    else -- Mid-point is outside the perimeter
      x = x - 1
      P = P + 2 * y - 2 * x + 1
    end
      
    -- All the perimeter points have already been printed
    if x < y then break end
      
    -- Printing the generated point and its reflection in the other octants after translation
    table.insert(coordTable, {x + x_centre, y + y_centre})
    table.insert(coordTable, {-x + x_centre, y + y_centre})
    table.insert(coordTable, {x + x_centre, -y + y_centre})
    table.insert(coordTable, {-x + x_centre, -y + y_centre})
      
    -- If the generated point is on the line x = y then the perimeter points have already been printed
    if x ~= y then
      table.insert(coordTable, {y + x_centre, x + y_centre})
      table.insert(coordTable, {-y + x_centre, x + y_centre})
      table.insert(coordTable, {y + x_centre, -x + y_centre})
      table.insert(coordTable, {-y + x_centre, -x + y_centre})
    end
  end
end


-- // mirror support //


function applyMirror(x, y, size, mirrorMode)
  local newx = x
  local newy = y
  
  --[[
    SUGGESTION: "point" is more a rotation
    -> maybe add the ability to apply a point rotation to the action instead
      - so that I could mirror the action in 4 corners, or even 8
      - point mirror 1 + point mirror 2 does what it should (looks like only one mirror), but maybe not what is expected
  ]]--
  if mirrorMode == "point" then
    newx = (399 - x) - (size - 1)
    newy = (399 - y) - (size - 1)
  elseif mirrorMode == "horizontal" then
    newx = (399 - y) - (size - 1)
    newy = (399 - x) - (size - 1)
  elseif mirrorMode == "vertical" then
    newx = y
    newy = x
  elseif mirrorMode == "diagonal_x" then
    newx = x
    newy = 399 - y - (size - 1)
  elseif mirrorMode == "diagonal_y" then
    newx = 399 - x - (size - 1)
    newy = y
  else
    print("Don't know this MIRROR_MODE: " .. mirrorMode)
  end
  return {newx, newy}
end



-- ///////////////////////
-- // control functions //
-- ///////////////////////


-- @TheRedDaemon
-- Uses a previous click and the current click to generate NEW coordlist that forms a shape.
-- Will return an empty coordlist after it stored the first coordinate for the shape.
-- Shapes alone should not produce duplicates.
-- WARNING: Currently only the first coordinate (coordlist[1]) will be used.
-- WARNING: Currently maximal 200 coords can be applied. This easily results in incomplete big shapes.
function applyShape(coordlist, size)
  if not BRUSH_SHAPE or isTableEmpty(coordlist) then
    BRUSH_SHAPE_LAST = {} -- remove last entry if brush inactive (sadly happens on every call)
    return coordlist
  end
  
  local newCoordlist = {}
  local x = coordlist[1][1]
  local y = coordlist[1][2]
  
  -- currently no shape that takes three points, so this can be general
  if isTableEmpty(BRUSH_SHAPE_LAST) then
    BRUSH_SHAPE_LAST = {x,y}
    return newCoordlist -- skip drawing, only remember
  end
  
  if BRUSH_SHAPE_SHAPE == "line" then
    fillWithLineCoords(BRUSH_SHAPE_LAST[1], BRUSH_SHAPE_LAST[2], x, y, newCoordlist)
  elseif BRUSH_SHAPE_SHAPE == "rect" then
    fillWithRectCoords(BRUSH_SHAPE_LAST[1], BRUSH_SHAPE_LAST[2], x, y, newCoordlist)
  elseif BRUSH_SHAPE_SHAPE == "rect45" then
    fillWithRect45Coords(BRUSH_SHAPE_LAST[1], BRUSH_SHAPE_LAST[2], x, y, newCoordlist)
  elseif BRUSH_SHAPE_SHAPE == "circle" then
    fillWithCircleCoords(BRUSH_SHAPE_LAST[1], BRUSH_SHAPE_LAST[2], x, y, newCoordlist)
  else
    print("No valid shape: " ..BRUSH_SHAPE_SHAPE)
  end
  
  BRUSH_SHAPE_LAST = {} -- remove point after shape was applied (or failed to do so)
  
  -- print("Number of coord duplicates after applying shape: " ..countCoordDuplicates(newCoordlist)) -- debug
  
  return newCoordlist
end


-- @TheRedDaemon
-- Modifies all coords in coordlist by adding a random deviation.
-- If BRUSH_SPRAY_INT < 1, this function will build a new coordlist with the remaining coords. 
-- Produces duplicates.
function applySpray(coordlist, size)
  if not BRUSH_SPRAY then
    return coordlist
  end
  
  if BRUSH_SPRAY_INT < 1 then
    local newCoordlist = {}
  
    for _, coord in ipairs(coordlist) do
      -- only add coord if random number smaller then BRUSH_SPRAY_INT
      if math.random() < BRUSH_SPRAY_INT then
        coord[1] = coord[1] + randomSprayDeviation(BRUSH_SPRAY_SIZE)
        coord[2] = coord[2] + randomSprayDeviation(BRUSH_SPRAY_SIZE)
        table.insert(newCoordlist, coord)
      end
    end
    
    coordlist = newCoordlist
  else
    for _, coord in ipairs(coordlist) do
      coord[1] = coord[1] + randomSprayDeviation(BRUSH_SPRAY_SIZE)
      coord[2] = coord[2] + randomSprayDeviation(BRUSH_SPRAY_SIZE)
    end
  end
  
  -- print("Number of coord duplicates after applying spray: " ..countCoordDuplicates(coordlist)) -- debug
  
  return coordlist
end


-- mirror all coordinates and add the new coordinates to the coordlist
-- Produces duplicates.
function applyMirrors(coordlist, size)
  local dummyCoordTable = {}
  for _, coord in pairs(coordlist) do
    if MIRROR_MODE ~= "off" then
      local firstMirror = applyMirror(coord[1], coord[2], size, MIRROR_MODE)
      table.insert(dummyCoordTable, firstMirror)
      
      if MIRROR_MODE2 ~= "off" then
        table.insert(dummyCoordTable, applyMirror(coord[1], coord[2], size, MIRROR_MODE2))
        table.insert(dummyCoordTable, applyMirror(firstMirror[1], firstMirror[2], size, MIRROR_MODE2))
      end
    end
  end
  for _, coord in pairs(dummyCoordTable) do
    table.insert(coordlist, coord)
  end
  
  -- print("Number of coord duplicates after applying mirrors: " ..countCoordDuplicates(coordlist)) -- debug
  
  return coordlist
end


function erase(x, y, brush)
  return applyBrush(x, y, brush)
end

function setTerrainTypeEarth(x, y, brush)
  return applyBrush(x, y, brush)
end

 -- change is actually a signed byte, it can be -1 for example to decrease terrain height
function changeTerrainHeight(x, y, brush, change)
  return transformTerrain(x, y, brush, change)
end

function levelTerrain(x, y, brush, unknown)
  return transformTerrain(x, y, brush, unknown)
end

function minHeightTerrain(x, y, brush, unknown)
  return transformTerrain(x, y, brush, unknown)
end

function createPlateau(x, y, brush, intensity)
  return transformTerrain(x, y, brush, intensity)
end

function createHill(x, y, intensity)
  return applyBrush(x, y, intensity)
end

function placeAnimal(x, y, animalType)
  return applyBrush(x, y, animalType)
end


 -- functions that now do the actual thing required :)
 
-- @TheRedDaemon
-- general function to create coordinatelist
function applyCoordModification(x, y, size)
  -- print("Current Coord: " ..x ..":" ..y) -- debug
  
  local coordinatelist = {{x, y}}
  for _, func in ipairs(ACTIVE_TRANSFORMATIONS) do -- ipairs to guarantee order
    coordinatelist = func(coordinatelist, 1)
  end
  
  -- print("Total number of coords: " ..getTableLength(coordinatelist)) -- debug
  
  return coordinatelist
end

function applyBrush (x, y, brush)
  coordinatelist = applyCoordModification(x, y, 1)  
  
  for k,coordpair in ipairs(coordinatelist) do
    table.insert(coordpair, brush)
  end
  
  return coordinatelist
end

function transformTerrain(x, y, brush, change)
  coordinatelist = applyCoordModification(x, y, 1)  
  
  for k,coordpair in ipairs(coordinatelist) do
    table.insert(coordpair, brush)
    table.insert(coordpair, change)
  end
  
  return coordinatelist
end

function setTerrainType(x, y, brush, terrainType, unknown)
  coordinatelist = applyCoordModification(x, y, 1)  
  
  for k,coordpair in ipairs(coordinatelist) do
    table.insert(coordpair, brush)
    table.insert(coordpair, terrainType)
    table.insert(coordpair, unknown)
  end
  
  return coordinatelist
end

 -- objectType == 20 means the object is a rock and math.floor(rockType / 4)+1 will indicate the rock size
function placeTreeOrRock(x, y, objectType, rockType)
  
  if objectType == 20 then -- adjust with a translation for the fact that a rock can be larger than 1x1
    coordinatelist = applyCoordModification(x, y, math.floor(rockType/4)+1)  
  else
    coordinatelist = applyCoordModification(x, y, 1)  
  end
  
  for k,coordpair in ipairs(coordinatelist) do
    table.insert(coordpair, objectType)
    table.insert(coordpair, rockType)
  end
  
  return coordinatelist  
end



-- ///////////////////////
-- // additional config //
-- ///////////////////////


-- @TheRedDaemon
-- Coordinate modification order
-- Lua was not seemingly not able to add global function refs at the start (before definition?)
ACTIVE_TRANSFORMATIONS = {
   applyShape,              -- 1. draw shape
   applySpray,              -- 2. mess it up
   applyMirrors             -- 3. mirror
}