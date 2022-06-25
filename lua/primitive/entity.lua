
----
cleanup.Register("primitive")

if CLIENT then
	language.Add("Cleanup_primitive", "Primitives")
	language.Add("Cleaned_primitive", "Cleaned up Primitives")
end

---- SUB CLASSES
g_primitive.entity_register = function(name, primitive, menuList)
	primitive.Type = "anim"
	primitive.Base = "primitive_base"
	primitive.ClassName = "primitive_" .. name
	primitive.AdminOnly = false

	if istable(menuList) and menuList.Category and #menuList.Category > 0 then
		if not g_primitive.menu[menuList.Category] then g_primitive.menu[menuList.Category] = { Entries = {}, Order = menuList.Order } end
		for k, v in pairs(menuList.Entries) do
			if not menuList.Hide then g_primitive.menu[menuList.Category].Entries[v] = true end
			g_primitive.class_lookup[v] = primitive.ClassName
		end
	end

	scripted_ents.Register(primitive, primitive.ClassName)

	if SERVER then
		duplicator.RegisterEntityClass(primitive.ClassName, function(ply, data)
			return g_primitive.entity_create(primitive.ClassName, ply, data)
		end, "Data")
	end
end
g_primitive.entity_reload = function()
	g_primitive.class_lookup = {}
	g_primitive.menu = {}

	local Path = "primitive/entities/"
	local Files, Folders = file.Find(Path .. "*.lua", "LUA")
	for _, File in pairs(Files) do
		if SERVER then AddCSLuaFile(Path .. File) end
		include(Path .. File)
	end

	if CLIENT then
		hook.Add("Think", "primitive.spawnmenu", function()
			if not IsValid(g_primitive_spawnmenu) then return end
			hook.Remove("Think", "primitive.spawnmenu")
			g_primitive.spawnmenu_rebuild()
		end)
	end
end

----
properties.Add("primitive_editor", {
	MenuLabel = "Edit Primitive",
	Order = 90001,
	PrependSpacer = true,
	MenuIcon = "icon16/shape_ungroup.png",

	Filter = function(self, ent, ply)
		if not IsValid(ent) then return false end
		if not ent.Editable_primitive_ then return false end
		if not scripted_ents.IsBasedOn(ent:GetClass(), "primitive_base") then return false end
		--if ent:GetTable().Base ~= "primitive_base" then return false end
		if not gamemode.Call("CanProperty", ply, "primitive_editor", ent) then return false end
		return true
	end,

	Action = function(self, ent)
		local editor = g_ContextMenu:Add("primitive_editor")
		editor:SetSize(320, 410)
		editor:Center()
		editor:SetEntity(ent)
	end
})

----
if SERVER then
	g_primitive.entity_create = function(class, ply, dupedata)
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

		ply:AddCount("Props", self)

		return self
	end

	local function primitive_spawn(ply, cmd, args)
		if not IsValid(ply) or not g_primitive or not g_primitive.class_lookup then return end

		local primitive_type = args[1]
		local primitive_class = g_primitive.class_lookup[primitive_type]

		if not primitive_class then return end

		if not scripted_ents.GetStored(primitive_class) or (scripted_ents.GetMember(primitive_class, "AdminOnly") and not ply:IsAdmin()) then return end
		if not gamemode.Call("PlayerSpawnProp", ply, g_primitive.default_model) then return end

		local entity = g_primitive.entity_create(primitive_class, ply)
		if not entity then return end

		local tr = util.TraceLine({start = ply:EyePos(), endpos = ply:EyePos() + ply:GetAimVector()*4096, filter = ply})
		if not tr.Hit then return end

		local ang
		if math.abs(tr.HitNormal.x) < 0.001 and math.abs(tr.HitNormal.y) < 0.001 then
			ang = Vector(0, 0, tr.HitNormal.z):Angle()
		else
			ang = tr.HitNormal:Angle()
		end
		ang.p = ang.p + 90

		entity:SetAngles(ang)
		entity:SetPos(tr.HitPos + ang:Up()*36)

		gamemode.Call("PlayerSpawnedProp", ply, g_primitive.default_model, entity)

		undo.Create("primitive")
			undo.SetPlayer(ply)
			undo.AddEntity(entity)
			undo.SetCustomUndoText(string.format("Undone primitive (%s)", primitive_class))
		undo.Finish(string.format("primitive (%s)", primitive_class))

		ply:AddCleanup("primitive", entity)

		DoPropSpawnedEffect(entity)

		entity:_primitive_Setup(primitive_type, true)
	end

	concommand.Add("primitive_spawn", primitive_spawn)
