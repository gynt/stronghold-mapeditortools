
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

    FEATURE.parameter = value           assign a new value to a feature parameter
    return FEATURE.parameter            return the current parameter value

As an example:

    MIRROR.mirrorMode = 'horizontal'    sets the mirror to 'horizontal'.
    return MIRROR.mirrorMode            returns the current MIRROR_MODE
    
Parameters are explained like this:

    FEATURE.parameter -> additional explanation
        possibleValues      additional value explanation
        ...
    
WARNING: Currently max 200 actions are supported. Big shapes, especially when mirrored, reach
         this limit very fast. So do not be surprised if only one half of a shape appears.

The following features are implemented and currently applied in the order they are mentioned:

    ## Tracing ##
    Useful to check some values.
    
    TRACING.active -> deactivate/activate
        boolean             false or true
    
    TRACING.printTracingName -> should the tracing name be printed
        boolean             false or true
    
    TRACING.tracingName -> name printed on execution
        String              some word, like "Tree"
    
    TRACING.printFirstCoord -> print the first received coordinate; in case of TRACING click coord
        boolean             false or true
    
    TRACING.printAllCoords -> prints all coordinates
        boolean             false or true
  
    TRACING.printNumberOfCoords -> count the number of coordinates and print it
        boolean             false or true
    
    TRACING.printNumberOfDuplicates -> count the number of duplicates and print it
        boolean             false or true
    
    TRACING.printDuplicates -> print all duplicates; requires TRACING.printNumberOfDuplicates = true  
        boolean             false or true
    
    TRACING.devourCoords -> delete all coordinates from the pipeline after the check
        boolean             false or true

    ## Shape Brush ##
    Uses the coordinates of two clicks (the first one does nothing) to create a shape.
    WARNING: The first coordinate is only invalidated after use or after disabling the shape brush.
             
    SHAPE.active -> deactivate/activate
        boolean             false or true
             
    SHAPE.shape -> the shape to apply
        "line"              a simple line between two points
        "rect"              rectangle seen from the front; clicks define edges
        "rect45"            rectangle along the diagonals; clicks define edges
        "circle"            a circle; first click sets middle, second border
        
    SHAPE.removeRememberedCoords -> if "true", than the first click is not drawn
        boolean             false or true
        
    SHAPE.connectShapes -> decides how shapes are drawn if multiple coordinates reach this phase
        true                coordinates are reused; for example, lines are connected
        false               coordinates are only used once
    
    ## Spray Brush ##
    "Sprays" the current coordinates by displacing them by a random amount.
    
    SPRAY.active -> deactivate/activate
        boolean             false or true
        
    SPRAY.sprayExp -> higher values lead to more positions close to the actual brush position
        Integer             whole numbers, should be bigger than 1
    
    SPRAY.spraySize -> max deviation from the actual brush position for both axes
        Integer             whole numbers
    
    SPRAY.sprayInt -> intensity; if random number bigger, skips the draw call
        Float               value between 0 to 1, inclusive   

    ## Shape Brush 2 ##
    Functions like "Shape Brush", but instead of "SHAPE", the feature name is "SHAPE_2".
    
    ## Rotation Mirroring ##
    Mirrors the actions around a defined center.
    The number of requested actions is evenly placed on a circle.
    
    ROTATION.active -> deactivate/activate
        boolean             false or true
    
    ROTATION.numberOfPoints -> number of actions to place around the center
        Integer             1 or bigger; 2 equals old 'Mirroring'.mirrorMode = "point"
    
    ROTATION.rotationCenterX -> x-coordinate of the rotation center
        Integer             map is 400x400; the center is 200
    
    ROTATION.rotationCenterY -> y-coordinate of the rotation center
        Integer             map is 400x400; the center is 200
    
    ROTATION.coordOrder -> order of coordinates after mirroring
        "shape"             draws original shape first, then the mirrored points
        "coord"             every single coordinate of the original shape is mirrored one after another

    ## Mirroring ##
    Actions are mirrored around one axis.
    
    MIRROR.active -> deactivate/activate
        boolean             false or true
                            
    MIRROR.mirrorMode
        "horizontal"
        "vertical"
        "diagonal_x"
        "diagonal_y"
        "point"             mirror around the center of the map; kept for legacy; might be faster
        
    MIRROR.coordOrder -> order of coordinates after mirroring
        "shape"             draws original shape first, then the mirror
        "coord"             every single coordinate of the original shape is mirrored one after another
        
    ## Mirroring 2 ##
    Functions like "Mirroring", but instead of "MIRROR", the feature name is "MIRROR_2".
    Allows to apply a second mirror.
    Using the same mirror mode twice however will only apply the original coordinates a second time.
    
    ## Tracing 2 ##
    Functions like "Tracing", but instead of "TRACING", the feature name is "TRACING_2".

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
          print("        Duplicate found: " ..coordOne[1] ..":" ..coordOne[2])
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


