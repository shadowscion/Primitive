
----
AddCSLuaFile("cl_init.lua")
AddCSLuaFile("shared.lua")

include("shared.lua")

----
function ENT:Initialize()
	self:SetModel(g_primitive.default_model)
	self:PhysicsInit(SOLID_VPHYSICS)
	self:SetMoveType(MOVETYPE_VPHYSICS)
	self:SetSolid(SOLID_VPHYSICS)
end

----
hook.Add("VariableEdited", "primitive.edited", function(ent, client, key, val, editor)
	if not ent or not ent.Editable_primitive_ then return end
	if isfunction(ent._primitive_OnEdited) then ent:_primitive_OnEdited(key, val) end
end)
