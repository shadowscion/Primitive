
-- BY SHADOWSCION

local Addon = Primitive
Addon.construct = {}

-- Addon.construct.registerType( name, factory=func, data=table )
-- Addon.construct.getType( name )
-- Addon.construct.get( name, param=table, thread=bool, physics=bool )

--[[

    HELPERS

]]

local math, table, coroutine, Vector, Angle, rawget, rawset =
      math, table, coroutine, Vector, Angle, rawget, rawset

local pi = math.pi
local tau = math.pi * 2

local zeroVec = Vector()
local addVec = zeroVec.Add
local mulVec = zeroVec.Mul
local divVec = zeroVec.Div
local subVec = zeroVec.Sub
local dotVec = zeroVec.Dot
local crossVec = zeroVec.Cross
local rotateVec = zeroVec.Rotate
local normalizeVec = zeroVec.Normalize
local getNormalizedVec = zeroVec.GetNormalized

local function map( x, in_min, in_max, out_min, out_max )
    return ( x - in_min ) * ( out_max - out_min ) / ( in_max - in_min ) + out_min
end

local function transform( verts, rotate, offset, thread )

    --[[
        NOTE:

        Vectors are mutable objects, which means this may have unexpected results if used incorrectly ( applying transform to same vertex multiple times by mistake ).
        That's why it's per construct, instead of in the global getter function.
    ]]

    if isangle( rotate ) and ( rotate.p ~= 0 or rotate.y ~= 0 or rotate.r ~= 0 ) then
        for i = 1, #verts do
            rotateVec( verts[i], rotate )
        end
    end

    if isvector( offset ) and ( offset.x ~= 0 or offset.y ~= 0 or offset.z ~= 0 ) then
        for i = 1, #verts do
            addVec( verts[i], offset )
        end
    end
end

local triangulate

