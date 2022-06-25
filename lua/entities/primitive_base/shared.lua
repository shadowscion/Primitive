
----
DEFINE_BASECLASS("base_anim")

ENT.PrintName = "primitive_base"
ENT.RenderGroup = RENDERGROUP_BOTH
ENT.AdminOnly = true
ENT.Editable_primitive_ = true

---- FOR OVERRIDE
ENT._primitive_SafeValues = {}

function ENT:_primitive_Setup()
end

function ENT:_primitive_SetupDataTables()
end

function ENT:_primitive_OnNotify(name, old, new)
end

function ENT:_primitive_OnUpdate() -- return construct
	return nil
end

function ENT:_primitive_PostUpdate()
end

function ENT:_primitive_GetUsedValues()
end

if SERVER then
	function ENT:_primitive_OnEdited(key, val)
	end
end

----
function ENT:SetupDataTables()
	self:_primitive_NetworkVar("Bool", 0, "debug_hitbox", {global = true, order = 10000, title = "Hitbox", category = "Debug Overlays", type = "Boolean"}, self._primitive_NotifyDebug)
	self:_primitive_NetworkVar("Bool", 1, "debug_vertex", {global = true, order = 10001, title = "Vertex", category = "Debug Overlays", type = "Boolean"}, self._primitive_NotifyDebug)
	self:_primitive_NetworkVar("Bool", 2, "debug_physics", {global = true, order = 10002, title = "Physics", category = "Debug Overlays", type = "Boolean"}, self._primitive_NotifyDebug)

	self:_primitive_SetupDataTables()
	self._primitive_UpdateTime = SysTime()
end

function ENT:_primitive_NetworkVar(type, id, key, edit, callback)
	local name = "_primitive_" .. key

	-- if edit.type == "String" or edit.type == "Float" or edit.type == "Int" then
	-- 	edit.waitforenter = true
	-- end

	self:NetworkVar(type, id, name, {KeyName = name, Edit = edit})

	if isfunction(callback) then
		self:NetworkVarNotify(name, callback)
	elseif callback == true then
		self:NetworkVarNotify(name, self._primitive_Notify)
	end
end

function ENT:_primitive_Notify(name, old, new)
	if old == new then
		return
	end

	if isfunction(self._primitive_SafeValues[name]) then
		local val = self._primitive_SafeValues[name](self, new)
		if new ~= val then
			self["Set" .. name](self, val)
			return
		end
	end

	self:_primitive_OnNotify(name, old, new)
	self._primitive_UpdateTime = SysTime()
end

function ENT:_primitive_GetVars(args, match)
	if match == true then match = self:_primitive_GetUsedValues() end
	local args = istable(args) and args or self:GetNetworkVars()
	local ret = {}
	local rep = "_primitive_"
	for k, v in pairs(args) do
		if string.StartWith(k, rep) then
			local key = string.gsub(k, rep, "")
			if match then ret[key] = match[k] and v else ret[key] = v end
		end
	end
	return ret
end

----
function ENT:Think()
	if self._primitive_UpdateTime and SysTime() - self._primitive_UpdateTime > (g_primitive.update_delay or 0.015) then
		self._primitive_UpdateTime = nil

		if hook.Run("primitive.preUpdate", self) == false then
			return
		end

		self:_primitive_Update()
	end
end

----
function ENT:_primitive_Update()
	local primitive = self:_primitive_OnUpdate() or g_primitive.construct_get(nil, nil, false, CLIENT)

	if primitive.physics then
		self:_primitive_UpdatePhysics(primitive)
	end

	if CLIENT then
		self:_primitive_UpdateRender(primitive)

		local vars = self:_primitive_GetUsedValues()
		for k, v in pairs(self:GetEditingData()) do
			if not vars then v.enabled = true else
				v.enabled = (v.global or vars[k] ~= nil) and true or false
			end
		end
	end

	self:_primitive_PostUpdate()
end

---
function ENT:primitive_RestoreConstraints(constraints)
	if constraints and next(constraints) then
		timer.Simple(0, function()
			if not self:GetPhysicsObject():IsValid() then return end
			for _, constr in pairs(constraints) do
				local factory = duplicator.ConstraintType[constr.Type]
				if not factory then
					break
				end
				local args = {}
				for i = 1, #factory.Args do
					args[ i ] = constr[factory.Args[i]]
				end
				factory.Func(unpack(args))
			end
		end)
	end
end

function ENT:primitive_RestorePhysics(mass, physprops)
	local physicsObject = self:GetPhysicsObject()

	if mass then physicsObject:SetMass(mass) end
	if physprops then
		if physprops.Gravity ~= nil then physicsObject:EnableGravity(physprops.Gravity) end
		if physprops.Material ~= nil then physicsObject:SetMaterial(physprops.Material) end
	end

	physicsObject:EnableMotion(false)
	physicsObject:Sleep()
end

function ENT:_primitive_UpdatePhysics(primitive)
	local constraints, mass, physprops
	if SERVER then
		if self.EntityMods and self.EntityMods.mass then
			mass = self.EntityMods.mass.Mass
		else
			local physicsObject = self:GetPhysicsObject()
			if physicsObject and physicsObject:IsValid() then
				mass = physicsObject:GetMass()
			end
		end

		if self.BoneMods and self.BoneMods[0] then
			physprops = self.BoneMods[0].physprops
		end

		constraints = {}
		for _, v in pairs(constraint.GetTable(self)) do
			table.insert(constraints, v)
		end
		constraint.RemoveAll(self)
		self.ConstraintSystem = nil
	end

	local succ = self:PhysicsInitMultiConvex(primitive.physics) -- PhysicsFromMesh????
	if succ then
		self:EnableCustomCollisions(true)
	else
		self:PhysicsInit(SOLID_VPHYSICS)
		self:EnableCustomCollisions(false)
	end

	self:SetMoveType(MOVETYPE_VPHYSICS)
	self:SetSolid(SOLID_VPHYSICS)

	if SERVER then
		if hook.Run("primitive.updatePhysics", self, constraints, mass, physprops) ~= false then
			self:primitive_RestorePhysics(mass, physprops)
			self:primitive_RestoreConstraints(constraints)
		end
	end
end
