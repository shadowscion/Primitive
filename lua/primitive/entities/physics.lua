
----
local math, table, string = math, table, string

do
	local PRIMITIVE = {}

	----
	local tooth = {wedge = "wedge", spike = "spike", cube = "cube"}

	PRIMITIVE._primitive_SafeValues = {
		_primitive_px = function(self, val) return math.Clamp(val, 0, 128) end,
		_primitive_py = function(self, val) return math.Clamp(val, 0, 128) end,
		_primitive_pz = function(self, val) return math.Clamp(val, 0, 128) end,
		_primitive_pdx = function(self, val) return math.Clamp(val, 1, 128) end,
		_primitive_pdy = function(self, val) return math.Clamp(val, 1, 8) end,
		_primitive_pdz = function(self, val) return math.Clamp(val, 1, 16) end,
		_primitive_pdw = function(self, val) return math.Clamp(val, 0, 128) end,
		_primitive_flange = function(self, val) return tobool(val) end,
		_primitive_mirror = function(self, val) return tobool(val) end,
		_primitive_double = function(self, val) return tobool(val) end,
		_primitive_tooth = function(self, val) return tooth[val] or tooth.cube end,
	}

	local used = {}
	for k, v in pairs(PRIMITIVE._primitive_SafeValues) do used[k] = true end

	function PRIMITIVE:_primitive_GetUsedValues()
		return used
	end

	----
	function PRIMITIVE:_primitive_SetupDataTables()
		local category = "Transform"
		self:_primitive_NetworkVar("Float", 0, "px", {order = 0, title = "Pos X", category = category, type = "Float", min = 0, max = 128}, true)
		self:_primitive_NetworkVar("Float", 1, "py", {order = 1, title = "Pos Y", category = category, type = "Float", min = 0, max = 128}, true)
		self:_primitive_NetworkVar("Float", 2, "pz", {order = 2, title = "Pos Z", category = category, type = "Float", min = 0, max = 128}, true)

		local category = "Profile"
		self:_primitive_NetworkVar("String", 0, "tooth", {order = 100, title = "Type", category = category, type = "Combo", values = table.Copy(tooth)}, true)

		self:_primitive_NetworkVar("Float", 3, "pdx", {order = 101, title = "Length X", category = category, type = "Float", min = 1, max = 128}, true)
		self:_primitive_NetworkVar("Float", 4, "pdy", {order = 102, title = "Length Y", category = category, type = "Float", min = 1, max = 8}, true)
		self:_primitive_NetworkVar("Float", 5, "pdz", {order = 103, title = "Length Z", category = category, type = "Float", min = 1, max = 16}, true)
		self:_primitive_NetworkVar("Float", 6, "pdw", {order = 104, title = "Gap", category = category, type = "Float", min = 0, max = 16}, true)
		self:_primitive_NetworkVar("Bool", 3, "double", {order = 105, title = "Double", category = category, type = "Boolean"}, true)
		self:_primitive_NetworkVar("Bool", 4, "mirror", {order = 106, title = "Mirror", category = category, type = "Boolean"}, true)

		local category = "Flange"
		self:_primitive_NetworkVar("Bool", 5, "flange", {order = 200, title = "Enable", category = category, type = "Boolean"}, true)
	end

	----
	function PRIMITIVE:_primitive_Setup(primitive_type, initialSpawn)
		if SERVER and initialSpawn then
			duplicator.StoreEntityModifier(self, "mass", {Mass = 100})
			duplicator.StoreBoneModifier(self, 0, "physprops", {GravityToggle = true, Material = "gmod_ice"})
		end

		self:Set_primitive_tooth("wedge")
		self:Set_primitive_flange(true)
		self:Set_primitive_double(true)
		self:Set_primitive_mirror(true)
		self:Set_primitive_px(24)
		self:Set_primitive_py(38)
		self:Set_primitive_pz(16)
		self:Set_primitive_pdx(24)
		self:Set_primitive_pdy(1)
		self:Set_primitive_pdz(8)
		self:Set_primitive_pdw(14)
	end

	function PRIMITIVE:_primitive_OnUpdate()
		return g_primitive.construct_get("rail_slider", self:_primitive_GetVars(nil, true), false, CLIENT)
	end

	if SERVER then
		function PRIMITIVE:_primitive_OnEdited(key, val)
		end
	else
		local baseMaterial = Material("phoenix_storms/iron_rails")

		function PRIMITIVE:_primitive_PostUpdate()
			if self._primitive_RenderMesh then self._primitive_RenderMesh.Material = baseMaterial end
		end
	end

	----
	g_primitive.entity_register("rail_slider", PRIMITIVE, {Category = "physics", Entries = {"rail_slider"}})
end


----
do
	local PRIMITIVE = {}

	----

	PRIMITIVE._primitive_SafeValues = {
	}

	local used = {}
	for k, v in pairs(PRIMITIVE._primitive_SafeValues) do used[k] = true end

	function PRIMITIVE:_primitive_GetUsedValues()
		return used
	end

	----
	function PRIMITIVE:_primitive_SetupDataTables()
		--[[
		local category = "Transform"
		self:_primitive_NetworkVar("Float", 0, "px", {order = 0, title = "Pos X", category = category, type = "Float", min = 0, max = 128}, true)
		self:_primitive_NetworkVar("Float", 1, "py", {order = 1, title = "Pos Y", category = category, type = "Float", min = 0, max = 128}, true)
		self:_primitive_NetworkVar("Float", 2, "pz", {order = 2, title = "Pos Z", category = category, type = "Float", min = 0, max = 128}, true)

		local category = "Profile"
		self:_primitive_NetworkVar("String", 0, "tooth", {order = 100, title = "Type", category = category, type = "Combo", values = table.Copy(tooth)}, true)

		self:_primitive_NetworkVar("Float", 3, "pdx", {order = 101, title = "Length X", category = category, type = "Float", min = 1, max = 128}, true)
		self:_primitive_NetworkVar("Float", 4, "pdy", {order = 102, title = "Length Y", category = category, type = "Float", min = 1, max = 8}, true)
		self:_primitive_NetworkVar("Float", 5, "pdz", {order = 103, title = "Length Z", category = category, type = "Float", min = 1, max = 16}, true)
		self:_primitive_NetworkVar("Float", 6, "pdw", {order = 104, title = "Gap", category = category, type = "Float", min = 0, max = 16}, true)
		self:_primitive_NetworkVar("Bool", 3, "double", {order = 105, title = "Double", category = category, type = "Boolean"}, true)
		self:_primitive_NetworkVar("Bool", 4, "mirror", {order = 106, title = "Mirror", category = category, type = "Boolean"}, true)

		local category = "Flange"
		self:_primitive_NetworkVar("Bool", 5, "flange", {order = 200, title = "Enable", category = category, type = "Boolean"}, true)
		]]
	end

	----
	function PRIMITIVE:_primitive_Setup(primitive_type)
	end

	function PRIMITIVE:_primitive_OnUpdate()
		return g_primitive.construct_get("rail_section", self:_primitive_GetVars(nil, true), false, CLIENT)
	end

	if SERVER then
		function PRIMITIVE:_primitive_OnEdited(key, val)
		end
	else
		function PRIMITIVE:_primitive_PostUpdate()
		end
	end

	----
	g_primitive.entity_register("rail_section", PRIMITIVE, {Category = "physics", Entries = {"rail_section (experimental)"}})
end
