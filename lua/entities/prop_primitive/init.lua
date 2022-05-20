

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

