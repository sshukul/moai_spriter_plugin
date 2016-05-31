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

local function createAnim ( self, name, x, y, scaleX, scaleY, reverseFlag, noSound )
  local layerSize = 9;

  local player = MOAIAnim.new ()
  player:reserveLinks ( (#self.curves[name] * layerSize) )
  
  local root = MOAITransform.new ()
  local props = {}
  
  for i, curveSet in orderedPairs ( self.curves[name] ) do
    local prop = MOAIProp2D.new ()
    prop:setParent ( root )
    prop:setDeck ( self.texture )
    prop:setPriority( curveSet.priority )      
    --prop:setBlendMode( MOAIProp.GL_SRC_ALPHA, MOAIProp.GL_ONE_MINUS_SRC_ALPHA )
    if curveSet.name ~= nil and curveSet.name ~= "" then
      prop.name = curveSet.name
    else
      prop.name = curveSet.id.name
    end
    
    self.scaleX = 1
    self.scaleY = 1
        
    local c = ( i - 1 ) * layerSize
    player:setLink ( c + 1, curveSet.id, prop, MOAIProp2D.ATTR_INDEX )
    player:setLink ( c + 2, curveSet.x, prop, MOAITransform.ATTR_X_LOC )
    player:setLink ( c + 3, curveSet.y, prop, MOAITransform.ATTR_Y_LOC )
    player:setLink ( c + 4, curveSet.r, prop, MOAITransform.ATTR_Z_ROT )
    player:setLink ( c + 5, curveSet.xs, prop, MOAITransform.ATTR_X_SCL )
    player:setLink ( c + 6, curveSet.ys, prop, MOAITransform.ATTR_Y_SCL )
    player:setLink ( c + 7, curveSet.px, prop, MOAITransform.ATTR_X_PIV )
    player:setLink ( c + 8, curveSet.py, prop, MOAITransform.ATTR_Y_PIV )
    player:setLink ( c + 9, curveSet.a, prop, MOAIColor.ATTR_A_COL )
    player:setCurve(curveSet.id)
    table.insert ( props, i, prop )
  end
  table.sort(props, comparePropPriorities)
  if reverseFlag then
    player:setMode(MOAITimer.LOOP_REVERSE)
  else
    player:setMode(MOAITimer.LOOP)
  end

  if scaleX and scaleY then
      root:setScl(scaleX, scaleY)
  end
  if x and y then
      root:setLoc(x, y)
  end
  player.root = root
  player.props = props
  
  player.insertProps = insertProps
  player.insertPropsRN = insertPropsRN
  player.removeProps = removeProps
  
  player:apply ( 0 )
  
  if noSound == nil or noSound == false then
    local keyFrameFunc = function ()
      local animCurves = self.curves[name]
      for i=1, table.getn(animCurves) do
        local curveSet = animCurves[i]
        local currentZIndex = curveSet.z:getValueAtTime(player:getTime())
        local prevZIndex = currentZIndex
        for j=1, table.getn(curveSet.frameTimes) do
          if curveSet.frameTimes[j] >= player:getTime() then
            if j > 2 then
              prevZIndex = curveSet.z:getValueAtTime(curveSet.frameTimes[j-2])
            else
              prevZIndex = curveSet.z:getValueAtTime(curveSet.frameTimes[table.getn(curveSet.frameTimes)])
            end
            break
          end
        end
        if currentZIndex ~= prevZIndex then
          for j, prop in ipairs ( player.props ) do
            if prop.name == curveSet.name then
              prop:setPriority(player.basePriority + currentZIndex)
            end
          end
        end
      end
      local animSounds = self.sounds[name]  
      if animSounds ~= nil then      
        --print_r(animSounds)
        for soundName, soundline in pairs ( animSounds ) do
          for i=1, table.getn(soundline) do
            local timeDiff = player:getTime()*1000 - soundline[i].time
            if timeDiff < 15 and timeDiff > 0 then
              
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
    player.keyFrameFunc = keyFrameFunc
    -- If you add another listener for EVENT_TIMER_KEYFRAME, don't forget to 
    -- add a call to player.keyFrameFunc() at the end if you want sounds and z-index
    -- changes to work
    player:setListener(MOAITimer.EVENT_TIMER_KEYFRAME, keyFrameFunc)
  end
  
  return player
end

function playSound(audioFileName)
  local sound = MOAIUntzSound.new()
  sound:load(audioFileName)   
  sound:setLooping(false)
  sound:play()
end

function spriter(filename, deck, names)
  local anims = dofile ( filename )
  local curves = {}
  local texture = deck
  local meta = {}
  local sounds = {}
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
    for i, object in orderedPairs ( objects ) do
      local numKeys = #object
      
      -- Texture ID
      local idCurve = MOAIAnimCurve.new ()
      idCurve:reserveKeys ( numKeys )

      -- Location
      local xCurve = MOAIAnimCurve.new ()
      xCurve:reserveKeys ( numKeys )

      local yCurve = MOAIAnimCurve.new ()
      yCurve:reserveKeys ( numKeys )

      -- Z-Index
      local zCurve = MOAIAnimCurve.new ()
      zCurve:reserveKeys ( numKeys )  

      -- Rotation
      local rCurve = MOAIAnimCurve.new ()
      rCurve:reserveKeys ( numKeys )

      -- Scale
      local sxCurve = MOAIAnimCurve.new ()
      sxCurve:reserveKeys ( numKeys )

      local syCurve = MOAIAnimCurve.new ()
      syCurve:reserveKeys ( numKeys )

      -- Alpha
      local aCurve = MOAIAnimCurve.new ()
      aCurve:reserveKeys ( numKeys )

      -- Pivot
      local pxCurve = MOAIAnimCurve.new ()
      pxCurve:reserveKeys ( numKeys )

      local pyCurve = MOAIAnimCurve.new ()
      pyCurve:reserveKeys ( numKeys )

      local prevTexture = nil
      local prevFrame = nil
      local name = nil
      local frameTimes = {}
      for ii, frame in orderedPairs ( object ) do
        time = frame.time / 1000
        table.insert(frameTimes, time)
        
        if frame.name then
          name = frame.name
        end
        idCurve:setKey ( ii, time, names[frame.texture], MOAIEaseType.FLAT)
        idCurve.name = frame.texture
        xCurve:setKey  ( ii, time, frame.x, MOAIEaseType.LINEAR)
        yCurve:setKey  ( ii, time, frame.y, MOAIEaseType.LINEAR)
        zCurve:setKey  ( ii, time, frame.zindex, MOAIEaseType.FLAT)

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

        rCurve:setKey  ( ii, time, frame.angleWithSpin, MOAIEaseType.LINEAR)                    
        sxCurve:setKey ( ii, time, frame.scale_x, MOAIEaseType.LINEAR)
        syCurve:setKey ( ii, time, frame.scale_y, MOAIEaseType.LINEAR)
        aCurve:setKey ( ii, time, frame.alpha, MOAIEaseType.LINEAR)
        pxCurve:setKey ( ii, time, frame.pivot_x, MOAIEaseType.LINEAR )
        pyCurve:setKey ( ii, time, frame.pivot_y, MOAIEaseType.LINEAR )
        prevTexture = frame.texture
        prevFrame = frame
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