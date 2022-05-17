AddCSLuaFile()

if not PRIMITIVE then
	PRIMITIVE = {}
end

local math = math
local table = table

properties.Add("primitive_edit", {
	MenuLabel = "Edit Primitive",
	Order = 90001,
	PrependSpacer = true,
	MenuIcon = "icon16/pencil.png",

	Filter = function(self, ent, ply)
		if not IsValid(ent) then
			return false
		end
		if ent:GetClass() ~= "gmod_primitive" then
			return false
		end
		if not gamemode.Call("CanProperty", ply, "primitive_edit", ent) then
			return false
		end
		return true
	end,

	Action = function(self, ent)
		local window = g_ContextMenu:Add("DFrame")
		window:SetSize(320, 400)
		window:SetTitle(tostring(ent))
		window:Center()
		window:SetSizable(true)

		local control = window:Add("primitive_editor")
		control:SetEntity(ent)
		control:Dock(FILL)

		control.OnEntityLost = function()
			window:Remove()
		end
	end
})

local function triangulate(vertices, indices, uv)
	uv = 2 / 48 --math.max(1, math.floor(math.abs(uv or 48)))
	local tris = {}
	for k, face in ipairs(indices) do
		local t1 = face[1]
		local t2 = face[2]
		for j = 3, #face do
			local t3 = face[j]
			local v1, v2, v3 = vertices[t1], vertices[t3], vertices[t2]
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
	return tris
end

-- local mins = Vector(math.huge, math.huge, math.huge)
-- local maxs = Vector(-math.huge, -math.huge, -math.huge)

-- for i = 1, #vertices do
-- 	local x = vertices[i].x
-- 	local y = vertices[i].y
-- 	local z = vertices[i].z

-- 	if x < mins.x then mins.x = x end
-- 	if y < mins.y then mins.y = y end
-- 	if z < mins.z then mins.z = z end
-- 	if x > maxs.x then maxs.x = x end
-- 	if y > maxs.y then maxs.y = y end
-- 	if z > maxs.z then maxs.z = z end
-- end

local builders = {}

/*
builders.spike = function(vars)
	local dx = math.Clamp(math.abs(vars._primitive_dx or 1), 1, 512)*0.5
	local dy = math.Clamp(math.abs(vars._primitive_dy or 1), 1, 512)*0.5
	local dz = math.Clamp(math.abs(vars._primitive_dz or 1), 1, 512)*0.5

	local vertices = {
		Vector(dx, 0, -dz),
		Vector(-dx, -dy, -dz),
		Vector(-dx, dy, -dz),
		Vector(-dx, dy, dz),
		Vector(-dx, -dy, dz),
	}

	if SERVER then
		return { vertices }
	else
		local indices = {
			{1,4,5},
			{1,3,4},
			{3,2,5,4},
			{2,1,5},
			{2,3,1},
		}

		return { vertices }, triangulate(vertices, indices), vertices
	end
end
*/

builders.wedge_corner = function(vars)
	local dx = math.Clamp(math.abs(vars._primitive_dx or 1), 1, 512)*0.5
	local dy = math.Clamp(math.abs(vars._primitive_dy or 1), 1, 512)*0.5
	local dz = math.Clamp(math.abs(vars._primitive_dz or 1), 1, 512)*0.5

	local vertices = {
		Vector(dx, dy, -dz),
		Vector(-dx, -dy, -dz),
		Vector(-dx, dy, -dz),
		Vector(-dx, dy, dz),
	}

	if SERVER then
		return { vertices }
	else
		local indices = {
			 {1,3,4},
			 {2,1,4},
			 {3,2,4},
			 {1,2,3},
		}

		return { vertices }, triangulate(vertices, indices), vertices
	end
end

builders.wedge = function(vars)
	local dx = math.Clamp(math.abs(vars._primitive_dx or 1), 1, 512)*0.5
	local dy = math.Clamp(math.abs(vars._primitive_dy or 1), 1, 512)*0.5
	local dz = math.Clamp(math.abs(vars._primitive_dz or 1), 1, 512)*0.5

	local vertices = {
		Vector(dx, -dy, -dz),
		Vector(dx, dy, -dz),
		Vector(-dx, -dy, -dz),
		Vector(-dx, dy, -dz),
		Vector(-dx, dy, dz),
		Vector(-dx, -dy, dz),
	}

	if SERVER then
		return { vertices }
	else
		local indices = {
			{1,2,5,6},
			{2,4,5},
			{4,3,6,5},
			{3,1,6},
			{3,4,2,1},
		}

		return { vertices }, triangulate(vertices, indices), vertices
	end
end

builders.pyramid = function(vars)
	local dx = math.Clamp(math.abs(vars._primitive_dx or 1), 1, 512)*0.5
	local dy = math.Clamp(math.abs(vars._primitive_dy or 1), 1, 512)*0.5
	local dz = math.Clamp(math.abs(vars._primitive_dz or 1), 1, 512)*0.5

	local vertices = {
		Vector(dx, -dy, -dz),
		Vector(dx, dy, -dz),
		Vector(-dx, -dy, -dz),
		Vector(-dx, dy, -dz),
		Vector(0, 0, dz),
	}

	if SERVER then
		return { vertices }
	else
		local indices = {
			{1,2,5},
			{2,4,5},
			{4,3,5},
			{3,1,5},
			{3,4,2,1},
		}

		return { vertices }, triangulate(vertices, indices), vertices
	end
end

