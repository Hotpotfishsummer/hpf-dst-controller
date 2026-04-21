local G = require("dst-controller/global")

local TrailblazerIntegration = {
    loaded = false,
}

function TrailblazerIntegration.Install()
    if TrailblazerIntegration.loaded then
        return true
    end

    if not G.AddComponentPostInit or not G.AddAction then
        print("[TrailblazerIntegration] Cannot load: mod environment is not ready")
        return false
    end

    local trailblazer = require("components/trailblazer")
    local ARRIVE_STEP = 0.15

    G.AddComponentPostInit("locomotor", function(self)
        local old_Clear = self.Clear
        local old_PreviewAction = self.PreviewAction
        local old_PushAction = self.PushAction
        local old_GoToEntity = self.GoToEntity
        local old_GoToPoint = self.GoToPoint

        local function TrailblazeProcess(locomotor, dest, run)
            if locomotor.trailblazePath ~= nil then
                if trailblazer.processPath(locomotor.trailblazePath, 250) then
                    if locomotor.trailblazePath.nativePath.steps ~= nil then
                        locomotor.dest = dest
                        locomotor.throttle = 1
                        locomotor.arrive_step_dist = ARRIVE_STEP * locomotor:GetSpeedMultiplier()
                        locomotor.wantstorun = run

                        locomotor.path = {}
                        locomotor.path.steps = locomotor.trailblazePath.nativePath.steps
                        locomotor.path.currentstep = 2
                        locomotor.path.handle = nil
                        locomotor.wantstomoveforward = true

                        locomotor:StartUpdatingInternal()
                    else
                        locomotor:Stop()
                    end

                    locomotor.trailblazePath = nil
                end
            end

            if locomotor.trailblazePath == nil and locomotor.trailblazeTask then
                locomotor.trailblazeTask:Cancel()
                locomotor.trailblazeTask = nil
            end
        end

        self.Clear = function(self)
            if self.trailblazeTask then
                self.trailblazeTask:Cancel()
                self.trailblazeTask = nil
            end
            if old_Clear then
                return old_Clear(self)
            end
        end

        self.PreviewAction = function(self, bufferedaction, run, try_instant)
            if bufferedaction and bufferedaction.action == G.ACTIONS.TRAILBLAZE then
                self.throttle = 1
                self:Trailblaze(bufferedaction.pos or bufferedaction.target, bufferedaction, run)
                return true
            end
            return old_PreviewAction(self, bufferedaction, run, try_instant)
        end

        self.PushAction = function(self, bufferedaction, run, try_instant)
            if bufferedaction and bufferedaction.action == G.ACTIONS.TRAILBLAZE then
                self.throttle = 1
                local success, reason = bufferedaction:TestForStart()
                if not success then
                    self.inst:PushEvent("actionfailed", { action = bufferedaction, reason = reason })
                    return
                end
                self:Trailblaze(bufferedaction.pos or bufferedaction.target, bufferedaction, run)
                if self.inst.components.playercontroller ~= nil then
                    self.inst.components.playercontroller:OnRemoteBufferedAction()
                end
                return
            end
            return old_PushAction(self, bufferedaction, run, try_instant)
        end

        self.GoToEntity = function(self, inst, bufferedaction, run)
            self.arrive_step_dist = ARRIVE_STEP
            return old_GoToEntity(self, inst, bufferedaction, run)
        end

        self.GoToPoint = function(self, pt, bufferedaction, run, overridedest)
            self.arrive_step_dist = ARRIVE_STEP
            return old_GoToPoint(self, pt, bufferedaction, run, overridedest)
        end

        self.Trailblaze = function(self, pt, bufferedaction, run)
            local point = pt
            if point == nil and bufferedaction ~= nil then
                point = bufferedaction.pos or bufferedaction.target
            end

            if point == nil then
                return
            end

            if self.trailblazeTask then
                self.trailblazeTask:Cancel()
                self.trailblazeTask = nil
            end

            local destination = nil
            if G.Dest then
                destination = G.Dest(nil, point, bufferedaction)
            end

            if destination == nil then
                destination = {
                    point = point,
                    IsValid = function()
                        return true
                    end,
                    GetPoint = function(dest_self)
                        local dest_point = dest_self.point
                        return dest_point.x, dest_point.y or 0, dest_point.z
                    end,
                }
            end

            local start_x, start_y, start_z = self.inst.Transform:GetWorldPosition()
            local p0 = G.Vector3(start_x, start_y, start_z)
            local p1 = G.Vector3(point.x, point.y or 0, point.z)

            self.trailblazePath = trailblazer.requestPath(p0, p1, self.pathcaps)
            self.trailblazeTask = self.inst:DoPeriodicTask(0, function()
                TrailblazeProcess(self, destination, run)
            end)
        end
    end)

    G.AddAction("TRAILBLAZE", "Travel via Trailblazer", function(act) end)

    TrailblazerIntegration.loaded = true
    print("[TrailblazerIntegration] Trailblazer backend loaded")
    return true
end

function TrailblazerIntegration.IsAvailable()
    if not TrailblazerIntegration.loaded then
        return false
    end

    local player = G.ThePlayer
    local locomotor = player and player.components and player.components.locomotor
    return locomotor ~= nil and locomotor.Trailblaze ~= nil
end

return TrailblazerIntegration