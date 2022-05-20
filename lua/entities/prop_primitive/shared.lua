

----------------------------------------------------------------
DEFINE_BASECLASS("base_anim")

ENT.PrintName = "Primitive"

cleanup.Register("prop_primitive")


----------------------------------------------------------------
local shape_generic = {
	["_primitive_dbg"] = false,

	["_primitive_type"] = "cube",
	["_primitive_dx"] = 48,
	["_primitive_dy"] = 48,
	["_primitive_dz"] = 48,
	["_primitive_dt"] = 4,
	["_primitive_maxseg"] = 16,
	["_primitive_numseg"] = 16,
	["_primitive_numring"] = 8,
	["_primitive_tx"] = 0,
	["_primitive_ty"] = 0,
}

local shape_typevars = {}

shape_typevars["cube"] = {
	["_primitive_type"] = "cube",
	["_primitive_dx"] = 48,
	["_primitive_dy"] = 48,
	["_primitive_dz"] = 48,
	["_primitive_tx"] = 0,
	["_primitive_ty"] = 0,
}
shape_typevars["wedge"] = {
	["_primitive_type"] = "wedge",
	["_primitive_dx"] = 48,
	["_primitive_dy"] = 48,
	["_primitive_dz"] = 48,
	["_primitive_tx"] = 0.5,
	["_primitive_ty"] = 0,
}
shape_typevars["wedge_corner"] = {
	["_primitive_type"] = "wedge_corner",
	["_primitive_dx"] = 48,
	["_primitive_dy"] = 48,
	["_primitive_dz"] = 48,
	["_primitive_tx"] = 0.5,
	["_primitive_ty"] = 0,
}
shape_typevars["pyramid"] = {
	["_primitive_type"] = "pyramid",
	["_primitive_dx"] = 48,
	["_primitive_dy"] = 48,
	["_primitive_dz"] = 48,
	["_primitive_tx"] = 0,
	["_primitive_ty"] = 0,
}
shape_typevars["cylinder"] = {
	["_primitive_type"] = "cylinder",
	["_primitive_dx"] = 48,
	["_primitive_dy"] = 48,
	["_primitive_dz"] = 48,
	["_primitive_dt"] = 4,
	["_primitive_maxseg"] = 16,
	["_primitive_numseg"] = 16,
	["_primitive_tx"] = 0,
	["_primitive_ty"] = 0,
}
shape_typevars["cone"] = {
	["_primitive_type"] = "cone",
	["_primitive_dx"] = 48,
	["_primitive_dy"] = 48,
	["_primitive_dz"] = 48,
	["_primitive_maxseg"] = 16,
	["_primitive_numseg"] = 16,
	["_primitive_tx"] = 0,
	["_primitive_ty"] = 0,
}
shape_typevars["tube"] = {
	["_primitive_type"] = "tube",
	["_primitive_dx"] = 48,
	["_primitive_dy"] = 48,
	["_primitive_dz"] = 48,
	["_primitive_dt"] = 4,
	["_primitive_maxseg"] = 16,
	["_primitive_numseg"] = 16,
	["_primitive_tx"] = 0,
	["_primitive_ty"] = 0,
}
shape_typevars["torus"] = {
	["_primitive_type"] = "torus",
	["_primitive_dx"] = 48,
	["_primitive_dy"] = 48,
	["_primitive_dz"] = 6,
	["_primitive_dt"] = 6,
	["_primitive_maxseg"] = 16,
	["_primitive_numseg"] = 16,
	["_primitive_numring"] = 16,
}
shape_typevars["sphere"] = {
	["_primitive_type"] = "sphere",
	["_primitive_dx"] = 48,
	["_primitive_dy"] = 48,
	["_primitive_dz"] = 48,
	["_primitive_numseg"] = 8,
}
shape_typevars["dome"] = {
	["_primitive_type"] = "dome",
	["_primitive_dx"] = 48,
	["_primitive_dy"] = 48,
	["_primitive_dz"] = 48,
	["_primitive_numseg"] = 8,
}
shape_typevars["cube_tube"] = {
	["_primitive_type"] = "cube_tube",
	["_primitive_dx"] = 48,
	["_primitive_dy"] = 48,
	["_primitive_dz"] = 48,
	["_primitive_dt"] = 4,
	["_primitive_numseg"] = 4,
	["_primitive_numring"] = 16,
}

function ENT:Get_primitive_typevars(shape)
	return shape_typevars[shape or self:Get_primitive_type()]
end