--[[
  Checks if the "mirrorMode" is supported.
  If not, returns "false" and sends message to console.

  @TheRedDaemon
]]--
function isValidMirrorMode(mirrorMode)
  if mirrorMode == "point" or mirrorMode == "horizontal" or mirrorMode == "vertical" or
      mirrorMode == "diagonal_x" or mirrorMode == "diagonal_y" then
    return true
  else
    print("Don't know this mirror mode: " .. mirrorMode)
    return false
  end
end


-- @gynt
function applyMirror(x, y, size, mirrorMode)
  local newx = x
  local newy = y
  
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
  end
  -- @TheRedDaemon: Fails silently to not clutter the console.
  
  return {newx, newy}
end



-- ///////////////////////
-- // control functions //
-- ///////////////////////


--[[
  Uses a previous click and the current click to generate NEW "coordlist" that forms a shape.
  Or will try to create multiple shapes in a NEW "coordlist" if it receives multiple coords.
  
  Returns an empty "coordlist" after it stored the first coordinate for the shape if
  "config.removeRememberedCoords" is set to "true".
  If multiple coords are received, then setting "config.connectShapes" to "true" will use non
  start or end coords twice and will result in connected shapes.
  A single shape should not produce duplicates. Multiple will.
  
  WARNING: Currently maximal 200 coords can be applied. This easily results in incomplete big shapes.
  WARNING: The first coordinate is only invalidated after use, after receiving multiple coords
           or after disabling the shape brush.
  
  @TheRedDaemon
]]--
function applyShape(config, coordlist, size)
  if not config.active or isTableEmpty(coordlist) then
    config.lastCoords = {} -- remove last entry if brush inactive (sadly happens on every call)
    return coordlist
  end
  local newCoordlist = {}
  
  -- trusting on continuous index (should this make issues: get length)
  -- currently no shape that takes three points, so this can be general
  if coordlist[2] == nil and isTableEmpty(config.lastCoords) then
    config.lastCoords = coordlist
    return config.removeRememberedCoords and newCoordlist or coordlist
  end
  
  local shape = config.shape
  local fillFunction = nil
  
  if shape == "line" then
    fillFunction = fillWithLineCoords
  elseif shape == "rect" then
    fillFunction = fillWithRectCoords
  elseif shape == "rect45" then
    fillFunction = fillWithRect45Coords
  elseif shape == "circle" then
    fillFunction = fillWithCircleCoords
  end
  
  if fillFunction == nil then
    print("No valid shape: " ..shape)
    config.lastCoords = {} -- remove due to invalid shape
    return coordlist
  end
  
  if coordlist[2] == nil then
    -- no shape with more than two coords, so:
    fillFunction(config.lastCoords[1][1], config.lastCoords[1][2],
        coordlist[1][1], coordlist[1][2], newCoordlist)
  else
    local connectShapes = config.connectShapes
  
    -- no shape with anything other than two coords, so the loop can be simple
    local lastCoord = nil
    for _, coord in ipairs(coordlist) do
      if lastCoord ~= nil then
        fillFunction(lastCoord[1], lastCoord[2], coord[1], coord[2], newCoordlist)
        lastCoord = connectShapes and coord or nil
      else
        lastCoord = coord
      end
    end
  end
  
  config.lastCoords = {} -- remove points after any kind of shape was applied
  
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
  if not config.active or isTableEmpty(coordlist) then
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
  
   1     |     4                 1     |     4                 1     |     3
    2    |    7                   2    |    5                   5    |    7  
     3   |  10                     3   |   6                     9   |  11   
  _______|_______               _______|_______               _______|_______
         |                             |                             |       
     11  |  12                     9   |  12                     10  |  12   
    8    |    9                   8    |    11                  6    |    8  
   5     |     6                 7     |     10                2     |     4 
   
  original order                ordered by original shape     ordered by original coordinates
  (not supported anymore)       .coordOrder(both): "shape"    .coordOrder(both): "coord"
  
  Produces coordinate duplicates.
  
  @gynt (original), @TheRedDaemon
]]--
function applyMirrors(config, coordlist, size)
  local mirrorMode = config.mirrorMode
  if not config.active or isTableEmpty(coordlist) or not isValidMirrorMode(mirrorMode) then
    return coordlist
  end
  local coordOrder = config.coordOrder
  
  if coordOrder == "coord" then
    local newCoordTable = {}
    
    for _, coord in ipairs(coordlist) do
      table.insert(newCoordTable, coord)
      table.insert(newCoordTable, applyMirror(coord[1], coord[2], size, mirrorMode))
    end
    coordlist = newCoordTable
    
  elseif coordOrder == "shape" then
    -- @TheRedDaemon: # should only have number indexes, so this should be fine.
    for index = 1, #coordlist do
      table.insert(coordlist, applyMirror(coordlist[index][1], coordlist[index][2], size, mirrorMode))
    end
  else
    print("No valid coordinate order: " ..coordOrder)
  end
  
  -- print("Number of coord duplicates after applying mirrors: " ..countCoordDuplicates(coordlist)) -- debug
  
  return coordlist
