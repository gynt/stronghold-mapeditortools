
--[[
  @TheRedDaemon:
  Some bigger restructuring might be necessary (one day). Among that:
    - even more visual space between function complexes
    - restructure function complexes
    - maybe some better helper functions for the config support functions
    - global create alias function
    - make all functions local that do not need to be accessed
    - a table of contents at the start, so that one could better CTRL+F to the intended place
]]--

-- //////////////////////////
-- // help text and status //
-- //////////////////////////


--[[
  Help text displayed by the console.
  
  Help text is created during start-up and can not be changed without restart?

  @TheRedDaemon
]]--
HELP = [[

This console is used to configure additional map editor features.
(feature, parameter and value are dummy names)

    feature()                           displays feature help text
    feature("parameter")                displays parameter help text
    feature("parameter", value)         assign a new value to a feature parameter


To get the current configurations you can use:


    status                              get all parameters of the active features
    return feature.parameter            get the value of one parameter

The following features are implemented and currently applied in the order they are mentioned:

    tracing, shape, spray, shape2, rotation, mirror, mirror2, tracing2

Use for example "mirror()" to get an explanation and a parameter list.

WARNING: Currently max 200 actions are supported. Big shapes, especially when mirrored, reach
         this limit very fast. So do not be surprised if only one half of a shape appears.
         
WARNING: The "QuickEdit"-mode of the windows console will freeze the game if a function wants
         to print something while the console is in "Selection"-mode.
         Either press "escape" or use right click or some key to leave this mode,
         or disable the "QuickEdit"-mode with:
            
            Right click on title bar -> Properties -> Options -> QuickEdit
]]


--[[
  Creates status text.
  
  The text will contain the value "active". However, non-active features are filtered.
  
  Note: The "func" value is received, but is not placed into the string.

  @TheRedDaemon
]]--
function getStatus()
  local statusTable = {}
  statusTable[1] = "\nSTATUS (in execution order):\n" -- first new line
  
  local count = 2
  local featureCounter = 1
  for _, feature in ipairs(ACTIVE_TRANSFORMATIONS) do
    local featureStatus = feature:getPublicStatus()
    -- only active
    if featureStatus.active ~= nil and featureStatus.active == true then
      if count == 2 then
        statusTable[count] = "\n\t\t\tCLICK\n"
        count = count + 1
      end
      
      statusTable[count] = "\n\t\t\t ||\n\t\t\t \\/\n\n"
      statusTable[count + 1] = tostring(featureCounter) .. ". " .. tostring(featureStatus.__name) .. "\n"
      count = count + 2
      featureCounter = featureCounter + 1
      
      for field, value in pairs(featureStatus) do
        if not (field == "__name" or field == "func") then
          local toPad = 30 - string.len(field)
          local featStr = tostring(field) .. string.rep(" ", toPad) .. ":    " .. tostring(value)
          statusTable[count] = "\t" .. featStr .. "\n"
          count = count + 1
        end
      end
    end
  end
  
  if count < 3 then
    statusTable[count] = "No feature active at the moment.\n"
  else
    statusTable[count] = "\n\t\t\t ||\n\t\t\t \\/\n\n\t\t\tGAME\n"
  end

  return table.concat(statusTable)
end


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
  
  if display == true then
    print("    Duplicates:")
  end
  
  local numberOfDuplicates = 0
  for indexOne, coordOne in ipairs(coordTable) do
    for indexTwo, coordTwo in ipairs(coordTable) do
      -- also ignore the same and previous entries to prevent duplicates of duplicates
      if indexOne < indexTwo and coordOne[1] == coordTwo[1] and coordOne[2] == coordTwo[2] then
        numberOfDuplicates = numberOfDuplicates + 1
      
        if display then
          print("        Duplicate " .. numberOfDuplicates .. ": " .. coordOne[1] .. ":" .. coordOne[2])
        end
      end
    end
  end
  
  if display == true then
    if numberOfDuplicates == 0 then
      print("        No duplicates.")
    end
    print("")
  end
  
  return numberOfDuplicates
end



-- ////////////////////////////////////////
-- // brush and mirror support functions //
-- ////////////////////////////////////////


-- // shape brush //


--[[
  Fills coordTable with {x,y} int coordinates using Bresenham's line algorithm.
  Returns the received table.
  
  According to source, this version does not guarantee a coordinate order. Could be x0, y0 to x1, y1 or vise versa.
  source: https://en.wikipedia.org/wiki/Bresenham%27s_line_algorithm

  @TheRedDaemon
]]--
function fillWithLineCoords(x0, y0, x1, y1, coordTable) 
  local index = #coordTable + 1
  local dx = math.abs(x1 - x0)
  local sx = x0 < x1 and 1 or -1
  local dy = -math.abs(y1 - y0)
  local sy = y0 < y1 and 1 or -1
  local err = dx + dy  -- error value e_xy
  while true do  -- loop
    coordTable[index] = {x0, y0}
    index = index + 1
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
  return coordTable
end


--[[
  Create coords in such a way that the player sees a rectangle.
  Returns the received table.
  
  Used own function, maybe change to four "fillWithLineCoords" one day?
  (But this would only save visual space in this file.)

  @TheRedDaemon
]]--
function fillWithRectCoords(x0, y0, x1, y1, coordTable)
  local xDiff = x1 - x0
  local yDiff = y1 - y0
  local stepsSide = (xDiff - yDiff) / 2
  local stepsDown = (xDiff + yDiff) / 2

  -- prevent duplicates with line algorithm
  if stepsSide == 0 or stepsDown == 0 then
    return fillWithLineCoords(x0, y0, x1, y1, coordTable)
  end
  
  local index = #coordTable + 1
  for i = 0, stepsSide, 0 < stepsSide and 1 or -1 do
    coordTable[index] = {x0 + i, y0 - i}
    coordTable[index + 1] = {x1 - i, y1 + i}
    index = index + 2
  end

  local ySign = 0 < stepsDown and 1 or -1
  for i = 0 + ySign, stepsDown - ySign + ySign * (stepsDown % 1 ~= 0 and 1 or 0), ySign do
    coordTable[index] = {x0 + i, y0 + i}
    coordTable[index + 1] = {x1 - i, y1 - i}
    index = index + 2
  end
  
  return coordTable
end


--[[
  Create coords in such a way that the player sees a rectangle rotated by 45 degree.
  Returns the received table.

  @TheRedDaemon
]]--
function fillWithRect45Coords(x0, y0, x1, y1, coordTable)
  -- prevent duplicates with line algorithm
  if x0 == x1 or y0 == y1 then
    return fillWithLineCoords(x0, y0, x1, y1, coordTable)
  end

  local index = #coordTable + 1
  for i = x0, x1, x0 < x1 and 1 or -1 do
    coordTable[index] = {i, y0}
    coordTable[index + 1] = {i, y1}
    index = index + 2
  end
  
  local ySign = y0 < y1 and 1 or -1
  for i = y0 + ySign, y1 - ySign, ySign do -- skip edges set by run over x
    coordTable[index] = {x0, i}
    coordTable[index + 1] = {x1, i}
    index = index + 2
  end
  
  return coordTable
end


