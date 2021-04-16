
-- ///////////////
-- // help text //
-- ///////////////


--[[
  Help text displayed by the console.
  
  Help text is created during start-up and can not be changed without restart?

  @TheRedDaemon
]]--
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
    WARNING: The first coordinate is only invalidated after use or after disabling the shape brush.
             
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
        
    MIRROR_ORDER -> order of coordinates after mirroring
        "shape"             draws original shape first, then first mirror, then second mirror
        "coord"             every single coordinate of the original shape is mirrored one after another

Available commands:
        help                display this help text again
        reload              reload the shc-mapmakerstools.lua file without restarting Stronghold.
        stack               get the current lua stack size
]]



-- //////////////////////
-- // helper functions //
-- //////////////////////


--[[
  Returns "true" should the table be empty.

  source: https://stackoverflow.com/a/1252776
  
  @TheRedDaemon
]]--
function isTableEmpty(t)
  local next = next
  return next(t) == nil
end


--[[
  Gets the number of entries in a table.
  
  Apparently there is #, but this only works on array-style tables.
  O(N) is the most efficient this can get without meta structures (a "count" variable for example)
  source: https://stackoverflow.com/a/2705804
  
  @TheRedDaemon
]]--
function getTableLength(t)
  local count = 0
  for _ in pairs(t) do count = count + 1 end
  return count
end


--[[
  A simple rounding to full numbers function.
  
  Note: 0.5 -> 1, but -0.5 -> 0
  source: https://scriptinghelpers.org/questions/4850/how-do-i-round-numbers-in-lua-answered
  
  @TheRedDaemon
]]--
function round(x)
  return x + 0.5 - (x + 0.5) % 1
end


--[[
  Find coord duplicates in "coordTable".
  
  If "display" true -> prints duplicates
  
  @TheRedDaemon
]]--
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


--[[
  Generates a random deviation for the spray brush.
  
  "centeringExp" is the exponent used on a random value between 0 and 1. Higher values increase
  the chance that the deviation is small and the resulting coord more centered. Should be 1 or bigger.
  Max deviation for both axes is set by "size".
  
  @TheRedDaemon
]]--
function randomSprayDeviation(centeringExp, size)
  local rand = round((math.random()^centeringExp) * size)
  rand = math.random() < 0.5 and -rand or rand -- plus or minus
  return rand
end


-- // shape brush //


--[[
  Fills coordTable with {x,y} int coordinates using Bresenham's line algorithm.
  
  According to source, this version does not guarantee a coordinate order. Could be x0, y0 to x1, y1 or vise versa.
  source: https://en.wikipedia.org/wiki/Bresenham%27s_line_algorithm

  @TheRedDaemon
]]--
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


--[[
  Create coords in such a way that the player sees a rectangle.
  
  Used own function, maybe change to four "fillWithLineCoords" one day?
  (But this would only save visual space in this file.)

  @TheRedDaemon
]]--
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


--[[
  Create coords in such a way that the player sees a rectangle rotated by 45 degree.

  @TheRedDaemon
]]--
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
-- @TheRedDaemon: as long as there is a limit on the input actions, this function does not make much sense


  Create coords in such a way that the player sees a filled rectangle rotated by 45 degree.

  @TheRedDaemon

function fillWithFilledRect45Coords(x0, y0, x1, y1, coordTable)  
  for i = x0, x1, x0 < x1 and 1 or -1 do
    for j = y0, y1, y0 < y1 and 1 or -1 do
      table.insert(coordTable, {i, j})
    end
  end
end
]]--