end


--[[
  Mirrors the coordinates around a defined center using rotation.
  The coordinates are applied clockwise.
  
  For explanation "coordOrder" see "applyMirrors".
  Produces coordinate duplicates.
  
  source: https://en.wikipedia.org/wiki/Rotation_matrix

  @TheRedDaemon
]]--
function applyRotationMirror(config, coordlist, size)
  local numberOfPoints = config.numberOfPoints
  if not config.active or isTableEmpty(coordlist) or numberOfPoints < 2 then
    return coordlist
  end
  
  local coordOrder = config.coordOrder
  if not (coordOrder == "coord" or coordOrder == "shape") then
    print("No valid coordinate order: " ..coordOrder)
    return coordlist
  end
  
  -- create transformation values
  local translationX = config.rotationCenterX - size / 2.0
  local translationY = config.rotationCenterY - size / 2.0
  local sinValues = {}
  local cosValues = {}
  local rotationAngle = 2 * math.pi / numberOfPoints
  for index = 1, numberOfPoints - 1 do
    table.insert(sinValues, math.sin(rotationAngle * index))
    table.insert(cosValues, math.cos(rotationAngle * index))
  end
  
  if coordOrder == "coord" then
    local newCoordTable = {}
    
    for _, coord in ipairs(coordlist) do
      local centeredX = coord[1] - translationX
      local centeredY = coord[2] - translationY
    
      table.insert(newCoordTable, coord)
      for rotIndex = 1, numberOfPoints - 1 do
        table.insert(newCoordTable, {
          round(centeredX * cosValues[rotIndex] 
            - centeredY * sinValues[rotIndex] + translationX),
          round(centeredX * sinValues[rotIndex]
            + centeredY * cosValues[rotIndex] + translationY)
        })
      end
    end
    coordlist = newCoordTable
    
  elseif coordOrder == "shape" then
    local numberOfCoords = #coordlist
    
    for rotIndex = 1, numberOfPoints - 1 do
      for coordIndex = 1, #coordlist do
        local centeredX = coordlist[coordIndex][1] - translationX
        local centeredY = coordlist[coordIndex][2] - translationY
      
        table.insert(coordlist, {
          round(centeredX * cosValues[rotIndex] 
            - centeredY * sinValues[rotIndex] + translationX),
          round(centeredX * sinValues[rotIndex]
            + centeredY * cosValues[rotIndex] + translationY)
        })
      end
    end
  end
  
  -- print("Number of coord duplicates after applying rotation mirrors: " ..countCoordDuplicates(coordlist)) -- debug
  
  return coordlist
