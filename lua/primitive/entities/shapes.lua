
local class = {}

local typen = { "cone", "cube", "cube_magic", "cube_hole", "cylinder", "dome", "plane", "pyramid", "sphere", "torus", "tube", "wedge", "wedge_corner" }
local typek, defaults = {}, {}

do
    for k, v in pairs( typen ) do
        typek[v] = v
    end

    defaults = {
        generic = {
            PrimDT = 4,
            PrimMAXSEG = 16,
            PrimMESHSMOOTH = 0,
            PrimNUMSEG = 16,
            PrimSIDES = 0,
            PrimSIZE = Vector( 48, 48, 48 ),
            PrimSUBDIV = 8,
            PrimTX = 0,
            PrimTY = 0,
        },
        cone = {
            PrimMAXSEG = 16,
            PrimMESHSMOOTH = 45,
            PrimNUMSEG = 16,
            PrimSIZE = Vector( 48, 48, 48 ),
            PrimTX = 0,
            PrimTY = 0,
            PrimTYPE = "cone",
        },
        cube = {
            PrimMESHSMOOTH = 0,
            PrimSIZE = Vector( 48, 48, 48 ),
            PrimTX = 0,
            PrimTY = 0,
            PrimTYPE = "cube",
        },
        cube_hole = {
            PrimDT = 4,
            PrimMESHSMOOTH = 65,
            PrimNUMSEG = 4,
            PrimSIZE = Vector( 48, 48, 48 ),
            PrimSUBDIV = 16,
            PrimTYPE = "cube_hole",
        },
        cube_magic = {
            PrimDT = 4,
            PrimMESHSMOOTH = 0,
            PrimSIDES = 63,
            PrimSIZE = Vector( 48, 48, 48 ),
            PrimTX = 0,
            PrimTY = 0,
            PrimTYPE = "cube_magic",
        },
        cylinder = {
            PrimMAXSEG = 16,
            PrimMESHSMOOTH = 65,
            PrimNUMSEG = 16,
            PrimSIZE = Vector( 48, 48, 48 ),
            PrimTX = 0,
            PrimTY = 0,
            PrimTYPE = "cylinder",
        },
        dome = {
            PrimMESHSMOOTH = 65,
            PrimSIZE = Vector( 48, 48, 48 ),
            PrimSUBDIV = 8,
            PrimTYPE = "dome",
        },
        plane = {
            PrimMESHSMOOTH = 0,
            PrimSIZE = Vector( 48, 48, 48 ),
            PrimTY = 0,
            PrimTYPE = "plane",
        },
        pyramid = {
            PrimMESHSMOOTH = 0,
            PrimSIZE = Vector( 48, 48, 48 ),
            PrimTX = 0,
            PrimTY = 0,
            PrimTYPE = "pyramid",
        },
        sphere = {
            PrimMESHSMOOTH = 65,
            PrimSIZE = Vector( 48, 48, 48 ),
            PrimSUBDIV = 8,
            PrimTYPE = "sphere",
        },
        torus = {
            PrimDT = 6,
            PrimMAXSEG = 16,
            PrimMESHSMOOTH = 65,
            PrimNUMSEG = 16,
            PrimSIZE = Vector( 48, 48, 6 ),
            PrimSUBDIV = 16,
            PrimTYPE = "torus",
        },
        tube = {
            PrimDT = 4,
            PrimMAXSEG = 16,
            PrimMESHSMOOTH = 65,
            PrimNUMSEG = 16,
            PrimSIZE = Vector( 48, 48, 48 ),
            PrimTX = 0,
            PrimTY = 0,
            PrimTYPE = "tube",
        },
        wedge = {
            PrimMESHSMOOTH = 0,
            PrimSIZE = Vector( 48, 48, 48 ),
            PrimTX = 0.5,
            PrimTY = 0,
            PrimTYPE = "wedge",
        },
        wedge_corner = {
            PrimMESHSMOOTH = 0,
            PrimSIZE = Vector( 48, 48, 48 ),
            PrimTX = 0.5,
            PrimTY = 0,
            PrimTYPE = "wedge_corner",
        },
    }
end


function class:PrimitiveOnSetup( initial, args )
    if initial and SERVER then
        duplicator.StoreEntityModifier( self, "mass", { Mass = 100 } )
    end

    local type, physics, uv = unpack( args )

    if defaults[type] then
        self:SetPrimTYPE( type )

        for k, v in pairs( defaults.generic ) do
            local set = defaults[type][k]
            if set == nil then set = v end

            if set ~= nil then
                self["Set" .. k]( self, set )
            end
        end

        if physics ~= nil then self:SetPrimMESHPHYS( tobool( physics ) ) end
        if tonumber( uv ) then self:SetPrimMESHUV( tonumber( uv ) ) end
    end
