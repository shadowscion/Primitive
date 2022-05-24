
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

/*
hook.Add("primitive.updatePhysics", "primitive.fixPos", function(ent, constraints, mass, physprops)

	local mins, maxs = ent:GetCollisionBounds()

	local entPos = ent:GetPos()
	local endposD = ent:LocalToWorld( mins )
	local tr_down = util.TraceLine( {
		start = entPos,
		endpos = endposD,
		filter = { ent }
	} )

	local endposU = ent:LocalToWorld( maxs )
	local tr_up = util.TraceLine( {
		start = entPos,
		endpos = endposU,
		filter = { ent }
	} )

	if ( tr_up.Hit && tr_down.Hit ) then return end

	if ( tr_down.Hit ) then ent:SetPos( entPos + ( tr_down.HitPos - endposD ) ) end
	if ( tr_up.Hit ) then ent:SetPos( entPos + ( tr_up.HitPos - endposU ) ) end

end)
*/