end


--[[
  Provides some tracing functions.
  
  Check the HELP text or the default configuration for more information.

  @TheRedDaemon
]]--
function applyTracing(config, coordlist, size)
  if not config.active then
    return coordlist
  end
  
  if config.printTracingName then
    print(config.tracingName ..":")
  end
  
  if config.printFirstCoord then
    if isTableEmpty(coordlist) then
      print("    No coordinates. Can not print first.")
    else
      print("    First Coordinate: " ..coordlist[1][1] ..":" ..coordlist[1][2])
    end
  end
  
  if config.printAllCoords then
    if isTableEmpty(coordlist) then
      print("        No coordinates.")
    else
      for index, coord in ipairs(coordlist) do
        print("        Coordinate " ..index ..": " ..coord[1] ..":" ..coord[2])
      end
    end
  end
  
  if config.printNumberOfCoords then
    print("    Total number of coordinates: " ..getTableLength(coordlist))
  end
  
  if config.printNumberOfDuplicates then
    print("    Number of coordinate duplicates: " ..countCoordDuplicates(coordlist, config.printDuplicates))
  end
  
  if config.devourCoords then
    coordlist = {}
  end
  
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
  
  WARNING: The only coordinate modifications so far that respect "size"
           are "applyMirror" and "applyRotationMirror".
  
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