local shape_names = {}
for k, v in pairs(shape_typevars) do
	shape_names[k] = k
end

local safe_kv = {
	["_primitive_type"] = function(oldvalue, newvalue)
		if (g_primitive and g_primitive.primitive_shapes) and not g_primitive.primitive_shapes[newvalue] then
			return oldvalue
		end
		return shape_typevars[newvalue] and newvalue or oldvalue
	end,
	["_primitive_dx"] = function(oldvalue, newvalue) return math.Clamp(newvalue, 1, 1024) end,
	["_primitive_dy"] = function(oldvalue, newvalue) return math.Clamp(newvalue, 1, 1024) end,
	["_primitive_dz"] = function(oldvalue, newvalue) return math.Clamp(newvalue, 1, 1024) end,
	["_primitive_dt"] = function(oldvalue, newvalue) return math.Clamp(newvalue, 1, 1024) end,
	["_primitive_maxseg"] = function(oldvalue, newvalue) return math.Round(math.Clamp(newvalue, 1, 32)) end,
	["_primitive_numseg"] = function(oldvalue, newvalue) return math.Round(math.Clamp(newvalue, 1, 32)) end,
	["_primitive_numring"] = function(oldvalue, newvalue) return math.Round(math.Clamp(newvalue, 1, 32)) end,
	["_primitive_tx"] = function(oldvalue, newvalue) return math.Clamp(newvalue, -1, 1) end,
	["_primitive_ty"] = function(oldvalue, newvalue) return math.Clamp(newvalue, -1, 1) end,
}

function ENT:SetSafeValues(name, oldvalue, newvalue)
	if oldvalue == newvalue then
		return
	end
	if safe_kv[name] then
		local value = safe_kv[name](oldvalue, newvalue)
		if value and newvalue ~= value and self["Set" .. name] then
			if SERVER then
				MsgC(Color(255, 255, 0), "primitive addon: ", Color(255, 100, 100), string.format("variable out of bounds | %s (%s) | %s\n", name, newvalue, self:GetVar("Player"):SteamID()))
			end
			self["Set" .. name](self, value)
		end
	end
	self._primitive_trigger_update = CurTime()
end


----------------------------------------------------------------
function ENT:_primitive_spawn(shape)
	local typevars = shape_typevars[shape]
	for k, v in pairs(shape_generic) do
		self["Set" .. k](self, typevars and typevars[k] or v)
	end
	self._primitive_trigger_update = CurTime()
end


----------------------------------------------------------------
function ENT:SetupDataTables()
	local category = "Config"
	self:NetworkVar("String", 0, "_primitive_type", {KeyName = "_primitive_type", Edit = {order = 100, category = category, title = "Type", type = "Combo", values = shape_names}})
	self:NetworkVar("Bool", 0, "_primitive_dbg", {KeyName = "_primitive_dbg", Edit = {order = 101, category = category, global = true, title = "Debug", type = "Boolean"}})

	local category = "Dimensions"
	self:NetworkVar("Float", 0, "_primitive_dx", {KeyName = "_primitive_dx", Edit = {order = 200, category = category, title = "Length X", type = "Float", min = 1, max = 1024}})
	self:NetworkVar("Float", 1, "_primitive_dy", {KeyName = "_primitive_dy", Edit = {order = 201, category = category, title = "Length Y", type = "Float", min = 1, max = 1024}})
	self:NetworkVar("Float", 2, "_primitive_dz", {KeyName = "_primitive_dz", Edit = {order = 202, category = category, title = "Length Z", type = "Float", min = 1, max = 1024}})

	local category = "Modifiers"
	self:NetworkVar("Int", 0, "_primitive_maxseg", {KeyName = "_primitive_maxseg", Edit = {order = 300, category = category, title = "Max Segments", type = "Int", min = 1, max = 32}})
	self:NetworkVar("Int", 1, "_primitive_numseg", {KeyName = "_primitive_numseg", Edit = {order = 301, category = category, title = "Num Segments", type = "Int", min = 1, max = 32}})
	self:NetworkVar("Int", 2, "_primitive_numring", {KeyName = "_primitive_numring", Edit = {order = 302, category = category, title = "Num Rings", type = "Int", min = 1, max = 32}})
	self:NetworkVar("Float", 3, "_primitive_dt", {KeyName = "_primitive_dt", Edit = {order = 303, category = category, title = "Thickness", type = "Float", min = 1, max = 1024}})
	self:NetworkVar("Float", 4, "_primitive_tx", {KeyName = "_primitive_tx", Edit = {order = 304, category = category, title = "Taper X", type = "Float", min = -1, max = 1}})
	self:NetworkVar("Float", 5, "_primitive_ty", {KeyName = "_primitive_ty", Edit = {order = 305, category = category, title = "Taper Y", type = "Float", min = -1, max = 1}})

	self:NetworkVarNotify("_primitive_type", self.SetSafeValues)
	self:NetworkVarNotify("_primitive_dx", self.SetSafeValues)
	self:NetworkVarNotify("_primitive_dy", self.SetSafeValues)
	self:NetworkVarNotify("_primitive_dz", self.SetSafeValues)
	self:NetworkVarNotify("_primitive_dt", self.SetSafeValues)
	self:NetworkVarNotify("_primitive_maxseg", self.SetSafeValues)
	self:NetworkVarNotify("_primitive_numseg", self.SetSafeValues)
	self:NetworkVarNotify("_primitive_numring", self.SetSafeValues)
	self:NetworkVarNotify("_primitive_tx", self.SetSafeValues)
	self:NetworkVarNotify("_primitive_ty", self.SetSafeValues)

	self._primitive_trigger_update = CurTime()
