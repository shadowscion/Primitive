
local function load( path, realm )
    local files, folders = file.Find( path .. "*.lua", "LUA" )

    for _, file in pairs( files ) do
        file = path .. file

        if SERVER then
            AddCSLuaFile( file )
        end

        if realm then
            include( file )
        end
    end
end

if SERVER then
    AddCSLuaFile( "core/util.lua" )
    AddCSLuaFile( "core/menu.lua" )
    AddCSLuaFile( "core/construct.lua" )
    AddCSLuaFile( "editor/editor.lua" )
end

include( "core/util.lua" )
include( "core/menu.lua" )
include( "core/construct.lua" )
load( "primitive/entities/", true )

if CLIENT then
    include( "editor/editor.lua" )
end

load( "primitive/editor/panels/", CLIENT )
