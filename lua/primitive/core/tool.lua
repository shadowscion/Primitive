
-------------------------------
--[[
    Some tools were written well and have class whitelist table I can just add primitives to.
]]

local preregister = {}

preregister.smartweld = function( tool )
    if tool.AllowedBaseClasses then
        tool.AllowedBaseClasses.primitive_base = true
    end
end

hook.Add( "PreRegisterSWEP", "Primitive_ToolRegister", function( swep, class )

    if class == "gmod_tool" and swep.Tool then
        local tools = swep.Tool

        for k, v in pairs( preregister ) do
            if tools[k] then v( tools[k] ) end
        end
    end

end )


-------------------------------
local toolblock = { makespherical = true, advresizer = true, forge = true, poly = true, resizer = true }
local tooldetour = {}

hook.Add( "CanTool", "Primitive_ToolBlock", function( ply, tr, toolname, tool, button )

    if toolblock[toolname] then
        local ent = tr.Entity

        if not ent or not ent.IsPrimitive or not IsValid( ent ) then return end
        if not scripted_ents.IsBasedOn( ent:GetClass(), "primitive_base" ) then return end

        if CLIENT and IsValid( ply ) then
            chat.AddText( string.format( "'%s' cannot be used on %s", toolname, ent ) )
        end

        return false
    end

    if tooldetour[toolname] then
        local ent = tr.Entity

        if not ent or not ent.IsPrimitive or not IsValid( ent ) then return end
        if not scripted_ents.IsBasedOn( ent:GetClass(), "primitive_base" ) then return end

        if SERVER and ent.CPPICanTool then
            if not ent:CPPICanTool( ply, toolname ) then return end
        end

        return tooldetour[toolname].func( tooldetour[toolname], ply, tr, tool, button )
    end

end )


-------------------------------
--[[
    Other tools require a dumber workaround that involves overriding the click functions
    when used on primitives.
]]


-- STACKER_IMPROVED
tooldetour.stacker_improved = { buttons = {}, func = function( self, ply, tr, tool, button )
    if self.buttons[button] then return self.buttons[button]( self, ply, tr, tool ) end
end }

tooldetour.stacker_improved.buttons[1] = function( self, ply, tr, tool, isRightClick )
    if ply:KeyDown( IN_USE ) or ( tool:GetUseShiftKey() and ply:KeyDown( IN_SPEED ) ) then
        if CLIENT then return false end

        local newCount = tool:GetStackSize() >= tool:GetMaxPerStack() and tool:GetMaxPerStack() or tool:GetStackSize() + 1
        ply:ConCommand( "stacker_improved_count " .. newCount )

        return false
    end

    if CLIENT then return true end

    local count = isRightClick and 1 or tool:GetStackSize()
    local maxCount = hook.Run( "StackerMaxPerStack", ply, count, isRightClick ) or tool:GetMaxPerStack()

    if maxCount >= 0 then
        count = math.Clamp( count, 0, maxCount )
    end

    local lastStackTime = improvedstacker.GetLastStackTime( ply, 0 )
    local delay = hook.Run( "StackerDelay", ply, lastStackTime ) or tool:GetDelay()

    local stackDirection = tool:GetDirection()
    local stackMode = tool:GetStackerMode()
    local stackOffset = tool:GetOffsetVector()
    local stackRotation = tool:GetRotationAngle()
    local stackRelative = tool:ShouldStackRelative()

    local stayInWorld = tobool( tool:GetServerInfo( "force_stayinworld" ) )

    local ent = tr.Entity
    local entPos = ent:GetPos()
    local entAng = ent:GetAngles()
    local entMod = ent:GetModel()
    local entSkin = ent:GetSkin()
    local entMat = ent:GetMaterial()
    local physMat = ent:GetPhysicsObject():GetMaterial()
    local physGrav = ent:GetPhysicsObject():IsGravityEnabled()

    local colorData = {
        Color = ent:GetColor(),
        RenderMode = ent:GetRenderMode(),
        RenderFX = ent:GetRenderFX()
    }

    local newEnt
    local newEnts = { ent }
    local lastEnt = ent

    local direction, offset
    local distance = improvedstacker.GetDistance( stackMode, stackDirection, ent )

    undo.Create( "stacker_improved" )

    local maxPerPlayer = hook.Run( "StackerMaxPerPlayer", ply, tool:GetNumberPlayerEnts() ) or tool:GetMaxPerPlayer()

    for i = 1, count do
        local stackerEntsSpawned = tool:GetNumberPlayerEnts()
        if maxPerPlayer >= 0 and stackerEntsSpawned >= maxPerPlayer then
            break
        end

        if not tool:GetSWEP():CheckLimit( "props" ) then
            break
        end

        if hook.Run( "PlayerSpawnProp", ply, entMod ) == false then
            break
        end

        if i == 1 or ( stackMode == improvedstacker.MODE_PROP and stackRelative ) then
            direction = improvedstacker.GetDirection( stackMode, stackDirection, entAng )
            offset = improvedstacker.GetOffset( stackMode, stackDirection, entAng, stackOffset )
        end

        entPos = entPos + ( direction * distance ) + offset
        improvedstacker.RotateAngle( stackMode, stackDirection, entAng, stackRotation )

        if stayInWorld and not util.IsInWorld( entPos ) then
            break
        end

        local data = duplicator.CopyEntTable( ent )
        newEnt = duplicator.CreateEntityFromTable( ply, data )

        newEnt:SetModel( entMod )
        newEnt:SetPos( entPos )
        newEnt:SetAngles( entAng )
        newEnt:SetSkin( entSkin )
        newEnt:Spawn()

        if not IsValid( newEnt ) or hook.Run( "StackerEntity", newEnt, ply ) ~= nil then
            break
        end
        if not IsValid( newEnt ) or hook.Run( "PlayerSpawnedProp", ply, entMod, newEnt ) ~= nil then
            break
        end

        improvedstacker.IncrementEntCount( ply )

        newEnt:CallOnRemove( "UpdateStackerTotal", function( ent, ply )
            if not IsValid( ply ) then return end
            improvedstacker.DecrementEntCount( ply )
        end, ply )

        tool:ApplyMaterial( newEnt, entMat )
        tool:ApplyColor( newEnt, colorData )
        tool:ApplyFreeze( ply, newEnt )

        if not tool:ApplyNoCollide( lastEnt, newEnt ) then
            newEnt:Remove()
            break
        end

        if not tool:ApplyWeld( lastEnt, newEnt ) then
            newEnt:Remove()
            break
        end

        tool:ApplyPhysicalProperties( ent, newEnt, tr.PhysicsBone, { GravityToggle = physGrav, Material = physMat } )

        lastEnt = newEnt
        table.insert( newEnts, newEnt )

        undo.AddEntity( newEnt )
        ply:AddCleanup( "props", newEnt )
    end

    newEnts = nil

    undo.SetPlayer( ply )
    undo.Finish( mode )

    return true