--[[
-- @TheRedDaemon: as long as there is a limit on the input actions, this function does not make much sense


  Create coords in such a way that the player sees a filled rectangle rotated by 45 degree.
  Returns the received table.

  @TheRedDaemon

function fillWithFilledRect45Coords(x0, y0, x1, y1, coordTable)
  local index = #coordTable + 1
  for i = x0, x1, x0 < x1 and 1 or -1 do
    for j = y0, y1, y0 < y1 and 1 or -1 do
      coordTable[index] = {i, j}
      index = index + 1
    end
  end
  return coordTable
end
]]--


--[[
  Function used to draw a circle using Mid-Point Circle Drawing Algorithm.
  Returns the received table.
  
  source: https://www.geeksforgeeks.org/mid-point-circle-drawing-algorithm/
  
  Note:
    - originally used Bresenham’s Algorithm (source: https://www.geeksforgeeks.org/bresenhams-circle-drawing-algorithm/)
    - but it produced duplicates I was unable to remove
    
  @TheRedDaemon
]]--
function fillWithCircleCoords(x_centre, y_centre, xr, yr, coordTable)
  local index = #coordTable + 1
  local r = round(math.sqrt((x_centre - xr)^2 + (y_centre - yr)^2))
  local x = r
  local y = 0
    
  -- Slightly changed for SHC, since it produced duplicates and wrong output:
  -- Printing the initial points on the axes after translation
  coordTable[index] = {r + x_centre, y_centre}
  index = index + 1
  if r > 0 then --When radius is zero only a single point will be printed
    coordTable[index] = {-r + x_centre, y_centre}
    coordTable[index + 1] = {x_centre, r + y_centre}
    coordTable[index + 2] = {x_centre, -r + y_centre}
    index = index + 3
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
    coordTable[index] = {x + x_centre, y + y_centre}
    coordTable[index + 1] = {-x + x_centre, y + y_centre}
    coordTable[index + 2] = {x + x_centre, -y + y_centre}
    coordTable[index + 3] = {-x + x_centre, -y + y_centre}
    index = index + 4
      
    -- If the generated point is on the line x = y then the perimeter points have already been printed
    if x ~= y then
      coordTable[index] = {y + x_centre, x + y_centre}
      coordTable[index + 1] = {-y + x_centre, x + y_centre}
      coordTable[index + 2] = {y + x_centre, -x + y_centre}
      coordTable[index + 3] = {-y + x_centre, -x + y_centre}
      index = index + 4
    end
  end
  return coordTable
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
  return newCoordlist
end


--[[
  Modifies coords in coordlist by adding a random deviation.
  
  This function will always build a new table.
  For a description of the config parameters see default values or HELP text.
  
  Produces coordinate duplicates.
  
  The parameter checks were removed. Only if "keepOriginalCoord" is active,
  wrong "sprayIntMode" and "coordOrder" will produce broken results.

  @TheRedDaemon
]]--
function applySpray(config, coordlist, size)
  if not config.active or isTableEmpty(coordlist) then
    return coordlist
  end
  
  -- get config values
  local sprayInt = config.sprayInt
  local sprayExp = config.sprayExp
  local sprayMin = config.sprayMin
  local sprayRange = config.sprayMax - sprayMin
  local sprayIntMode = config.sprayIntMode
  local coordOrder = config.coordOrder
  local keepOriginalCoord = config.keepOriginalCoord
  
  -- whether deviation should apply
  local intOnOrig = sprayIntMode == "original" or sprayIntMode == "both"
  local intOnDev = not keepOriginalCoord or sprayIntMode ~= "original" -- always needed, except when "original"

  local keepOriginFunc
  if sprayIntMode == "together" then
    keepOriginFunc = function(keepDev)
      return keepDev
    end
  elseif sprayIntMode == "separator" then
    keepOriginFunc = function(keepDev)
      return not keepDev
    end
  else
    keepOriginFunc = function(keepDev)
      return not intOnOrig or math.random() < sprayInt
    end
  end
  
  -- under here used conditions, the loop actually writes in the same table
  -- attaches an index to the tables, to get right index
  local originalCoords = { nextIndex = 1 }
  local deviatedCoords = (not keepOriginalCoord or coordOrder == "coordOriginal" or
      coordOrder == "coordDeviated") and originalCoords or { nextIndex = 1 }
  local switchApplyOrder = coordOrder == "coordDeviated"
  
  for _, coord in ipairs(coordlist) do
    local keepDev = not intOnDev or math.random() < sprayInt 
    local keepOrigin = keepOriginalCoord and keepOriginFunc(keepDev)
        
    if keepOrigin and not switchApplyOrder then
      originalCoords[originalCoords.nextIndex] = coord
      originalCoords.nextIndex = originalCoords.nextIndex + 1
    end
    
    if keepDev then -- compute deviation here
      local devX = round((math.random()^sprayExp) * sprayRange) + sprayMin
      local devY = round((math.random()^sprayExp) * sprayRange) + sprayMin
    
      deviatedCoords[deviatedCoords.nextIndex] = {
        coord[1] + (math.random() < 0.5 and -devX or devX),
        coord[2] + (math.random() < 0.5 and -devY or devY)
      }
      deviatedCoords.nextIndex = deviatedCoords.nextIndex + 1
    end
    
    if keepOrigin and switchApplyOrder then
      originalCoords[originalCoords.nextIndex] = coord
      originalCoords.nextIndex = originalCoords.nextIndex + 1
    end
  end
  
  -- add coords if not already one table
  if keepOriginalCoord then
    if coordOrder == "original" then
      for _, coord in ipairs(deviatedCoords) do
        originalCoords[originalCoords.nextIndex] = coord
        originalCoords.nextIndex = originalCoords.nextIndex + 1
      end
    elseif coordOrder == "deviated" then
      for _, coord in ipairs(originalCoords) do
        deviatedCoords[deviatedCoords.nextIndex] = coord
        deviatedCoords.nextIndex = deviatedCoords.nextIndex + 1
      end
      originalCoords = deviatedCoords
    end
  end
  
  originalCoords.nextIndex = nil -- remove index
  coordlist = originalCoords -- originalCoords is filled with all coords
  
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
  
  @gynt, @Krarilotus, @TheRedDaemon
]]--
function applyMirror(config, coordlist, size)
  local mirrorMode = config.mirrorMode
  if not config.active or isTableEmpty(coordlist) then
    return coordlist
  end
  
  -- @TheRedDaemon: Create mirroring function.
  local invertPos = 400 - size
  local mirrorFunc = nil
  if mirrorMode == "point" then
    mirrorFunc = function(x, y) return {invertPos - x, invertPos - y} end
  elseif mirrorMode == "horizontal" then
    mirrorFunc = function(x, y) return {invertPos - y, invertPos - x} end
  elseif mirrorMode == "vertical" then
    mirrorFunc = function(x, y) return {y, x} end
  elseif mirrorMode == "diagonal_x" then
    mirrorFunc = function(x, y) return {x, invertPos - y} end
  elseif mirrorMode == "diagonal_y" then
    mirrorFunc = function(x, y) return {invertPos - x, y} end
  elseif mirrorMode == "quadrant_before" then
    mirrorFunc = function(x, y) return {invertPos - y, x} end
  elseif mirrorMode == "quadrant_after" then
    mirrorFunc = function(x, y) return {y, invertPos - x} end
  else -- @TheRedDaemon: Do nothing. Fails silently.
    mirrorFunc = function(x, y) return {x, y} end
  end 
  
  local coordOrder = config.coordOrder
  if coordOrder == "coord" then
    local newCoordTable = {}

    local index = 1
    for _, coord in ipairs(coordlist) do
      newCoordTable[index] = coord
      newCoordTable[index + 1] = mirrorFunc(coord[1], coord[2])
      index = index + 2
    end
    coordlist = newCoordTable
    
  elseif coordOrder == "shape" then
    
    local numberOfCoords = #coordlist
    for index = 1, numberOfCoords do
      local coord = coordlist[index]
      coordlist[numberOfCoords + index] = mirrorFunc(coord[1], coord[2])
    end
  end -- no coordOrder fails silently
  
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
  
  -- create transformation values
  local translationX = config.rotationCenterX - size / 2.0
  local translationY = config.rotationCenterY - size / 2.0
  local sinValues = {}
  local cosValues = {}
  local rotationAngle = 2 * math.pi / numberOfPoints
  for index = 1, numberOfPoints - 1 do
    sinValues[index] = math.sin(rotationAngle * index)
    cosValues[index] = math.cos(rotationAngle * index)
  end
  
  local coordOrder = config.coordOrder
  if coordOrder == "coord" then
    local newCoordTable = {}
    
    local index = 1
    for _, coord in ipairs(coordlist) do
      local centeredX = coord[1] - translationX
      local centeredY = coord[2] - translationY
    
      newCoordTable[index] = coord
      for rotIndex = 1, numberOfPoints - 1 do
        newCoordTable[index + rotIndex] = {
          round(centeredX * cosValues[rotIndex] 
            - centeredY * sinValues[rotIndex] + translationX),
          round(centeredX * sinValues[rotIndex]
            + centeredY * cosValues[rotIndex] + translationY)
        }
      end
      index = index + numberOfPoints
    end
    coordlist = newCoordTable
    
  elseif coordOrder == "shape" then
    local numberOfCoords = #coordlist
    
    for rotIndex = 1, numberOfPoints - 1 do
      for coordIndex = 1, #coordlist do
        local coord = coordlist[coordIndex]
        local centeredX = coord[1] - translationX
        local centeredY = coord[2] - translationY
      
        coordlist[numberOfCoords * rotIndex + coordIndex] = {
          round(centeredX * cosValues[rotIndex] 
            - centeredY * sinValues[rotIndex] + translationX),
          round(centeredX * sinValues[rotIndex]
            + centeredY * cosValues[rotIndex] + translationY)
        }
      end
    end
  end -- no coordOrder fails silently
  
  return coordlist
