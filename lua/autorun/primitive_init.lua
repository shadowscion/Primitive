
----
g_primitive = {}
g_primitive.update_delay = SERVER and 0.25 or 0.015
g_primitive.default_model = "models/combine_helicopter/helicopter_bomb01.mdl"

if SERVER then
	AddCSLuaFile("primitive/vgui/editor.lua")
	AddCSLuaFile("primitive/construct.lua")
	AddCSLuaFile("primitive/entity.lua")

	include("primitive/construct.lua")
	include("primitive/entity.lua")
else
	if not shadowscion_standard_font then
		shadowscion_standard_font = "shadowscion_standard_font"
		surface.CreateFont(shadowscion_standard_font, {size = 13, weight = 800, font = "Tahoma"})
	end

	include("primitive/construct.lua")
	include("primitive/vgui/editor.lua")
	include("primitive/entity.lua")
end

----
g_primitive.entity_reload()
