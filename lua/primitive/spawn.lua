

--
g_primitive.primitive_types = {}

local t = {menu = "shapes", class = "primitive_shape"}
for k, v in pairs(table.GetKeys(g_primitive.primitive_shapes)) do
	g_primitive.primitive_types[string.gsub(v, " ", "")] = t
end

g_primitive.primitive_types["base"] = {menu = "special", class = "primitive_base", hide = true}
g_primitive.primitive_types["slider"] = {menu = "special", class = "primitive_slider"}


--
if SERVER then
	local function makeEntity(class, ply, dupedata) -- limits would go here?
		local self = ents.Create(class)
		if not (self and self:IsValid()) then
			return false
		end

		if dupedata then
			duplicator.DoGeneric(self, dupedata)
		end

		self:Spawn()
		self:Activate()
		self:SetVar("Player", ply)

		return self
	end

	duplicator.RegisterEntityClass("primitive_base", function(ply, data)
		return makeEntity("primitive_base", ply, data)
	end, "Data")
	duplicator.RegisterEntityClass("primitive_shape", function(ply, data)
		return makeEntity("primitive_shape", ply, data)
	end, "Data")
	duplicator.RegisterEntityClass("primitive_slider", function(ply, data)
		return makeEntity("primitive_slider", ply, data)
	end, "Data")

	concommand.Add("primitive_spawn", function(ply, cmd, args)
		if not IsValid(ply) then return end

		local primitive_type = args[1]

		if not g_primitive.primitive_types[primitive_type] then return end

		local primitive_class = g_primitive.primitive_types[primitive_type].class

		if not scripted_ents.GetStored(primitive_class) or (scripted_ents.GetMember(primitive_class, "AdminOnly") and not ply:IsAdmin()) then return end
		if not gamemode.Call("PlayerSpawnProp", ply, primitive_class) then return end

		local tr = util.TraceLine({start = ply:EyePos(), endpos = ply:EyePos() + ply:GetAimVector()*4096, filter = ply})
		if not tr.Hit then return end

		local entity = makeEntity(primitive_class, ply)
		if not entity then return end

		local ang
		if math.abs(tr.HitNormal.x) < 0.001 and math.abs(tr.HitNormal.y) < 0.001 then
			ang = Vector(0, 0, tr.HitNormal.z):Angle()
		else
			ang = tr.HitNormal:Angle()
		end
		ang.p = ang.p + 90

		entity:SetAngles(ang)
		entity:SetPos(tr.HitPos + ang:Up()*36)

		gamemode.Call("PlayerSpawnedProp", ply, entity:GetModel(), entity)

		undo.Create("Primitive")
			undo.SetPlayer(ply)
			undo.AddEntity(entity)
			undo.SetCustomUndoText(string.format("Undone primitive (%s)", primitive_class))
		undo.Finish(string.format("primitive (%s)", primitive_class))

		ply:AddCleanup("primitive", entity)

		DoPropSpawnedEffect(entity)

		if entity._primitive_reset then
			entity:_primitive_reset(args[1])
		end
	end)
end


--
if CLIENT then
	hook.Add("PopulateContent", "primitive.spawnmenu", function(pnl, tree, ...)
		if not g_primitive or not g_primitive.primitive_types then
			return
		end

		local root = tree:AddNode("Primitive", "icon16/shape_ungroup.png")

		root:SetExpanded(tobool(cookie.GetNumber("primitive.smx", 0)))
		root.Expander.DoClick = function()
			root:SetExpanded(not root:GetExpanded())
			cookie.Set("primitive.smx", root:GetExpanded() and 1 or 0)
		end

		local cats = {}

		for k, v in SortedPairsByMemberValue(g_primitive.primitive_types, "menu", true) do
			if not cats[v.menu] then
				cats[v.menu] = root:AddNode(v.menu, "icon16/shape_handles.png")
				cats[v.menu]:SetExpanded(true)
			end
		end

		for k, v in SortedPairs(g_primitive.primitive_types) do
			if v.hide then goto CONTINUE end

			local node = cats[v.menu]:AddNode(k, "icon16/bullet_toggle_plus.png")
			node.Icon:SetImageColor(Color(166, 197, 248))

			node.DoClick = function()
				tree:SetSelectedItem(nil)
				RunConsoleCommand("primitive_spawn", k)
				surface.PlaySound("ui/buttonclickrelease.wav")
			end

			::CONTINUE::
		end
	end)
end