end


--[[
  Provides some tracing functions.
  
  Check the help texts or the default configuration for more information.

  @TheRedDaemon
]]--
function applyTracing(config, coordlist, size)
  if not config.active then
    return coordlist
  end
  
  if config.printTracingName then
    print("")
    print(config.tracingName ..":")
  end
  
  if config.printFirstCoord then
    print("")
    if isTableEmpty(coordlist) then
      print("    No coordinates. Can not print first.")
    else
      print("    First Coordinate: " ..coordlist[1][1] ..":" ..coordlist[1][2])
    end
  end
  
  if config.printAllCoords then
    print("")
    print("    All coordinates:")
    if isTableEmpty(coordlist) then
      print("        No coordinates.")
    else
      for index, coord in ipairs(coordlist) do
        print("        Coordinate " ..index ..": " ..coord[1] ..":" ..coord[2])
      end
    end
  end
  
  if config.printNumberOfCoords then
    print("")
    print("    Total number of coordinates: " .. #coordlist)
  end
  
  if config.printNumberOfDuplicates then
    print("")
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
  
  local coordinatelist = {{x, y}}
  for _, config in ipairs(ACTIVE_TRANSFORMATIONS) do -- ipairs to guarantee order
    coordinatelist = config.func(config, coordinatelist, size)
  end
  
  return coordinatelist
end


-- @gynt
function applyBrush (x, y, brush)
  coordinatelist = applyCoordModification(x, y, 1)  
  
  for k,coordpair in ipairs(coordinatelist) do
    coordpair[3] = brush
  end
  
  return coordinatelist
end


--[[
  Called by some terrain transform tools(?).
  
  @TheRedDaemon:
    Excluded are seemingly: "Hill", "Mountain"
      - "Hill" and "Mountain" appear to be independent formn the brush size.
    The value "change" seems to indicate the change in height?
    However, the leveling tool (do not have english name right now, bottom right)
    produces "change" = 1, like the raise land tool. It does not care about a manually set "change".
    
    "change" creates various things:
      - The flattening tool does weird stuff, but mostly raises land.
      - The tools to raise and lower are the most consistent: The higher (or lower) the values, the faster
        the land is lowered or raised. A test with -100 however resulted in the effect, that executing it
        raised the land to max, but using it on max land lowered it to the ground level.
      - The plateaus work only if the value is 4 (lower plateau) or 8 (higher plateau), otherwise they draw
        tiles.
      - The leveling tool does not care about this value.
  
  @gynt, @TheRedDaemon
]]--
function transformTerrain(x, y, brush, change)
  coordinatelist = applyCoordModification(x, y, 1)  
  
  for k,coordpair in ipairs(coordinatelist) do
    coordpair[3] = brush
    coordpair[4] = change
  end
  
  return coordinatelist
end


--[[
  Called if terrain (tiles) should be modified. (Land and water tools)
  
  @TheRedDaemon:
    "terrainType" (32 bit) and "unknown" (8 bit) seem to be one(?) bit-flag array.
    Not all of them seem to be used or are at least usable on normal ground.
    Tests with some mixed values produced nothing.
    The only unused(?) texture found is produced by setting the 19th bit in "terrainType". (Some stone texture)
    There might be unknown other dependencies.
  
  @gynt, @TheRedDaemon
]]--
function setTerrainType(x, y, brush, terrainType, unknown)
  coordinatelist = applyCoordModification(x, y, 1)  
  
  for k,coordpair in ipairs(coordinatelist) do
    coordpair[3] = brush
    coordpair[4] = terrainType
    coordpair[5] = unknown
  end
  
  return coordinatelist
end


--[[
  Called by the vegetation and object tools.
  
  @TheRedDaemon:
    The orientation of a rock is not received.
    "rockType" is 0 for everything else.
    The animal tool does not trigger this.
    "objectType" and "rockType" seem to flow into similar values.
    Raising "objectType" might start to produce rocks, even far past objectType == 20.
    Any faulty combination will result in an invisible object. Takes space, but is nothing.
    It does not seem to be a clean bit-flag array. There are other dependencies.
    Object variants are not received here.
    ASSUMPTION: The values are actually part of an optimized bit object and/or are much smaller.
                As a result, returning very big values creates issues, maybe overflows?

  @gynt: objectType == 20 means the object is a rock and math.floor(rockType / 4)+1 will indicate the rock size
  
  @gynt, @TheRedDaemon
]]--
function placeTreeOrRock(x, y, objectType, rockType)
  
  if objectType == 20 then -- adjust with a translation for the fact that a rock can be larger than 1x1
    coordinatelist = applyCoordModification(x, y, math.floor(rockType/4)+1)  
  else
    coordinatelist = applyCoordModification(x, y, 1)  
  end
  
  for k,coordpair in ipairs(coordinatelist) do
    coordpair[3] = objectType
    coordpair[4] = rockType
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

  
  -- // assert functions //
  
  
  -- @TheRedDaemon
  local function checkType(value, intendedType, failMessage)
    local res = type(value) == intendedType
    if not res and failMessage ~= nil then
      print(failMessage)
    end
    return res
  end

  
  -- @TheRedDaemon
  local function isBoolean(value)
    return checkType(value, "boolean", "The given parameter value is not true or false (Boolean).")
  end
  
  
  -- @TheRedDaemon
  local function isNumber(value)
    return checkType(value, "number", "The given parameter value is no number.")
  end
  
  
  -- @TheRedDaemon
  local function isInteger(value)
    local res = isNumber(value)
    if res and math.floor(value) ~= value then
      print("The given parameter value is no whole number (Integer).")
      res = false
    end
    return res
  end
  
  
  -- @TheRedDaemon
  local function isString(value)
    return checkType(value, "string", "The given parameter value is no string.")
  end
  
  
  --[[
    Checks if a number is in a specific range (inclusive).
    Setting "minRange" or "maxRange" to "nil" will assume no border.
  
    @TheRedDaemon
  ]]--
  local function isInRange(number, minRange, maxRange, rangeMessage)
    if minRange ~= nil and number < minRange then
      print("The given number is too small. Allowed range: ", rangeMessage)
      return false
    end
    
    if maxRange ~= nil and number > maxRange then
      print("The given number is too big. Allowed range: ", rangeMessage)
      return false
    end
    
    return true
  end
  
  
  -- // configuration tables //
  
  
  --[[
    Create default configuration base table.
  
    @TheRedDaemon
  ]]--
  local DefaultBase = {
    active      =   false   ,   -- is the modification active
    
    _FieldUtil_ =   {}      ,   -- includes check functions and help texts by parameter name
    __name = "Base Configuration Object", -- debug info
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
    General function to set a field in the configuration.
    Also prints help texts.
    
    Returns true if any field was set. Might not be the field requested through "field".
  
    @TheRedDaemon
  ]]--
  function DefaultBase:setField(field, value)
    if field == nil then
      local featureCon = self._FieldUtil_[self.__name]
      local featureText = featureCon ~= nil and featureCon.help or nil
      if featureText == nil then
        featureText = "No feature description found."
      end
      
      print(featureText)
      return false
    end
    
    local fieldUtil = nil
    local currentClass = self
    repeat
      fieldUtil = currentClass._FieldUtil_[field]
      if fieldUtil == nil then
        currentClass = getmetatable(currentClass) -- check parent for validation or help text
        if currentClass == nil then
          print("No parameter handler for this name found: ", field)
          return false
        end
      end
    until (fieldUtil ~= nil)
    
    if value == nil then
      local fieldText = fieldUtil.help
      if fieldText == nil then
        fieldText = "No parameter description found."
      end
      print(fieldText)
      return false
    end
    
    return fieldUtil.set(self, field, value)
  end
  
  
  --[[
    General function to guard a simple field assignment.
    If this configuration does not have an index named "field", the assignment is prevented.
    
    WARNING: Does not prevent wrong assignments to valid fields.
  
    @gynt, @TheRedDaemon
  ]]--
  function DefaultBase:guardedAssign(field, value)
    if self[field] == nil then
      print("'" .. tostring(field) .. "' is not a valid parameter for this feature.")
    else
      rawset(self, field, value)
    end
  end
  
  
  --[[
    Creates a status using the structure in _FieldUtil_.
    Aliases will be filtered by using rawget(), so that they do not fall through on accident.
    
    Will return a table of key value pairs. Keys are the parameter.
    The configuration description will be in "__name"..
  
    @TheRedDaemon
  ]]--
  function DefaultBase:getPublicStatus()
    local statusTable = {}
    
    statusTable.__name = self._FieldUtil_[self.__name] ~= nil and self.__name or "Unknown"
    
    local currentClass = self
    repeat
      local currentFieldUtil = nil
      repeat
        currentFieldUtil = rawget(currentClass, "_FieldUtil_")
        if currentFieldUtil == nil then
          currentClass = getmetatable(currentClass) -- check parent
        end
        if currentClass == nil then
          return statusTable -- we are done
        end
      until (currentFieldUtil ~= nil)

      for field, _ in pairs(currentFieldUtil) do
      
        -- will notice default fields, filters aliases, does not override (keeps specialized)
        if rawget(currentClass, field) ~= nil and statusTable[field] == nil then
          statusTable[field] = self[field] -- add current value
        end
      end
      
      currentClass = getmetatable(currentClass)
    until (currentClass == nil)
    
    return statusTable
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
    self.__call = DefaultBase.setField -- sets __call always to default handler
    self.__newindex = DefaultBase.guardedAssign -- sets __newindex always to default handler
    return fields
  end


  -- @TheRedDaemon: Create default configuration tables:


  local DefaultShape = DefaultBase:new{
    shape                   =   "line"          ,   -- shapes: "line", "rect", "rect45", "circle"
    removeRememberedCoords  =   true            ,   -- "true": coord added to "lastCoords" is removed from the pipeline
    connectShapes           =   false           ,   -- connectShapes: "true": coordlist index is only moved by 1 before the next shape is drawn
                                                    --                "false": uses coords only once, unused remainders are silently discarded
             
    --[[
      @TheRedDaemon: I am a bit annoyed that this config holds some status.
      
      SUGGESTION:
        Maybe use yet another modification "applyCollector" (or something like this), which collects an amount
        of coords before giving all of it to the next stage, so one would have an extra system for that.
        Options could be the number to collect and whether or not the collected coords should be devoured.
        Issues:
          - Too complicated for now -> Shape would need two options to work.
          - Resetting the collections would require some sort of notification, like a "changed brush" or
            "deselected" tool event.
    ]]--
    lastCoords              =   {}              ,   -- data: last selected points
                            
    func                    =   applyShape      ,
    
    __name = "Shape Feature Configuration", -- debug info
  }
  
  local DefaultMirror = DefaultBase:new{
    mirrorMode  =   "point"         ,   -- mirroring type: "horizontal", "vertical", "diagonal_x", "diagonal_y", "point",
                                        --                 "quadrant_before", "quadrant_after"
    coordOrder  =   "coord"         ,   -- order of coordinates after mirroring: "shape", "coord"
    
    func        =   applyMirror     ,
    
    __name = "Mirror Feature Configuration", -- debug info
  }
  
  
  local DefaultSpray = DefaultBase:new{
    sprayExp            =   3               ,   -- higher -> more centered, should be bigger than 1
    sprayMax            =   8               ,   -- max spray deviation for both axes
    sprayMin            =   0               ,   -- min spray deviation for both axes
    sprayInt            =   0.25            ,   -- intensity -> 0 to 1, if random number bigger, skips the draw call
    keepOriginalCoord   =   false           ,   -- "true": also applies the original coord alongside the deviated
    sprayIntMode        =   "both"          ,   -- effect of Int on: "deviated", "original", "both", "together", "separator"
    coordOrder          =   "original"      ,   -- which coords are applied first: "original", "deviated", "coordOriginal", "coordDeviated"
    
    func                =   applySpray      ,
    
    __name = "Spray Feature Configuration", -- debug info
  }
  
  
  local DefaultRotationMirror = DefaultBase:new{
    numberOfPoints  =   2                   ,   -- how many points will be the result (mirrors = numberOfPoints - 1)
    rotationCenterX =   200                 ,   -- x-coordinate of the rotation center
    rotationCenterY =   200                 ,   -- y-coordinate of the rotation center
    coordOrder      =   "coord"             ,   -- order of coordinates after mirroring: "shape", "coord"
    
    func            =   applyRotationMirror ,
    
    __name = "Rotation Mirror Feature Configuration", -- debug info
  }
  
  
  local DefaultTracing = DefaultBase:new{
    printTracingName        =   true            ,   -- should the tracing name be printed
    tracingName             =   "Tracing"       ,   -- name printed on execution
    printFirstCoord         =   true            ,   -- print the first coord in the coordlist, equal to click if utility first
    printAllCoords          =   true            ,   -- prints all coords
    printNumberOfCoords     =   true            ,   -- count the number of coords and print it
    printNumberOfDuplicates =   true            ,   -- count the number of duplicates and print it
    printDuplicates         =   true            ,   -- if they are counted, all duplicates are also printed  
    devourCoords            =   false           ,   -- delete all coords from the pipeline
    
    func                    =   applyTracing    ,
    
    __name = "Tracing Feature Configuration", -- debug info
  }

  --[[
    Create all _FieldUtil_ for the configurations.
    
    @TheRedDaemon
  ]]--
  
  -- @TheRedDaemon: Do the (...).set functions need the field value?
  -- @TheRedDaemon: It might be beneficial to create some helper functions in the future.
  
  
  -- // base
  local baseFieldUtil = DefaultBase._FieldUtil_
  
  baseFieldUtil[DefaultBase.__name] = {}
  baseFieldUtil[DefaultBase.__name].help = [[
    
      ## Base Configuration ##
      This is a raw configuration object.
      If you can read this and you did not intend to experiment with the functions,
      please report this as a bug on github.]]
  
  -- func
  baseFieldUtil.func = {}
  
  function baseFieldUtil.func.set(config, field, value)
    print("The function of this configuration can not be changed with this method.")
  end
  
  baseFieldUtil.func.help = [[
    
      "func"
      The parameter "func" contains the function which will be called with this configuration.
      This is an internal value and should not be changed.]]
      
  -- active
  baseFieldUtil.active = {}
  
  function baseFieldUtil.active.set(config, field, value)
    local res = isBoolean(value)
    if res then
      config.active = value
      if value then
        print("Feature activated.")
      else
        print("Feature deactivated.")
      end
    end
    return res
  end
  
  baseFieldUtil.active.help = [[
    
      "active"
      General activation parameter. Controls whether the feature is active or not.
      This parameter might be set by other parameter changes.
      
          false                     feature is deactivated
          true                      feature is active
          
      Default: ]] .. tostring(DefaultBase.active)
  
  
  -- // spray
  DefaultSpray._FieldUtil_ = {}
  local sprayFieldUtil = DefaultSpray._FieldUtil_
  
  sprayFieldUtil[DefaultSpray.__name] = {}
  sprayFieldUtil[DefaultSpray.__name].help = [[
    
      ## Spray Modification ##
      "Sprays" the received coordinates by displacing them by a random amount.
    
      Parameter                     Possible values
          active                        false, true
          sprayExp / exp                >= 1.0
          sprayMin / min                0 <= value <= sprayMax
          sprayMax / max                >= sprayMin
          sprayInt / int                0.0 <= value <= 1.0
          keepOriginalCoord / keep      false, true
          sprayIntMode / mode           "deviated", "original", "both", "together", "separator",
                                            "none", "off"
          coordOrder / order            "original", "deviated", "coordOriginal", "coordDeviated"]]
  
  -- sprayExp
  sprayFieldUtil.sprayExp = {}
  
  function sprayFieldUtil.sprayExp.set(config, field, value)
    local res = isNumber(value) and isInRange(value, 1, nil, ">= 1.0")
    if res then
      config.sprayExp = value
      print("Set spray exponent to: ", value)
    end
    return res
  end
  
  sprayFieldUtil.sprayExp.help = [[
    
      "sprayExp", alias: "exp"
      This value is the exponent that is applied to a random number between 0.0 and 1.0.
      Higher values lead to smaller deviations and more positions close
      to the actual brush coordinate.
          
          >= 1.0                    numbers equal to / bigger than 1.0

      Default: ]] .. tostring(DefaultSpray.sprayExp)
  
  sprayFieldUtil.exp = sprayFieldUtil.sprayExp -- alias
  
  -- sprayInt
  sprayFieldUtil.sprayInt = {}
  
  function sprayFieldUtil.sprayInt.set(config, field, value)
    local res = isNumber(value) and isInRange(value, 0, 1, "0.0 <= value <= 1.0")
    if res then
      config.sprayInt = value
      print("Set spray intensity to: ", value)
    end
    return res
  end
  
  sprayFieldUtil.sprayInt.help = [[
    
      "sprayInt", alias: "int"
      Basically the intensity of the spray.
      If a random number between 0.0 and 1.0 is bigger than this value, a coordinate is removed.
      This check is made for every coordinate.
                
          0.0 <= value <= 1.0       numbers between 0.0 and 1.0 (inclusive)

      Default: ]] .. tostring(DefaultSpray.sprayInt)
  
  sprayFieldUtil.int = sprayFieldUtil.sprayInt -- alias
  
  -- sprayMin
  sprayFieldUtil.sprayMin = {}
  
  function sprayFieldUtil.sprayMin.set(config, field, value)
    local res = isInteger(value) and isInRange(value, 0, config.sprayMax, "0 <= value <= sprayMax")
    if res then
      config.sprayMin = value
      print("Set spray min to: ", value)
    end
    return res
  end
  
  sprayFieldUtil.sprayMin.help = [[
    
      "sprayMin", alias: "min"
      This value sets the minimal deviation from the actual brush position for both axes.

          0 <= value <= sprayMax    whole numbers equal to / bigger than 0 and
                                        smaller / equal to the parameter "sprayMax"

      Default: ]] .. tostring(DefaultSpray.sprayMin)
  
  sprayFieldUtil.min = sprayFieldUtil.sprayMin -- alias
  
  -- sprayMax
  sprayFieldUtil.sprayMax = {}
  
  function sprayFieldUtil.sprayMax.set(config, field, value)
    local res = isInteger(value) and isInRange(value, config.sprayMin, nil, ">= sprayMin")
    if res then
      config.sprayMax = value
      print("Set spray max to: ", value)
    end
    return res
  end
  
  sprayFieldUtil.sprayMax.help = [[
    
      "sprayMax", alias: "max"
      This value sets the maximal deviation from the actual brush position for both axes.

          >= sprayMin               whole numbers equal to / bigger than the parameter "sprayMin"

      Default: ]] .. tostring(DefaultSpray.sprayMax)
  
  sprayFieldUtil.max = sprayFieldUtil.sprayMax -- alias
  
  -- keepOriginalCoord
  sprayFieldUtil.keepOriginalCoord = {}
  
  function sprayFieldUtil.keepOriginalCoord.set(config, field, value)
    local res = isBoolean(value)
    if res then
      config.keepOriginalCoord = value
      if value then
        print("Original coordinates are kept in the pipeline.")
      else
        print("Original coordinates are removed from the pipeline.")
      end
    end
    return res
  end
  
  sprayFieldUtil.keepOriginalCoord.help = [[
    
      "keepOriginalCoord", alias: "keep"
      This value defines how to handle the original coordinates.
      If they are kept, then they are not effected by deviation, but potentially intensity.

          false                     original coordinates are removed
          true                      original coordinates stay and may be effected by intensity

      Default: ]] .. tostring(DefaultSpray.keepOriginalCoord)
  
  sprayFieldUtil.keep = sprayFieldUtil.keepOriginalCoord -- alias
  
  -- sprayIntMode
  sprayFieldUtil.sprayIntMode = {}
  
  function sprayFieldUtil.sprayIntMode.set(config, field, value)
    local res = isString(value)
    if res then
      if value == "none" or value == "off" then
        config.keepOriginalCoord = false
        print("Original coordinates are not kept anymore.")
      elseif value == "deviated" or value == "original" or
          value == "both" or value == "together" or
          value == "separator" then
        config.sprayIntMode = value
        config.keepOriginalCoord = true
        print("Original coordinates are kept and intensity mode is set to: ", value)
      else
        res = false
        print("No valid intensity mode: ", value)
      end
    end
    return res
  end
  
  sprayFieldUtil.sprayIntMode.help = [[
    
      "sprayIntMode", alias: "mode"
      Defines how intensity effects the deviated original and deviated coordinates.
      Only relevant if "keepOriginalCoord" is true and active.
      Setting values other than "none" or "off" will also activate "keepOriginalCoord".

          "deviated"                effects the deviated coordinates; original are always applied
          "original"                effects the original coordinates; deviated are always applied
          "both"                    effects both coordinates independent from each other
          "together"                either both or no coordinates are applied
          "separator"               intensity applies to deviated coordinates; uses original
                                        if deviated is not used
          "none" / "off"            disables "keepOriginalCoord"

      Default: ]] .. tostring(DefaultSpray.sprayIntMode)
  
  sprayFieldUtil.mode = sprayFieldUtil.sprayIntMode -- alias
  
  -- coordOrder
  sprayFieldUtil.coordOrder = {}
  
  function sprayFieldUtil.coordOrder.set(config, field, value)
    local res = isString(value)
    if res then
      if value == "original" or value == "deviated" or
          value == "coordOriginal" or value == "coordDeviated" then
        config.coordOrder = value
        print("Set coordinate order to: ", value)
      else
        res = false
        print("No valid coordinate order: ", value)
      end
    end
    return res
  end
  
  sprayFieldUtil.coordOrder.help = [[
    
      "coordOrder", alias: "order"
      Defines how the coordinates are ordered in the pipeline after the spray is applied.
      Only relevant if "keepOriginalCoord" is true and active, since this value defines
      the order of the original and deviated coordinates.

          "original"                all original coordinates first
          "deviated"                all deviated coordinates first
          "coordOriginal"           if both coordinates are applied, apply the original first,
                                        then the deviated    
          "coordDeviated"           if both coordinates are applied, apply the deviated first,
                                        then the original

      Default: ]] .. tostring(DefaultSpray.coordOrder)
  
  sprayFieldUtil.order = sprayFieldUtil.coordOrder -- alias
  
  
  -- // mirror
  DefaultMirror._FieldUtil_ = {}
  local mirrorFieldUtil = DefaultMirror._FieldUtil_
  
  mirrorFieldUtil[DefaultMirror.__name] = {}
  mirrorFieldUtil[DefaultMirror.__name].help = [[
    
      ## Mirror Modification ##
      Actions are mirrored around one axis.
      
      Parameter                     Possible values
          active                        false, true
          mirrorMode / mode             "horizontal", "vertical", "diagonal_x", "diagonal_y", "point",
                                            "quadrant_before", "quadrant_after", "none", "off"
          coordOrder / order            "shape", "coord"]]
  
  -- mirrorMode
  mirrorFieldUtil.mirrorMode = {}
  
  function mirrorFieldUtil.mirrorMode.set(config, field, value)
    local res = isString(value)
    if res then
      if value == "none" or value == "off" then
        config.active = false
        print("Mirror deactivated.")
      elseif value == "horizontal" or value == "vertical" or
          value == "diagonal_x" or value == "diagonal_y" or
          value == "point" or value == "quadrant_before" or
          value == "quadrant_after" then
        config.mirrorMode = value
        config.active = true
        print("Set mirror active and to mode: ", value)
      else
        res = false
        print("No valid mirror mode: ", value)
      end
    end
    return res
  end
  
  mirrorFieldUtil.mirrorMode.help = [[
    
      "mirrorMode", alias: "mode"
      The type of mirror to apply.
      Setting values other than "none" or "off" will also activate this feature.

          "horizontal"              mirror around the horizontal
          "vertical"                mirror around the vertical
          "diagonal_x"              mirror around the direction of the x-coordinates
          "diagonal_y"              mirror around the direction of the y-coordinates
          "point"                   mirror around the center of the map
          "quadrant_before"         mirrors actions in the clockwise next quadrant
          "quadrant_after"          mirrors actions in the counterclockwise next quadrant
          "none" / "off"            disables this mirror feature

      Default: ]] .. tostring(DefaultMirror.mirrorMode)
  
  mirrorFieldUtil.mode = mirrorFieldUtil.mirrorMode -- alias
  
  -- coordOrder
  mirrorFieldUtil.coordOrder = {}
  
  function mirrorFieldUtil.coordOrder.set(config, field, value)
    local res = isString(value)
    if res then
      if value == "shape" or value == "coord" then
        config.coordOrder = value
        print("Set coordinate order to: ", value)
      else
        res = false
        print("No valid coordinate order: ", value)
      end
    end
    return res
  end
  
  mirrorFieldUtil.coordOrder.help = [[
    
      "coordOrder", alias: "order"
      Defines the order of coordinates after they are mirrored.

          "shape"                   received coordinates are mirrored as a whole and then attached to the list
          "coord"                   every single coordinate will be followed by its mirrored version

      Default: ]] .. tostring(DefaultMirror.coordOrder)
  
  mirrorFieldUtil.order = mirrorFieldUtil.coordOrder -- alias
  
  
  -- // shape
  DefaultShape._FieldUtil_ = {}
  local shapeFieldUtil = DefaultShape._FieldUtil_
  
  shapeFieldUtil[DefaultShape.__name] = {}
  shapeFieldUtil[DefaultShape.__name].help = [[
    
      ## Shape Modification ##
      This feature uses the received coordinates to generate a shape of coordinates.
      If it receives only one, it is remembered until it receives a second one to build a shape with.
      Should it receive more than one, it will try to generate as many shapes as it has coordinates for.
      
      WARNING:
          - The remembered coordinate is only invalidated after use or after disabling this feature.
          - Some transformations, like creating hills, may display wrong tiles until the view
            is rotated at least once when being applied. This seems to be a vanilla game bug.
            If not changed this way, the tiles will be visually bugged in the normal game.
      
      Parameter                     Possible values
          active                        false, true
          shape                         "line", "rect", "rect45", "circle", "none", "off"
          removeRememberedCoords /      false, true
            remove
          connectShapes / connect       false, true]]
  
  -- shape
  shapeFieldUtil.shape = {}
  
  function shapeFieldUtil.shape.set(config, field, value)
    local res = isString(value)
    if res then
      if value == "none" or value == "off" then
        config.active = false
        print("Shape brush deactivated.")
      elseif value == "line" or value == "rect" or
          value == "rect45" or value == "circle" then
        config.shape = value
        config.active = true
        print("Set shape brush active and to shape: ", value)
      else
        res = false
        print("No valid shape: ", value)
      end
    end
    return res
  end
  
  shapeFieldUtil.shape.help = [[
    
      "shape"
      The type of shape to apply.
      Setting values other than "none" or "off" will also activate this feature.
        
          "line"                    a simple line between two points
          "rect"                    rectangle seen from the front; coordinates define edges
          "rect45"                  rectangle along the diagonals; coordinates define edges
          "circle"                  a circle; first coordinate sets middle, second the radius
          "none" / "off"            disables this shape feature

      Default: ]] .. tostring(DefaultShape.shape)
  
  -- removeRememberedCoords
  shapeFieldUtil.removeRememberedCoords = {}
  
  function shapeFieldUtil.removeRememberedCoords.set(config, field, value)
    local res = isBoolean(value)
    if res then
      config.removeRememberedCoords = value
      if value then
        print("Remembered coordinates are now removed from the pipeline.")
      else
        print("Remembered coordinates will stay in the pipeline.")
      end
    end
    return res
  end
  
  shapeFieldUtil.removeRememberedCoords.help = [[
    
      "removeRememberedCoords", alias: "remove"
      The shape feature stores a coordinate should it receive only one without having stored any.
      This value indicates whether this first coordinate is discarded or passed further.
 
          false                     keeps the coordinate in the pipeline
          true                      remembered coordinate is discarded

      Default: ]] .. tostring(DefaultShape.removeRememberedCoords)
   
  shapeFieldUtil.remove = shapeFieldUtil.removeRememberedCoords -- alias
  
  -- connectShapes
  shapeFieldUtil.connectShapes = {}
  
  function shapeFieldUtil.connectShapes.set(config, field, value)
    local res = isBoolean(value)
    if res then
      config.connectShapes = value
      if value then
        print("Coordinates will be reused between shapes.")
      else
        print("Coordinates are only used once.")
      end
    end
    return res
  end
  
  shapeFieldUtil.connectShapes.help = [[
    
      "connectShapes", alias: "connect"
      The shape modification may receive multiple coordinates and then tries to create multiple shapes.
      This value decides how the coordinates are used.
      
          false                     coordinates are only used once
          true                      coordinates are reused; for example, lines are connected

      Default: ]] .. tostring(DefaultShape.connectShapes)
   
  shapeFieldUtil.connect = shapeFieldUtil.connectShapes -- alias
  
  
  -- // rotation mirror
  DefaultRotationMirror._FieldUtil_ = {}
  local rotationFieldUtil = DefaultRotationMirror._FieldUtil_
  
  rotationFieldUtil[DefaultRotationMirror.__name] = {}
  rotationFieldUtil[DefaultRotationMirror.__name].help = [[
    
      ## Rotation Mirroring ##
      Mirrors the actions around a defined center.
      The requested actions are evenly placed on a circle.
      
      Parameter                     Possible values
          active                        false, true
          numberOfPoints / points       >= 1
          rotationCenterX / x           whole numbers
          rotationCenterY / y           whole numbers
          coordOrder / order            "shape", "coord"]]
  
  -- numberOfPoints
  rotationFieldUtil.numberOfPoints = {}
  
  function rotationFieldUtil.numberOfPoints.set(config, field, value)
    local res = isInteger(value) and isInRange(value, 1, nil, ">= 1")
    if res then
      config.numberOfPoints = value
      
      if value == 1 then
        config.active = false
        print("Disabled rotation mirror.")
      else
        config.active = true
        print("Enabled rotation mirror and set number of points to: ", value)
      end
    end
    return res
  end
  
  rotationFieldUtil.numberOfPoints.help = [[
    
      "numberOfPoints", alias: "points"
      This value defines the number of actions to place around the center.
      Setting it to "1" deactivates the feature, higher values enable it.

          >= 1                      whole numbers equal to / bigger than 1

      Default: ]] .. tostring(DefaultRotationMirror.numberOfPoints)
  
  rotationFieldUtil.points = rotationFieldUtil.numberOfPoints -- alias
  
  -- rotationCenterX
  rotationFieldUtil.rotationCenterX = {}
  
  function rotationFieldUtil.rotationCenterX.set(config, field, value)
    local res = isInteger(value)
    if res then
      config.rotationCenterX = value
      print("Set x-coordinate of rotation center to: ", value)
    end
    return res
  end
  
  rotationFieldUtil.rotationCenterX.help = [[
    
      "rotationCenterX", alias: "x"
      The x-coordinate of the rotation center.
      The map has a size of 400x400, with the center being at 200.

          25, 200, 345, ...         whole numbers

      Default: ]] .. tostring(DefaultRotationMirror.rotationCenterX)
  
  rotationFieldUtil.x = rotationFieldUtil.rotationCenterX -- alias
  
  -- rotationCenterY
  rotationFieldUtil.rotationCenterY = {}
  
  function rotationFieldUtil.rotationCenterY.set(config, field, value)
    local res = isInteger(value)
    if res then
      config.rotationCenterY = value
      print("Set y-coordinate of rotation center to: ", value)
    end
    return res
  end
  
  rotationFieldUtil.rotationCenterY.help = [[
    
      "rotationCenterY", alias: "y"
      The y-coordinate of the rotation center.
      The map has a size of 400x400, with the center being at 200.

          25, 200, 345, ...         whole numbers

      Default: ]] .. tostring(DefaultRotationMirror.rotationCenterY)
  
  rotationFieldUtil.y = rotationFieldUtil.rotationCenterY -- alias
  
  -- coordOrder
  rotationFieldUtil.coordOrder = {}
  
  function rotationFieldUtil.coordOrder.set(config, field, value)
    local res = isString(value)
    if res then
      if value == "shape" or value == "coord" then
        config.coordOrder = value
        print("Set coordinate order to: ", value)
      else
        res = false
        print("No valid coordinate order: ", value)
      end
    end
    return res
  end
  
  rotationFieldUtil.coordOrder.help = [[
    
      "coordOrder", alias: "order"
      Defines the order of coordinates after they are mirrored.
      However, the mirrored coordinates are created clockwise, regardless of this setting.

          "shape"                   received coordinates are mirrored as a whole and then attached to the list
          "coord"                   every single coordinate will be followed by its mirrored versions

      Default: ]] .. tostring(DefaultRotationMirror.coordOrder)
  
  rotationFieldUtil.order = rotationFieldUtil.coordOrder -- alias


  -- // tracing
  DefaultTracing._FieldUtil_ = {}
  local tracingFieldUtil = DefaultTracing._FieldUtil_
  
  tracingFieldUtil[DefaultTracing.__name] = {}
  tracingFieldUtil[DefaultTracing.__name].help = [[
    
      ## Tracing ##
      Allows to display some values in the console.
      
      Parameter                     Possible values
          active                        false, true
          printTracingName              false, true
          tracingName                   string    
          printFirstCoord               false, true
          printAllCoords                false, true
          printNumberOfCoords           false, true
          printNumberOfDuplicates       false, true
          printDuplicates               false, true
          devourCoords                  false, true]]
          
  -- printTracingName
  tracingFieldUtil.printTracingName = {}
  
  function tracingFieldUtil.printTracingName.set(config, field, value)
    local res = isBoolean(value)
    if res then
      config.printTracingName = value
      if value then
        print("Tracing name is printed.")
      else
        print("Tracing name is not printed.")
      end
    end
    return res
  end
  
  tracingFieldUtil.printTracingName.help = [[
    
      "printTracingName"
      A tracing configuration can have a name.
      This value decides whether it is printed on usage.
      
          false                     does not print the tracing name
          true                      prints the tracing name
          
      Default: ]] .. tostring(DefaultTracing.printTracingName)
      
  -- tracingName
  tracingFieldUtil.tracingName = {}
  
  function tracingFieldUtil.tracingName.set(config, field, value)
    local res = isString(value)
    if res then
      config.tracingName = value
      print("Set tracing name to: ", value)
    end
    return res
  end
  
  tracingFieldUtil.tracingName.help = [[
    
      "tracingName"
      The name of this tracing configuration.
      
          string                    a string; example: "Tracing"
          
      Default: ]] .. tostring(DefaultTracing.tracingName)
  
  -- printFirstCoord
  tracingFieldUtil.printFirstCoord = {}
  
  function tracingFieldUtil.printFirstCoord.set(config, field, value)
    local res = isBoolean(value)
    if res then
      config.printFirstCoord = value
      if value then
        print("Prints the first received coordinate.")
      else
        print("Does not print the first received coordinate.")
      end
    end
    return res
  end
  
  tracingFieldUtil.printFirstCoord.help = [[
    
      "printFirstCoord"
      This value decides whether the first coordinate this feature receives during execution should be printed.
      
          false                     does not print the first received coordinate
          true                      prints the first received coordinate
          
      Default: ]] .. tostring(DefaultTracing.printFirstCoord)
      
  -- printAllCoords
  tracingFieldUtil.printAllCoords = {}
  
  function tracingFieldUtil.printAllCoords.set(config, field, value)
    local res = isBoolean(value)
    if res then
      config.printAllCoords = value
      if value then
        print("Prints all received coordinates.")
      else
        print("Does not print the received coordinates.")
      end
    end
    return res
  end
  
  tracingFieldUtil.printAllCoords.help = [[
    
      "printAllCoords"
      This value decides whether all coordinates this feature receives during execution should be printed.
      
          false                     does not print all received coordinates
          true                      prints all received coordinates
          
      Default: ]] .. tostring(DefaultTracing.printAllCoords)
      
  -- printNumberOfCoords
  tracingFieldUtil.printNumberOfCoords = {}
  
  function tracingFieldUtil.printNumberOfCoords.set(config, field, value)
    local res = isBoolean(value)
    if res then
      config.printNumberOfCoords = value
      if value then
        print("Prints number of all coordinates.")
      else
        print("Does not print number of all coordinates.")
      end
    end
    return res
  end
  
  tracingFieldUtil.printNumberOfCoords.help = [[
    
      "printNumberOfCoords"
      This value decides whether the number of all received coordinates should be printed.
      
          false                     does not print number
          true                      print number of all received coordinates
          
      Default: ]] .. tostring(DefaultTracing.printNumberOfCoords)
      
  -- printNumberOfDuplicates
  tracingFieldUtil.printNumberOfDuplicates = {}
  
  function tracingFieldUtil.printNumberOfDuplicates.set(config, field, value)
    local res = isBoolean(value)
    if res then
      config.printNumberOfDuplicates = value
      if value then
        print("Prints number of noticed coordinate duplicates.")
      else
        print("Does not print number of noticed coordinate duplicates.")
      end
    end
    return res
  end
  
  tracingFieldUtil.printNumberOfDuplicates.help = [[
    
      "printNumberOfDuplicates"
      This value decides whether the number of all noticed coordinate duplicates should be printed.
      
          false                     does not print number
          true                      print number of all noticed coordinate duplicates
          
      Default: ]] .. tostring(DefaultTracing.printNumberOfDuplicates)
      
  -- printDuplicates
  tracingFieldUtil.printDuplicates = {}
  
  function tracingFieldUtil.printDuplicates.set(config, field, value)
    local res = isBoolean(value)
    if res then
      config.printDuplicates = value
      if value then
        config.printNumberOfDuplicates = true
        print("Print all coordinate duplicate information.")
      else
        print("Does not print all noticed coordinate duplicates.")
      end
    end
    return res
  end
  
  tracingFieldUtil.printDuplicates.help = [[
    
      "printDuplicates"
      This value decides whether all noticed coordinate duplicates should be printed.
      Since the printing takes place during the counting, setting this to "true" will also
      activate "printNumberOfDuplicates".
      Setting it to "false" however will not deactivate "printNumberOfDuplicates".
      
      
          false                     do not print all noticed coordinate duplicates
          true                      print all noticed coordinate duplicates
          
      Default: ]] .. tostring(DefaultTracing.printDuplicates)
      
  -- devourCoords
  tracingFieldUtil.devourCoords = {}
  
  function tracingFieldUtil.devourCoords.set(config, field, value)
    local res = isBoolean(value)
    if res then
      config.devourCoords = value
      if value then
        print("Received coordinates are removed.")
      else
        print("Received coordinates are passed on.")
      end
    end
    return res
  end
  
  tracingFieldUtil.devourCoords.help = [[
    
      "devourCoords"
      This value decides whether to delete all coordinates from the pipeline after the check or not.
    
          false                     keep the coordinates
          true                      delete all coordinates
          
      Default: ]] .. tostring(DefaultTracing.devourCoords)


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


mirror = ConfigConstructor.newMirrorConfig{ active = true }

-- @TheRedDaemon: Second mirror. Sends table with from default deviating value.
mirror2 = ConfigConstructor.newMirrorConfig()

spray = ConfigConstructor.newSprayConfig()

shape = ConfigConstructor.newShapeConfig()

shape2 = ConfigConstructor.newShapeConfig()

rotation = ConfigConstructor.newRotationMirrorConfig()

tracing = ConfigConstructor.newTracingConfig()

tracing2 = ConfigConstructor.newTracingConfig{ tracingName = "Tracing 2" }


--[[
  Coordinate modification order
  
  Lua was seemingly not able to add global function refs at the start (before definition?).
  So the array and it's values are created here.

  @TheRedDaemon
]]--
ACTIVE_TRANSFORMATIONS = {
  tracing       ,           -- 1. check some stuff
  shape         ,           -- 2. draw shape
  spray         ,           -- 3. mess it up
  shape2        ,           -- 4. maybe create more complex shape
  rotation      ,           -- 5. mirror using rotation
  mirror        ,           -- 6. mirror
  mirror2       ,           -- 7. second mirror
  tracing2      ,           -- 8. check stuff again
}