--[[
  Create default modification configurations using simple LUA OOP.
  Source: https://www.lua.org/pil/16.2.html

  Wrapped it in different scope to also test scoping and function assign.
  This can be changed.

  @TheRedDaemon
]]--
ConfigConstructor = {} -- default constructors
do
  
  
  --[[
    Create default configuration base table.
  
    @TheRedDaemon
  ]]--
  local DefaultBase = {
    active      =   false                 ,   -- is the modification active
  }
  
  
  --[[
    Add dummy "func" to "DefaultBase".
    Executed if func in config not set. Returns "coordinatelist" unchanged.
  
    @TheRedDaemon
  ]]--
  function DefaultBase.func(config, coordinatelist, size)
    print("Noticed config without a valid function. No changes to coords.")
    return coordinatelist
  end


  --[[
    Constructs new object (or class, there does not seem to be a difference) from the default base values.
    "fields" is a table that can already provide values that extend the object or override functions.
  
    @TheRedDaemon
  ]]--
  function DefaultBase:new(fields)
    fields = fields or {}
    setmetatable(fields, self)
    self.__index = self
    return fields
  end


  -- @TheRedDaemon: Create default configuration tables:


  local DefaultShape = DefaultBase:new{
    shape                   =   "line"          ,   -- shapes: "line", "rect", "rect45", "circle"
    removeRememberedCoords  =   true            ,   -- "true": coord added to "lastCoords" is removed from the pipeline
    connectShapes           =   false           ,   -- connectShapes: "true": coordlist index is only moved by 1 before the next shape is drawn
                                                    --                "false": uses coords only once, unused remainders are silently discarded
                            
    lastCoords              =   {}              ,   -- data: last selected points
                            
    func                    =   applyShape      ,
  }
  
  
  local DefaultMirror = DefaultBase:new{
    mirrorMode  =   "horizontal"    ,   -- mirroring type: "horizontal", "vertical", "diagonal_x", "diagonal_y", "point"
    coordOrder  =   "coord"         ,   -- order of coordinates after mirroring: "shape", "coord"
    
    func        =   applyMirrors    ,
  }
  
  
  local DefaultSpray = DefaultBase:new{
    sprayExp    =   3               ,   -- defines how centered the random positions should be (higher -> more centered, should be bigger than 1)
    spraySize   =   8               ,   -- max spray deviation for both axes
    sprayInt    =   0.25            ,   -- intensity -> 0 to 1, if random number bigger, skips the draw call
    
    func        =   applySpray      ,
  }
  
  
  local DefaultRotationMirror = DefaultBase:new{
    numberOfPoints  =   2                   ,   -- how many points will be the result (mirrors = numberOfPoints - 1)
    rotationCenterX =   200                 ,   -- x-coordinate of the rotation center
    rotationCenterY =   200                 ,   -- y-coordinate of the rotation center
    coordOrder      =   "coord"             ,   -- order of coordinates after mirroring: "shape", "coord"
    
    func            =   applyRotationMirror ,
  }
  
  
  local DefaultTracing = DefaultBase:new{
    printTracingName        =   false           ,   -- should the tracing name be printed
    tracingName             =   "Tracing"       ,   -- name printed on execution
    printFirstCoord         =   false           ,   -- print the first coord in the coordlist, equal to click if utility first
    printAllCoords          =   false           ,   -- prints all coords
    printNumberOfCoords     =   false           ,   -- count the number of coords and print it
    printNumberOfDuplicates =   false           ,   -- count the number of duplicates and print it
    printDuplicates         =   false           ,   -- if they are counted, all duplicates are also printed  
    devourCoords            =   false           ,   -- delete all coords from the pipeline
    
    func                    =   applyTracing    ,
  }


  -- Add the default new functions to "ConfigConstructor":
  
  
  -- @TheRedDaemon 
  function ConfigConstructor.newBaseConfig(fields)
    return DefaultBase:new(fields)
  end
  
  
  -- @TheRedDaemon
  function ConfigConstructor.newSprayConfig(fields)
    return DefaultSpray:new(fields)
  end
  
  
  -- @TheRedDaemon
  function ConfigConstructor.newShapeConfig(fields)
    return DefaultShape:new(fields)
  end
  
  
  -- @TheRedDaemon
  function ConfigConstructor.newMirrorConfig(fields)
    return DefaultMirror:new(fields)
  end
  
  
  -- @TheRedDaemon
  function ConfigConstructor.newRotationMirrorConfig(fields)
    return DefaultRotationMirror:new(fields)
  end
  
  -- @TheRedDaemon
  function ConfigConstructor.newTracingConfig(fields)
    return DefaultTracing:new(fields)
  end
end


-- @TheRedDaemon: Create modification configurations:


MIRROR = ConfigConstructor.newMirrorConfig()

-- @TheRedDaemon: Second mirror. Sends table with from default deviating value.
MIRROR_2 = ConfigConstructor.newMirrorConfig{ mirrorMode = "vertical" }

SPRAY = ConfigConstructor.newSprayConfig()

SHAPE = ConfigConstructor.newShapeConfig()

SHAPE_2 = ConfigConstructor.newShapeConfig{ connectShapes = true }

ROTATION = ConfigConstructor.newRotationMirrorConfig()

TRACING = ConfigConstructor.newTracingConfig()

TRACING_2 = ConfigConstructor.newTracingConfig{ tracingName = "Tracing 2" }


--[[
  Coordinate modification order
  
  Lua was seemingly not able to add global function refs at the start (before definition?).
  So the array and it's values are created here.

  @TheRedDaemon
]]--
ACTIVE_TRANSFORMATIONS = {
  TRACING       ,           -- 1. check some stuff
  SHAPE         ,           -- 2. draw shape
  SPRAY         ,           -- 3. mess it up
  SHAPE_2       ,           -- 4. maybe create more complex shape
  ROTATION      ,           -- 5. mirror using rotation
  MIRROR        ,           -- 6. mirror
  MIRROR_2      ,           -- 7. second mirror
  TRACING_2     ,           -- 8. check stuff again
}