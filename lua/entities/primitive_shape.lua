

--
AddCSLuaFile()
DEFINE_BASECLASS("primitive_base")

ENT.PrintName = "Primitive (Shape)"
ENT.AdminOnly = false


--
local shape_typevars = {}

function ENT:Get_primitive_typevars(shape)
	return shape_typevars[shape or self:Get_primitive_shape()] or shape_typevars.generic
end


--
local shapes = {}
for k, v in pairs(g_primitive.primitive_shapes) do shapes[k] = isfunction(v) and k or nil end

shape_typevars.generic = {
	_primitive_dbg = false,
	_primitive_shape = "cube",
	_primitive_dx = 48,
	_primitive_dy = 48,
	_primitive_dz = 48,
	_primitive_dt = 4,
	_primitive_maxseg = 16,
	_primitive_numseg = 16,
	_primitive_subdiv = 8,
	_primitive_tx = 0,
	_primitive_ty = 0,
	_primitive_modv = "",
}
shape_typevars.cone = {
	_primitive_shape = "cone",
	_primitive_dx = 48,
	_primitive_dy = 48,
	_primitive_dz = 48,
	_primitive_maxseg = 16,
	_primitive_numseg = 16,
	_primitive_tx = 0,
	_primitive_ty = 0,
	_primitive_modv = "normals=45",
}
shape_typevars.cube = {
	_primitive_shape = "cube",
	_primitive_dx = 48,
	_primitive_dy = 48,
	_primitive_dz = 48,
	_primitive_tx = 0,
	_primitive_ty = 0,
}
shape_typevars.cube_magic = {
	_primitive_shape = "cube_magic",
	_primitive_dx = 48,
	_primitive_dy = 48,
	_primitive_dz = 48,
	_primitive_dt = 4,
	_primitive_tx = 0,
	_primitive_ty = 0,
	_primitive_modv = "sides=111111",
}
shape_typevars.cube_tube = {
	_primitive_shape = "cube_tube",
	_primitive_dx = 48,
	_primitive_dy = 48,
	_primitive_dz = 48,
	_primitive_dt = 4,
	_primitive_numseg = 4,
	_primitive_subdiv = 16,
	_primitive_modv = "normals=65",
}
shape_typevars.cylinder = {
	_primitive_shape = "cylinder",
	_primitive_dx = 48,
	_primitive_dy = 48,
	_primitive_dz = 48,
	_primitive_maxseg = 16,
	_primitive_numseg = 16,
	_primitive_tx = 0,
	_primitive_ty = 0,
	_primitive_modv = "normals=65",
}
shape_typevars.dome = {
	_primitive_shape = "dome",
	_primitive_dx = 48,
	_primitive_dy = 48,
	_primitive_dz = 48,
	_primitive_numseg = 8,
	_primitive_modv = "normals=65",
}
shape_typevars.pyramid = {
	_primitive_shape = "pyramid",
	_primitive_dx = 48,
	_primitive_dy = 48,
	_primitive_dz = 48,
	_primitive_tx = 0,
	_primitive_ty = 0,
}
shape_typevars.sphere = {
	_primitive_shape = "sphere",
	_primitive_dx = 48,
	_primitive_dy = 48,
	_primitive_dz = 48,
	_primitive_numseg = 8,
	_primitive_modv = "normals=65",
}
shape_typevars.torus = {
	_primitive_shape = "torus",
	_primitive_dx = 48,
	_primitive_dy = 48,
	_primitive_dz = 6,
	_primitive_dt = 6,
	_primitive_maxseg = 16,
	_primitive_numseg = 16,
	_primitive_subdiv = 16,
	_primitive_modv = "normals=65",
}
shape_typevars.tube = {
	_primitive_shape = "tube",
	_primitive_dx = 48,
	_primitive_dy = 48,
	_primitive_dz = 48,
	_primitive_dt = 4,
	_primitive_maxseg = 16,
	_primitive_numseg = 16,
	_primitive_tx = 0,
	_primitive_ty = 0,
	_primitive_modv = "normals=65",
}
shape_typevars.wedge = {
	_primitive_shape = "wedge",
	_primitive_dx = 48,
	_primitive_dy = 48,
	_primitive_dz = 48,
	_primitive_tx = 0.5,
	_primitive_ty = 0,
}
shape_typevars.wedge_corner = {
	_primitive_shape = "wedge_corner",
	_primitive_dx = 48,
	_primitive_dy = 48,
	_primitive_dz = 48,
	_primitive_tx = 0.5,
	_primitive_ty = 0,
}

