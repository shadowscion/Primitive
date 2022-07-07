
do

    local class = {}

    function class:PrimitiveGetConstruct()
        local keys = self:PrimitiveGetKeys()
        return Primitive.construct.get( "rail_slider", keys, true, keys.PrimMESHPHYS )
    end


    function class:PrimitiveSetupDataTables()
        self:PrimitiveVar( "PrimBASE", "Bool", { category = "base", title = "enabled", panel = "bool" }, true )
        self:PrimitiveVar( "PrimBPOS", "Vector", { category = "base", title = "offset", panel = "vector", min = Vector( -500, -500, -500 ), max = Vector( 500, 500, 500) }, true )
        self:PrimitiveVar( "PrimBDIM", "Vector", { category = "base", title = "size", panel = "vector", min = Vector( 1, 1, 1 ), max = Vector( 100, 100, 100) }, true )

        local types = { wedge = "slider_wedge", spike = "slider_spike", cube = "slider_cube", blade = "slider_blade" }
        self:PrimitiveVar( "PrimCTYPE", "String", { category = "contact point", title = "type", panel = "combo", values = types }, true )

        local options = { "front left", "front right", "rear left", "rear right", "double" }
        self:PrimitiveVar( "PrimCENUMS", "Int", { category = "contact point", title = "options", panel = "bitfield", lbl = options }, true )
        self:PrimitiveVar( "PrimCGAP", "Float", { category = "contact point", title = "gap", panel = "float", min = 0, max = 100 }, true )
        self:PrimitiveVar( "PrimCPOS", "Vector", { category = "contact point", title = "offset", panel = "vector", min = Vector( 0, 0, 0 ), max = Vector( 500, 500, 500) }, true )
        self:PrimitiveVar( "PrimCROT", "Angle", { category = "contact point", title = "rotate", panel = "angle" }, true )
        self:PrimitiveVar( "PrimCDIM", "Vector", { category = "contact point", title = "size", panel = "vector", min = Vector( 1, 1, 1 ), max = Vector( 100, 100, 100) }, true )

        local types = { wedge = "slider_wedge", spike = "slider_spike", cube = "slider_cube", blade = "slider_blade" }
        self:PrimitiveVar( "PrimFTYPE", "String", { category = "flange", title = "type", panel = "combo", values = types }, true )

        local options = { "front left", "front right", "rear left", "rear right" }
        self:PrimitiveVar( "PrimFENUMS", "Int", { category = "flange", title = "options", panel = "bitfield", lbl = options }, true )
        self:PrimitiveVar( "PrimFGAP", "Float", { category = "flange", title = "width", panel = "float", min = 0, max = 100 }, true )
    end


    function class:PrimitiveOnSetup( initial, args )
        if initial and SERVER then
            duplicator.StoreEntityModifier( self, "mass", { Mass = 100 } )
            duplicator.StoreBoneModifier( self, 0, "physprops", { GravityToggle = true, Material = "gmod_ice" } )
        end

        self:SetPrimBASE( true )
        self:SetPrimBDIM( Vector( 24, 24, 1 ) )

        self:SetPrimCTYPE( "slider_spike" )
        self:SetPrimFTYPE( "slider_spike" )

        self:SetPrimCENUMS( bit.bor( 1, 1, 2, 4, 8 ) )
        self:SetPrimFENUMS( bit.bor( 1, 1, 2, 4, 8 ) )

        self:SetPrimBPOS( Vector( 0, 0, 16 ) )
        self:SetPrimCPOS( Vector( 24, 38, 0 ) )
        self:SetPrimCDIM( Vector( 24, 1, 8 ) )

        self:SetPrimCGAP( 14 )
        self:SetPrimFGAP( 14 )

        self:SetPrimMESHPHYS( true )
    end


    local spawnlist
    if CLIENT then
        class.baseMaterial = Material( "phoenix_storms/iron_rails" )

        spawnlist = {
            { category = "physics", entity = "primitive_rail_slider", title = "rail_slider", command = "" },
        }

        local callbacks = {
            EDITOR_OPEN = function ( self, editor, name, val )
                for k, cat in pairs( editor.categories ) do
                    if k == "debug" or k == "mesh" or k == "model" then cat:ExpandRecurse( false ) else cat:ExpandRecurse( true ) end
                end
            end,

            PrimBASE = function( self, editor, name, val )
                editor:HideRow( "PrimBPOS", tobool( val ) )
                editor:HideRow( "PrimBDIM", tobool( val ) )
            end,

            PrimCENUMS = function( self, editor, name, val )
                local enabled = bit.band( val, bit.bor( 1, 1, 2, 4, 8 ) ) ~= 0
                local double = bit.band( val, 16 ) == 16

                editor:HideRow( "PrimCGAP", enabled and double ) -- double
                editor:HideRow( "PrimCPOS", enabled )
                editor:HideRow( "PrimCROT", enabled )
                editor:HideRow( "PrimCDIM", enabled )

                editor:HideRow( "PrimFGAP", not double )

                if editor.m_bInitialzied then
                    editor:ScrollToChild( editor.categories["contact point"] )
                end
            end,

            PrimFENUMS = function( self, editor, name, val )
                local enabled = bit.band( val, bit.bor( 1, 1, 2, 4, 8 ) ) ~= 0

                if editor.m_bInitialzied then
                    editor:ScrollToChild( editor.categories.flange )
                end
            end,
        }

        function class:EditorCallback( editor, name, val )
            if callbacks[name] then callbacks[name]( self, editor, name, val ) end
        end
    end

    Primitive.funcs.registerClass( "rail_slider", class, spawnlist )