builders.cube = function(vars)
	local dx = math.Clamp(math.abs(vars._primitive_dx or 1), 1, 512)*0.5
	local dy = math.Clamp(math.abs(vars._primitive_dy or 1), 1, 512)*0.5
	local dz = math.Clamp(math.abs(vars._primitive_dz or 1), 1, 512)*0.5

	local vertices = {
		Vector(dx, -dy, -dz),
		Vector(dx, dy, -dz),
		Vector(dx, dy, dz),
		Vector(dx, -dy, dz),
		Vector(-dx, -dy, -dz),
		Vector(-dx, dy, -dz),
		Vector(-dx, dy, dz),
		Vector(-dx, -dy, dz),
	}

	if SERVER then
		return { vertices }
	else
		local indices = {
			{1,2,3,4},
			{2,6,7,3},
			{6,5,8,7},
			{5,1,4,8},
			{4,3,7,8},
			{5,6,2,1},
		}

		return { vertices }, triangulate(vertices, indices), vertices
	end
end

builders.tube = function(vars)
	local maxSegments = 32
	local numSegments = math.Clamp(math.abs(math.floor(vars._primitive_segments or maxSegments)), 1, maxSegments)

	local dx1 = math.Clamp(math.abs(vars._primitive_dx or 1), 1, 512)*0.5
	local dx2 = math.Clamp(dx1 - math.abs(vars._primitive_thickness or 1), 0, dx1)
	local dy1 = math.Clamp(math.abs(vars._primitive_dy or 1), 1, 512)*0.5
	local dy2 = math.Clamp(dy1 - math.abs(vars._primitive_thickness or 1), 0, dy1)
	local dz = math.Clamp(math.abs(vars._primitive_dz or 1), 1, 512)*0.5

	local vertices = {}
	for i = 0, numSegments do
		local a = math.rad((i / maxSegments) * -360)
		table.insert(vertices, Vector(math.sin(a)*dx1, math.cos(a)*dy1, dz))
		table.insert(vertices, Vector(math.sin(a)*dx1, math.cos(a)*dy1, -dz))
		table.insert(vertices, Vector(math.sin(a)*dx2, math.cos(a)*dy2, dz))
		table.insert(vertices, Vector(math.sin(a)*dx2, math.cos(a)*dy2, -dz))
	end

	local pmesh = {}
	for i = 1, #vertices - 4, 4 do
		table.insert(pmesh, {
			vertices[i + 0],
			vertices[i + 1],
			vertices[i + 2],
			vertices[i + 3],
			vertices[i + 4],
			vertices[i + 5],
			vertices[i + 6],
			vertices[i + 7],
		})
	end

	if SERVER then
		return pmesh
	else
		local indices = {}
		for i = 1, #vertices - 4, 4 do
			table.insert(indices, {i + 0, i + 4, i + 6, i + 2})
			table.insert(indices, {i + 4, i + 0, i + 1, i + 5})
			table.insert(indices, {i + 2, i + 6, i + 7, i + 3})
			table.insert(indices, {i + 5, i + 1, i + 3, i + 7})
		end
		if numSegments ~= maxSegments then
			local i = numSegments*4 + 1
			table.insert(indices, {i + 2, i + 0, i + 1, i + 3})
			table.insert(indices, {1, 3, 4, 2})
		end

		return pmesh, triangulate(vertices, indices), vertices
	end
end

builders.cylinder = function(vars)
	local maxSegments = 32
	local numSegments = math.Clamp(math.abs(math.floor(vars._primitive_segments or maxSegments)), 1, maxSegments)

	local dx = math.Clamp(math.abs(vars._primitive_dx or 1), 1, 512)*0.5
	local dy = math.Clamp(math.abs(vars._primitive_dy or 1), 1, 512)*0.5
	local dz = math.Clamp(math.abs(vars._primitive_dz or 1), 1, 512)*0.5

	local vertices = {}
	for i = 0, numSegments do
		local a = math.rad((i / maxSegments) * -360)
		table.insert(vertices, Vector(math.sin(a)*dx, math.cos(a)*dy, dz))
		table.insert(vertices, Vector(math.sin(a)*dx, math.cos(a)*dy, -dz))
		table.insert(vertices, Vector(0, 0, dz))
		table.insert(vertices, Vector(0, 0, -dz))
	end

	local pmesh = {}
	if numSegments ~= maxSegments then
		pmesh = { {}, {} }
		for i = 1, #vertices do
			table.insert(pmesh[i - 1 < (maxSegments*2 + 2) and 1 or 2], vertices[i])
		end
	else
		pmesh = { vertices }
	end

	if SERVER then
		return pmesh
	else
		local indices = {}
		for i = 1, #vertices - 4, 4 do
			table.insert(indices, {i + 0, i + 4, i + 6, i + 2})
			table.insert(indices, {i + 4, i + 0, i + 1, i + 5})
			table.insert(indices, {i + 2, i + 6, i + 7, i + 3})
			table.insert(indices, {i + 5, i + 1, i + 3, i + 7})
		end
		if numSegments ~= maxSegments then
			local i = numSegments*4 + 1
			table.insert(indices, {i + 2, i + 0, i + 1, i + 3})
			table.insert(indices, {1, 3, 4, 2})
		end

		return pmesh, triangulate(vertices, indices), vertices
	end
end

function PRIMITIVE.Build(vars)
	local bfunc = builders[vars._primitive_type]
	if bfunc then
		return bfunc(vars)
	end
end