local _primitive_safenw = {
	_primitive_dx = function(self, old, new) return math.Clamp(new, 1, 1024) end,
	_primitive_dy = function(self, old, new) return math.Clamp(new, 1, 1024) end,
	_primitive_dz = function(self, old, new) return math.Clamp(new, 1, 1024) end,
	_primitive_dt = function(self, old, new) return math.Clamp(new, 1, 1024) end,
	_primitive_tx = function(self, old, new) return math.Clamp(new, -1, 1) end,
	_primitive_ty = function(self, old, new) return math.Clamp(new, -1, 1) end,
	_primitive_maxseg = function(self, old, new) return math.Round(math.Clamp(new, 1, 32)) end,
	_primitive_numseg = function(self, old, new) return math.Round(math.Clamp(new, 1, 32)) end,
	_primitive_subdiv = function(self, old, new) return math.Round(math.Clamp(new, 1, 32)) end,
	_primitive_shape = function(self, old, new) return shapes[new] or next(shapes) end,
}

local mod_patterns = {"(sides=%d%d%d%d%d%d)","(normals=%d+)"}
_primitive_safenw._primitive_modv = function(self, oldvalue, newvalue)
	newvalue = string.gsub(string.lower(newvalue), " ", "")
	local ret = {}
	for k, v in ipairs(mod_patterns) do
		local a, b, c = string.find(newvalue, v)
		if c then
			ret[#ret + 1] = c
		end
	end
	return table.concat(ret, ",")
end

ENT._primitive_safenw = _primitive_safenw


--
function ENT:_primitive_datatables()
	local category = "Configure"
	self:NetworkVar("String", 0, "_primitive_shape", {KeyName = "_primitive_shape", Edit = {order = 100, category = category, title = "Type", type = "Combo", values = shapes, icons = "vgui/primitive/%s.png"}})

	local category = "Resize"
	self:NetworkVar("Float", 0, "_primitive_dx", {KeyName = "_primitive_dx", Edit = {order = 200, category = category, title = "Length X", type = "Float", min = 1, max = 1024}})
	self:NetworkVar("Float", 1, "_primitive_dy", {KeyName = "_primitive_dy", Edit = {order = 201, category = category, title = "Length Y", type = "Float", min = 1, max = 1024}})
	self:NetworkVar("Float", 2, "_primitive_dz", {KeyName = "_primitive_dz", Edit = {order = 202, category = category, title = "Length Z", type = "Float", min = 1, max = 1024}})

	local category = "Modify"
	self:NetworkVar("Float", 3, "_primitive_dt", {KeyName = "_primitive_dt", Edit = {order = 300, category = category, title = "Thickness", type = "Float", min = 1, max = 1024}})
	self:NetworkVar("Float", 4, "_primitive_tx", {KeyName = "_primitive_tx", Edit = {order = 301, category = category, title = "Taper X", type = "Float", min = -1, max = 1}})
	self:NetworkVar("Float", 5, "_primitive_ty", {KeyName = "_primitive_ty", Edit = {order = 302, category = category, title = "Taper Y", type = "Float", min = -1, max = 1}})
	self:NetworkVar("Int", 0, "_primitive_subdiv", {KeyName = "_primitive_subdiv", Edit = {order = 303, category = category, title = "Subdivide", type = "Int", min = 1, max = 32}})
	self:NetworkVar("Int", 1, "_primitive_maxseg", {KeyName = "_primitive_maxseg", Edit = {order = 304, category = category, title = "Max Segments", type = "Int", min = 1, max = 32}})
	self:NetworkVar("Int", 2, "_primitive_numseg", {KeyName = "_primitive_numseg", Edit = {order = 305, category = category, title = "Num Segments", type = "Int", min = 1, max = 32}})
	self:NetworkVar("String", 1, "_primitive_modv", {KeyName = "_primitive_modv", Edit = {global = true, order = 306, category = category, title = "Variables", type = "String", waitforenter = true}})
end


--
if SERVER then
	ENT._primitive_trigger_editor = {
		_primitive_shape = true
	}

	function ENT:_primitive_onEdit(key, val)
		if key == "_primitive_shape" and self:Get_primitive_shape() ~= val then
			self:_primitive_reset(val)
		end
	end

	function ENT:_primitive_reset(shape, ...)
		local typevars = self:Get_primitive_typevars(shape)
		for k, v in pairs(shape_typevars.generic) do
			self["Set" .. k](self, typevars[k] or v)
		end
	end
else
	function ENT:_primitive_postRebuild()
		local typevars = self:Get_primitive_typevars()
		for k, v in pairs(self:GetEditingData()) do
			v.enabled = (v.global or typevars[k] ~= nil) and true or false
		end
	end
end


--
function ENT:_primitive_onRebuild()
	local shape, err
	if SERVER then
		shape, err = g_primitive.primitive_build(self:GetNetworkVars())
	else
		shape, err = g_primitive.primitive_build(self:GetNetworkVars(), nil, true)
	end

	if not shape then return end

	shape.tris = err

	return true, shape
end

