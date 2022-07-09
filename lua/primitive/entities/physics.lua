
do

    local class = {}


    local construct = { data = { name = "airfoil" } }
    function class:PrimitiveGetConstruct()
        local keys = self:PrimitiveGetKeys()
        return Primitive.construct.generate( construct, "airfoil", keys, true, keys.PrimMESHPHYS )
    end


    function class:PrimitiveSetupDataTables()

        local helpDST = "Alters the density of vertices toward the leading and trailing edges"
        local helpAFM = "'M' term - the maximum camber as a percentage of the chord"
        local helpAFP = "'P' term - the distance between the leading edge and the maximum camber"
        local helpAFT = "'T' term - the maximum thickness of the airfoil as a percentage of the chord"
        local helpCHORD = "The distance between the leading and trailing edges"

        local category = "airfoil"
        self:PrimitiveVar( "PrimINTERP", "String", { category = category, title = "point distribution", panel = "combo", values = { linear = "linear", cosine = "cosine", quadratic = "quadratic" }, help = helpDST }, true )
        self:PrimitiveVar( "PrimAFM", "Float", { category = category, title = "max camber", panel = "float", min = 0, max = 9.5, help = helpAFM }, true )
        self:PrimitiveVar( "PrimAFP", "Float", { category = category, title = "max camber pos", panel = "float", min = 0, max = 90, help = helpAFP }, true )
        self:PrimitiveVar( "PrimAFTR", "Float", { category = category, title = "thickness (root)", panel = "float", min = 1, max = 40, help = helpAFT }, true )
        self:PrimitiveVar( "PrimAFTT", "Float", { category = category, title = "thickness (tip)", panel = "float", min = 1, max = 40, help = helpAFT }, true )
        self:PrimitiveVar( "PrimCHORDR", "Float", { category = category, title = "chord (root)", panel = "float", min = 1, max = 2000, help = helpCHORD }, true )
        self:PrimitiveVar( "PrimCHORDT", "Float", { category = category, title = "chord (tip)", panel = "float", min = 1, max = 2000, help = helpCHORD }, true )

        local category = "wing"
        self:PrimitiveVar( "PrimSPAN", "Float", { category = category, title = "span", panel = "float", min = 1, max = 2000 }, true )
        self:PrimitiveVar( "PrimSWEEP", "Float", { category = category, title = "sweep angle", panel = "float", min = -45, max = 45 }, true )
        self:PrimitiveVar( "PrimDIHEDRAL", "Float", { category = category, title = "dihedral angle", panel = "float", min = -45, max = 45 }, true )

        local category = "control surface"

        self:PrimitiveVar( "PrimSURFOPTS", "Int", { category = category, title = "options", panel = "bitfield", lbl = { "enabled", "inverse clip" } }, true )

    end


    function class:PrimitiveOnSetup( initial, args )
        if initial and SERVER then
            duplicator.StoreEntityModifier( self, "mass", { Mass = 100 } )
        end

        self:SetPrimINTERP( "cosine" )
        self:SetPrimAFM( 2 )
        self:SetPrimAFP( 40 )
        self:SetPrimAFTR( 12 )
        self:SetPrimAFTT( 12 )
        self:SetPrimCHORDR( 100 )
        self:SetPrimCHORDT( 100 )

        self:SetPrimSPAN( 300 )
        self:SetPrimSWEEP( 0 )

        self:SetPrimDEBUG( bit.bor( 1, 2 ) )
        self:SetPrimMESHSMOOTH( 60 )
        self:SetPrimMESHPHYS( false )
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


    local function NACA4DIGIT( distr, samples, chord, M, P, T, xoff, yoff, zoff )
        --[[

            terms and coefficients from https://en.wikipedia.org/wiki/NACA_airfoil#Equation_for_a_symmetrical_4-digit_NACA_airfoil

            notation = mpxx 2412

            M = m / 100
            P = p / 10
            T = xx / 100

            -0.1015   open edge a4
            -0.1036   closed edge a4

        ]]

        local xoff = xoff or 0
        local yoff = yoff or 0
        local zoff = zoff or 0

        local M = M / 100
        local P = P / 10
        local T = T / 100

        local a0 = 0.2969
        local a1 = -0.1260
        local a2 = -0.3516
        local a3 = 0.2843
        local a4 = -0.1036

        local samples = samples - 1
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

            points[i + 1] = Vector( -ux * chord + xoff, yoff, uy * chord + zoff + 0 )
            points[buffer - i] = Vector( -lx * chord + xoff, yoff, ly * chord + zoff - 0 )
        end

        return points
    end

    local interp = {}
    interp.linear = function( lhs, rhs ) return 1 - lhs / rhs end
    interp.cosine = function( lhs, rhs ) return 0.5 * ( math.cos( ( lhs / rhs ) * math.pi ) + 1 ) end
    interp.quadratic = function( lhs, rhs ) return ( 1 - lhs / rhs ) ^ 2 end

    construct.factory = function( param, data, thread, physics )
        local verts, faces, convexes

        -- parameters
        local yoff = param.PrimSPAN
        local xoff = math.sin( math.rad( param.PrimSWEEP * 2 ) ) * ( yoff + param.PrimCHORDR )
        local zoff = math.sin( math.rad( param.PrimDIHEDRAL * 2 ) ) * ( yoff + param.PrimCHORDR )

        local pointSamples = 25
        local spacing = interp[param.PrimINTERP] or interp.linear

        local M = math.Clamp( tonumber( param.PrimAFM ) or 0, 0, 9.5 )
        local P = math.Clamp( tonumber( param.PrimAFP ) or 0, 0, 90 )
        local rT = math.Clamp( tonumber( param.PrimAFTR ) or 0, 1, 40 )
        local tT = math.Clamp( tonumber( param.PrimAFTT ) or 0, 1, 40 )
        local rC = tonumber( param.PrimCHORDR ) or 1
        local tC = tonumber( param.PrimCHORDT ) or 1

        local rV = NACA4DIGIT( spacing, pointSamples, rC, M, P, rT )
        local tV = NACA4DIGIT( spacing, pointSamples, tC, M, P, tT, xoff, yoff, zoff )

        -- mesh
        local surfaceCutoffIndex = math.ceil( pointSamples * 0.25 )
        local loftPointCount
        if #rV == #tV then loftPointCount = #rV else return end

        local verts = {}
        if CLIENT then faces = {} end
        if physics then convexes = {} end

        local bits = tonumber( param.PrimSURFOPTS ) or 0
        local enableClip = bit.band( bits, 1 ) == 1
        local enableClipInverse = enableClip and bit.band( bits, 2 ) == 2

        local loftLoopCount
        if enableClip then loftLoopCount = 4 else loftLoopCount = 2 end

        -- lookups for clipping vertices from physics/faces
        -- not at all a proper way to do this but works and is easy to invert

        local clipi = {
            [loftLoopCount - 1] = true
        }

        local clipj = {
            [loftPointCount] = true,
            [pointSamples] = true,
        }

        local clipk = {
            [1] = {},
        }
        for i = 1, surfaceCutoffIndex do
            clipk[1][i] = true
            clipk[1][loftPointCount - i] = true
        end

        for i = 0, loftLoopCount - 1 do
            local d = i / ( loftLoopCount - 1 )
            local k = i * loftPointCount

            local hull
            if convexes and enableClip and d < 1 then
                hull = {}
                convexes[#convexes + 1] = hull
            end

            for j = 1, loftPointCount do
                local p0 = rV[j]
                local p1 = tV[j]

                verts[#verts + 1] = p0 + ( p1 - p0 ) * d -- interpolate the two airfoils

                local v1 = k + j
                local v2 = k + j + 1
                local v3 = k + j + loftPointCount + 1
                local v4 = k + j + loftPointCount

                if enableClip then
                    local exit = clipk[i] and clipk[i][j]

                    if enableClipInverse then
                        if not exit then
                            goto SKIP
                        end

                        if faces then -- instead of all this horse shit why not close the entire face at each loft and cutoff?
                            -- side caps
                            local a = k - j + loftPointCount
                            local b = a + 1
                            faces[#faces + 1] = { b, a, v2, v1 }
                            faces[#faces + 1] = { a + loftPointCount, b + loftPointCount, v4, v3 }
                        end
                    else
                        if exit or clipi[i] or clipj[j] then
                            if exit and j <= surfaceCutoffIndex then
                                if faces then
                                    -- side caps
                                    local a = k - j + loftPointCount
                                    local b = a + 1
                                    faces[#faces + 1] = { v1, v2, a, b }
                                    faces[#faces + 1] = { v3, v4, b + loftPointCount, a + loftPointCount }

                                    if j == surfaceCutoffIndex then

                                        local a = k + 2 * loftPointCount - surfaceCutoffIndex
                                        local b = k + loftPointCount - surfaceCutoffIndex

                                        faces[#faces + 1] = { v2, v3, a, b }

                                        if hull then
                                            hull[#hull + 1] = a
                                            hull[#hull + 1] = b
                                        end
                                    end
                                end
                            end

                            goto SKIP
                        end
                    end
                else
                    if clipi[i] or clipj[j] then
                        goto SKIP
                    end
                end

                if faces then
                    faces[#faces + 1] = { v1, v2, v3, v4 }
                end

                if hull then
                    hull[#hull + 1] = v1
                    hull[#hull + 1] = v4
                end

                ::SKIP::
            end
        end

        if convexes then
            if not enableClip then
                convexes = { verts }
            else
                for i = 1, #convexes do
                    local hull = convexes[i]
                    for j = 1, #hull do
                        local k = hull[j]
                        hull[j] = verts[k]
                    end
                end
            end
        end

        return { verts = verts, faces = faces, convexes = convexes }
    end

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
