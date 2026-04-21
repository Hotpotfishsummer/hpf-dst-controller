local ARRIVE_STEP = .15 -- Original value inaccessible

AddComponentPostInit("locomotor", function(self)

  -- Cleans up the locomotor if necessary
  local CleanupLocomotorNow = function()
    self:Stop()
    GLOBAL.ThePlayer:EnableMovementPrediction(false)
  end

  -- Cleans up the locomotor if necessary
  local CleanupLocomotorLater = function(self)
    -- Cleanup later to avoid rubber-banding
    self.trailblazerCleanupLater = true
    -- Do not clean up now
    self.trailblazerCleanupClear = nil

    -- Cleanup, but only if the locomotor is not pathfinding
    killTask = function()
      if self.dest == nil then
        if self.trailblazerCleanupLater == true then
          CleanupLocomotorNow()
        end
      else
        GLOBAL.ThePlayer:DoTaskInTime(1.5, killTask)
      end
    end

    GLOBAL.ThePlayer:DoTaskInTime(1.5, killTask)
  end

  -- Clear Override
  local _Clear = self.Clear
  self.Clear = function(self)
    if self.trailblazerCleanupClear then
      CleanupLocomotorLater(self)
    else
      _Clear(self)
    end
  end

  -- PreviewAction Override
  local _PreviewAction = self.PreviewAction
  self.PreviewAction = function(self, bufferedaction, run, try_instant)
    if bufferedaction == nil then
      return false
    end
    if bufferedaction.action == GLOBAL.ACTIONS.TRAILBLAZE then
      self.throttle = 1
      _Clear(self)
      self:Trailblaze(bufferedaction.pos, bufferedaction, run, disablePM)
    else
      return _PreviewAction(self, bufferedaction, run, try_instant) 
    end
  end
      
  -- PushAction Override
  local _PushAction = self.PushAction
  self.PushAction = function(self, bufferedaction, run, try_instant)
    if bufferedaction == nil then
      return
    end
    if bufferedaction.action == GLOBAL.ACTIONS.TRAILBLAZE then
  
      self.throttle = 1
      local success, reason = bufferedaction:TestForStart()
      if not success then
        self.inst:PushEvent("actionfailed", { action = bufferedaction, reason = reason })
        return
      end
      _Clear(self)
      self:Trailblaze(bufferedaction.pos, bufferedaction, run)
      if self.inst.components.playercontroller ~= nil then
       self.inst.components.playercontroller:OnRemoteBufferedAction()
      end
    else
      return _PushAction(self, bufferedaction, run, try_instant) 
    end
  end
  	
  -- Navigate to entity (Fix speedmult)
  local _GoToEntity = self.GoToEntity
  self.GoToEntity = function(self, inst, bufferedaction, run)
  	self.arrive_step_dist = ARRIVE_STEP
  	_GoToEntity(self, inst, bufferedaction, run)
  end
  	
  -- Navigate to point (Fix speedmult)
  local _GoToPoint = self.GoToPoint
  self.GoToPoint = function(self, pt, bufferedaction, run, overridedest)
  	self.arrive_step_dist = ARRIVE_STEP
  	_GoToPoint(self, pt, bufferedaction, run, overridedest)
  end
     
  -- Concurrent processing
  local trailblazer = GLOBAL.require("components/trailblazer")
  local trailblazerProcess = function(self, dest, run)
  	
    -- Path is not nil, process!
    if self.trailblazePath ~= nil then
      -- If path is finished
      if trailblazer.processPath(self.trailblazePath, 250) then
        -- If pathfinding was successful
        if self.trailblazePath.nativePath.steps ~= nil then
  				
          -- Populate pathfinding variables
  		    self.dest = dest
  		    self.throttle = 1
  
  			  self.arrive_step_dist = ARRIVE_STEP * self:GetSpeedMultiplier()
  			  self.wantstorun = run
  
  			  self.path = {}
  			  self.path.steps = self.trailblazePath.nativePath.steps
  			  self.path.currentstep = 2
  			  self.path.handle = nil
  				
  			  self.wantstomoveforward = true

          -- Register deferred cleanup if necessary
          if self.trailblazerCleanup == true then

            -- Cleanup on destination reached
            self.inst:ListenForEvent("onreachdestination", function() CleanupLocomotorLater(self) end)

            -- Cleanup if the path gets cleared (user strays)
            self.trailblazerCleanupClear = true

            -- Cleanup scheduled, do not cleanup now
            self.trailblazerCleanup = nil
          end

  		    self:StartUpdatingInternal()

        -- If pathfinding was unsuccessful
        else
  			  self:Stop()
  		  end
  			self.trailblazePath = nil
      end
    end

    -- Path is no longer wanted (or may be complete)  		
  	if self.trailblazePath == nil then
      self.trailblazeTask:Cancel()
  		self.trailblazeTask = nil

      if self.trailblazerCleanup then
        CleanupLocomotorNow()
      end
  	end
  end
  	
  -- Pathfind via custom algorithm
  self.Trailblaze = function(self, pt, bufferedaction, run, disablePM)
    local dest = {}
    if GLOBAL.CurrentRelease.GreaterOrEqualTo( ReleaseID.R08_ROT_TURNOFTIDES ) then
      dest = GLOBAL.Dest(overridedest, nil, bufferedaction)
    else
      dest = GLOBAL.Dest(overridedest, pt)
    end    

  	if self.trailblazeTask ~= nil then
    	self.trailblazeTask:Cancel()
  		self.trailblazeTask = nil
  	end
  	
  	local p0 = GLOBAL.Vector3(self.inst.Transform:GetWorldPosition())
  	local p1 = GLOBAL.Vector3(dest:GetPoint())
  	
  	self.trailblazePath = trailblazer.requestPath(p0, p1, self.pathcaps)
  	self.trailblazeTask = self.inst:DoPeriodicTask(0, function() trailblazerProcess(self, dest, run) end)
  end
end)

-- Register trailblaze action (can be submitted to locomotor just like WALKTO; uses custom pathfinding algorithm)
AddAction("TRAILBLAZE", "Travel via Trailblaze", function(act) end)
