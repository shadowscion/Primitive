

do

    local class = {}


    function class:PrimitiveSetupDataTables()

        local types = { linear = "linear", cosine = "cosine", quadratic = "quadratic" }
        self:PrimitiveVar( "PrimTDIST", "String", { category = "airfoil", title = "distribution", panel = "combo", values = types }, true )

        self:PrimitiveVar( "PrimAFM", "Float", { category = "airfoil", title = "max camber % (M)", panel = "float", min = 0, max = 9.5 }, true )
        self:PrimitiveVar( "PrimAFP", "Float", { category = "airfoil", title = "max camber pos % (P)", panel = "float", min = 0, max = 90 }, true )
        self:PrimitiveVar( "PrimAFT", "Float", { category = "airfoil", title = "chord thickness % (T)", panel = "float", min = 1, max = 40 }, true )

        self:PrimitiveVar( "PrimCHORD", "Int", { category = "airfoil", title = "chord length", panel = "int",  min = 1, max = 1000 }, true )

        self:PrimitiveVar( "PrimWING", "Int", { category = "wing", title = "length", panel = "int",  min = 1, max = 2000 }, true )

    end

    function class:PrimitivePostNetworkNotify( name, keyval )
    end


    function class:PrimitiveOnSetup( initial, args )
        if initial and SERVER then
            duplicator.StoreEntityModifier( self, "mass", { Mass = 100 } )
        end

        self:SetPrimTDIST( "cosine" )
        self:SetPrimAFM( 2 )
        self:SetPrimAFP( 40 )
        self:SetPrimAFT( 12 )
        self:SetPrimCHORD( 100 )
        self:SetPrimWING( 100 )

        self:SetPrimDEBUG( bit.bor( 4 ) )
        self:SetPrimMESHPHYS( true )
        self:SetPrimMESHSMOOTH( 65 )
    end


    local construct = { data = { name = "airfoil" } }
    function class:PrimitiveGetConstruct()
        local keys = self:PrimitiveGetKeys()
        return Primitive.construct.generate( construct, "airfoil", keys, true, keys.PrimMESHPHYS )
    end

    local tdistr = {
        linear = function( lhs, rhs ) return 1 - lhs / rhs end,
        cosine = function( lhs, rhs ) return 0.5 * ( math.cos( ( lhs / rhs ) * math.pi ) + 1 ) end,
        quadratic = function( lhs, rhs ) return ( 1 - lhs / rhs ) ^ 2 end,
    }

    local function airfoil( distr, samples, chord, M, P, T )
        --[[
            coefficients from https://en.wikipedia.org/wiki/NACA_airfoil#Equation_for_a_symmetrical_4-digit_NACA_airfoil
                -0.1015   open edge
                -0.1036   closed edge

            notation = mpxx 2412
                M = m / 100
                P = p / 10
                T = xx / 100
        ]]

        local M = M / 100
        local P = P / 10
        local T = T / 100

        local a0 = 0.2969
        local a1 = -0.1260
        local a2 = -0.3516
        local a3 = 0.2843
        local a4 = -0.1036

        local distr = tdistr[distr] or tdistr.linear
        local buffer = samples * 2 + 2
        local points = {}

        for i = 0, samples do
            local x = distr( i, samples )
            local yc, dyc_dx

            -- https://en.wikipedia.org/wiki/NACA_airfoil#Equation_for_a_cambered_4-digit_NACA_airfoil
            -- oof
            if x >= 0 and x < P then
                yc = ( M / P ^ 2 ) * ( ( 2 * P * x ) - x ^ 2 )
                dyc_dx = ( ( 2 * M ) / ( P ^ 2 ) ) * ( P - x )

            elseif x >= P and x <= 1 then
                yc = ( M / ( 1 - P ) ^ 2 ) * ( 1 - ( 2 * P ) + ( 2 * P * x ) - ( x ^ 2 ) )
                dyc_dx = ( ( 2 * M ) / ( ( 1 - P ) ^ 2 ) ) * ( P - x )

            end

            local theta = math.atan( dyc_dx )
            local yt = 5 * T * ( a0 * math.sqrt( x ) + a1 * x + a2 * x ^ 2 + a3 * x ^ 3 + a4 * x ^ 4 )

            -- upper
            local ux = x - yt * math.sin( theta )
            local uy = yc + yt * math.cos( theta )

            -- lower
            local lx = x + yt * math.sin( theta )
            local ly = yc - yt * math.cos( theta )

            points[i + 1] = Vector( ux * chord, 0, uy * chord )
            points[buffer - i] = Vector( lx * chord, 0, ly * chord )
        end

       -- points[#points].z = points[1].z

        return points
    end

    construct.factory = function( param, data, thread, physics )
        local verts, faces, convexes

        local maxDetail = SERVER and 5 or 25
        local chordLength = tonumber( param.PrimCHORD ) or 1
        local wingLength = tonumber( param.PrimWING ) or 1

        local M = math.Clamp( tonumber( param.PrimAFM ) or 0, 0, 9.5 )
        local P = math.Clamp( tonumber( param.PrimAFP ) or 0, 0, 90 )
        local T = math.Clamp( tonumber( param.PrimAFT ) or 0 , 1, 40 )

        local airfoilPoints = airfoil( param.PrimTDIST, maxDetail, chordLength, M, P, T )
        local airfoilPointsCount = #airfoilPoints

        local verts = {}
        local faces = {}
        local loftCount = 2

        --[[
            each loft section needs to be a convex
            should just be a cube for simplicty
        ]]

        for i = 0, loftCount - 1 do
            local loftY = ( i / loftCount ) * wingLength

            local ibuffer = i * airfoilPointsCount
            local isnext = i < loftCount - 1
            local cap = {}

            for j = 1, airfoilPointsCount do
                local point = Vector( airfoilPoints[j] )
                point.y = point.y + loftY

                local index = #verts + 1
                verts[index] = point

                if CLIENT then
                    if j < airfoilPointsCount then
                        if isnext then
                            local v1 = j + ibuffer
                            local v2 = j + airfoilPointsCount + ibuffer
                            local v3 = v2 + 1
                            local v4 = v1 + 1
                            faces[#faces + 1] = { v1, v2, v3, v4 }
                        end

                        local v1 = j + ibuffer
                        local v2 = v1 + 1
                        local v3 = 2 * ibuffer + airfoilPointsCount - v1
                        local v4 = v3 + 1

                        if i == 0 then
                            faces[#faces + 1] = { v1, v2, v3, v4 }
                        else
                            faces[#faces + 1] = { v4, v3, v2, v1 }
                        end
                    end
                end
            end

        end

        if physics then
            convexes = { verts }
        end

        return { verts = verts, faces = faces, convexes = convexes }
    end


    local spawnlist
    if CLIENT then
        spawnlist = {
            { category = "physics", entity = "primitive_airfoil", title = "airfoil", command = "" },
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

    Primitive.funcs.registerClass( "airfoil", class, spawnlist )

end





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


--[=====[
do

    --[[
        SPUR GEAR

        it's beautiful
        and unfortunately for now, generation is too expensive to include in the addon
    ]]

    local class = { AdminOnly = false }

    local Vector = Vector
    local math, table, rawset, rawget =
          math, table, rawset, rawget

    local rotateVec = Vector().Rotate

    local function curvePointXY( radius, dist )
        local t = ( math.sqrt( dist * dist - radius * radius ) / radius ) - math.acos( radius / dist )
        return dist * math.cos( t ), dist * math.sin( t )
    end

    local function curvePointW( x, y, dist )
        local len = math.sqrt( x * x + y * y )
        return ( x / len ) * dist, ( y / len ) * dist
    end

    local function curveCenterXY( numTeeth, baseRadius, pitchDiameter )
        local x, y = curvePointXY( baseRadius, pitchDiameter * 0.5 )

        local a = -math.atan( y / x )
        local l = ( ( -math.pi * 2 ) / ( numTeeth * 2 ) ) * 0.5

        return math.cos( a + l ), math.sin( a + l )
    end

    local function curvePoints( numTeeth, detail, height, pitchDiameter, baseDiameter, tipDiameter, rootDiameter )
        local baseRadius = baseDiameter * 0.5

        local cx, cy = curveCenterXY( numTeeth, baseRadius, pitchDiameter )      -- involute center
        local curveS = ( ( tipDiameter - baseDiameter ) * 0.5 ) / ( detail - 1 ) -- involute step
        local curveR = baseRadius                                                -- involute radius

        local dist = ( baseDiameter ~= rootDiameter ) and ( rootDiameter * 0.5 )
        local curveP = {}

        local ibuffer = detail * 2 + 1

        for i = 1, detail do
            local x, y = curvePointXY( baseRadius, curveR )
            curveR = curveR + curveS

            local px = x * cx - y * cy
            local py = x * cy + y * cx

            curveP[i] = Vector( px, py, height )
            curveP[ibuffer - i] = Vector( px, -py, height )
        end

        if dist then
            local rx, ry = curvePointW( curveP[1].x, curveP[1].y, dist )

            table.insert( curveP, 1, Vector( rx, ry, height ) )
            table.insert( curveP, Vector( rx, -ry, height ) )
        end

        return curveP
    end

    local buildGear

    if CLIENT then

        --[[

            the only reason these are split by realm is to avoid all the boolean comparisons in the nested loops
            for face generation

        ]]

        function buildGear( curveP, curveN, numTeeth, verts, faces, convexes, thread )
            local toothAngle = Angle()
            local toothAngleStep = 360 / numTeeth

            local faceUpperCap = {}
            local faceLowerCap = {}

            for i = 0, numTeeth - 1 do
                toothAngle.y = toothAngleStep * i

                local vbuffer = #verts
                local ibuffer = curveN * i

                local faceUpper = {}
                local faceLower = {}

                local convex
                if convexes then
                    convex = {}
                end

                local islast = i == numTeeth - 1
                local isnext = i ~= 0

                for j = 1, curveN do
                    local pointUpper = Vector( curveP[j] )
                    rotateVec( pointUpper, toothAngle )

                    local pointLower = Vector( pointUpper.x, pointUpper.y, -pointUpper.z )

                    local idUpper = vbuffer + j
                    local idLower = vbuffer + j + curveN

                    verts[idUpper] = pointUpper
                    verts[idLower] = pointLower

                    faceUpper[j] = idUpper
                    faceLower[curveN - j + 1] = idLower

                    if j < curveN then
                        faces[#faces + 1] = { idUpper, idUpper + curveN, idUpper + curveN + 1, idUpper + 1 }

                        if j == 1 then
                            faceUpperCap[#faceUpperCap + 1] = idUpper
                            faceUpperCap[#faceUpperCap + 1] = idUpper + curveN - 1
                            faceLowerCap[#faceLowerCap + 1] = idLower
                            faceLowerCap[#faceLowerCap + 1] = idLower + curveN - 1

                            if isnext then
                                faces[#faces + 1] = { idLower, idUpper, idUpper - curveN - 1, idUpper - 1 }
                            end
                        end
                    elseif islast then
                        faces[#faces + 1] = { curveN + 1, 1, idUpper, idLower }
                    end

                    if convexes then
                        convex[j] = pointUpper
                        convex[j + curveN] = pointLower

                        if j == 1 or j == curveN then
                            local circle = convexes[1]
                            circle[#circle + 1] = verts[idUpper]
                            circle[#circle + 1] = verts[idLower]
                        end
                    end
                end

                faces[#faces + 1] = faceUpper
                faces[#faces + 1] = faceLower

                if convexes then
                    convexes[#convexes + 1] = convex
                end
            end

            faceLowerCap = table.Reverse( faceLowerCap )
            faces[#faces + 1] = faceUpperCap
            faces[#faces + 1] = faceLowerCap

            return verts, faces, convexes
        end

    else

        function buildGear( curveP, curveN, numTeeth, verts, convexes, thread )
            local toothAngle = Angle()
            local toothAngleStep = 360 / numTeeth

            for i = 0, numTeeth - 1 do
                toothAngle.y = toothAngleStep * i

                local vbuffer = #verts
                local ibuffer = curveN * i

                local convex
                if convexes then
                    convex = {}
                end

                local islast = i == numTeeth - 1
                local isnext = i ~= 0

                for j = 1, curveN do
                    local pointUpper = Vector( curveP[j] )
                    rotateVec( pointUpper, toothAngle )

                    local pointLower = Vector( pointUpper.x, pointUpper.y, -pointUpper.z )

                    local idUpper = vbuffer + j
                    local idLower = vbuffer + j + curveN

                    verts[idUpper] = pointUpper
                    verts[idLower] = pointLower

                    if convexes then
                        convex[j] = pointUpper
                        convex[j + curveN] = pointLower

                        if j == 1 or j == curveN then
                            local circle = convexes[1]
                            circle[#circle + 1] = verts[idUpper]
                            circle[#circle + 1] = verts[idLower]
                        end
                    end
                end

                if convexes then
                    convexes[#convexes + 1] = convex
                end
            end

            return verts, convexes
        end

    end


    local construct = { name = "gear", data = { canThread = true } }
    construct.factory = function( param, data, thread, physics )
        local verts, faces, convexes

        -- gear parameters
        local numTeeth = math.Clamp( tonumber( param.PrimCOUNT ) or 20, 3, 60 )
        local module = math.Clamp( tonumber( param.PrimMODULE ) or 1, 1, 50 )
        local gearHeight = math.Clamp( tonumber( param.PrimHEIGHT ) or 1, 1, 1000 ) * 0.5
        local pressureAngle = math.Clamp( tonumber( param.PrimANGLE ) or 20, 0, 45 )

        -- gear setup
        local toothDetail = SERVER and 2 or 4
        local addendum = module
        local dedendum = module * 1.25
        local pitchDiameter = module * numTeeth                                                              -- tooth mid point
        local rootDiameter = pitchDiameter - dedendum * 2                                                    -- tooth start point
        local tipDiameter = pitchDiameter + addendum * 2                                                     -- tooth end point
        local baseDiameter = math.max( rootDiameter, pitchDiameter * math.cos( math.rad( pressureAngle ) ) ) -- involute start point

        -- gear profile curve
        local curveP = curvePoints( numTeeth, toothDetail, gearHeight, pitchDiameter, baseDiameter, tipDiameter, rootDiameter )
        local curveN = #curveP

        -- gear profile array
        local verts, faces, convexes

        if CLIENT then
            verts, faces, convexes = buildGear( curveP, curveN, numTeeth, {}, {}, physics and { {} }, thread )
        else
            verts, convexes = buildGear( curveP, curveN, numTeeth, {}, physics and { {} }, thread )
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
    end


    function class:PrimitiveOnSetup( initial, args )
        if initial and SERVER then
            duplicator.StoreEntityModifier( self, "mass", { Mass = 100 } )
            duplicator.StoreBoneModifier( self, 0, "physprops", { GravityToggle = true, Material = "gmod_ice" } )
        end

        self:SetPrimCOUNT( 20 )
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

--]=====]
