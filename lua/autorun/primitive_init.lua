AddCSLuaFile()

if not PRIMITIVE then
	PRIMITIVE = {Builders = {}}
end

local math =  math
local table = table
local Vector = Vector
local pi = math.pi
local tau = math.pi*2

properties.Add("primitive_edit", {
	MenuLabel = "Edit Primitive",
	Order = 90001,
	PrependSpacer = true,
	MenuIcon = "icon16/pencil.png",

	Filter = function(self, ent, ply)
		if not IsValid(ent) then
			return false
		end
		if ent:GetClass() ~= "prop_primitive" then
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

hook.Add("PopulateContent", "primitive_spawnlist", function(pnlContent, tree, browse)
	local pnode = tree:AddNode("Primitive", "icon16/shape_square.png")
	pnode:SetExpanded(true)

	for k, v in SortedPairs(PRIMITIVE.Builders) do
		local tnode = pnode:AddNode(k, "icon16/bullet_blue.png")
		tnode.DoClick = function(self)
			tree:SetSelectedItem(nil)
			RunConsoleCommand("primitive_spawn", k)
			surface.PlaySound("ui/buttonclickrelease.wav" )
		end
		if tnode.SetToolTip then
			tnode:SetToolTip("Edit this primitive in the context (c) menu!")
		end
	end
end)

function PRIMITIVE.triangulate(vertices, indices, uv)
	uv = 2/48 --math.max(1, math.floor(math.abs(uv or 48)))
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

local builders = PRIMITIVE.Builders

function PRIMITIVE.Build(vars)
	local bfunc = builders[vars._primitive_type]
	if bfunc then
		return bfunc(vars)
	end
end

--[[
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
		return {vertices}
	else
		local indices = {
			{1, 4, 5},
			{1, 3, 4},
			{3, 2, 5, 4},
			{2, 1, 5},
			{2, 3, 1},
		}

		return {vertices}, triangulate(vertices, indices), vertices
	end
end
]]

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
		return {vertices}
	else
		local indices = {
			{1, 2, 5},
			{2, 4, 5},
			{4, 3, 5},
			{3, 1, 5},
			{3, 4, 2, 1},
		}

		return {vertices}, PRIMITIVE.triangulate(vertices, indices), vertices
	end
end

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
		return {vertices}
	else
		local indices = {
			 {1, 3, 4},
			 {2, 1, 4},
			 {3, 2, 4},
			 {1, 2, 3},
		}

		return {vertices}, PRIMITIVE.triangulate(vertices, indices), vertices
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
		return {vertices}
	else
		local indices = {
			{1, 2, 5, 6},
			{2, 4, 5},
			{4, 3, 6, 5},
			{3, 1, 6},
			{3, 4, 2, 1},
		}

		return {vertices}, PRIMITIVE.triangulate(vertices, indices), vertices
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
		return {vertices}
	else
		local indices = {
			{1, 2, 3, 4},
			{2, 6, 7, 3},
			{6, 5, 8, 7},
			{5, 1, 4, 8},
			{4, 3, 7, 8},
			{5, 6, 2, 1},
		}

		return {vertices}, PRIMITIVE.triangulate(vertices, indices), vertices
	end
end

builders.tube = function(vars)
	local maxsegments = math.Clamp(math.abs(math.floor(vars._primitive_maxsegments or 32)), 3, 32)
	local numsegments = math.Clamp(math.abs(math.floor(vars._primitive_numsegments or maxsegments)), 1, maxsegments)

	local dx1 = math.Clamp(math.abs(vars._primitive_dx or 1), 1, 512)*0.5
	local dx2 = math.Clamp(dx1 - math.abs(vars._primitive_thickness or 1), 0, dx1)
	local dy1 = math.Clamp(math.abs(vars._primitive_dy or 1), 1, 512)*0.5
	local dy2 = math.Clamp(dy1 - math.abs(vars._primitive_thickness or 1), 0, dy1)
	local dz = math.Clamp(math.abs(vars._primitive_dz or 1), 1, 512)*0.5

	local vertices = {}
	for i = 0, numsegments do
		local a = math.rad((i/maxsegments) * -360)
		vertices[#vertices + 1] = Vector(math.sin(a)*dx1, math.cos(a)*dy1, dz)
		vertices[#vertices + 1] = Vector(math.sin(a)*dx1, math.cos(a)*dy1, -dz)
		vertices[#vertices + 1] = Vector(math.sin(a)*dx2, math.cos(a)*dy2, dz)
		vertices[#vertices + 1] = Vector(math.sin(a)*dx2, math.cos(a)*dy2, -dz)
	end

	local pmesh = {}
	for i = 1, #vertices - 4, 4 do
		pmesh[#pmesh + 1] = {
			vertices[i + 0],
			vertices[i + 1],
			vertices[i + 2],
			vertices[i + 3],
			vertices[i + 4],
			vertices[i + 5],
			vertices[i + 6],
			vertices[i + 7],
		}
	end

	if SERVER then
		return pmesh
	else
		local indices = {}
		for i = 1, #vertices - 4, 4 do
			indices[#indices + 1] = {i + 0, i + 4, i + 6, i + 2}
			indices[#indices + 1] = {i + 4, i + 0, i + 1, i + 5}
			indices[#indices + 1] = {i + 2, i + 6, i + 7, i + 3}
			indices[#indices + 1] = {i + 5, i + 1, i + 3, i + 7}
		end

		if numsegments ~= maxsegments then
			local i = numsegments*4 + 1
			indices[#indices + 1] = {i + 2, i + 0, i + 1, i + 3}
			indices[#indices + 1] = {1, 3, 4, 2}
		end

		return pmesh, PRIMITIVE.triangulate(vertices, indices), vertices
	end
end

builders.cone = function(vars)
	local maxsegments = math.Clamp(math.abs(math.floor(vars._primitive_maxsegments or 32)), 3, 32)
	local numsegments = math.Clamp(math.abs(math.floor(vars._primitive_numsegments or maxsegments)), 1, maxsegments)

	local dx = math.Clamp(math.abs(vars._primitive_dx or 1), 1, 512)*0.5
	local dy = math.Clamp(math.abs(vars._primitive_dy or 1), 1, 512)*0.5
	local dz = math.Clamp(math.abs(vars._primitive_dz or 1), 1, 512)*0.5

	local vertices = {}
	for i = 0, numsegments do
		local a = math.rad((i/maxsegments) * -360)
		vertices[#vertices + 1] = Vector(math.sin(a)*dx, math.cos(a)*dy, -dz)
	end

	local c0 = #vertices
	local c1 = c0 + 1
	local c2 = c0 + 2

	vertices[#vertices + 1] = Vector(0, 0, -dz)
	vertices[#vertices + 1] = Vector(0, 0, dz)

	local pmesh = {}
	if numsegments ~= maxsegments then
		pmesh = {{vertices[c1], vertices[c2]}, {vertices[c1], vertices[c2]}}
		for i = 1, c0 do
			if (i - 1 <= maxsegments*0.5) then
				table.insert(pmesh[1], vertices[i])
			end
			if (i - 1 >= maxsegments*0.5) then
				table.insert(pmesh[2], vertices[i])
			end
		end
	else
		pmesh = {vertices}
	end

	if SERVER then
		return pmesh
	else
		local indices = {}
		for i = 1, c0 do
			indices[#indices + 1] = {i + 0, i + 1, c2}
			if i < c0 then
				indices[#indices + 1] = {i + 0, c1, i + 1}
			end
		end

		if numsegments ~= maxsegments then
			indices[#indices + 1] = {c0, c1, c2}
			indices[#indices + 1] = {c0 + 1, 1, c2}
		end

		if CLIENT then
			return pmesh, PRIMITIVE.triangulate(vertices, indices), vertices
		end
	end
end

builders.cylinder = function(vars)
	local maxsegments = math.Clamp(math.abs(math.floor(vars._primitive_maxsegments or 32)), 3, 32)
	local numsegments = math.Clamp(math.abs(math.floor(vars._primitive_numsegments or maxsegments)), 1, maxsegments)

	local dx = math.Clamp(math.abs(vars._primitive_dx or 1), 1, 512)*0.5
	local dy = math.Clamp(math.abs(vars._primitive_dy or 1), 1, 512)*0.5
	local dz = math.Clamp(math.abs(vars._primitive_dz or 1), 1, 512)*0.5

	local vertices = {}
	for i = 0, numsegments do
		local a = math.rad((i/maxsegments) * -360)
		vertices[#vertices + 1] = Vector(math.sin(a)*dx, math.cos(a)*dy, -dz)
		vertices[#vertices + 1] = Vector(math.sin(a)*dx, math.cos(a)*dy, dz)
	end

	local c0 = #vertices
	local c1 = c0 + 1
	local c2 = c0 + 2

	vertices[#vertices + 1] = Vector(0, 0, -dz)
	vertices[#vertices + 1] = Vector(0, 0, dz)

	local pmesh = {}
	if numsegments ~= maxsegments then
		pmesh = {{vertices[c1], vertices[c2]}, {vertices[c1], vertices[c2]}}
		for i = 1, c0 do
			if i - 2 <= maxsegments then
				table.insert(pmesh[1], vertices[i])
			end
			if i - 1 >= maxsegments then
				table.insert(pmesh[2], vertices[i])
			end
		end
	else
		pmesh = {vertices}
	end

	if SERVER then
		return pmesh
	else
		local indices = {}
		for i = 1, c0 - 2, 2 do
			indices[#indices + 1] = {i, i + 2, i + 3, i + 1}
			indices[#indices + 1] = {i, c1, i + 2}
			indices[#indices + 1] = {i + 1, i + 3, c2}
		end

		if numsegments ~= maxsegments then
			indices[#indices + 1] = {c1, c2, c0, c0 - 1}
			indices[#indices + 1] = {c1, 1, 2, c2}
		end

		if CLIENT then
			return pmesh, PRIMITIVE.triangulate(vertices, indices), vertices
		end
	end
end

builders.torus = function(vars)
	local maxsegments = math.Clamp(math.abs(math.floor(vars._primitive_maxsegments or 32)), 3, 32)
	local numsegments = math.Clamp(math.abs(math.floor(vars._primitive_numsegments or 32)), 1, maxsegments)
	local numrings = math.Clamp(math.abs(math.floor(vars._primitive_numrings or 16)), 3, 32)

	local rad_x1 = math.Clamp(math.abs(vars._primitive_dx or 1), 1, 512)*0.5
	local rad_x2 = math.Clamp(math.abs(vars._primitive_thickness or 1), 0.5, 512)
	local rad_y1 = math.Clamp(math.abs(vars._primitive_dy or 1), 1, 512)*0.5
	local rad_y2 = math.Clamp(math.abs(vars._primitive_thickness or 1), 0.5, 512)
	local rad_z = math.Clamp(math.abs(vars._primitive_dz or 1), 1, 512)*0.5

	local pmesh = {}

	do
		local numrings = math.min(6, numrings)

		local vertices = {}
		for j = 0, numrings do
			for i = 0, maxsegments do
				local u = i/maxsegments*tau
				local v = j/numrings*tau
				vertices[#vertices + 1] = Vector((rad_x1 + rad_x2*math.cos(v))*math.cos(u), (rad_y1 + rad_y2*math.cos(v))*math.sin(u), rad_z*math.sin(v))
			end
		end

		for j = 1, numrings do
			for i = 1, numsegments do
				if not pmesh[i] then
					pmesh[i] = {}
				end

				local part = pmesh[i]
				part[#part + 1] = vertices[(maxsegments + 1)*j + i]
				part[#part + 1] = vertices[(maxsegments + 1)*(j - 1) + i]
				part[#part + 1] = vertices[(maxsegments + 1)*(j - 1) + i + 1]
				part[#part + 1] = vertices[(maxsegments + 1)*j + i + 1]
			end
		end
	end

	if SERVER then
		return pmesh
	else
		local vertices = {}
		for j = 0, numrings do
			for i = 0, maxsegments do
				local u = i/maxsegments*tau
				local v = j/numrings*tau
				vertices[#vertices + 1] = Vector((rad_x1 + rad_x2*math.cos(v))*math.cos(u), (rad_y1 + rad_y2*math.cos(v))*math.sin(u), rad_z*math.sin(v))
			end
		end

		local indices = {}
		for j = 1, numrings do
			for i = 1, numsegments do
				indices[#indices + 1] = {(maxsegments + 1)*j + i, (maxsegments + 1)*(j - 1) + i, (maxsegments + 1)*(j - 1) + i + 1, (maxsegments + 1)*j + i + 1}
			end
		end

		if numsegments ~= maxsegments then
			local cap1 = {}
			local cap2 = {}

			for j = 1, numrings do
				cap1[#cap1 + 1] = (maxsegments + 1)*j + 1
				cap2[#cap2 + 1] = (maxsegments + 1)*(numrings - j) + numsegments + 1
			end

			indices[#indices + 1] = cap1
			indices[#indices + 1] = cap2
		end

		return pmesh, PRIMITIVE.triangulate(vertices, indices), vertices
	end
end

builders.sphere = function(vars)
	local segments = math.Clamp(math.abs(math.ceil(vars._primitive_numsegments or 32)), 4, 32)

	local rx = math.Clamp(math.abs(vars._primitive_dx or 1), 1, 512)*0.5
	local ry = math.Clamp(math.abs(vars._primitive_dy or 1), 1, 512)*0.5
	local rz = math.Clamp(math.abs(vars._primitive_dz or 1), 1, 512)*0.5

	local pmesh = {}
	do
		local segments = math.min(8, segments)

		for y = 0, segments do
			local v = y/segments
			local t = v*pi

			local cosPi = math.cos(t)
			local sinPi = math.sin(t)

			for x = 0, segments do
				local u = x/segments
				local p = u*tau

				local cosTau = math.cos(p)
				local sinTau = math.sin(p)

				pmesh[#pmesh + 1] = Vector((-rx*cosTau*sinPi), (ry*sinTau*sinPi), (rz*cosPi))
			end
		end
	end

	if SERVER then
		return {pmesh}
	else
		local vertices = {}
		local indices = {}

		for y = 0, segments do
			local v = y/segments
			local t = v*pi

			local cosPi = math.cos(t)
			local sinPi = math.sin(t)

			for x = 0, segments do
				local u = x/segments
				local p = u*tau

				local cosTau = math.cos(p)
				local sinTau = math.sin(p)

				vertices[#vertices + 1] = Vector((-rx*cosTau*sinPi), (ry*sinTau*sinPi), (rz*cosPi))
			end

			if y > 0 then
				local i = #vertices - 2*(segments + 1)
				while (i + segments + 2) < #vertices do
					indices[#indices + 1] = {i + 1, i + 2, i + segments + 3, i + segments + 2}
					i = i + 1
				end
			end
		end

		return {pmesh}, PRIMITIVE.triangulate(vertices, indices), vertices
	end
end

builders.dome = function(vars)
	local segments = math.Clamp(math.abs(2*math.Round((vars._primitive_numsegments or 32)/2)), 4, 32)

	local rx = math.Clamp(math.abs(vars._primitive_dx or 1), 1, 512)*0.5
	local ry = math.Clamp(math.abs(vars._primitive_dy or 1), 1, 512)*0.5
	local rz = math.Clamp(math.abs(vars._primitive_dz or 1), 1, 512)*0.5

	local pmesh = {}
	do
		local segments = math.min(8, segments)

		for y = 0, segments*0.5 do
			local v = y/segments
			local t = v*pi

			local cosPi = math.cos(t)
			local sinPi = math.sin(t)

			for x = 0, segments do
				local u = x/segments
				local p = u*tau

				local cosTau = math.cos(p)
				local sinTau = math.sin(p)

				pmesh[#pmesh + 1] = Vector((-rx*cosTau*sinPi), (ry*sinTau*sinPi), (rz*cosPi))
			end
		end
	end

	if SERVER then
		return {pmesh}
	else
		local vertices = {}
		local indices = {}

		for y = 0, segments*0.5 do
			local v = y/segments
			local t = v*pi

			local cosPi = math.cos(t)
			local sinPi = math.sin(t)

			for x = 0, segments do
				local u = x/segments
				local p = u*tau

				local cosTau = math.cos(p)
				local sinTau = math.sin(p)

				vertices[#vertices + 1] = Vector((-rx*cosTau*sinPi), (ry*sinTau*sinPi), (rz*cosPi))
			end

			if y > 0 then
				local i = #vertices - 2*(segments + 1)
				while (i + segments + 2) < #vertices do
					indices[#indices + 1] = {i + 1, i + 2, i + segments + 3, i + segments + 2}
					i = i + 1
				end
			end
		end

		local buf = #vertices
		local cap = {}

		for i = 0, segments do
			cap[#cap + 1] = i + buf - segments
		end

		indices[#indices + 1] = cap

		return {pmesh}, PRIMITIVE.triangulate(vertices, indices), vertices
	end
end