end

do

    --[[
        SPUR GEAR

        it's beautiful
        and unfortunately too costly to allow
    ]]

    local class = { AdminOnly = true }

    local Vector = Vector
    local math, table, rawset, rawget =
          math, table, rawset, rawget

    local rotateVec = Vector().Rotate

    local function getInvolutePoint( radius, dist )
        local t = ( math.sqrt( dist * dist - radius * radius ) / radius ) - math.acos( radius / dist )
        return dist * math.cos( t ), dist * math.sin( t )
    end

    local construct = { name = "gear", data = { canThread = true } }
    construct.factory = function( param, data, thread, physics )
        local verts = {}

        local faces
        if CLIENT then faces = {} end

        local convexes
        if physics then convexes = { {} } end

        local toothCount = math.Clamp( tonumber( param.PrimCOUNT ) or 20, 3, 60 )
        local gearModule = math.Clamp( tonumber( param.PrimMODULE ) or 1, 1, 50 )
        local gearHeight = math.Clamp( tonumber( param.PrimHEIGHT ) or 1, 1, 1000 )
        local pressureAngle = math.Clamp( tonumber( param.PrimANGLE ) or 20, 0, 45 )

        local addendum = gearModule
        local dedendum = gearModule * 1.25

        local pitchDia = gearModule * toothCount -- tooth midpoint
        local rootDia = pitchDia - dedendum * 2 -- tooth start point
        local tipDia = pitchDia + addendum * 2 -- tooth end point
        local baseDia = math.max( rootDia, pitchDia * math.cos( math.rad( pressureAngle ) ) ) -- involute start point
        local baseRad = baseDia * 0.5

        -- setup curve
        local invCount = SERVER and 2 or 4
        local invStep = ( ( tipDia - baseDia ) * 0.5 ) / ( invCount - 1 )
        local invRadius = baseRad
        local invPoints = {}

        -- this aligns the curve along the center x axis so it's easy to mirror
        local xaxis, yaxis = getInvolutePoint( baseRad, pitchDia * 0.5 )
        local axisAngle = -math.atan( yaxis / xaxis )
        local arcLength = ( ( -math.pi * 2 ) / ( toothCount * 2 ) ) * 0.5

        local carc = math.cos( axisAngle + arcLength )
        local sarc = math.sin( axisAngle + arcLength )

        -- calculate involute
        local h = gearHeight * 0.5
        for i = 0, invCount - 1 do
            local x, y = getInvolutePoint( baseRad, invRadius )
            invRadius = invRadius + invStep

            local px = x * carc - y * sarc
            local py = x * sarc + y * carc

            rawset( invPoints, i + 1, Vector( px, py, h ) )
            rawset( invPoints, invCount * 2 - i, Vector( px, -py, h ) )
        end

        if baseDia ~= rootDia then
            -- normalize and multiply the end points by the root radius
            -- to get the root points

            local rad = rootDia * 0.5

            local pnt = invPoints[1]
            local len = math.sqrt( pnt.x * pnt.x + pnt.y * pnt.y )
            table.insert( invPoints, 1, Vector( ( pnt.x / len ) * rad, ( pnt.y / len ) * rad, h ) )

            local pnt = invPoints[#invPoints]
            local len = math.sqrt( pnt.x * pnt.x + pnt.y * pnt.y )
            table.insert( invPoints, Vector( ( pnt.x / len ) * rad, ( pnt.y / len ) * rad, h ) )
        end

        local invNumP = #invPoints
        local invFace = table.GetKeys( invPoints )

        local toothStep = 360 / toothCount
        local toothAngle = Angle()

        local capUpper, capLower
        if faces then
            capUpper = {}
            capLower = {}
        end

        for i = 0, toothCount - 1 do
            toothAngle.y = toothStep * i

            local vbuffer = #verts
            local ibuffer = invNumP * i

            local faceUpper, faceLower
            if faces then
                faceUpper = {}
                faceLower = {}
            end

            local convex
            if physics then
                convex = {}
            end

            local islast = i == toothCount - 1
            local isnext = i ~= 0

            for j = 1, invNumP do
                local pointUpper = Vector( rawget( invPoints, j ) )
                rotateVec( pointUpper, toothAngle )

                local pointLower = Vector( pointUpper.x, pointUpper.y, -pointUpper.z )

                local idUpper = vbuffer + j
                local idLower = vbuffer + j + invNumP

                rawset( verts, idUpper, pointUpper )
                rawset( verts, idLower, pointLower )

                if faces then
                    rawset( faceUpper, j, idUpper )
                    rawset( faceLower, invNumP - j + 1, idLower )

                    if j < invNumP then
                        faces[#faces + 1] = { idUpper, idUpper + invNumP, idUpper + invNumP + 1, idUpper + 1 }

                        if j == 1 then
                            capUpper[#capUpper + 1] = idUpper
                            capUpper[#capUpper + 1] = idUpper + invNumP - 1
                            capLower[#capLower + 1] = idLower
                            capLower[#capLower + 1] = idLower + invNumP - 1

                            if isnext then
                                faces[#faces + 1] = { idLower, idUpper, idUpper - invNumP - 1, idUpper - 1 }
                            end
                        end
                    elseif islast then
                        faces[#faces + 1] = { invNumP + 1, 1, idUpper, idLower }
                    end
                end

                if physics then
                    rawset( convex, j, pointUpper )
                    rawset( convex, j + invNumP, pointLower )

                    if j == 1 or j == invNumP then
                        local circle = convexes[1]
                        circle[#circle + 1] = rawget( verts, idUpper )
                        circle[#circle + 1] = rawget( verts, idLower )
                    end
                end
            end

            if faces then
                faces[#faces + 1] = faceUpper
                faces[#faces + 1] = faceLower
            end

            if physics then
                convexes[#convexes + 1] = convex
            end
        end

        if faces then
            capLower = table.Reverse( capLower )
            faces[#faces + 1] = capUpper
            faces[#faces + 1] = capLower
        end

        return { verts = verts, faces = faces, convexes = convexes }
    end

    function class:PrimitiveGetConstruct()
        local keys = self:PrimitiveGetKeys()
        return Primitive.construct.generate( construct, "gear", keys, true, keys.PrimMESHPHYS )
    end

    function class:PrimitiveSetupDataTables()
        self:PrimitiveVar( "PrimCOUNT", "Int", { category = "gear", title = "tooth count", panel = "int", min = 3, max = 60 }, true )
        self:PrimitiveVar( "PrimMODULE", "Float", { category = "gear", title = "module", panel = "float", min = 1, max = 50 }, true )
        self:PrimitiveVar( "PrimANGLE", "Float", { category = "gear", title = "pressure angle", panel = "float", min = 1, max = 45 }, true )
        self:PrimitiveVar( "PrimHEIGHT", "Float", { category = "gear", title = "height", panel = "float", min = 1, max = 1000 }, true )

        -- TODO: way to add debugs per ent

        --local edit = self:GetEditingData()
        --edit.PrimDEBUG.lbl = { "hitbox", "vertex", "convex", "gear_profile" }
    end


    function class:PrimitiveOnSetup( initial, args )
        if initial and SERVER then
            duplicator.StoreEntityModifier( self, "mass", { Mass = 100 } )
            duplicator.StoreBoneModifier( self, 0, "physprops", { GravityToggle = true, Material = "gmod_ice" } )
        end

        self:SetPrimCOUNT( 4 )
        self:SetPrimMODULE( 7 )
        self:SetPrimANGLE( 20 )
        self:SetPrimHEIGHT( 12 )
    end


    local spawnlist
    if CLIENT then
        class.baseMaterial = Material( "metal6" )

        spawnlist = {
            { category = "physics", entity = "primitive_gear", title = "gear", command = "" },
        }

        local callbacks = {
            EDITOR_OPEN = function ( self, editor, name, val )
                for k, cat in pairs( editor.categories ) do
                    if k == "debug" or k == "mesh" or k == "model" then cat:ExpandRecurse( false ) else cat:ExpandRecurse( true ) end
                end
            end,
        }

        function class:EditorCallback( editor, name, val )
            if callbacks[name] then callbacks[name]( self, editor, name, val ) end
        end
    end

    Primitive.funcs.registerClass( "gear", class, spawnlist )

end