--[[
  Function used to draw a circle using Mid-Point Circle Drawing Algorithm.
  
  source: https://www.geeksforgeeks.org/mid-point-circle-drawing-algorithm/
  
  Note:
    - originally used Bresenham’s Algorithm (source: https://www.geeksforgeeks.org/bresenhams-circle-drawing-algorithm/)
    - but it produced duplicates I was unable to remove
    
  @TheRedDaemon
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


-- @gynt
function applyMirror(x, y, size, mirrorMode)
  local newx = x
  local newy = y
  
  --[[
    @TheRedDaemon:
  
    SUGGESTION: "point" is also a rotation
    -> maybe add the ability to apply a point rotation to the action instead
      - so that I could mirror the action in 4 corners, or even 8
      - center is between 199 and 200, so rotation likely requires translation by -199.5 before
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


--[[
  Uses a previous click and the current click to generate NEW coordlist that forms a shape.
  
  Will return an empty coordlist after it stored the first coordinate for the shape.
  Shapes alone should not produce duplicates.
  
  WARNING: Currently only the first coordinate (coordlist[1]) will be used.
  WARNING: Currently maximal 200 coords can be applied. This easily results in incomplete big shapes.
  WARNING: The first coordinate is only invalidated after use or after disabling the shape brush.
  
  @TheRedDaemon
]]--
function applyShape(config, coordlist, size)
  if not config.shapeActive or isTableEmpty(coordlist) then
    config.lastCoords = {} -- remove last entry if brush inactive (sadly happens on every call)
    return coordlist
  end
  
  local refLastCoords = config.lastCoords
  local newCoordlist = {}
  local x = coordlist[1][1]
  local y = coordlist[1][2]
  
  -- currently no shape that takes three points, so this can be general
  if isTableEmpty(refLastCoords) then
    config.lastCoords = {x,y}
    return newCoordlist -- skip drawing, only remember
  end
  
  local shape = config.shape
  if shape == "line" then
    fillWithLineCoords(refLastCoords[1], refLastCoords[2], x, y, newCoordlist)
  elseif shape == "rect" then
    fillWithRectCoords(refLastCoords[1], refLastCoords[2], x, y, newCoordlist)
  elseif shape == "rect45" then
    fillWithRect45Coords(refLastCoords[1], refLastCoords[2], x, y, newCoordlist)
  elseif shape == "circle" then
    fillWithCircleCoords(refLastCoords[1], refLastCoords[2], x, y, newCoordlist)
  else
    print("No valid shape: " ..shape)
  end
  
  config.lastCoords = {} -- remove point after shape was applied (or failed to do so)
  
  -- print("Number of coord duplicates after applying shape: " ..countCoordDuplicates(newCoordlist)) -- debug
  
  return newCoordlist
end


--[[
  Modifies all coords in coordlist by adding a random deviation.
  
  If config.sprayInt < 1, this function will build a new coordlist with the remaining coords. 
  Produces coordinate duplicates.

  @TheRedDaemon
]]--
function applySpray(config, coordlist, size)
  if not config.sprayActive then
    return coordlist
  end
  
  local sprayInt = config.sprayInt
  local sprayExp = config.sprayExp
  local spraySize = config.spraySize
  
  if sprayInt < 1 then
    local newCoordlist = {}
  
    for _, coord in ipairs(coordlist) do
      -- only add coord if random number smaller then sprayInt
      if math.random() < sprayInt then
        coord[1] = coord[1] + randomSprayDeviation(sprayExp, spraySize)
        coord[2] = coord[2] + randomSprayDeviation(sprayExp, spraySize)
        table.insert(newCoordlist, coord)
      end
    end
    
    coordlist = newCoordlist
  else
    for _, coord in ipairs(coordlist) do
      coord[1] = coord[1] + randomSprayDeviation(sprayExp, spraySize)
      coord[2] = coord[2] + randomSprayDeviation(sprayExp, spraySize)
    end
  end
  
  -- print("Number of coord duplicates after applying spray: " ..countCoordDuplicates(coordlist)) -- debug
  
  return coordlist
end


--[[
  Mirror all coordinates and return a modified or new "coordlist" with all coordinates.
  
  The coordinate structure after mirroring might have some effects on the results.
  For example, bigger rocks might block each other.
  The order types are shown here, using an example where the shape "line" is used to draw a 3 coord line,
  which is then mirrored two times (first with vertical mirror, then horizontal):
  
   1     |     4                 1     |     4                 1     |     2
    2    |    7                   2    |    5                   5    |    6  
     3   |  10                     3   |   6                     9   |  10   
  _______|_______               _______|_______               _______|_______
         |                             |                             |       
     11  |  12                     9   |  12                     11  |  12   
    8    |    9                   8    |    11                  7    |    8  
   5     |     6                 7     |     10                3     |     4 
   
  original order                ordered by original shape     ordered by original coordinates
  (not supported anymore)       MIRROR_ORDER: "shape"         MIRROR_ORDER: "coord"
  
  Produces coordinate duplicates.
  
  @gynt (original), @TheRedDaemon
]]--
function applyMirrors(config, coordlist, size)
  
  local mirrorOrder = config.mirrorOrder
  local mirrorMode = config.mirrorMode
  local mirrorMode2 = config.mirrorMode2
  
  if mirrorOrder == "coord" then
    local newCoordTable = {}
    
    for _, coord in ipairs(coordlist) do
      table.insert(newCoordTable, coord)
    
      if mirrorMode ~= "off" then
        local firstMirror = applyMirror(coord[1], coord[2], size, mirrorMode)
        table.insert(newCoordTable, firstMirror)
        
        if mirrorMode2 ~= "off" then
          table.insert(newCoordTable, applyMirror(coord[1], coord[2], size, mirrorMode2))
          table.insert(newCoordTable, applyMirror(firstMirror[1], firstMirror[2], size, mirrorMode2))
        end
      end
    end
    coordlist = newCoordTable
    
  elseif mirrorOrder == "shape" then
  
    if mirrorMode ~= "off" then
      local numberOfCoords = #coordlist -- @TheRedDaemon: Should only have number indexes, so this should be fine.
      for index = 1, numberOfCoords do
        table.insert(coordlist, applyMirror(coordlist[index][1], coordlist[index][2], size, mirrorMode))
      end
      
      if mirrorMode2 ~= "off" then
        for index = 1, numberOfCoords * 2 do
          table.insert(coordlist, applyMirror(coordlist[index][1], coordlist[index][2], size, mirrorMode2))
        end
      end
    end
  else
    print("No valid mirror order: " ..mirrorOrder)
  end
  
  -- print("Number of coord duplicates after applying mirrors: " ..countCoordDuplicates(coordlist)) -- debug
  
  return coordlist
end


-- @gynt
function erase(x, y, brush)
  return applyBrush(x, y, brush)
end


-- @gynt
function setTerrainTypeEarth(x, y, brush)
  return applyBrush(x, y, brush)
end


--[[
  change is actually a signed byte, it can be -1 for example to decrease terrain height

  @gynt
]]--
function changeTerrainHeight(x, y, brush, change)
  return transformTerrain(x, y, brush, change)
end


-- @gynt
function levelTerrain(x, y, brush, unknown)
  return transformTerrain(x, y, brush, unknown)
end


-- @gynt
function minHeightTerrain(x, y, brush, unknown)
  return transformTerrain(x, y, brush, unknown)
end


-- @gynt
function createPlateau(x, y, brush, intensity)
  return transformTerrain(x, y, brush, intensity)
end


-- @gynt
function createHill(x, y, intensity)
  return applyBrush(x, y, intensity)
end


-- @gynt
function placeAnimal(x, y, animalType)
  return applyBrush(x, y, animalType)
end


-- @gynt: functions that now do the actual thing required :)


--[[
  General function to create coordinatelist.
  
  @TheRedDaemon 
]]--
function applyCoordModification(x, y, size)
  -- print("Current Coord: " ..x ..":" ..y) -- debug
  
  local coordinatelist = {{x, y}}
  for _, config in ipairs(ACTIVE_TRANSFORMATIONS) do -- ipairs to guarantee order
    coordinatelist = config.func(config, coordinatelist, size)
  end
  
  -- print("Total number of coords: " ..getTableLength(coordinatelist)) -- debug
  
  return coordinatelist
end


-- @gynt
function applyBrush (x, y, brush)
  coordinatelist = applyCoordModification(x, y, 1)  
  
  for k,coordpair in ipairs(coordinatelist) do
    table.insert(coordpair, brush)
  end
  
  return coordinatelist
end


-- @gynt
function transformTerrain(x, y, brush, change)
  coordinatelist = applyCoordModification(x, y, 1)  
  
  for k,coordpair in ipairs(coordinatelist) do
    table.insert(coordpair, brush)
    table.insert(coordpair, change)
  end
  
  return coordinatelist
end


-- @gynt
function setTerrainType(x, y, brush, terrainType, unknown)
  coordinatelist = applyCoordModification(x, y, 1)  
  
  for k,coordpair in ipairs(coordinatelist) do
    table.insert(coordpair, brush)
    table.insert(coordpair, terrainType)
    table.insert(coordpair, unknown)
  end
  
  return coordinatelist
end


--[[
  objectType == 20 means the object is a rock and math.floor(rockType / 4)+1 will indicate the rock size
  
  @gynt
]]--
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



-- /////////////////////
-- // config and data //
-- /////////////////////


-- @TheRedDaemon: Currently everything but "func" is named differently. Would it make sense to find more common variables?

MIRROR = {
  mirrorMode    =   "off"           ,   -- mirroring type: "off", "horizontal", "vertical", "diagonal_x", "diagonal_y", "point"
  mirrorMode2   =   "off"           ,   -- second mirroring type: same values as first
  mirrorOrder   =   "coord"         ,   -- order of coordinates after mirroring: "shape", "coord"

  func          =   applyMirrors    ,
}


SPRAY = {
  sprayActive   =   false           ,   -- is spray coord modification active
  sprayExp      =   3               ,   -- defines how centered the random positions should be (higher -> more centered, should be bigger than 1)
  spraySize     =   8               ,   -- max spray deviation for both axes
  sprayInt      =   0.25            ,   -- intensity -> 0 to 1, if random number bigger, skips the draw call

  func          =   applySpray      ,   
}


SHAPE = {
  shapeActive   =   false           ,   -- is spray coord modification active
  shape         =   "line"          ,   -- shapes: "line", "rect", "rect45", "circle" -- @TheRedDaemon: Not happy about the variable name. Suggestions?

  lastCoords    =   {}              ,   -- data: last selected points

  func          =   applyShape      ,
}


--[[
  Coordinate modification order
  
  Lua was not seemingly not able to add global function refs at the start (before definition?).
  So the array is created here.

  @TheRedDaemon
]]--
ACTIVE_TRANSFORMATIONS = {
   SHAPE,               -- 1. draw shape
   SPRAY,               -- 2. mess it up
   MIRROR               -- 3. mirror
}