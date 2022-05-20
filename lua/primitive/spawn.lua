

----------------------------------------------------------------
if SERVER then
	local function spawn_setup(ply, args)
		if not IsValid(ply) or not scripted_ents.GetStored("prop_primitive") then
			return
		end
		if scripted_ents.GetMember("prop_primitive", "AdminOnly") and not ply:IsAdmin() then
			return
		end
		if not gamemode.Call("PlayerSpawnProp", ply, "prop_primitive") then
			return
		end

		local trace = util.TraceLine({start = ply:EyePos(), endpos = ply:EyePos() + ply:GetAimVector()*4096, filter = ply})
		if not trace.Hit then
			return
		end

		local ent = ents.Create("prop_primitive")
		ent:SetModel("models/hunter/blocks/cube025x025x025.mdl")
		ent:SetPos(trace.HitPos + trace.HitNormal*36)
		ent:Spawn()
		ent:Activate()
		ent:SetVar("Player", ply)

		if not IsValid(ent) then
			return
		end

		gamemode.Call("PlayerSpawnedProp", ply, "models/hunter/blocks/cube025x025x025.mdl", ent)

		undo.Create("Prop")
			undo.SetPlayer(ply)
			undo.AddEntity(ent)
			undo.SetCustomUndoText(string.format("Undone primitive (%s)", args[1]))
		undo.Finish(string.format("primitive (%s)", args[1]))

		ply:AddCleanup("props", ent)

		ent:_primitive_reset(args[1])
	end

	concommand.Add("primitive_spawn", function(ply, cmd, args)
		spawn_setup(ply, args)
	end)

	duplicator.RegisterEntityClass("prop_primitive", function(ply, data)
		if scripted_ents.GetMember("prop_primitive", "AdminOnly") and not ply:IsAdmin() then
			return false
		end
		if not gamemode.Call("PlayerSpawnProp", ply, "prop_primitive") then
			return false
		end

		local ent = ents.Create("prop_primitive")
		if not IsValid(ent) then
			return false
		end

		ent:SetModel("models/hunter/blocks/cube025x025x025.mdl")
		ent:Spawn()
		ent:Activate()
		ent:SetVar("Player", ply)

		if data then
			duplicator.DoGeneric(ent, data)
		end

		gamemode.Call("PlayerSpawnedProp", ply, "models/hunter/blocks/cube025x025x025.mdl", ent)

		ply:AddCleanup("props", ent)

		return ent
	end, "Data")
else
	local function CreateSpawnMenu(pnl, tree, ...)
		if not g_primitive or not g_primitive.primitive_shapes then
			return
		end

		local node_a = tree:AddNode("Primitive", "icon16/shape_square.png")
		node_a.Icon:SetImageColor(Color(0, 255, 255))

		node_a:SetExpanded(tobool(cookie.GetNumber("primitive.smx", 0)))
		node_a.Expander.DoClick = function()
			node_a:SetExpanded(not node_a:GetExpanded())
			cookie.Set("primitive.smx", node_a:GetExpanded() and 1 or 0)
		end

		for k, v in SortedPairs(g_primitive.primitive_shapes) do
			local node_b = node_a:AddNode(k, "icon16/bullet_blue.png")
			node_b.Icon:SetImageColor(Color(0, 255, 255))
			node_b.DoClick = function(self)
				tree:SetSelectedItem(nil)

				RunConsoleCommand("primitive_spawn", k)
				surface.PlaySound("ui/buttonclickrelease.wav")
			end
		end
	end

	hook.Add("PopulateContent", "primitive.spawnmenu", CreateSpawnMenu)
end
