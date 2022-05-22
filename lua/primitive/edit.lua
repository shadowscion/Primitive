

--
properties.Add("primitive_editor", {
	MenuLabel = "Edit Primitive",
	Order = 90001,
	PrependSpacer = true,
	MenuIcon = "icon16/shape_ungroup.png",

	Filter = function(self, ent, ply)
		if not IsValid(ent) then return false end
		if not ent._primitive_canEdit then return false end
		if ent:GetTable().Base ~= "primitive_base" then return false end
		if not gamemode.Call("CanProperty", ply, "primitive_editor", ent) then return false end
		return true
	end,

	Action = function(self, ent)
		local editor = g_ContextMenu:Add("primitive_editor")
		editor:SetSize(320, 400)
		editor:Center()
		editor:SetEntity(ent)
	end
})
