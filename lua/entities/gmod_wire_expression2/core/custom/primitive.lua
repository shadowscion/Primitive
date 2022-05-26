
E2Lib.RegisterExtension("primitive", false, "Allows the manipulation of primitive entities.")

local function check(self, ent)
	if not IsValid(ent) and not ent:IsWorld() then return false end
	if not isOwner(self, ent) then return false end
	if not scripted_ents.IsBasedOn(ent:GetClass(), "primitive_base") then return false end
	return true
end

local setfunc_wait = 0
local setfunc_list = {}

hook.Add("Think", "primitive.e2think", function()
	if SysTime() - setfunc_wait < 0.25 then
		return
	end

	setfunc_wait = SysTime()

	for ent, sets in pairs(setfunc_list) do
		if ent and ent:IsValid() then
			for key, val in pairs(sets) do
				ent[key](ent, val)
			end
		end
		setfunc_list[ent] = nil
	end
end)

local function edit(self, ent, key, val)
	if not check(self, ent) or not ent._primitive_GetVars then return 0 end

	local vars = ent:_primitive_GetVars()
	if not istable(vars) or vars[key] == nil then return 0 end

	local key = "Set_primitive_" .. key
	if not isfunction(ent[key]) then return 0 end

	if not setfunc_list[ent] then setfunc_list[ent] = {} end

	setfunc_list[ent][key] = val

	return 1
end

__e2setcost(15)

e2function number primitiveEdit(entity ent, string key, ...)
	local args = {...}
	return edit(self, ent, key, args[1])
end

local e2type = {string = "s", number = "n", boolean = "n"}
e2function table primitiveGetVars(entity ent)
	local ret = E2Lib.newE2Table()
	if not check(self, ent) or not ent._primitive_GetVars then return ret end

	for k, v in pairs(ent:_primitive_GetVars()) do
		local lt = type(v)
		local et = e2type[lt]
		if et then
			ret.s[k] = lt
			ret.stypes[k] = et
			ret.size = ret.size + 1
		end
	end

	return ret
end
