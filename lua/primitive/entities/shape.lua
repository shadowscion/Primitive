
----
local math, table, string = math, table, string

do
	local PRIMITIVE = {}

	----
	local shapes_list = {"cone", "cube", "cube_magic", "cube_tube", "cylinder", "dome", "pyramid", "sphere", "torus", "tube", "wedge", "wedge_corner"}
	local shapes_lookup = {}
	for k, v in pairs(shapes_list) do
		shapes_lookup[v] = v
	end

	local shapes_vars = {}
	shapes_vars.generic      = {dx=48, dy=48, dz=48, dt=4, tx=0, ty=0, maxseg=16, numseg=16, subdiv=8, modv=""}
	shapes_vars.cone         = {dx=48, dy=48, dz=48, tx=0, ty=0, maxseg=16, numseg=16, modv="normals=45"}
	shapes_vars.cube         = {dx=48, dy=48, dz=48, tx=0, ty=0}
	shapes_vars.cube_magic   = {dx=48, dy=48, dz=48, dt=4, tx=0, ty=0, modv="sides=111111"}
	shapes_vars.cube_tube    = {dx=48, dy=48, dz=48, dt=4, numseg=4, subdiv=16, modv="normals=65"}
	shapes_vars.cylinder     = {dx=48, dy=48, dz=48, tx=0, ty=0, maxseg=16, numseg=16, modv="normals=65"}
	shapes_vars.dome         = {dx=48, dy=48, dz=48, numseg=8, modv="normals=65"}
	shapes_vars.pyramid      = {dx=48, dy=48, dz=48, tx=0, ty=0}
	shapes_vars.sphere       = {dx=48, dy=48, dz=48, numseg=8, modv="normals=65"}
	shapes_vars.torus        = {dx=48, dy=48, dz=6, dt=6, maxseg=16, numseg=16, subdiv=16, modv="normals=65"}
	shapes_vars.tube         = {dx=48, dy=48, dz=48, dt=4, tx=0, ty=0, maxseg=16, numseg=16, modv="normals=65"}
	shapes_vars.wedge        = {dx=48, dy=48, dz=48, tx=0.5, ty=0}
	shapes_vars.wedge_corner = {dx=48, dy=48, dz=48, tx=0.5, ty=0}

	for k, v in pairs(shapes_vars) do
		shapes_vars[k] = {_primitive_shape=k}
		for i, j in pairs(v) do
			shapes_vars[k]["_primitive_" .. i] = j
		end
	end

	----
	PRIMITIVE._primitive_SafeValues = {
		_primitive_dx = function(self, val) return math.Clamp(val, 1, 1024) end,
		_primitive_dy = function(self, val) return math.Clamp(val, 1, 1024) end,
		_primitive_dz = function(self, val) return math.Clamp(val, 1, 1024) end,
		_primitive_dt = function(self, val) return math.Clamp(val, 1, 1024) end,
		_primitive_tx = function(self, val) return math.Clamp(val, -1, 1) end,
		_primitive_ty = function(self, val) return math.Clamp(val, -1, 1) end,
		_primitive_maxseg = function(self, val) return math.Round(math.Clamp(val, 1, 32)) end,
		_primitive_numseg = function(self, val) return math.Round(math.Clamp(val, 1, 32)) end,
		_primitive_subdiv = function(self, val) return math.Round(math.Clamp(val, 1, 32)) end,
		_primitive_shape = function(self, val) return shapes_lookup[val] or "cube" end,
	}
	local mod_patterns = {"(sides=%d%d%d%d%d%d)","(normals=%d+)"}
	PRIMITIVE._primitive_SafeValues._primitive_modv = function(self, val)
		local val = string.gsub(string.lower(val), " ", "")
		local ret = {}
		for k, v in ipairs(mod_patterns) do
			local a, b, c = string.find(val, v)
			if c then
				ret[#ret + 1] = c
			end
		end
		return table.concat(ret, ",")
	end

	----
	function PRIMITIVE:_primitive_GetUsedValues()
		return shapes_vars[self:Get_primitive_shape()] or shapes_vars.generic
	end

	function PRIMITIVE:_primitive_Setup(primitive_type, initialSpawn)
		if SERVER and initialSpawn then
			duplicator.StoreEntityModifier(self, "mass", {Mass = 100})
		end
		for k, v in pairs(shapes_vars.generic) do
			self["Set" .. k](self, shapes_vars[primitive_type][k] or v)
		end
	end

	function PRIMITIVE:_primitive_SetupDataTables()
		local category = "Configure"
		self:_primitive_NetworkVar("String", 0, "shape", {order = 100, category = category, title = "Type", type = "Combo", values = table.Copy(shapes_lookup), icons = "vgui/primitive/%s.png"}, true)

		local category = "Resize"
		self:_primitive_NetworkVar("Float", 0, "dx", {order = 200, category = category, title = "Length X", type = "Float", min = 1, max = 1024}, true)
		self:_primitive_NetworkVar("Float", 1, "dy", {order = 201, category = category, title = "Length Y", type = "Float", min = 1, max = 1024}, true)
		self:_primitive_NetworkVar("Float", 2, "dz", {order = 202, category = category, title = "Length Z", type = "Float", min = 1, max = 1024}, true)

		local category = "Modify"
		self:_primitive_NetworkVar("Float", 3, "dt", {order = 300, category = category, title = "Thickness", type = "Float", min = 1, max = 1024}, true)
		self:_primitive_NetworkVar("Float", 4, "tx", {order = 301, category = category, title = "Taper X", type = "Float", min = -1, max = 1}, true)
		self:_primitive_NetworkVar("Float", 5, "ty", {order = 302, category = category, title = "Taper Y", type = "Float", min = -1, max = 1}, true)
		self:_primitive_NetworkVar("Int", 0, "subdiv", {order = 303, category = category, title = "Subdivisions", type = "Int", min = 1, max = 32}, true)
		self:_primitive_NetworkVar("Int", 1, "maxseg", {order = 304, category = category, title = "Max Segments", type = "Int", min = 1, max = 32}, true)
		self:_primitive_NetworkVar("Int", 2, "numseg", {order = 305, category = category, title = "Num Segments", type = "Int", min = 1, max = 32}, true)
		self:_primitive_NetworkVar("String", 1, "modv", {order = 306, category = category, title = "Variables", type = "String", global = true}, true)
	end

	function PRIMITIVE:_primitive_OnUpdate()
		return g_primitive.construct_get(self:Get_primitive_shape(), self:_primitive_GetVars(nil, true), false, CLIENT)
	end

	if SERVER then
		function PRIMITIVE:_primitive_OnEdited(key, val)
			if key == "_primitive_shape" and self:Get_primitive_shape() ~= val then
				self:_primitive_Setup(val)
			end
		end
	end

	----
	g_primitive.entity_register("shape", PRIMITIVE, {Category = "shape", Entries = shapes_list})
end
