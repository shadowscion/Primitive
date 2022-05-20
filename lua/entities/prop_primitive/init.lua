

----------------------------------------------------------------
AddCSLuaFile("shared.lua")
AddCSLuaFile("cl_init.lua")
include("shared.lua")


----------------------------------------------------------------
function ENT:Initialize()
	self:PhysicsInit(SOLID_VPHYSICS)
	self:SetMoveType(MOVETYPE_VPHYSICS)
	self:SetSolid(SOLID_VPHYSICS)
end


----------------------------------------------------------------
function ENT:_primitive_postupdate(success, shape, ret)
end


----------------------------------------------------------------
hook.Add("VariableEdited", "PrimitiveEditorTrigger", function(ent, client, key, val, editor)
	if key == "_primitive_type" and ent:Get_primitive_type() ~= val then
		ent:_primitive_reset(val)
	end
end)
