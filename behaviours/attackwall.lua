AttackWall = Class(BehaviourNode, function(self, inst)
    BehaviourNode._ctor(self, "AttackWall")
    self.inst = inst
end)

function AttackWall:__tostring()
    return string.format("target %s", tostring(self.target))
end

function AttackWall:Visit()
    
    if self.status == READY then
        
        local radius = 1.5 + (self.inst.Physics and self.inst.Physics:GetRadius() or 0)
		self.target = FindEntity(self.inst, radius, 
			function(guy) -- 为什么叫guy？是coder犯二了么。。。
				if guy:HasTag("wall") and self.inst.components.combat:CanTarget(guy) then
					local angle = anglediff(self.inst.Transform:GetRotation(), self.inst:GetAngleToPoint(Vector3(guy.Transform:GetWorldPosition() )))
					return math.abs(angle) < 30
				end
				
			end)
     
		if self.target then
			self.status = RUNNING
			self.inst.components.locomotor:Stop()
			self.done = false
		else
			self.status = FAILED
		end
		
    end

    if self.status == RUNNING then
        --local is_attacking = self.inst.sg:HasStateTag("attack")
        if not self.target or not self.target.entity:IsValid() or (self.target.components.health and self.target.components.health:IsDead())then
            self.status = FAILED
            self.inst.components.locomotor:Stop()
        else
			if self.inst.components.combat:TryAttack(self.target) then
				self.status = SUCCESS
			else
				self.status = FAILED
			end
			self:Sleep(1)
        end
    end
end