end

----
if CLIENT then
	local font = "DermaDefault"

	local function upper(str)
	    return (str:gsub("^%l", string.upper))
	end

	g_primitive.spawnmenu_rebuild = function()
		g_primitive_spawnmenu:Clear()

		if not g_primitive.menu then return end

		g_primitive_spawnmenu.Label:SetFont(font)
		g_primitive_spawnmenu:SetExpanded(tobool(cookie.GetNumber("primitive.smx", 0)))

		local Order = 1000
		for Category, Entries in SortedPairs(g_primitive.menu) do
			if not Entries.Order then
				Order = Order + 1
				Entries.Order = Order
			end
		end

		local Categories = {}
		for Category, Entries in SortedPairsByMemberValue(g_primitive.menu, "Order") do
			if not Categories[Category] then
				Categories[Category] = g_primitive_spawnmenu:AddNode(upper(Category), "icon16/shape_handles.png")
				Categories[Category]:SetExpanded(g_primitive_spawnmenu:GetExpanded(), false)
				Categories[Category].DoClick = function(self)
					g_primitive_spawnmenu.tree:SetSelectedItem(nil)
					self:SetExpanded(not self:GetExpanded())
					--g_primitive_spawnmenu:swapPanel(self)
				end
				Categories[Category].Label:SetFont(font)
			end
			for Entry, Class in SortedPairs(Entries.Entries) do
				local Node = Categories[Category]:AddNode(Entry, "icon16/bullet_toggle_plus.png")
				Node.Icon:SetImageColor(Color(166, 197, 248))
				Node.DoClick = function(self)
					RunConsoleCommand("primitive_spawn", Entry)
					surface.PlaySound("ui/buttonclickrelease.wav")
					--g_primitive_spawnmenu:swapPanel(self)
				end
				Node.Label:SetFont(font)
			end
		end
	end

	local panel_icon
	if file.Exists("materials/vgui/primitive/workshop_icon.png", "GAME") then panel_icon = Material("vgui/primitive/workshop_icon.png", "nocull smooth") end

	hook.Add("PopulateContent", "primitive.spawnmenu", function(pnl, tree, ...)
		if IsValid(g_primitive_spawnmenu) then
			g_primitive_spawnmenu:Remove()
		end
		g_primitive_spawnmenu = tree:AddNode("Primitive", "icon16/shape_ungroup.png")
		g_primitive_spawnmenu.tree = tree
		g_primitive_spawnmenu.SetExpanded = function(self, bExpand, bSurpressAnimation)
			DTree_Node.SetExpanded(self, bExpand, false)
			cookie.Set("primitive.smx", self:GetExpanded() and 1 or 0)
		end
		g_primitive_spawnmenu.DoClick = function(self)
			g_primitive_spawnmenu.tree:SetSelectedItem(nil)
			self:SetExpanded(not self:GetExpanded())
			self:swapPanel()
		end
		g_primitive_spawnmenu.swapPanel = function(self, node)
			if self.innerPanel then pnl:SwitchPanel(self.innerPanel) end
		end

		if panel_icon then
			g_primitive_spawnmenu.innerPanel = vgui.Create("DPanel", pnl)
			g_primitive_spawnmenu.innerPanel:SetVisible(false)
			g_primitive_spawnmenu.innerPanel.Paint = function(_, w, h)
				surface.SetDrawColor(255, 255, 255, 75)
				surface.SetMaterial(panel_icon)
				surface.DrawTexturedRect(0, 0, w, h)
				surface.SetDrawColor(0, 0, 0, 255)
				surface.DrawOutlinedRect(0, 0, w, h, 1)
			end
		end

		g_primitive.spawnmenu_rebuild()
	end)
end
