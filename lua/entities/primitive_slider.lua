

--
AddCSLuaFile()
DEFINE_BASECLASS("primitive_base")

ENT.PrintName = "Primitive (Slider)"
ENT.AdminOnly = false


--
function ENT:_primitive_reset(args)
	self:Set_primitive_tooth("wedge")
	self:Set_primitive_flange(true)
	self:Set_primitive_double(true)
	self:Set_primitive_mirror(true)
	self:Set_primitive_px(24)
	self:Set_primitive_py(38)
	self:Set_primitive_pz(16)
	self:Set_primitive_pdx(24)
	self:Set_primitive_pdy(1)
	self:Set_primitive_pdz(8)
	self:Set_primitive_pdw(14)

	duplicator.StoreEntityModifier(self, "mass", {Mass = 100})
	duplicator.StoreBoneModifier(self, 0, "physprops", {GravityToggle = true, Material = "gmod_ice"})
end


--
local _primitive_safenw = {
	_primitive_px = function(self, old, new) return math.Clamp(new, 0, 128) end,
	_primitive_py = function(self, old, new) return math.Clamp(new, 0, 128) end,
	_primitive_pz = function(self, old, new) return math.Clamp(new, 0, 128) end,
	_primitive_pdx = function(self, old, new) return math.Clamp(new, 1, 128) end,
	_primitive_pdy = function(self, old, new) return math.Clamp(new, 1, 8) end,
	_primitive_pdz = function(self, old, new) return math.Clamp(new, 1, 16) end,
	_primitive_pdw = function(self, old, new) return math.Clamp(new, 0, 128) end,
	_primitive_flange = function(self, old, new) return tobool(new) end,
	_primitive_mirror = function(self, old, new) return tobool(new) end,
	_primitive_double = function(self, old, new) return tobool(new) end,
}

local tooth = {wedge = "wedge", spike = "spike", cube = "cube"}
_primitive_safenw._primitive_tooth = function(self, old, new) return tooth[new] or tooth.cube end

ENT._primitive_safenw = _primitive_safenw


--
function ENT:_primitive_datatables()
	local category = "Transform"
	self:NetworkVar("Float", 0, "_primitive_px", {KeyName = "_primitive_px", Edit = {order = 0, title = "Pos X", category = category, type = "Float", min = 0, max = 128}})
	self:NetworkVar("Float", 1, "_primitive_py", {KeyName = "_primitive_py", Edit = {order = 1, title = "Pos Y", category = category, type = "Float", min = 0, max = 128}})
	self:NetworkVar("Float", 2, "_primitive_pz", {KeyName = "_primitive_pz", Edit = {order = 2, title = "Pos Z", category = category, type = "Float", min = 0, max = 128}})


	local category = "Profile"
	self:NetworkVar("String", 0, "_primitive_tooth", {KeyName = "_primitive_tooth", Edit = {order = 100, title = "Type", category = category,
		type = "Combo", values = tooth}})

	self:NetworkVar("Float", 3, "_primitive_pdx", {KeyName = "_primitive_pdx", Edit = {order = 101, title = "Length X", category = category, type = "Float", min = 1, max = 128}})
	self:NetworkVar("Float", 4, "_primitive_pdy", {KeyName = "_primitive_pdy", Edit = {order = 102, title = "Length Y", category = category, type = "Float", min = 1, max = 8}})
	self:NetworkVar("Float", 5, "_primitive_pdz", {KeyName = "_primitive_pdz", Edit = {order = 103, title = "Length Z", category = category, type = "Float", min = 1, max = 16}})
	self:NetworkVar("Float", 6, "_primitive_pdw", {KeyName = "_primitive_pdw", Edit = {order = 104, title = "Gap", category = category, type = "Float", min = 0, max = 16}})
	self:NetworkVar("Bool", 1, "_primitive_double", {KeyName = "_primitive_double", Edit = {order = 105, title = "Double", category = category, type = "Boolean"}})
	self:NetworkVar("Bool", 2, "_primitive_mirror", {KeyName = "_primitive_mirror", Edit = {order = 106, title = "Mirror", category = category, type = "Boolean"}})


	local category = "Flange"
	self:NetworkVar("Bool", 3, "_primitive_flange", {KeyName = "_primitive_flange", Edit = {order = 200, title = "Enable", category = category, type = "Boolean"}})
end

