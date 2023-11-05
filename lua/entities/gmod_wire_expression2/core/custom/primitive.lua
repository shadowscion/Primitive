
E2Lib.RegisterExtension( "primitive", false, "Allows the manipulation of primitive entities." )

local ANTISPAM_UPDATE_DELAY = 0.5

local function isValidPrimitive( self, ent )
	if not IsValid( ent ) or not scripted_ents.IsBasedOn( ent:GetClass(), "primitive_base" ) then
		return false
	end

	return true
end

local function antispam( ent, key )
	if not ent.E2PrimitiveAntispam then
		ent.E2PrimitiveAntispam = {}
	end

	local time = CurTime()
	local spam = ent.E2PrimitiveAntispam[key]

	if not spam then
		ent.E2PrimitiveAntispam[key] = time
		return true
	end

	if time - spam < ANTISPAM_UPDATE_DELAY then
		return false
	end

	ent.E2PrimitiveAntispam[key] = time

	return true
end

local e2type = {}
e2type.Vector = function( val )
	local a = val[1]
	local b = val[2]
	local c = val[3]

	return Vector( a, b, c )
end
e2type.Angle = function( val )
	local a = val[1]
	local b = val[2]
	local c = val[3]

	return Angle( a, b, c )
end

local function editVariable( ply, ent, key, val )
	if not antispam( ent, key ) then
		return
	end

	local editor = ent:GetEditingData()[key]

	if val == nil or not istable( editor ) then
		return
	end

	if e2type[editor.typename] then
		val = e2type[editor.typename]( val )
	end

	-- permissions are checked here, it's what the editor uses
	-- values are clamped by primitive entity itself
	hook.Run( "VariableEdited", ent, ply, key, tostring( val ), editor )
end

__e2setcost( 15 )

e2function void primitiveEdit( entity ent, string key, ...args )
	if not isValidPrimitive( self, ent ) then return end

	editVariable( self.player, ent, key, args[1] )
end

__e2setcost( 30 )

local e2table = { string = "s", number = "n", boolean = "n" }

e2function table primitiveGetVars( entity ent )
	local ret = E2Lib.newE2Table()

	if not isValidPrimitive( self, ent ) then return ret end

	local editor = ent:GetEditingData()

	for k, v in pairs( editor ) do
		local sub = E2Lib.newE2Table()

		ret.s[k] = v.typename
		ret.stypes[k] = "s"
		ret.size = ret.size + 1
	end

	return ret
end
