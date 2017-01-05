-- 
--  spriter.lua
--  sprinter-moai
--  
--  Created by Jon Baker on 2012-11-09.
--  Extended by Saurabh Shukul
--  Distributed under MPL-2.0 licence (http://opensource.org/licenses/MPL-2.0)
-- 

local texture
local curves = {}

local function insertProps ( self, layer )
  self.basePriority = nil
  for i, v in ipairs ( self.props ) do
    layer:insertProp ( v )
    if self.basePriority == nil then
      self.basePriority = v:getPriority()
    end
  end
end

-- This convenience function is added here for anyone using the 
-- RapaNui framework in combination with Moai SDK
local function insertPropsRN ( self , highestPriority )
  self.rnprops = {}
  self.basePriority = nil
  for i, v in ipairs ( self.props ) do
    o = RNObject.new()
    o.prop = v
    o.prop.name = v.name
    o.prop:setIndex(1)
    if highestPriority ~= nil then
      highestPriority = highestPriority + 1
      o.prop:setPriority(highestPriority)
      if self.basePriority == nil then
        self.basePriority = highestPriority
      end
    end
    o:setLocatingMode(CENTERED_MODE)
    o.isAnim = true
    local parentGroup = RNFactory.mainGroup

    RNFactory.screen:addRNObject(o)
    table.insert ( self.rnprops, i, o )
  end
  return highestPriority
end

function table.contains(table, element)
  if table ~= nil then
    for _, value in pairs(table) do
      if type(value) == 'table' or type(element) == 'table' then
        if table.equals(value, element) then
         return true
        end
      elseif value == element then
        return true
      end
    end
  end
  return false
end

local function removeProps ( self, layer )
  for i, v in ipairs ( self.props ) do
    layer:removeProp ( v )
  end
end

function comparePropPriorities(a,b)
  if b == nil or b:getPriority() == nil then
    return false
  elseif a == nil or a:getPriority() == nil then
    return true
  else 
    return a:getPriority() < b:getPriority()
  end
end

local function createAnim ( self, name, x, y, scaleX, scaleY, reverseFlag, noSound, noAlpha, objectsToSkip )
  local layerSize = 12;
  if noAlpha then
    layerSize = 8
  end

  local spriterAnim = MOAIAnim.new ()
  spriterAnim:reserveLinks ( (#self.curves[name] * layerSize) )
  
  local root = MOAITransform.new ()
  local props = {}

  local numSkippedObjects = 0
  local idCurveWithMostKeyframes = nil;
  for i, curveSet in orderedPairs ( self.curves[name] ) do
    local objectName
    if curveSet.name ~= nil and curveSet.name ~= "" then
      objectName = curveSet.name
    else
      objectName = curveSet.id.name
    end
    
    -- Don't render objects specifically told to skip. This could be used for 
    -- example when creating shadows of sprites using the same sprite object
    -- but skipping certain elements that should cast shadows like sprite FX, particles etc.
    if objectsToSkip == nil or not table.contains(objectsToSkip, objectName) then    
      local prop = MOAIProp.new ()
      prop.name = objectName
      prop:setParent ( root )
      prop:setDeck ( self.texture )
      prop:setPriority( curveSet.priority )      
      --prop:setBlendMode( MOAIProp.GL_ALPHA, MOAIProp.GL_ONE_MINUS_SRC_ALPHA )    
      prop.texture = curveSet.id.name
      
      self.scaleX = 1
      self.scaleY = 1
          
      local c = ( i - 1 ) * layerSize
      spriterAnim:setLink ( c + 1, curveSet.id, prop, MOAIProp.ATTR_INDEX )
      spriterAnim:setLink ( c + 2, curveSet.x, prop, MOAITransform.ATTR_X_LOC )
      spriterAnim:setLink ( c + 3, curveSet.y, prop, MOAITransform.ATTR_Y_LOC )
      spriterAnim:setLink ( c + 4, curveSet.r, prop, MOAITransform.ATTR_Z_ROT )
      spriterAnim:setLink ( c + 5, curveSet.xs, prop, MOAITransform.ATTR_X_SCL )
      spriterAnim:setLink ( c + 6, curveSet.ys, prop, MOAITransform.ATTR_Y_SCL )
      spriterAnim:setLink ( c + 7, curveSet.px, prop, MOAITransform.ATTR_X_PIV )
      spriterAnim:setLink ( c + 8, curveSet.py, prop, MOAITransform.ATTR_Y_PIV )
      
      -- Use the noAlpha flag for sprites where you are manipulating the color 
      -- manually, for example setting color black for shadows, as premultiplied
      -- alpha manipulation will overrwrite that. hasAlpha detects if a sprite
      -- has alpha changes or not and skips alpha manipulation in those cases
      if (noAlpha == nil or noAlpha == false) then
        -- Moai uses premultiplied alpha, 
        -- so we should multiply every color component by alpha value
        spriterAnim:setLink ( c + 9, curveSet.a, prop, MOAIColor.ATTR_A_COL )
        spriterAnim:setLink ( c + 10, curveSet.a, prop, MOAIColor.ATTR_B_COL )
        spriterAnim:setLink ( c + 11, curveSet.a, prop, MOAIColor.ATTR_G_COL )
        spriterAnim:setLink ( c + 12, curveSet.a, prop, MOAIColor.ATTR_R_COL )
      end
      
      if idCurveWithMostKeyframes == nil or curveSet.id.numKeys > idCurveWithMostKeyframes.numKeys then
        idCurveWithMostKeyframes = curveSet.id
      end
      table.insert ( props, i - numSkippedObjects, prop )
    else
      numSkippedObjects = numSkippedObjects + 1
    end    
  end
  spriterAnim:setCurve(idCurveWithMostKeyframes)
  table.sort(props, comparePropPriorities)
  if reverseFlag then
    spriterAnim:setMode(MOAITimer.LOOP_REVERSE)
  else
    spriterAnim:setMode(MOAITimer.LOOP)
  end

  if scaleX and scaleY then
      root:setScl(scaleX, scaleY)
  end
  if x and y then
      root:setLoc(x, y)
  end
  spriterAnim.root = root
  spriterAnim.props = props
  
  spriterAnim.insertProps = insertProps
  spriterAnim.insertPropsRN = insertPropsRN
  spriterAnim.removeProps = removeProps
  
  spriterAnim:apply ( 0 )
  
  if noSound == nil or noSound == false then
    local keyFrameFunc = function ()
      local animCurves = self.curves[name]
      for i=1, table.getn(animCurves) do
        local curveSet = animCurves[i]
        local endTime = curveSet.frameTimes[table.getn(curveSet.frameTimes)]
        local curTime = spriterAnim:getTime()
        if curTime > endTime then
          curTime = endTime
        end
        local currentZIndex = curveSet.z:getValueAtTime(curTime)
        local prevZIndex = currentZIndex
        for j=1, table.getn(curveSet.frameTimes) do
          if curveSet.frameTimes[j] >= spriterAnim:getTime() then
            if j > 2 then
              prevZIndex = curveSet.z:getValueAtTime(curveSet.frameTimes[j-2])
            else
              prevZIndex = curveSet.z:getValueAtTime(curveSet.frameTimes[table.getn(curveSet.frameTimes)])
            end
            break
          end
        end
        if currentZIndex ~= prevZIndex then
          for j, prop in ipairs ( spriterAnim.props ) do
            if prop.name == curveSet.name then
              prop:setPriority(spriterAnim.basePriority + currentZIndex)
            end
          end
        end
      end
      local animSounds = self.sounds[name]  
      if animSounds ~= nil then      
        for soundName, soundline in pairs ( animSounds ) do
          for i=1, table.getn(soundline) do
            local timeDiff = spriterAnim:getTime()*1000 - soundline[i].time
            if timeDiff < 20 and timeDiff > 0 then
              -- You can define an override function called spriterPlaySoundOverride in you own game logic
              -- if you want to do clever things like rewriting the sound file path
              -- or playing custom sounds at run time based on the scene 
              -- (eg: replacing "footstep.wav" with "audio/footstep_beach.ogg" or something)
              if spriterPlaySoundOverride ~= nil then
                spriterPlaySoundOverride(soundline[i].sound)
              else
                playSound(soundline[i].sound)
              end
            end
          end
        end
      end
    end
    spriterAnim.keyFrameFunc = keyFrameFunc
    -- If you add another listener for EVENT_TIMER_KEYFRAME, don't forget to 
    -- add a call to spriterAnim.keyFrameFunc() at the end if you want sounds and z-index
    -- changes to work
    spriterAnim:setListener(MOAITimer.EVENT_TIMER_KEYFRAME, keyFrameFunc)
  end
  
  return spriterAnim
end

function playSound(audioFileName)
  local sound = MOAIUntzSound.new()
  sound:load(audioFileName)   
  sound:setLooping(false)
  sound:play()
end

-- char_maps_to_apply is optional, only if you want to apply character maps
function spriter(filename, deck, names, char_maps_to_apply)
  local anims, charMaps = dofile ( filename )
  local curves = {}
  local texture = deck
  local meta = {}
  local sounds = {}
  local charMapsArr = {}
  
  -- If we are applying any character maps, fetch and combine all of them into one
  if char_maps_to_apply then
    for i, charMapName in pairs ( char_maps_to_apply ) do
      local charMap = charMaps[charMapName]
      if charMap then
        for j=1, table.getn(charMap) do
          table.insert(charMapsArr, charMap[j])
        end
      end
    end
  end
  
  for animName, animData in orderedPairs ( anims ) do
    --print("\n\nAdding animation " .. anim .. "\n\n")
    
    local objects = animData['objects']
    if animData['meta'] ~= nil then
      local animMeta = {}
      animMeta['anim'] = animName
      animMeta['meta'] = animData['meta']
      table.insert(meta, animMeta)
    end
    if animData['sounds'] ~= nil then
      sounds[animName] = animData['sounds']
    end
    
    local animCurves = {}
    local frameTimes = {}
    for i, object in orderedPairs ( objects ) do
      local numKeys = #object
      
      -- extraKeys is used to insert two extra curve keys at frame at time 0 and right before
      -- the first appearance, for objects that appear mid timeline without being in the 
      -- animation from the beginning
      local extraKeys = 0
      if object[1].time ~= 0 then
        extraKeys = 2
      end
      
      -- Texture ID
      local idCurve = MOAIAnimCurve.new ()
      idCurve:reserveKeys ( numKeys + extraKeys)
      idCurve.numKeys = numKeys

      -- Location
      local xCurve = MOAIAnimCurve.new ()
      xCurve:reserveKeys ( numKeys + extraKeys)

      local yCurve = MOAIAnimCurve.new ()
      yCurve:reserveKeys ( numKeys + extraKeys)

      -- Z-Index
      local zCurve = MOAIAnimCurve.new ()
      zCurve:reserveKeys ( numKeys + extraKeys)  

      -- Rotation
      local rCurve = MOAIAnimCurve.new ()
      rCurve:reserveKeys ( numKeys + extraKeys)

      -- Scale
      local sxCurve = MOAIAnimCurve.new ()
      sxCurve:reserveKeys ( numKeys + extraKeys)

      local syCurve = MOAIAnimCurve.new ()
      syCurve:reserveKeys ( numKeys + extraKeys)

      -- Alpha
      local aCurve = MOAIAnimCurve.new ()
      aCurve:reserveKeys ( numKeys + extraKeys)

      -- Pivot
      local pxCurve = MOAIAnimCurve.new ()
      pxCurve:reserveKeys ( numKeys + extraKeys)

      local pyCurve = MOAIAnimCurve.new ()
      pyCurve:reserveKeys ( numKeys + extraKeys)

      local prevTexture = nil
      local prevFrame = nil
      local name = nil
      local counterExtraFrame = 0
      for ii, frame in orderedPairs ( object ) do
        local time = frame.time / 1000
        local repeatIterations = 1
        local repeatTime = 0
        -- counterExtraFrame is used to insert an extra starting frame at time 0 and right before
        -- the first appearance, for objects that appear mid timeline without being in the 
        -- animation from the beginning
        if ii == 1 and time ~= 0 then
          table.insert(frameTimes, 0)
          table.insert(frameTimes, time - .2)
          repeatIterations = 3    
          repeatTime = time
          time = 0
        end
        if not table.contains(frameTimes, time) then
          table.insert(frameTimes, time)
        end
        
        if frame.name then
          name = frame.name
        end
        
        local texture = frame.texture 
        for j=1, table.getn(charMapsArr) do
          local map = charMapsArr[j]
          if texture == map.file then 
            if map.target_file then
              texture = map.target_file
            else
              texture = nil
            end
          end
        end
        
        for j=1, repeatIterations do 
          if repeatTime ~= 0 then
            if j < 3 then
              frame.alpha = 0
            end            
          end
          if texture then 
            idCurve:setKey ( ii+counterExtraFrame, time, names[texture], MOAIEaseType.FLAT)
            idCurve.name = texture
          else 
            idCurve:setKey ( ii+counterExtraFrame, time, -1, MOAIEaseType.FLAT)
            idCurve.name = ""
          end
          
          local easeType = MOAIEaseType.LINEAR
          
          if frame.curve_type ~= nil then
            if frame.curve_type == "quadratic" then
              if frame.c1 <= .5 then
                easeType = MOAIEaseType.SOFT_EASE_OUT
              else
                easeType = MOAIEaseType.SOFT_EASE_IN
              end
            elseif frame.curve_type == "quartic" then
              if frame.c1 <= .5 and frame.c2 <= .5 and frame.c3 <= .5 then
                easeType = MOAIEaseType.EASE_OUT
              elseif frame.c1 >= .5 and frame.c2 >= .5 and frame.c3 >= .5 then
                easeType = MOAIEaseType.EASE_IN
              else
                easeType = MOAIEaseType.SMOOTH
              end
            end
          end
          xCurve:setKey  ( ii+counterExtraFrame, time, frame.x, easeType)
          yCurve:setKey  ( ii+counterExtraFrame, time, frame.y, easeType)
          zCurve:setKey  ( ii+counterExtraFrame, time, frame.zindex, MOAIEaseType.FLAT)

          frame.angleWithSpin = frame.angle
          if prevFrame ~= nil then
            if frame.angle < prevFrame.angle and prevFrame.spin == 1 then
              frame.angleWithSpin = frame.angle + 360
            elseif frame.angle > prevFrame.angle and prevFrame.spin == -1 then
              frame.angleWithSpin = frame.angle - 360
            end
            
            if prevFrame.angleWithSpin >= 360 and prevFrame.angle < 360 then
              local numRotations = math.floor(math.abs(prevFrame.angleWithSpin / 360))
              if numRotations == 0 then
                numRotations = 1
              end
              frame.angleWithSpin = frame.angleWithSpin + (360 * numRotations)
            elseif prevFrame.angleWithSpin <= 0 and prevFrame.angle > 0 then
              local numRotations = math.floor(math.abs(prevFrame.angleWithSpin / 360)) + 1
              frame.angleWithSpin = frame.angleWithSpin - (360 * numRotations)
            end
          end
          if frame.alpha == nil then
            frame.alpha = 1
          end

          rCurve:setKey  ( ii+counterExtraFrame, time, frame.angleWithSpin, easeType)                    
          sxCurve:setKey ( ii+counterExtraFrame, time, frame.scale_x, easeType)
          syCurve:setKey ( ii+counterExtraFrame, time, frame.scale_y, easeType)
          aCurve:setKey ( ii+counterExtraFrame, time, frame.alpha, easeType)
          pxCurve:setKey ( ii+counterExtraFrame, time, frame.pivot_x, easeType )
          pyCurve:setKey ( ii+counterExtraFrame, time, frame.pivot_y, easeType )
          prevTexture = texture
          prevFrame = frame          
          if repeatTime ~= 0 then            
            if j == 1 then
              time = repeatTime - .2
            else 
              time = repeatTime
              repeatTime = 0
            end
            counterExtraFrame = counterExtraFrame + 1
          end
        end
      end

      local curveSet = {}

      curveSet.id = idCurve
      curveSet.x = xCurve
      curveSet.y = yCurve
      curveSet.z = zCurve
      curveSet.r = rCurve
      curveSet.xs = sxCurve
      curveSet.ys = syCurve
      curveSet.a = aCurve
      curveSet.px = pxCurve
      curveSet.py = pyCurve
      curveSet.priority = object[1].zindex
      curveSet.name = name
      curveSet.frameTimes = frameTimes
      table.insert ( animCurves, i, curveSet )            
    end
    curves[animName] = animCurves
  end
  local sprite = {}
  sprite.curves = curves
  sprite.texture = texture
  sprite.createAnim = createAnim
  sprite.name = name
  sprite.sounds = sounds

  return sprite, meta
end

-- Helper function for animation level tags
function getAnimTagsAtTime(meta, anim_name, time)
  for i=1, table.getn(meta) do
    local anim = meta[i]['anim']
    local animMeta = meta[i]['meta']
    if anim == anim_name then
      local tagline = animMeta['tags']
      if tagline ~= nil then
        local prevTags = nil
        for tagline_time, tags in orderedPairs ( tagline ) do
          if tagline_time == time then
            return tags
          elseif tagline_time > time then
            return prevTags
          else 
            prevTags = tags
          end
        end
        return prevTags
      end
    end
  end
  return nil
end
  
-- Helper function for animation level tags
function animHasTagAtTime(meta, anim_name, time, tag_name) 
  local tags = getAnimTagsAtTime(meta, anim_name, time)
  for i, tag in orderedPairs ( tags ) do
    if tag == tag_name then
      return true
    end 
  end
  return false
end

-- Helper function for action / spawn points
function getPointLocAndAngle(anim, point_name) 
  for i, prop in pairs ( anim.props ) do
    if prop.name == point_name then 
      local pointx, pointy = prop:getLoc()
      return pointx, pointy, prop:getRot()
    end
  end
end