end


----------------------------------------------------------------
local function CopyConstraints(self)
	local constraints = {}
	for _, v in pairs(constraint.GetTable(self)) do
		constraints[#constraints + 1] = v
	end
	constraint.RemoveAll(self)
	self.ConstraintSystem = nil
	return constraints
end

local function ApplyConstraints(self, constraints)
	if not istable(constraints) or next(constraints) == nil or not self:GetPhysicsObject():IsValid() then
		return
	end
	for _, info in pairs(constraints) do
		local make = duplicator.ConstraintType[info.Type]
		if make then
			local args = {}
			for i = 1, #make.Args do
				args[i] = info[make.Args[i]]
			end
			local new, temp = make.Func(unpack(args))
		end
	end
end

function ENT:_primitive_update()
	local shape, ret = g_primitive.primitive_build(self:GetNetworkVars(), nil, CLIENT and g_primitive.primitive_triangulate)
	if not istable(shape) then
		self:_primitive_postupdate(false, shape, ret)
		return
	end

	if istable(shape.phys) then
		local move, sleep, mass, constraints
		if SERVER then
			local phys = self:GetPhysicsObject()
			if phys and phys:IsValid() then
				move, sleep, mass = phys:IsMoveable(), phys:IsAsleep(), phys:GetMass()
			end
			constraints = CopyConstraints(self)
		end

		local success
		if #shape.phys == 1 then
			success = self:PhysicsInitConvex(shape.phys[1])
		else
			success = self:PhysicsInitMultiConvex(shape.phys)
		end

		if not success then
			self:PhysicsInit(SOLID_VPHYSICS)
			self:SetMoveType(MOVETYPE_VPHYSICS)
			self:SetSolid(SOLID_VPHYSICS)
			self:EnableCustomCollisions(false)
		else
			self:SetMoveType(MOVETYPE_VPHYSICS)
			self:SetSolid(SOLID_VPHYSICS)
			self:EnableCustomCollisions(true)
		end

		if SERVER then
			local phys = self:GetPhysicsObject()
			if phys and phys:IsValid() then
				phys:EnableMotion(move)
				if not sleep then phys:Wake() end
				if mass then phys:SetMass(mass) end
			end

			if constraints and next(constraints) then
				timer.Simple(0, function()
					ApplyConstraints(self, constraints)
				end)
			end
		end
	end

	if CLIENT then
		if not istable(ret) or #ret < 3 then
			self:_primitive_postupdate(false, shape, ret)
			return
		end

		local typevars = shape_typevars[self:Get_primitive_type()]
		for k, v in pairs(self:GetEditingData()) do
			v.enabled = (v.global or typevars[k] ~= nil) and true or false
		end

		self:SetRenderBounds(self:GetCollisionBounds())
	end

	self:_primitive_postupdate(true, shape, ret)
end


function ENT:Think()
	if self._primitive_trigger_update and CurTime() - self._primitive_trigger_update > (g_primitive.update_delay or 0.015) then
		self._primitive_trigger_update = nil
		if hook.Run("primitive.preUpdate", self) == false then
			return
		end
		self:_primitive_update()
	end

	if CLIENT then
		local physobj = self:GetPhysicsObject()
		if physobj:IsValid() then
			physobj:SetPos(self:GetPos())
			physobj:SetAngles(self:GetAngles())
			physobj:EnableMotion(false)
			physobj:Sleep()
		end
	end
end