end

tooldetour.stacker_improved.buttons[2] = function( self, ply, tr, tool )
    if ply:KeyDown( IN_USE ) or ( tool:GetUseShiftKey() and ply:KeyDown( IN_SPEED ) ) then
        if CLIENT then return false end

        local count = tool:GetStackSize()
        local newCount = ( count <= 1 and 1 ) or count - 1

        ply:ConCommand( "stacker_improved_count " .. newCount )

        return false
    end

    return self.buttons[1]( self, ply, tr, tool, true )
end

tooldetour.stacker_improved.buttons[3] = function( self, ply, tr, tool )
    if CLIENT then return false end

    local direction = tool:GetDirection()

    if direction == improvedstacker.DIRECTION_DOWN then
        direction = improvedstacker.DIRECTION_FRONT
    else
        direction = direction + 1
    end

    ply:ConCommand( "stacker_improved_direction " .. direction )

    return false
end


-- STACKER
tooldetour.stacker = { buttons = {}, func = function( self, ply, tr, tool, button )
    if self.buttons[button] then return self.buttons[button]( self, ply, tr, tool ) end
end }

tooldetour.stacker.buttons[1] = function( self, ply, tr, tool, isRightClick )
    if CLIENT then return true end

    local Freeze = tool:GetClientNumber( "freeze" ) == 1
    local Weld = tool:GetClientNumber( "weld" ) == 1
    local NoCollide = tool:GetClientNumber( "nocollide" ) == 1
    local Mode = tool:GetClientNumber( "mode" )
    local Dir = tool:GetClientNumber( "dir" )
    local Count = tool:GetClientNumber( "count" )
    local OffsetX = tool:GetClientNumber( "offsetx" )
    local OffsetY = tool:GetClientNumber( "offsety" )
    local OffsetZ = tool:GetClientNumber( "offsetz" )
    local RotP = tool:GetClientNumber( "rotp" )
    local RotY = tool:GetClientNumber( "roty" )
    local RotR = tool:GetClientNumber( "rotr" )
    local Recalc = tool:GetClientNumber( "recalc" ) == 1
    local Offset = Vector( OffsetX, OffsetY, OffsetZ )
    local Rot = Angle( RotP, RotY, RotR )

    local Ent = tr.Entity

    local NewVec = Ent:GetPos()
    local NewAng = Ent:GetAngles()
    local LastEnt = Ent

    if Count <= 0 then return false end

    undo.Create( "stacker" )

    for i = 1, Count, 1 do
        if not tool:GetSWEP():CheckLimit( "props" ) then break end

        if i == 1 or ( Mode == 2 and Recalc == true ) then
            StackDir, Height, ThisOffset = tool:StackerCalcPos( LastEnt, Mode, Dir, Offset )
        end

        NewVec = NewVec + StackDir * Height + ThisOffset
        NewAng = NewAng + Rot

        if not Ent:IsInWorld() then
            return false
        end

        local data = duplicator.CopyEntTable( Ent )
        NewEnt = duplicator.CreateEntityFromTable( ply, data )

        NewEnt:SetModel( Ent:GetModel() )
        NewEnt:SetColor( Ent:GetColor() )
        NewEnt:SetPos( NewVec )
        NewEnt:SetAngles( NewAng )
        NewEnt:Spawn()

        if Freeze then
            ply:AddFrozenPhysicsObject( NewEnt, NewEnt:GetPhysicsObject() )
            NewEnt:GetPhysicsObject():EnableMotion(false)
        else
            NewEnt:GetPhysicsObject():Wake()
        end

        if Weld then
            local WeldEnt = constraint.Weld( LastEnt, NewEnt, 0, 0, 0 )
            undo.AddEntity( WeldEnt )
        end

        if NoCollide then
            local NoCollideEnt = constraint.NoCollide( LastEnt, NewEnt, 0, 0 )
            undo.AddEntity( NoCollideEnt )
        end

        LastEnt = NewEnt

        undo.AddEntity( NewEnt )

        ply:AddCount( "props", NewEnt )
        ply:AddCleanup( "props", NewEnt )

        if PropDefender && PropDefender.Player && PropDefender.Player.Give then
            PropDefender.Player.Give( ply, NewEnt, false )
        end
    end

    undo.SetPlayer( ply )
    undo.Finish()

    return true
end