function ENT:_primitive_onNWNotify(name, old, new)
	self._primitive_rebuild = CurTime()
end


--
local constructShape
do
	local shapes = {}
	local function registerShape(name, verts, faces)
		shapes[name] = {
			verts = verts,
			faces = faces,
		}
	end

	function constructShape(name, pos, ang, scale, vtbl)
		local shape = shapes[name]
		if not shape then return end

		local physics = {}
		for k, v in ipairs(shape.verts) do
			local vert = Vector(v)
			if scale then
				vert.x = vert.x*scale.x
				vert.y = vert.y*scale.y
				vert.z = vert.z*scale.z
			end
			if ang then vert:Rotate(ang) end
			if pos then
				vert.x = vert.x+pos.x
				vert.y = vert.y+pos.y
				vert.z = vert.z+pos.z
			end
			if vtbl then vtbl[#vtbl + 1] = vert end
			physics[k] = vert
		end

		local tris
		if CLIENT then
			local uv = 1/48
			tris = {}
			for k, face in ipairs(shape.faces) do
				local t1 = face[1]
				local t2 = face[2]
				for j = 3, #face do
					local t3 = face[j]
					local v1, v2, v3 = physics[t1], physics[t2], physics[t3]
					local normal = (v3 - v1):Cross(v2 - v1)
					normal:Normalize()

					v1 = {pos = v1, normal = normal}
					v2 = {pos = v2, normal = normal}
					v3 = {pos = v3, normal = normal}

					local nx, ny, nz = math.abs(normal.x), math.abs(normal.y), math.abs(normal.z)
					if nx > ny and nx > nz then
						local nw = normal.x < 0 and -1 or 1
						v1.u = v1.pos.z*nw*uv
						v1.v = v1.pos.y*uv
						v2.u = v2.pos.z*nw*uv
						v2.v = v2.pos.y*uv
						v3.u = v3.pos.z*nw*uv
						v3.v = v3.pos.y*uv
					elseif ny > nz then
						local nw = normal.y < 0 and -1 or 1
						v1.u = v1.pos.x*uv
						v1.v = v1.pos.z*nw*uv
						v2.u = v2.pos.x*uv
						v2.v = v2.pos.z*nw*uv
						v3.u = v3.pos.x*uv
						v3.v = v3.pos.z*nw*uv
					else
						local nw = normal.z < 0 and 1 or -1
						v1.u = v1.pos.x*nw*uv
						v1.v = v1.pos.y*uv
						v2.u = v2.pos.x*nw*uv
						v2.v = v2.pos.y*uv
						v3.u = v3.pos.x*nw*uv
						v3.v = v3.pos.y*uv
					end

					tris[#tris + 1] = v1
					tris[#tris + 1] = v2
					tris[#tris + 1] = v3
					t2 = t3
				end
			end
		end

		return physics, tris
	end

	registerShape("wedge",
		{
			Vector(-0.500000, -0.500000, 0.500000),
			Vector(-0.500000, 0.500000, 0.300000),
			Vector(-0.500000, -0.500000, 0.300000),
			Vector(0.500000, -0.000000, -0.500000),
			Vector(0.500000, -0.500000, 0.300000),
			Vector(0.500000, -0.500000, 0.500000),
			Vector(0.500000, 0.500000, 0.500000),
			Vector(0.500000, 0.500000, 0.300000),
			Vector(-0.500000, 0.500000, 0.500000),
			Vector(-0.500000, 0.000000, -0.500000),
		},
		{
			{1, 3, 2},
			{3, 5, 4},
			{6, 5, 3},
			{2, 8, 7},
			{6, 1, 9},
			{2, 10, 4},
			{7, 8, 5},
			{9, 1, 2},
			{2, 3, 10},
			{3, 4, 10},
			{6, 3, 1},
			{2, 7, 9},
			{6, 9, 7},
			{2, 4, 8},
			{6, 7, 5},
			{5, 8, 4},
		}
	)
	registerShape("spike",
		{
			Vector(0.500000, -0.500000, 0.300000),
			Vector(-0.500000, -0.500000, 0.500000),
			Vector(-0.500000, -0.500000, 0.300000),
			Vector(0.500000, 0.500000, 0.300000),
			Vector(0.000000, 0.000000, -0.500000),
			Vector(-0.500000, 0.500000, 0.300000),
			Vector(0.500000, 0.500000, 0.500000),
			Vector(0.500000, -0.500000, 0.500000),
			Vector(-0.500000, 0.500000, 0.500000),
		},
		{
			{1, 3, 2},
			{4, 5, 1},
			{5, 6, 3},
			{2, 3, 6},
			{6, 4, 7},
			{4, 1, 8},
			{2, 9, 7},
			{4, 6, 5},
			{3, 1, 5},
			{1, 2, 8},
			{2, 6, 9},
			{6, 7, 9},
			{4, 8, 7},
			{2, 7, 8},
		}
	)
	registerShape("cube",
		{
			Vector(-0.500000, 0.500000, -0.500000),
			Vector(-0.500000, 0.500000, 0.500000),
			Vector(0.500000, 0.500000, -0.500000),
			Vector(0.500000, 0.500000, 0.500000),
			Vector(-0.500000, -0.500000, -0.500000),
			Vector(-0.500000, -0.500000, 0.500000),
			Vector(0.500000, -0.500000, -0.500000),
			Vector(0.500000, -0.500000, 0.500000),
		},
		{
			{3, 2, 1},
			{7, 4, 3},
			{5, 8, 7},
			{1, 6, 5},
			{1, 7, 3},
			{6, 4, 8},
			{3, 4, 2},
			{7, 8, 4},
			{5, 6, 8},
			{1, 2, 6},
			{1, 5, 7},
			{6, 2, 4},
		}
	)
end


--
local flippers = {Vector(1, 1, 1), Vector(1, -1, 1), Vector(-1, 1, 1), Vector(-1, -1, 1)}

local function insertShape(ptbl, ttbl, physics, tris)
	if istable(ptbl) and istable(physics) then
		ptbl[#ptbl + 1] = physics
	end
	if istable(ttbl) and istable(tris) then
		for i = 1, #tris do
			ttbl[#ttbl + 1] = tris[i]
		end
	end
end

function ENT:_primitive_onRebuild()
	local tooth = _primitive_safenw._primitive_tooth(self, nil, self:Get_primitive_tooth())
	local px = _primitive_safenw._primitive_px(self, nil, self:Get_primitive_px())
	local py = _primitive_safenw._primitive_py(self, nil, self:Get_primitive_py())
	local pz = _primitive_safenw._primitive_pz(self, nil, self:Get_primitive_pz())
	local dx = _primitive_safenw._primitive_pdx(self, nil, self:Get_primitive_pdx())
	local dy = _primitive_safenw._primitive_pdy(self, nil, self:Get_primitive_pdy())
	local dz = _primitive_safenw._primitive_pdz(self, nil, self:Get_primitive_pdz())
	local dw = _primitive_safenw._primitive_pdw(self, nil, self:Get_primitive_pdw())

	local flange = self:Get_primitive_flange()
	local double = self:Get_primitive_double()
	local mirror = self:Get_primitive_mirror()

	dw = math.max(dw, double and dy*2 or dy)
	if dw == dy then flange = false end

	if not mirror then
		px = 0
	else
		px = math.max(px, dx*0.5)
		py = math.max(py, 0.5)
	end

	local scale = Vector(dx, dy, dz)
	local pos = Vector(px, py + dy*0.5 - 0.5, 0)
	local flangeScale = Vector(dx, dw, 0.5)
	local flangePos = Vector(px, py + flangeScale.y*0.5 - 0.5, dz*0.5 + flangeScale.z*0.5)

	if double then
		double = Vector(px, py + flangeScale.y - 0.5 - dy*0.5, 0)
	end

	local physics, tris, verts = {}
	if CLIENT then
		tris = {}
		verts = {}
	end

	insertShape(physics, tris, constructShape("cube", Vector(0, 0, pz), nil, Vector(math.max(dx, px) + 1, math.max(dy, py) + 1, 1), verts))

	for i = 1, #flippers do
		if i > 2 and not mirror then
			break
		end

		local flip = flippers[i]

		insertShape(physics, tris, constructShape(tooth, pos*flip, nil, scale, verts))
		if flange then
			insertShape(physics, tris, constructShape("cube", flangePos*flip, nil, flangeScale, verts))
		end
		if double then
			insertShape(physics, tris, constructShape(tooth, double*flip, nil, scale, verts))
		end
	end

	return true, {vertex = verts, tris = tris, physics = physics}
end
