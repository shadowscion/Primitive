
do

    local class = {}

    local generator = {
        data = { name = "rail_slider" },

        factory = function( param, data, thread, physics )
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
                local cube = Primitive.construct.simpleton.get( "cube" )
                cube:insert( verts, faces, convexes, bpos, nil, bdim )
            end


            -- contact point
            local cube = Primitive.construct.simpleton.get( "cube" )
            local cbits = math.floor( tonumber( param.PrimCENUMS ) or 0 )

            local cgap = tonumber( param.PrimCGAP ) or 0
            cgap = cgap + cdim.y

            local flip = {
                Vector( 1, 1, 1 ), -- front left
                Vector( 1, -1, 1 ), -- front right
                Vector( -1, 1, 1 ), -- rear left
                Vector( -1, -1, 1 ), -- rear right
            }

            local double = bit.band( cbits, 16 ) == 16


            -- flange
            local fbits = math.floor( tonumber( param.PrimFENUMS ) or 0 )

            local getflange
            if bit.band( fbits, 1 ) == 1 then
                function getflange( i, pos, rot, side )

                    cube:insert( verts, faces, convexes, pos + Vector( 0, 0, 25 ), nil, bdim )

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

                    cube:insert( verts, faces, convexes, pos, rot, cdim )

                    if getflange then getflange( i, pos, rot, side ) end

                    if double then
                        pos = pos - ( rot:Right() * side.y * cgap )
                        cube:insert( verts, faces, convexes, pos, rot, cdim )
                    end
                end
            end

            Primitive.construct.util.transform( verts, param.PrimMESHROT, param.PrimMESHPOS, thread )

            return { verts = verts, faces = faces, convexes = convexes }
        end,
    }


    function class:PrimitiveGetConstruct()
        local keys = self:PrimitiveGetKeys()
        return Primitive.construct.generate( generator, generator.data.name, keys, true, keys.PrimMESHPHYS )
        --return Primitive.construct.get( "rail_slider", keys, true, keys.PrimMESHPHYS )
    end


    function class:PrimitiveSetupDataTables()

        self:PrimitiveVar( "PrimBASE", "Bool", { category = "base", title = "enabled", panel = "bool" }, true )
        self:PrimitiveVar( "PrimBPOS", "Vector", { category = "base", title = "offset", panel = "vector", min = Vector( -500, -500, -500 ), max = Vector( 500, 500, 500) }, true )
        self:PrimitiveVar( "PrimBDIM", "Vector", { category = "base", title = "size", panel = "vector", min = Vector( 1, 1, 1 ), max = Vector( 100, 100, 100) }, true )

        local types = { wedge = "wedge", spike = "spike", cube = "cube", blade = "blade" }
        self:PrimitiveVar( "PrimCTYPE", "String", { category = "contact point", title = "type", panel = "combo", values = types }, true )

        local options = { "front left", "front right", "rear left", "rear right", "double" }
        self:PrimitiveVar( "PrimCENUMS", "Int", { category = "contact point", title = "options", panel = "bitfield", lbl = options }, true )
        self:PrimitiveVar( "PrimCGAP", "Float", { category = "contact point", title = "gap", panel = "float", min = 0, max = 100 }, true )
        self:PrimitiveVar( "PrimCPOS", "Vector", { category = "contact point", title = "offset", panel = "vector", min = Vector( 0, 0, 0 ), max = Vector( 500, 500, 500) }, true )
        self:PrimitiveVar( "PrimCROT", "Angle", { category = "contact point", title = "rotate", panel = "angle" }, true )
        self:PrimitiveVar( "PrimCDIM", "Vector", { category = "contact point", title = "size", panel = "vector", min = Vector( 1, 1, 1 ), max = Vector( 100, 100, 100) }, true )

        local options = { "enabled", "automatic", "front left", "front right", "rear left", "rear right" }
        self:PrimitiveVar( "PrimFENUMS", "Int", { category = "flange", title = "options", panel = "bitfield", lbl = options }, true )

        self:PrimitiveVar( "PrimFPOS", "Vector", { category = "flange", title = "offset", panel = "vector", min = Vector( 0, 0, 0 ), max = Vector( 500, 500, 500) }, true )
        self:PrimitiveVar( "PrimFROT", "Angle", { category = "flange", title = "rotate", panel = "angle" }, true )
        self:PrimitiveVar( "PrimFDIM", "Vector", { category = "flange", title = "size", panel = "vector", min = Vector( 1, 1, 1 ), max = Vector( 100, 100, 100) }, true )

    end


    function class:PrimitiveSetup( initial, args )
        if initial and SERVER then
            duplicator.StoreEntityModifier( self, "mass", { Mass = 100 } )
            duplicator.StoreBoneModifier( self, 0, "physprops", { GravityToggle = true, Material = "gmod_ice" } )
        end

        self:SetPrimBASE( true )
        self:SetPrimBDIM( Vector( 24, 24, 1 ) )

        self:SetPrimCTYPE( "blade" )
        self:SetPrimCENUMS( bit.bor( 1, 1, 2, 4, 8 ) )
        self:SetPrimCPOS( Vector( 0, 50, 0 ) )
        self:SetPrimCDIM( Vector( 24, 1, 12 ) )

        self:SetPrimFENUMS( bit.bor( 1, 1, 2 ) )

        self:SetPrimMESHPHYS( true )
        self:SetPrimMESHUV( 48 )
    end


    local spawnlist
    if CLIENT then
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
                editor:HideRow( "PrimCGAP", bit.band( val, 16 ) == 16 ) -- double
            end,

            PrimFENUMS = function( self, editor, name, val )
                local children = editor.rows[name].ChildNodes:GetChildren()

                if bit.band( val, 1 ) == 1 then
                    -- check if 'enabled' flag is set

                    children[2]:SetVisible( true )

                    local enabled = true

                    if bit.band( val, 2 ) == 2 then
                        -- check if 'automatic' flag is set
                        enabled = false

                    end

                    for i = 3, #children do
                        children[i]:SetVisible( enabled )
                    end

                    editor:HideRow( "PrimFPOS", enabled )
                    editor:HideRow( "PrimFROT", enabled )
                    editor:HideRow( "PrimFDIM", enabled )

                    if editor.m_bInitialzied then
                        editor:ScrollToChild( editor.categories.flange )
                    end
                else
                    -- else hide other options

                    for i = 2, #children do
                        children[i]:SetVisible( false )
                    end

                    editor:HideRow( "PrimFPOS", false )
                    editor:HideRow( "PrimFROT", false )
                    editor:HideRow( "PrimFDIM", false )
                end
            end,
        }

        function class:EditorCallback( editor, name, val )
            if callbacks[name] then callbacks[name]( self, editor, name, val ) end
        end
    end

    Primitive.funcs.registerClass( "rail_slider", class, spawnlist )

end

