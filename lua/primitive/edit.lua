

----------------------------------------------------------------
properties.Add("primitive_edit", {
	MenuLabel = "Edit Primitive",
	Order = 90001,
	PrependSpacer = true,
	MenuIcon = "icon16/pencil.png",

	Filter = function(self, ent, ply)
		if not IsValid(ent) or ent:GetClass() ~= "prop_primitive" or not gamemode.Call("CanProperty", ply, "primitive_edit", ent) then
			return false
		end
		return true
	end,

	Action = function(self, ent)
		local editor = g_ContextMenu:Add("primitive_editor")
		editor:SetSize(320, 400)
		editor:Center()
		editor:SetEntity(ent)
	end
})