if CLIENT then
    local YIELD_THRESHOLD = 1

    local function calcInside( vertices, thread )
        for i = #vertices, 1, -1 do
            local v = vertices[i]
            vertices[#vertices + 1] = { pos = v.pos, normal = -v.normal, u = v.u, v = v.v, userdata = v.userdata }

            if thread and ( i % YIELD_THRESHOLD == 0 ) then coroutine.yield( false ) end
        end
    end

    local function calcBounds( vertex, mins, maxs )
        local x = vertex.x
        local y = vertex.y
        local z = vertex.z
        if x < mins.x then mins.x = x elseif x > maxs.x then maxs.x = x end
        if y < mins.y then mins.y = y elseif y > maxs.y then maxs.y = y end
        if z < mins.z then mins.z = z elseif z > maxs.z then maxs.z = z end
    end

    local function calcNormals( vertices, deg, thread )

        -- credit to Sevii for this craziness

        deg = math.cos( math.rad( deg ) )

        local norms = setmetatable( {}, { __index = function( t, k ) local r = setmetatable( {}, { __index = function( t, k ) local r = setmetatable( {}, { __index = function( t, k ) local r = {} t[k] = r return r end } ) t[k] = r return r end } ) t[k] = r return r end } )

        for i = 1, #vertices do
            local vertex = vertices[i]
            local pos = vertex.pos
            local norm = norms[pos[1]][pos[2]][pos[3]]
            norm[#norm + 1] = vertex.normal

            if thread and ( i % YIELD_THRESHOLD == 0 ) then coroutine.yield( false ) end
        end

        for i = 1, #vertices do
            local vertex = vertices[i]
            local normal = Vector()
            local count = 0
            local pos = vertex.pos

            local nk = norms[pos[1]][pos[2]][pos[3]]
            for j = 1, #nk do
                local norm = nk[j]
                if dotVec( vertex.normal, norm ) >= deg then
                    addVec( normal, norm )
                    count = count + 1
                end
            end

            if count > 1 then
                divVec( normal, count )
                vertex.normal = normal
            end

            if thread and ( i % YIELD_THRESHOLD == 0 ) then coroutine.yield( false ) end
        end
    end

    local function calcTangents( vertices, thread )

        -- credit to https://gamedev.stackexchange.com/questions/68612/how-to-compute-tangent-and-bitangent-vectors
        -- seems to work but i have no idea how or why, nor why i cant do this during triangulation

        local tan1 = {}
        local tan2 = {}

        for i = 1, #vertices do
            tan1[i] = Vector( 0, 0, 0 )
            tan2[i] = Vector( 0, 0, 0 )

            if thread and ( i % YIELD_THRESHOLD == 0 ) then coroutine.yield( false ) end
        end

        for i = 1, #vertices - 2, 3 do
            local v1 = vertices[i]
            local v2 = vertices[i + 1]
            local v3 = vertices[i + 2]

            local p1 = v1.pos
            local p2 = v2.pos
            local p3 = v3.pos

            local x1 = p2.x - p1.x
            local x2 = p3.x - p1.x
            local y1 = p2.y - p1.y
            local y2 = p3.y - p1.y
            local z1 = p2.z - p1.z
            local z2 = p3.z - p1.z

            local us1 = v2.u - v1.u
            local us2 = v3.u - v1.u
            local ut1 = v2.v - v1.v
            local ut2 = v3.v - v1.v

            local r = 1 / ( us1 * ut2 - us2 * ut1 )

            local sdir = Vector( ( ut2 * x1 - ut1 * x2 ) * r, ( ut2 * y1 - ut1 * y2 ) * r, ( ut2 * z1 - ut1 * z2 ) * r )
            local tdir = Vector( ( us1 * x2 - us2 * x1 ) * r, ( us1 * y2 - us2 * y1 ) * r, ( us1 * z2 - us2 * z1 ) * r )

            addVec( tan1[i], sdir )
            addVec( tan1[i + 1], sdir )
            addVec( tan1[i + 2], sdir )

            addVec( tan2[i], tdir )
            addVec( tan2[i + 1], tdir )
            addVec( tan2[i + 2], tdir )

            if thread and ( i % YIELD_THRESHOLD == 0 ) then coroutine.yield( false ) end
        end

        for i = 1, #vertices do
            local n = vertices[i].normal
            local t = tan1[i]

            local tangent = ( t - n * dotVec( n, t ) )
            normalizeVec( tangent )

            vertices[i].userdata = { tangent[1], tangent[2], tangent[3], dotVec( crossVec( n, t ), tan2[i] ) }

            if thread and ( i % YIELD_THRESHOLD == 0 ) then coroutine.yield( false ) end
        end
    end

    local ENUM_TANGENTS = 1
    local ENUM_INSIDE = 2
    local ENUM_INVERT = 4

    function triangulate( result, param, thread, physics )

        --[[
            CONFIG

            if necessary, other addons ( like prop2mesh ) can override flags by setting the skip params
                .skip_bounds
                .skip_tangents
                .skip_inside
                .skip_invert
                .skip_uv
                .skip_normals
        ]]

        local fbounds, ftangents, finside, finvert

        local mins, maxs
        if not param.skip_bounds then

            -- if physics are generated we can use GetCollisionBounds for SetRenderBounds
            -- otherwise we need to get mins and maxs manually

            if not physics then
                mins = Vector( math.huge, math.huge, math.huge )
                maxs = Vector( -math.huge, -math.huge, -math.huge )

                fbounds = true
            end
        end

        local bits = tonumber( param.PrimMESHENUMS ) or 0

        if not param.skip_tangents then
            if system.IsLinux() or system.IsOSX() then ftangents = true else ftangents = bit.band( bits, ENUM_TANGENTS ) == ENUM_TANGENTS end
        end

        if not param.skip_inside then
            finside = bit.band( bits, ENUM_INSIDE ) == ENUM_INSIDE
        end

        if not param.skip_invert then
            finvert = bit.band( bits, ENUM_INVERT ) == ENUM_INVERT
        end

        local uvlen
        if not param.skip_uv then
            uvlen = tonumber( param.PrimMESHUV ) or 48
            if uvlen < 8 then uvlen = 8 end
            uvlen = 1 / uvlen
        end

        -- TRIANGULATE

        result.tris = {}

        local vertices = result.tris
        local faces = result.faces
        local verts = result.verts

        for i = 1, #faces do
            local face = faces[i]
            local t1 = face[1]
            local t2 = face[2]

            for j = 3, #face do
                local t3 = face[j]
                local p1, p2, p3 = verts[t1], verts[t3], verts[t2]
                local normal = crossVec( p3 - p1, p2 - p1 )
                normalizeVec( normal )

                local v1 = { pos = finvert and p3 or p1, normal = normal }
                local v2 = { pos = finvert and p2 or p2, normal = normal }
                local v3 = { pos = finvert and p1 or p3, normal = normal }

                if fbounds then
                    calcBounds( p1, mins, maxs )
                    calcBounds( p2, mins, maxs )
                    calcBounds( p3, mins, maxs )
                end

                if uvlen then
                    local nx, ny, nz = math.abs( normal.x ), math.abs( normal.y ), math.abs( normal.z )
                    if nx > ny and nx > nz then
                        local nw = normal.x < 0 and -1 or 1
                        v1.u = v1.pos.z * nw * uvlen
                        v1.v = v1.pos.y * uvlen
                        v2.u = v2.pos.z * nw * uvlen
                        v2.v = v2.pos.y * uvlen
                        v3.u = v3.pos.z * nw * uvlen
                        v3.v = v3.pos.y * uvlen

                    elseif ny > nz then
                        local nw = normal.y < 0 and -1 or 1
                        v1.u = v1.pos.x * uvlen
                        v1.v = v1.pos.z * nw * uvlen
                        v2.u = v2.pos.x * uvlen
                        v2.v = v2.pos.z * nw * uvlen
                        v3.u = v3.pos.x * uvlen
                        v3.v = v3.pos.z * nw * uvlen

                    else
                        local nw = normal.z < 0 and 1 or -1
                        v1.u = v1.pos.x * nw * uvlen
                        v1.v = v1.pos.y * uvlen
                        v2.u = v2.pos.x * nw * uvlen
                        v2.v = v2.pos.y * uvlen
                        v3.u = v3.pos.x * nw * uvlen
                        v3.v = v3.pos.y * uvlen

                    end
                end

                vertices[#vertices + 1] = v1
                vertices[#vertices + 1] = v2
                vertices[#vertices + 1] = v3

                t2 = t3
            end

            if thread and ( i % YIELD_THRESHOLD == 0 ) then coroutine.yield( false ) end
        end

        -- POSTPROCESS

        if not param.skip_normals then
            local smooth = tonumber( param.PrimMESHSMOOTH ) or 0
            if smooth ~= 0 then
                calcNormals( vertices, smooth, thread )
            end
        end

        if ftangents then
            calcTangents( vertices, thread )
        end

        if finside then
            calcInside( vertices, thread )
        end

        if fbounds then
            result.mins = mins
            result.maxs = maxs
        end
    end

end


--[[

    ERROR MODEL OVERRIDE

]]

local function errorModel( code, name, err )
    local message
    if code == 1 then message = "Non-existant construct" end
    if code == 2 then message = "Lua error" end
    if code == 3 then message = "Bad return" end
    if code == 4 then message = "Bad physics table" end
    if code == 5 then message = "Bad vertex table" end
    if code == 6 then message = "Triangulation failed" end

    local result = {
        error = {
            code = code,
            name = name,
            lua = err,
            msg = message,
        }
    }

    print( "-----------------------------" )
    PrintTable( result.error )
    print( "-----------------------------" )

    result.verts = {
        Vector( 12, -12, -12 ),
        Vector( 12, 12, -12 ),
        Vector( 12, 12, 12 ),
        Vector( 12, -12, 12 ),
        Vector( -12, -12, -12 ),
        Vector( -12, 12, -12 ),
        Vector( -12, 12, 12 ),
        Vector( -12, -12, 12 ),
    }

    if CLIENT then
        result.faces = {
            { 1, 2, 3, 4 },
            { 2, 6, 7, 3 },
            { 6, 5, 8, 7 },
            { 5, 1, 4, 8 },
            { 4, 3, 7, 8 },
            { 5, 6, 2, 1 },
        }

        triangulate( result, {} )
    end

    result.convexes = { result.verts }

    return result
end


--[[

    'CONSTRUCT' LIBRARY

]]

Addon.construct.util = { map = map, transform = transform, triangulate = triangulate }

local construct_types = {}


function Addon.construct.getType( name )
    return construct_types[name]
end


function Addon.construct.registerType( name, factory, data )
    assert( construct_types[name] == nil , string.format( "Construct type [%s] already exists!", name ) )
    assert( isfunction( factory ), "Factory argument must be a function!" )

    data = istable( data ) and data or {}
    data.name = name

    construct_types[name] = { factory = factory, data = data }
end
local registerType = Addon.construct.registerType


local function getResult( construct, name, param, thread, physics )
    local success, result = pcall( construct.factory, param, construct.data, thread, physics )

    -- lua error, error model CODE 2

    if not success then
        return true, errorModel( 2, name, result )
    end

    -- Bad return, error model CODE 3

    if not istable( result ) then
        return true, errorModel( 3, name )
    end

    -- Bad physics table, error model CODE 4

    if physics and ( not istable( result.convexes ) or #result.convexes < 1 ) then
        return true, errorModel( 4, name )
    end

    -- only clients truly require verts, faces, tris

    if CLIENT then
        -- Bad vertex table, error model CODE 5

        if not istable( result.verts ) or #result.verts < 3 then
            return true, errorModel( 5, name )
        end

        if istable( result.faces ) and not param.skip_tris then
            local suc, err = pcall( triangulate, result, param, thread, physics )

            -- Triangulation failed, error model CODE 6

            if not suc or err or not istable( result.tris ) or #result.tris < 3 then
                return true, errorModel( 6, name, err )
            end
        end
    else
        result.faces = nil
        result.verts = nil
    end

    return true, result
end


--[[
    NOTE: Although this function can be called with a valid but unregistered construct, that should only be done
    for convenience while developing. Not registering the construct means other addons ( like prop2mesh )
    will not have quick access to it.
]]

function Addon.construct.generate( construct, name, param, thread, physics )

    -- Non-existant construct, error model CODE 1

    if construct == nil then
        return true, errorModel( 1, name )
    end

    name = construct.data.name or "NO_NAME"

    -- Expected yield: true, true, table

    if thread and construct.data.canThread then
        return true, coroutine.create( function()
            coroutine.yield( getResult( construct, name, param, true, physics ) )
        end )
    end

    -- Expected return: true, table

    return getResult( construct, name, param, false, physics )
end


function Addon.construct.get( name, param, thread, physics )
    return Addon.construct.generate( construct_types[name], name, param, thread, physics )
end


--[[

    PREFAB SHAPES THAT CAN BE INSERTED INTO A VERTEX/CONVEX TABLE

]]

local simpleton
do

    -- copies and transforms vertex table, offsets face table by ibuffer
    local function copy( self, pos, rot, scale, ibuffer )
        local verts = {}
        local faces = table.Copy( self.faces )

        if ibuffer then
            for faceid = 1, #faces do
                local face = faces[faceid]
                for vertid = 1, #face do
                    face[vertid] = face[vertid] + ibuffer
                end
            end
        end

        for i = 1, #self.verts do
            local vertex = Vector( self.verts[i] )

            if scale then
                mulVec( vertex, scale )
            end
            if rot then
                rotateVec( vertex, rot )
            end
            if pos then
                addVec( vertex, pos )
            end

            verts[i] = vertex
        end

        return verts, faces
    end

    -- inserts a simpleton into verts, faces, convexes
    local function insert( self, verts, faces, convexes, pos, rot, scale, hull )
        local pverts, pfaces = self:copy( pos, rot, scale, ( verts and faces ) and #verts or 0 )

        if faces then
            for faceid = 1, #pfaces do
                faces[#faces + 1] = pfaces[faceid]
            end
        end

        if convexes and not hull then
            hull = {}
            convexes[#convexes + 1] = hull
        end

        if hull or verts then
            for i = 1, #pverts do
                local vertex = pverts[i]
                if hull then
                    hull[#hull + 1] = vertex
                end
                if verts then
                    verts[#verts + 1] = vertex
                end
            end
        end

        return pverts, pfaces
    end

    local types = {}

    function simpleton( name )
        return types[name]
    end

    local function register( name, pverts, pfaces )
        types[name] = { name = name, verts = pverts, faces = pfaces, copy = copy, insert = insert }
        return types[name] or types.cube
    end

    Addon.construct.simpleton = {
        get = simpleton,
        set = function ( name, pverts, pfaces )
            return { name = name, verts = pverts, faces = pfaces, copy = copy, insert = insert }
        end,
        register = register,
    }

    register( "plane",
    {
        Vector( -0.5, 0.5, 0 ),
        Vector( -0.5, -0.5, 0 ),
        Vector( 0.5, -0.5, 0 ),
        Vector( 0.5, 0.5, 0 ),
    },
    {
        { 1, 2, 3, 4 },

    } )

    register( "cube",
    {
        Vector( -0.5, 0.5, -0.5 ),
        Vector( -0.5, 0.5, 0.5 ),
        Vector( 0.5, 0.5, -0.5 ),
        Vector( 0.5, 0.5, 0.5 ),
        Vector( -0.5, -0.5, -0.5 ),
        Vector( -0.5, -0.5, 0.5 ),
        Vector( 0.5, -0.5, -0.5 ),
        Vector( 0.5, -0.5, 0.5 )
    },
    {
        { 1, 5, 6, 2 },
        { 5, 7, 8, 6 },
        { 7, 3, 4, 8 },
        { 3, 1, 2, 4 },
        { 4, 2, 6, 8 },
        { 1, 3, 7, 5 }
    } )

    types.slider_cube = types.cube

    register( "slider_wedge",
    {
        Vector( -0.5, -0.5, 0.5 ),
        Vector( -0.5, 0.5, 0.3 ),
        Vector( -0.5, -0.5, 0.3 ),
        Vector( 0.5, -0, -0.5 ),
        Vector( 0.5, -0.5, 0.3 ),
        Vector( 0.5, -0.5, 0.5 ),
        Vector( 0.5, 0.5, 0.5 ),
        Vector( 0.5, 0.5, 0.3 ),
        Vector( -0.5, 0.5, 0.5 ),
        Vector( -0.5, 0, -0.5 ),
    },
    {
        { 9, 1, 6, 7 },
        { 9, 2, 3, 1 },
        { 1, 3, 5, 6 },
        { 6, 5, 8, 7 },
        { 7, 8, 2, 9 },
        { 3, 10, 4, 5 },
        { 8, 4, 10, 2 },
        { 2, 10, 3 },
        { 5, 4, 8 },
    } )

    register( "slider_spike",
    {
        Vector( 0.5, -0.5, 0.3 ),
        Vector( -0.5, -0.5, 0.5 ),
        Vector( -0.5, -0.5, 0.3 ),
        Vector( 0.5, 0.5, 0.3 ),
        Vector( 0, 0, -0.5 ),
        Vector( -0.5, 0.5, 0.3 ),
        Vector( 0.5, 0.5, 0.5 ),
        Vector( 0.5, -0.5, 0.5 ),
        Vector( -0.5, 0.5, 0.5 ),
    },
    {
        { 3, 5, 1 },
        { 6, 5, 3 },
        { 1, 5, 4 },
        { 4, 5, 6 },
        { 9, 6, 3, 2 },
        { 2, 3, 1, 8 },
        { 8, 1, 4, 7 },
        { 7, 4, 6, 9 },
        { 7, 9, 2, 8 },
    } )

    register( "slider_blade",
    {
        Vector( 0.5, 0.5, 0.5 ),
        Vector( 0.5, -0.5, 0.5 ),
        Vector( 0.5, -0.25, 0.153185 ),
        Vector( 0.433013, -0.5, 0.173407 ),
        Vector( 0.433013, 0.5, 0.173407 ),
        Vector( 0.433013, -0.25, -0.173407 ),
        Vector( 0.25, -0.25, -0.412490 ),
        Vector( 0.25, -0.5, -0.065675 ),
        Vector( 0.25, 0.5, -0.065675 ),
        Vector( 0, -0.25, -0.5 ),
        Vector( 0, -0.5, -0.153185 ),
        Vector( -0, 0.5, -0.153185 ),
        Vector( -0.25, -0.25, -0.412490 ),
        Vector( -0.25, -0.5, -0.065675 ),
        Vector( -0.25, 0.5, -0.065675 ),
        Vector( -0.433013, -0.25, -0.173407 ),
        Vector( -0.433013, -0.5, 0.173407 ),
        Vector( -0.433013, 0.5, 0.173407 ),
        Vector( -0.5, -0.5, 0.5 ),
        Vector( -0.5, 0.5, 0.5 ),
        Vector( -0.5, -0.25, 0.153186 ),
    },
    {
        { 1, 2, 3 },
        { 2, 4, 6, 3 },
        { 3, 6, 5, 1 },
        { 4, 8, 7, 6 },
        { 6, 7, 9, 5 },
        { 11, 10, 7, 8 },
        { 9, 7, 10, 12 },
        { 14, 13, 10, 11 },
        { 12, 10, 13, 15 },
        { 17, 16, 13, 14 },
        { 15, 13, 16, 18 },
        { 21, 16, 17, 19 },
        { 20, 18, 16, 21 },
        { 20, 21, 19 },
        { 19, 17, 14, 11, 8, 4, 2 },
        { 1, 5, 9, 12, 15, 18, 20 },
        { 2, 1, 20, 19 },
     } )

end




--[[

    COMPLEX SHAPES

]]

registerType( "rail_slider", function( param, data, thread, physics )
    local verts, faces, convexes = {}

    if CLIENT then faces = {} end
    if physics then convexes = {} end


    -- base
    local bpos = isvector( param.PrimBPOS ) and Vector( param.PrimBPOS ) or Vector( 1, 1, 1 )
    local bdim = isvector( param.PrimBDIM ) and Vector( param.PrimBDIM ) or Vector( 1, 1, 1 )

    bpos.z = bpos.z + bdim.z * 0.5


    -- contact point
    local cpos = isvector( param.PrimCPOS ) and Vector( param.PrimCPOS ) or Vector( 1, 1, 1 )
    local crot = isangle( param.PrimCROT ) and Angle( param.PrimCROT ) or Angle()
    local cdim = isvector( param.PrimCDIM ) and Vector( param.PrimCDIM ) or Vector( 1, 1, 1 )

    cpos.y = cpos.y + cdim.y * 0.5
    cpos.z = cpos.z + cdim.z * 0.5


    -- base
    if tobool( param.PrimBASE ) then
        local cube = simpleton( "cube" )
        cube:insert( verts, faces, convexes, bpos, nil, bdim )
    end


    -- contact point
    local ctype = simpleton( tostring( param.PrimCTYPE ) )
    local cbits = math.floor( tonumber( param.PrimCENUMS ) or 0 )

    local cgap = tonumber( param.PrimCGAP ) or 0
    cgap = cgap + cdim.y

    local flip = {
        Vector( 1, 1, 1 ), -- front left
        Vector( 1, -1, 1 ), -- front right
        Vector( -1, 1, 1 ), -- rear left
        Vector( -1, -1, 1 ), -- rear right
    }

    local ENUM_CDOUBLE = 16
    local double = bit.band( cbits, ENUM_CDOUBLE ) == ENUM_CDOUBLE


    -- flange
    local fbits, getflange = math.floor( tonumber( param.PrimFENUMS ) or 0 )

    local ENUM_FENABLE = 1
    if bit.band( fbits, ENUM_FENABLE ) == ENUM_FENABLE then
        local fdim
        if double then
            fdim = Vector( cdim.x, cgap - cdim.y, cdim.z * 0.25 )
        else
            fdim = Vector( cdim.x, tonumber( param.PrimFGAP ) or 1, cdim.z * 0.25 )
        end

        if fdim.y > 0 then
            local ftype = simpleton( tostring( param.PrimFTYPE ) )

            function getflange( i, pos, rot, side )
                local s = bit.lshift( 1, i - 1 )

                if bit.band( fbits, s ) == s then
                    local pos = Vector( pos )

                    pos = pos - ( rot:Right() * ( fdim.y * 0.5 + cdim.y * 0.5 ) * side.y )
                    pos = pos + ( rot:Up() * ( cdim.z * 0.5 - fdim.z * 0.5 ) )

                    ftype:insert( verts, faces, convexes, pos, rot, fdim )
                end
            end
        end
    end


    -- builder
    for i = 1, 4 do
        local side = bit.lshift( 1, i - 1 )

        if bit.band( cbits, side ) == side then
            side = flip[i]

            local pos = cpos * side
            local rot = Angle( -crot.p * side.x, crot.y * side.x * side.y, crot.r * side.y )

            pos.x = pos.x + ( cdim.x * side.x * 0.5 )

            ctype:insert( verts, faces, convexes, pos, rot, cdim )

            if getflange then getflange( i, pos, rot, side ) end

            if double then
                pos = pos - ( rot:Right() * side.y * cgap )
                ctype:insert( verts, faces, convexes, pos, rot, cdim )
            end
        end
    end

    transform( verts, param.PrimMESHROT, param.PrimMESHPOS, thread )

    return { verts = verts, faces = faces, convexes = convexes }
end )



--[[

    BASIC SHAPES

]]

registerType( "cone", function( param, data, thread, physics )
    local verts, faces, convexes

    local maxseg = param.PrimMAXSEG or 32
    if maxseg < 3 then maxseg = 3 elseif maxseg > 32 then maxseg = 32 end
    local numseg = param.PrimNUMSEG or 32
    if numseg < 1 then numseg = 1 elseif numseg > maxseg then numseg = maxseg end

    local dx = ( isvector( param.PrimSIZE ) and param.PrimSIZE[1] or 1 ) * 0.5
    local dy = ( isvector( param.PrimSIZE ) and param.PrimSIZE[2] or 1 ) * 0.5
    local dz = ( isvector( param.PrimSIZE ) and param.PrimSIZE[3] or 1 ) * 0.5

    local tx = map( param.PrimTX or 0, -1, 1, -2, 2 )
    local ty = map( param.PrimTY or 0, -1, 1, -2, 2 )

    verts = {}
    for i = 0, numseg do
        local a = math.rad( ( i / maxseg ) * -360 )
        verts[#verts + 1] = Vector( math.sin( a ) * dx, math.cos( a ) * dy, -dz )
    end

    local c0 = #verts
    local c1 = c0 + 1
    local c2 = c0 + 2

    verts[#verts + 1] = Vector( 0, 0, -dz )
    verts[#verts + 1] = Vector( -dx * tx, dy * ty, dz )

    if CLIENT then
        faces = {}
        for i = 1, c0 - 1 do
            faces[#faces + 1] = { i, i + 1, c2 }
            faces[#faces + 1] = { i, c1, i + 1 }
        end
        if numseg ~= maxseg then
            faces[#faces + 1] = { c0, c1, c2 }
            faces[#faces + 1] = { c0 + 1, 1, c2 }
        end
    end

    if physics then
        if numseg ~= maxseg then
            convexes = { { verts[c1], verts[c2] }, { verts[c1], verts[c2] } }
            for i = 1, c0 do
                if ( i - 1 <= maxseg * 0.5 ) then
                    table.insert( convexes[1], verts[i] )
                end
                if ( i - 0 >= maxseg * 0.5 ) then
                    table.insert( convexes[2], verts[i] )
                end
            end
        else
            convexes = { verts }
        end
    end

    transform( verts, param.PrimMESHROT, param.PrimMESHPOS, thread )

    return { verts = verts, faces = faces, convexes = convexes }
end )


registerType( "cube", function( param, data, thread, physics )
    local verts, faces, convexes

    local dx = ( isvector( param.PrimSIZE ) and param.PrimSIZE[1] or 1 ) * 0.5
    local dy = ( isvector( param.PrimSIZE ) and param.PrimSIZE[2] or 1 ) * 0.5
    local dz = ( isvector( param.PrimSIZE ) and param.PrimSIZE[3] or 1 ) * 0.5

    local tx = 1 - ( param.PrimTX or 0 )
    local ty = 1 - ( param.PrimTY or 0 )

    if tx == 0 and ty == 0 then
        verts = {
            Vector( dx, -dy, -dz ),
            Vector( dx, dy, -dz ),
            Vector( -dx, -dy, -dz ),
            Vector( -dx, dy, -dz ),
            Vector( 0, 0, dz ),
        }
    else
        verts = {
            Vector( dx, -dy, -dz ),
            Vector( dx, dy, -dz ),
            Vector( dx * tx, dy * ty, dz ),
            Vector( dx * tx, -dy * ty, dz ),
            Vector( -dx, -dy, -dz ),
            Vector( -dx, dy, -dz ),
            Vector( -dx * tx, dy * ty, dz ),
            Vector( -dx * tx, -dy * ty, dz ),
        }
    end

    if CLIENT then
        if tx == 0 and ty == 0 then
            faces = {
                { 1, 2, 5 },
                { 2, 4, 5 },
                { 4, 3, 5 },
                { 3, 1, 5 },
                { 3, 4, 2, 1 },
            }
        else
            faces = {
                { 1, 2, 3, 4 },
                { 2, 6, 7, 3 },
                { 6, 5, 8, 7 },
                { 5, 1, 4, 8 },
                { 4, 3, 7, 8 },
                { 5, 6, 2, 1 },
            }
        end
    end

    if physics then
        convexes = { verts }
    end

    transform( verts, param.PrimMESHROT, param.PrimMESHPOS, thread )

    return { faces = faces, verts = verts, convexes = convexes }
end )


registerType( "cube_magic", function( param, data, thread, physics )
    local verts, faces, convexes

    local dx = ( isvector( param.PrimSIZE ) and param.PrimSIZE[1] or 1 ) * 0.5
    local dy = ( isvector( param.PrimSIZE ) and param.PrimSIZE[2] or 1 ) * 0.5
    local dz = ( isvector( param.PrimSIZE ) and param.PrimSIZE[3] or 1 ) * 0.5

    local tx = 1 - ( param.PrimTX or 0 )
    local ty = 1 - ( param.PrimTY or 0 )

    local dt = math.min( param.PrimDT or 1, dx, dy )

    if dt == dx or dt == dy then -- simple diff check is not correct, should be sine of taper angle?
        local construct = construct_types.cube
        return construct.factory( param, construct.data, thread, physics )
    end

    local sides
    for i = 1, 6 do
        local flag = bit.lshift( 1, i - 1 )
        local bits = bit.band( tonumber( param.PrimSIDES ) or 0, flag ) == flag

        if bits then
            if not sides then sides = {} end
            sides[i] = true
        end
    end

    if not sides then sides = { true, true, true, true, true, true } end

    local normals = {
        Vector( 1, 0, 0 ):Angle(),
        Vector( -1, 0, 0 ):Angle(),
        Vector( 0, 1, 0 ):Angle(),
        Vector( 0, -1, 0 ):Angle(),
        Vector( 0, 0, 1 ):Angle(),
        Vector( 0, 0, -1 ):Angle(),
    }

    local a = Vector( 1, -1, -1 )
    local b = Vector( 1, 1, -1 )
    local c = Vector( 1, 1, 1 )
    local d = Vector( 1, -1, 1 )

    verts = {}
    if physics then convexes = {} end
    if CLIENT then faces = {} end

    local ibuffer = 1

    for k, v in ipairs( normals ) do
        if not sides[k] then
            ibuffer = ibuffer - 8
        else
            local vec = Vector( a )
            rotateVec( vec, v )

            vec.x = vec.x * dx
            vec.y = vec.y * dy
            vec.z = vec.z * dz

            if vec.z > 0 then
                vec.x = vec.x * tx
                vec.y = vec.y * ty
            end

            verts[#verts + 1] = vec
            verts[#verts + 1] = vec - getNormalizedVec( vec ) * dt

            local vec = Vector( b )
            rotateVec( vec, v )

            vec.x = vec.x * dx
            vec.y = vec.y * dy
            vec.z = vec.z * dz

            if vec.z > 0 then
                vec.x = vec.x * tx
                vec.y = vec.y * ty
            end

            verts[#verts + 1] = vec
            verts[#verts + 1] = vec - getNormalizedVec( vec ) * dt

            local vec = Vector( c )
            rotateVec( vec, v )

            vec.x = vec.x * dx
            vec.y = vec.y * dy
            vec.z = vec.z * dz

            if vec.z > 0 then
                vec.x = vec.x * tx
                vec.y = vec.y * ty
            end

            verts[#verts + 1] = vec
            verts[#verts + 1] = vec - getNormalizedVec( vec ) * dt

            local vec = Vector( d )
            rotateVec( vec, v )

            vec.x = vec.x * dx
            vec.y = vec.y * dy
            vec.z = vec.z * dz

            if vec.z > 0 then
                vec.x = vec.x * tx
                vec.y = vec.y * ty
            end

            verts[#verts + 1] = vec
            verts[#verts + 1] = vec - getNormalizedVec( vec ) * dt

            if physics then
                local count = #verts
                convexes[#convexes + 1] = {
                    verts[count - 0],
                    verts[count - 1],
                    verts[count - 2],
                    verts[count - 3],
                    verts[count - 4],
                    verts[count - 5],
                    verts[count - 6],
                    verts[count - 7],
                }
            end

            if CLIENT then
                local n = ( k - 1 ) * 8 + ibuffer
                faces[#faces + 1] = { n + 0, n + 2, n + 4, n + 6 }
                faces[#faces + 1] = { n + 3, n + 1, n + 7, n + 5 }
                faces[#faces + 1] = { n + 1, n + 0, n + 6, n + 7 }
                faces[#faces + 1] = { n + 2, n + 3, n + 5, n + 4 }
                faces[#faces + 1] = { n + 5, n + 7, n + 6, n + 4 }
                faces[#faces + 1] = { n + 0, n + 1, n + 3, n + 2 }
            end
        end
    end

    transform( verts, param.PrimMESHROT, param.PrimMESHPOS, thread )

    return { verts = verts, faces = faces, convexes = convexes }
end )


registerType( "cube_hole", function( param, data, thread, physics )
    local verts, faces, convexes

    local dx = ( isvector( param.PrimSIZE ) and param.PrimSIZE[1] or 1 ) * 0.5
    local dy = ( isvector( param.PrimSIZE ) and param.PrimSIZE[2] or 1 ) * 0.5
    local dz = ( isvector( param.PrimSIZE ) and param.PrimSIZE[3] or 1 ) * 0.5
    local dt = math.min( param.PrimDT or 1, dx, dy )

    if dt == dx or dt == dy then
        local construct = construct_types.cube
        return construct.factory( param, construct.data, thread, physics )
    end

    local numseg = param.PrimNUMSEG or 4
    if numseg > 4 then numseg = 4 elseif numseg < 1 then numseg = 1 end

    local numring = 4 * math.Round( ( param.PrimSUBDIV or 32 ) / 4 )
    if numring < 4 then numring = 4 elseif numring > 32 then numring = 32 end

    local cube_angle = Angle( 0, 90, 0 )
    local cube_corner0 = Vector( 1, 0, 0 )
    local cube_corner1 = Vector( 1, 1, 0 )
    local cube_corner2 = Vector( 0, 1, 0 )

    local ring_steps0 = numring / 4
    local ring_steps1 = numring / 2
    local capped = numseg ~= 4
    if CLIENT then
        faces = capped and { { 8, 7, 1, 4 } } or {}
    end

    verts = {}

    if physics then
        convexes = {}
    end

    for i = 0, numseg - 1 do
        rotateVec( cube_corner0, cube_angle )
        rotateVec( cube_corner1, cube_angle )
        rotateVec( cube_corner2, cube_angle )

        local part
        if physics then part = {} end

        verts[#verts + 1] = Vector( cube_corner0.x * dx, cube_corner0.y * dy, -dz )
        verts[#verts + 1] = Vector( cube_corner1.x * dx, cube_corner1.y * dy, -dz )
        verts[#verts + 1] = Vector( cube_corner2.x * dx, cube_corner2.y * dy, -dz )
        verts[#verts + 1] = Vector( cube_corner0.x * dx, cube_corner0.y * dy, dz )
        verts[#verts + 1] = Vector( cube_corner1.x * dx, cube_corner1.y * dy, dz )
        verts[#verts + 1] = Vector( cube_corner2.x * dx, cube_corner2.y * dy, dz )

        local count_end0 = #verts
        if CLIENT then
            faces[#faces + 1] = { count_end0 - 5, count_end0 - 4, count_end0 - 1, count_end0 - 2 }
            faces[#faces + 1] = { count_end0 - 4, count_end0 - 3, count_end0 - 0, count_end0 - 1 }
        end

        local ring_angle = -i * 90
        for j = 0, ring_steps0 do
            local a = math.rad( ( j / numring ) * -360 + ring_angle )
            verts[#verts + 1] = Vector( math.sin( a ) * ( dx - dt ), math.cos( a ) * ( dy - dt ), -dz )
            verts[#verts + 1] = Vector( math.sin( a ) * ( dx - dt ), math.cos( a ) * ( dy - dt ), dz )
        end

        local count_end1 = #verts
        if physics then
            convexes[#convexes + 1] = {
                verts[count_end0 - 0],
                verts[count_end0 - 3],
                verts[count_end0 - 4],
                verts[count_end0 - 1],
                verts[count_end1 - 0],
                verts[count_end1 - 1],
                verts[count_end1 - ring_steps1 * 0.5],
                verts[count_end1 - ring_steps1 * 0.5 - 1],
            }
            convexes[#convexes + 1] = {
                verts[count_end0 - 2],
                verts[count_end0 - 5],
                verts[count_end0 - 4],
                verts[count_end0 - 1],
                verts[count_end1 - ring_steps1],
                verts[count_end1 - ring_steps1 - 1],
                verts[count_end1 - ring_steps1 * 0.5],
                verts[count_end1 - ring_steps1 * 0.5 - 1],
            }
        end

        if CLIENT then
            faces[#faces + 1] = { count_end0 - 1, count_end0 - 0, count_end1 - 0 }
            faces[#faces + 1] = { count_end0 - 1, count_end1 - ring_steps1, count_end0 - 2 }
            faces[#faces + 1] = { count_end0 - 4, count_end1 - 1, count_end0 - 3 }
            faces[#faces + 1] = { count_end0 - 4, count_end0 - 5, count_end1 - ring_steps1 - 1 }

            for j = 0, ring_steps0 - 1 do
                local count_end2 = count_end1 - j * 2
                faces[#faces + 1] = { count_end0 - 1, count_end2, count_end2 - 2 }
                faces[#faces + 1] = { count_end0 - 4, count_end2 - 3, count_end2 - 1 }
                faces[#faces + 1] = { count_end2, count_end2 - 1, count_end2 - 3, count_end2 - 2 }
            end

            if capped and i == numseg  - 1 then
                faces[#faces + 1] = { count_end0, count_end0 - 3, count_end1 - 1, count_end1 }
            end
        end
    end

    transform( verts, param.PrimMESHROT, param.PrimMESHPOS, thread )

    return { verts = verts, faces = faces, convexes = convexes }
end )


registerType( "cylinder", function( param, data, thread, physics )
    local verts, faces, convexes

    local maxseg = param.PrimMAXSEG or 32
    if maxseg < 3 then maxseg = 3 elseif maxseg > 32 then maxseg = 32 end
    local numseg = param.PrimNUMSEG or 32
    if numseg < 1 then numseg = 1 elseif numseg > maxseg then numseg = maxseg end

    local dx = ( isvector( param.PrimSIZE ) and param.PrimSIZE[1] or 1 ) * 0.5
    local dy = ( isvector( param.PrimSIZE ) and param.PrimSIZE[2] or 1 ) * 0.5
    local dz = ( isvector( param.PrimSIZE ) and param.PrimSIZE[3] or 1 ) * 0.5

    local tx = 1 - ( param.PrimTX or 0 )
    local ty = 1 - ( param.PrimTY or 0 )

    verts = {}
    if tx == 0 and ty == 0 then
        for i = 0, numseg do
            local a = math.rad( ( i / maxseg ) * -360 )
            verts[#verts + 1] = Vector( math.sin( a ) * dx, math.cos( a ) * dy, -dz )
        end
    else
        for i = 0, numseg do
            local a = math.rad( ( i / maxseg ) * -360 )
            verts[#verts + 1] = Vector( math.sin( a ) * dx, math.cos( a ) * dy, -dz )
            verts[#verts + 1] = Vector( math.sin( a ) * ( dx * tx ), math.cos( a ) * ( dy * ty ), dz )
        end
    end

    local c0 = #verts
    local c1 = c0 + 1
    local c2 = c0 + 2

    verts[#verts + 1] = Vector( 0, 0, -dz )
    verts[#verts + 1] = Vector( 0, 0, dz )

    if CLIENT then
        faces = {}
        if tx == 0 and ty == 0 then
            for i = 1, c0 - 1 do
                faces[#faces + 1] = { i, i + 1, c2 }
                faces[#faces + 1] = { i, c1, i + 1 }
            end

            if numseg ~= maxseg then
                faces[#faces + 1] = { c0, c1, c2 }
                faces[#faces + 1] = { c0 + 1, 1, c2 }
            end
        else
            for i = 1, c0 - 2, 2 do
                faces[#faces + 1] = { i, i + 2, i + 3, i + 1 }
                faces[#faces + 1] = { i, c1, i + 2 }
                faces[#faces + 1] = { i + 1, i + 3, c2 }
            end

            if numseg ~= maxseg then
                faces[#faces + 1] = { c1, c2, c0, c0 - 1 }
                faces[#faces + 1] = { c1, 1, 2, c2 }
            end
        end
    end

    if physics then
        if numseg ~= maxseg then
            convexes = { { verts[c1], verts[c2] }, { verts[c1], verts[c2] } }
            if tx == 0 and ty == 0 then
                for i = 1, c0 do
                    if ( i - 1 <= maxseg * 0.5 ) then
                        table.insert( convexes[1], verts[i] )
                    end
                    if ( i - 1 >= maxseg * 0.5 ) then
                        table.insert( convexes[2], verts[i] )
                    end
                end
            else
                for i = 1, c0 do
                    if i - ( maxseg > 3 and 2 or 1 ) <= maxseg then
                        table.insert( convexes[1], verts[i] )
                    end
                    if i - 1 >= maxseg then
                        table.insert( convexes[2], verts[i] )
                    end
                end
            end
        else
            convexes = { verts }
        end
    end

    transform( verts, param.PrimMESHROT, param.PrimMESHPOS, thread )

    return { verts = verts, faces = faces, convexes = convexes }
end )


registerType( "dome", function( param, data, thread, physics )
    return construct_types.sphere.factory( param, data, thread, physics )
end, { isDome = true, canThread = true } )


registerType( "pyramid", function( param, data, thread, physics )
    local verts, faces, convexes

    local dx = ( isvector( param.PrimSIZE ) and param.PrimSIZE[1] or 1 ) * 0.5
    local dy = ( isvector( param.PrimSIZE ) and param.PrimSIZE[2] or 1 ) * 0.5
    local dz = ( isvector( param.PrimSIZE ) and param.PrimSIZE[3] or 1 ) * 0.5

    local tx = map( param.PrimTX or 0, -1, 1, -2, 2 )
    local ty = map( param.PrimTY or 0, -1, 1, -2, 2 )

    verts = {
        Vector( dx, -dy, -dz ),
        Vector( dx, dy, -dz ),
        Vector( -dx, -dy, -dz ),
        Vector( -dx, dy, -dz ),
        Vector( -dx * tx, dy * ty, dz ),
    }

    if CLIENT then
        faces = {
            { 1, 2, 5 },
            { 2, 4, 5 },
            { 4, 3, 5 },
            { 3, 1, 5 },
            { 3, 4, 2, 1 },
        }
    end

    if physics then
        convexes = { verts }
    end

    transform( verts, param.PrimMESHROT, param.PrimMESHPOS, thread )

    return { verts = verts, faces = faces, convexes = convexes }
end )


registerType( "sphere", function( param, data, thread, physics )
    local verts, faces, convexes

    local subdiv = 2 * math.Round( ( param.PrimSUBDIV or 32 ) / 2 )
    if subdiv < 4 then subdiv = 4 elseif subdiv > 32 then subdiv = 32 end

    local dx = ( isvector( param.PrimSIZE ) and param.PrimSIZE[1] or 1 ) * 0.5
    local dy = ( isvector( param.PrimSIZE ) and param.PrimSIZE[2] or 1 ) * 0.5
    local dz = ( isvector( param.PrimSIZE ) and param.PrimSIZE[3] or 1 ) * 0.5

    local isdome = data.isDome

    if CLIENT then
        verts, faces = {}, {}

        for y = 0, isdome and subdiv * 0.5 or subdiv do
            local v = y / subdiv
            local t = v * pi

            local cosPi = math.cos( t )
            local sinPi = math.sin( t )

            for x = 0, subdiv  do
                local u = x / subdiv
                local p = u * tau

                local cosTau = math.cos( p )
                local sinTau = math.sin( p )

                verts[#verts + 1] = Vector( -dx * cosTau * sinPi, dy * sinTau * sinPi, dz * cosPi )
            end

            if y > 0 then
                local i = #verts - 2 * ( subdiv + 1 )
                while ( i + subdiv + 2 ) < #verts do
                    faces[#faces + 1] = { i + 1, i + 2, i + subdiv + 3, i + subdiv + 2 }
                    i = i + 1
                end
            end
        end

        if isdome then
            local buf = #verts
            local cap = {}

            for i = 0, subdiv do
                cap[#cap + 1] = i + buf - subdiv
            end

            faces[#faces + 1] = cap
        end

        transform( verts, param.PrimMESHROT, param.PrimMESHPOS, thread )
    end

    if physics then
        local limit = 8

        if verts and subdiv <= limit then
            convexes = { verts }
        else

            -- sphere vertex count can increase dramatically with each subdivision
            -- clamping this is important !!!!

            local subdiv = 2 * math.Round( math.min( subdiv, limit ) / 2 )

            convexes = {}
            for y = 0, isdome and subdiv * 0.5 or subdiv do
                local v = y / subdiv
                local t = v * pi

                local cosPi = math.cos( t )
                local sinPi = math.sin( t )

                for x = 0, subdiv do
                    local u = x / subdiv
                    local p = u * tau

                    local cosTau = math.cos( p )
                    local sinTau = math.sin( p )

                    convexes[#convexes + 1] = Vector( -dx * cosTau * sinPi, dy * sinTau * sinPi, dz * cosPi )
                end
            end

            transform( convexes, param.PrimMESHROT, param.PrimMESHPOS, thread )

            convexes = { convexes }
        end
    end

    return { faces = faces, verts = verts, convexes = convexes }
end, { canThread = true } )


registerType( "torus", function( param, data, thread, physics )
    local verts, faces, convexes

    local maxseg = param.PrimMAXSEG or 32
    if maxseg < 3 then maxseg = 3 elseif maxseg > 32 then maxseg = 32 end
    local numseg = param.PrimNUMSEG or 32
    if numseg < 1 then numseg = 1 elseif numseg > maxseg then numseg = maxseg end
    local numring = param.PrimSUBDIV or 16
    if numring < 3 then numring = 3 elseif numring > 32 then numring = 32 end

    local dx = ( isvector( param.PrimSIZE ) and param.PrimSIZE[1] or 1 ) * 0.5
    local dy = ( isvector( param.PrimSIZE ) and param.PrimSIZE[2] or 1 ) * 0.5
    local dz = ( isvector( param.PrimSIZE ) and param.PrimSIZE[3] or 1 ) * 0.5
    local dt = math.min( ( param.PrimDT or 1 ) * 0.5, dx, dy )

    if dt == dx or dt == dy then
    end

    if CLIENT then
        verts = {}
        for j = 0, numring do
            for i = 0, maxseg do
                local u = i / maxseg * tau
                local v = j / numring * tau
                verts[#verts + 1] = Vector( ( dx + dt * math.cos( v ) ) * math.cos( u ), ( dy + dt * math.cos( v ) ) * math.sin( u ), dz * math.sin( v ) )
            end
        end

        faces = {}
        for j = 1, numring do
            for i = 1, numseg do
                faces[#faces + 1] = { ( maxseg + 1 ) * j + i, ( maxseg + 1 ) * ( j - 1 ) + i, ( maxseg + 1 ) * ( j - 1 ) + i + 1, ( maxseg + 1 ) * j + i + 1 }
            end
        end

        if numseg ~= maxseg then
            local cap1 = {}
            local cap2 = {}

            for j = 1, numring do
                cap1[#cap1 + 1] = ( maxseg + 1 ) * j + 1
                cap2[#cap2 + 1] = ( maxseg + 1 ) * ( numring - j ) + numseg + 1
            end

            faces[#faces + 1] = cap1
            faces[#faces + 1] = cap2
        end

        transform( verts, param.PrimMESHROT, param.PrimMESHPOS, thread )
    end

    if physics then
        local numring = math.min( 4, numring ) -- we want a lower detailed convexes model
        local pverts = {}
        for j = 0, numring do
            for i = 0, maxseg do
                local u = i / maxseg * tau
                local v = j / numring * tau
                pverts[#pverts + 1] = Vector( ( dx + dt * math.cos( v ) ) * math.cos( u ), ( dy + dt * math.cos( v ) ) * math.sin( u ), dz * math.sin( v ) )
            end
        end

        convexes = {}
        for j = 1, numring do
            for i = 1, numseg do
                if not convexes[i] then
                    convexes[i] = {}
                end
                local part = convexes[i]
                part[#part + 1] = pverts[( maxseg + 1 ) * j + i]
                part[#part + 1] = pverts[( maxseg + 1 ) * ( j - 1 ) + i]
                part[#part + 1] = pverts[( maxseg + 1 ) * ( j - 1 ) + i + 1]
                part[#part + 1] = pverts[( maxseg + 1 ) * j + i + 1]
            end
        end

        transform( pverts, param.PrimMESHROT, param.PrimMESHPOS, thread )
    end

    return { verts = verts, faces = faces, convexes = convexes }
end, { canThread = true } )


registerType( "tube", function( param, data, thread, physics )
    local verts, faces, convexes

    local maxseg = param.PrimMAXSEG or 32
    if maxseg < 3 then maxseg = 3 elseif maxseg > 32 then maxseg = 32 end
    local numseg = param.PrimNUMSEG or 32
    if numseg < 1 then numseg = 1 elseif numseg > maxseg then numseg = maxseg end

    local dx = ( isvector( param.PrimSIZE ) and param.PrimSIZE[1] or 1 ) * 0.5
    local dy = ( isvector( param.PrimSIZE ) and param.PrimSIZE[2] or 1 ) * 0.5
    local dz = ( isvector( param.PrimSIZE ) and param.PrimSIZE[3] or 1 ) * 0.5
    local dt = math.min( param.PrimDT or 1, dx, dy )

    if dt == dx or dt == dy then -- MAY NEED TO REFACTOR THIS IN THE FUTURE IF CYLINDER MODIFIERS ARE CHANGED
        local construct = construct_types.cylinder
        return construct.factory( param, construct.data, thread, physics )
    end

    local tx = 1 - ( param.PrimTX or 0 )
    local ty = 1 - ( param.PrimTY or 0 )
    local iscone = tx == 0 and ty == 0

    verts = {}
    if iscone then
        for i = 0, numseg do
            local a = math.rad( ( i / maxseg ) * -360 )
            verts[#verts + 1] = Vector( math.sin( a ) * dx, math.cos( a ) * dy, -dz )
            verts[#verts + 1] = Vector( math.sin( a ) * ( dx - dt ), math.cos( a ) * ( dy - dt ), -dz )
        end
    else
        for i = 0, numseg do
            local a = math.rad( ( i / maxseg ) * -360 )
            verts[#verts + 1] = Vector( math.sin( a ) * dx, math.cos( a ) * dy, -dz )
            verts[#verts + 1] = Vector( math.sin( a ) * ( dx * tx ), math.cos( a ) * ( dy * ty ), dz )
            verts[#verts + 1] = Vector( math.sin( a ) * ( dx - dt ), math.cos( a ) * ( dy - dt ), -dz )
            verts[#verts + 1] = Vector( math.sin( a ) * ( ( dx - dt ) * tx ), math.cos( a ) * ( ( dy - dt ) * ty ), dz )
        end
    end

    local c0 = #verts
    local c1 = c0 + 1
    local c2 = c0 + 2

    verts[#verts + 1] = Vector( 0, 0, -dz )
    verts[#verts + 1] = Vector( 0, 0, dz )

    if CLIENT then
        faces = {}
        if iscone then
            for i = 1, c0 - 2, 2 do
                faces[#faces + 1] = { i + 3, i + 2, i + 0, i + 1 } -- bottom
                faces[#faces + 1] = { i + 0, i + 2, c2 } -- outside
                faces[#faces + 1] = { i + 3, i + 1, c2 } -- inside
            end

            if numseg ~= maxseg then
                local i = numseg * 2 + 1
                faces[#faces + 1] = { i, i + 1, c2 }
                faces[#faces + 1] = { 2, 1, c2 }
            end
        else
            for i = 1, c0 - 4, 4 do
                faces[#faces + 1] = { i + 0, i + 2, i + 6, i + 4 } -- bottom
                faces[#faces + 1] = { i + 4, i + 5, i + 1, i + 0 } -- outside
                faces[#faces + 1] = { i + 2, i + 3, i + 7, i + 6 } -- inside
                faces[#faces + 1] = { i + 5, i + 7, i + 3, i + 1 } -- top
            end

            if numseg ~= maxseg then
                local i = numseg * 4 + 1
                faces[#faces + 1] = { i + 2, i + 3, i + 1, i + 0 }
                faces[#faces + 1] = { 1, 2, 4, 3 }
            end
        end
    end

    if physics then
        convexes = {}
        if iscone then
            for i = 1, c0 - 2, 2 do
                convexes[#convexes + 1] = { verts[c2], verts[i], verts[i + 1], verts[i + 2], verts[i + 3] }
            end
        else
            for i = 1, c0 - 4, 4 do
                convexes[#convexes + 1] = { verts[i], verts[i + 1], verts[i + 2], verts[i + 3], verts[i + 4], verts[i + 5], verts[i + 6], verts[i + 7] }
            end
        end
    end

    transform( verts, param.PrimMESHROT, param.PrimMESHPOS, thread )

    return { verts = verts, faces = faces, convexes = convexes }
end )


registerType( "wedge", function( param, data, thread, physics )
    local verts, faces, convexes

    local dx = ( isvector( param.PrimSIZE ) and param.PrimSIZE[1] or 1 ) * 0.5
    local dy = ( isvector( param.PrimSIZE ) and param.PrimSIZE[2] or 1 ) * 0.5
    local dz = ( isvector( param.PrimSIZE ) and param.PrimSIZE[3] or 1 ) * 0.5

    local tx = map( param.PrimTX or 0, -1, 1, -2, 2 )
    local ty = 1 - ( param.PrimTY or 0 )

    if ty == 0 then
        verts = {
            Vector( dx, -dy, -dz ),
            Vector( dx, dy, -dz ),
            Vector( -dx, -dy, -dz ),
            Vector( -dx, dy, -dz ),
            Vector( -dx * tx, 0, dz ),
        }
    else
        verts = {
            Vector( dx, -dy, -dz ),
            Vector( dx, dy, -dz ),
            Vector( -dx, -dy, -dz ),
            Vector( -dx, dy, -dz ),
            Vector( -dx * tx, dy * ty, dz ),
            Vector( -dx * tx, -dy * ty, dz ),
        }
    end

    if CLIENT then
        if ty == 0 then
            faces = {
                { 1, 2, 5 },
                { 2, 4, 5 },
                { 4, 3, 5 },
                { 3, 1, 5 },
                { 3, 4, 2, 1 },
            }
        else
            faces = {
                { 1, 2, 5, 6 },
                { 2, 4, 5 },
                { 4, 3, 6, 5 },
                { 3, 1, 6 },
                { 3, 4, 2, 1 },
            }
        end
    end

    if physics then
        convexes = { verts }
    end

    transform( verts, param.PrimMESHROT, param.PrimMESHPOS, thread )

    return { verts = verts, faces = faces, convexes = convexes }
end )


registerType( "wedge_corner", function( param, data, thread, physics )
    local verts, faces, convexes

    local dx = ( isvector( param.PrimSIZE ) and param.PrimSIZE[1] or 1 ) * 0.5
    local dy = ( isvector( param.PrimSIZE ) and param.PrimSIZE[2] or 1 ) * 0.5
    local dz = ( isvector( param.PrimSIZE ) and param.PrimSIZE[3] or 1 ) * 0.5

    local tx = map( param.PrimTX or 0, -1, 1, -2, 2 )
    local ty = map( param.PrimTY or 0, -1, 1, 0, 2 )

    verts = {
        Vector( dx, dy, -dz ),
        Vector( -dx, -dy, -dz ),
        Vector( -dx, dy, -dz ),
        Vector( -dx * tx, dy * ty, dz ),
    }

    if CLIENT then
        faces = {
            { 1, 3, 4 },
            { 2, 1, 4 },
            { 3, 2, 4 },
            { 1, 2, 3 },
        }
    end

    if physics then
        convexes =  { verts }
    end

    transform( verts, param.PrimMESHROT, param.PrimMESHPOS, thread )

    return { verts = verts, faces = faces, convexes = convexes }
end )