end


function class:PrimitiveGetConstruct()
    return self:PrimitiveGetConstructSimple( self.primitive.keys.PrimTYPE )
end


function class:PrimitiveSetupDataTables()
    self:PrimitiveVar( "PrimTYPE", "String", { category = "modify", title = "type", panel = "combo", values = typek, icons = "primitive/icons/%s.png" }, true )
    self:PrimitiveVar( "PrimSIZE", "Vector", { category = "modify", title = "size", panel = "vector", min = Vector( 1, 1, 1 ), max = Vector( 1000, 1000, 1000 ) }, true )

    self:PrimitiveVar( "PrimDT", "Float", { category = "modify", title = "thickness", panel = "float", min = 1, max = 1000 }, true )
    self:PrimitiveVar( "PrimTX", "Float", { category = "modify", title = "taper x", panel = "float", min = -1, max = 1 }, true )
    self:PrimitiveVar( "PrimTY", "Float", { category = "modify", title = "taper y", panel = "float", min = -1, max = 1 }, true )

    self:PrimitiveVar( "PrimSUBDIV", "Int", { category = "modify", title = "subdivide", panel = "int", min = 1, max = 32 }, true )
    self:PrimitiveVar( "PrimMAXSEG", "Int", { category = "modify", title = "max segments", panel = "int", min = 1, max = 32 }, true )
    self:PrimitiveVar( "PrimNUMSEG", "Int", { category = "modify", title = "num segments", panel = "int", min = 1, max = 32 }, true )
    self:PrimitiveVar( "PrimSIDES", "Int", { category = "modify", title = "sides", panel = "bitfield", lbl = { "front", "rear", "left", "right", "top", "bottom" } }, true )
end


local spawnlist
if CLIENT then
    spawnlist = {
        { category = "shapes", entity = "primitive_shape", title = "cone", command = "cone 1 48" },
        { category = "shapes", entity = "primitive_shape", title = "cube", command = "cube 1 48" },
        { category = "shapes", entity = "primitive_shape", title = "cube_magic", command = "cube_magic 1 48" },
        { category = "shapes", entity = "primitive_shape", title = "cube_hole", command = "cube_hole 1 48" },
        { category = "shapes", entity = "primitive_shape", title = "cylinder", command = "cylinder 1 48" },
        { category = "shapes", entity = "primitive_shape", title = "dome", command = "dome 1 48" },
        { category = "shapes", entity = "primitive_shape", title = "plane", command = "plane 1 48" },
        { category = "shapes", entity = "primitive_shape", title = "pyramid", command = "pyramid 1 48" },
        { category = "shapes", entity = "primitive_shape", title = "sphere", command = "sphere 1 48" },
        { category = "shapes", entity = "primitive_shape", title = "torus", command = "torus 1 48" },
        { category = "shapes", entity = "primitive_shape", title = "tube", command = "tube 1 48" },
        { category = "shapes", entity = "primitive_shape", title = "wedge", command = "wedge 1 48" },
        { category = "shapes", entity = "primitive_shape", title = "wedge_corner", command = "wedge_corner 1 48" },
    }

    local callbacks = {
        EDITOR_OPEN = function ( self, editor, name, val )
            for k, cat in pairs( editor.categories ) do
                if k == "debug" or k == "mesh" or k == "model" then cat:ExpandRecurse( false ) else cat:ExpandRecurse( true ) end
            end
        end,
        PrimTYPE = function( self, editor, name, val )
            if defaults[val] == nil then
                return
            end

            local edit = self:GetEditingData()
            for k, row in pairs( editor.rows ) do
                row:SetVisible( edit[k].global or defaults[val][k] ~= nil )
            end

            if self.primitive.keys[name] ~= val then
                for k, v in pairs( defaults.generic ) do
                    local set = defaults[val][k]
                    if set == nil then set = v end

                    if set ~= nil then
                        self:EditValue( k, tostring( set ) )
                    end
                end
            end

            editor:InvalidateChildren( true )
        end,
    }

    function class:EditorCallback( editor, name, val )
        if callbacks[name] then callbacks[name]( self, editor, name, val ) end
    end
end


Primitive.funcs.registerClass( "shape", class, spawnlist )
