

--
AddCSLuaFile()
DEFINE_BASECLASS("base_anim")

cleanup.Register("primitive")
if CLIENT then
	language.Add("Cleanup_primitive", "Primitives")
	language.Add("Cleaned_primitive", "Cleaned up Primitives")
end

ENT.PrintName = "Primitive (Base)"
ENT.AdminOnly = true
ENT.RenderGroup = RENDERGROUP_BOTH

ENT._primitive_canEdit = true


--
--[[
hook.Add("_primitive.prerebuild", "_primitive", function(ent) return true end)
hook.Add("_primitive.postrebuild", "_primitive", function(ent) end)
]]

if SERVER then
	util.AddNetworkString("_primitive.net")

	hook.Add("VariableEdited", "_primitive", function(ent, client, key, val, editor)
		if ent and ent._primitive_onEdit and ent._primitive_trigger_editor and ent._primitive_trigger_editor[key] then
			ent:_primitive_onEdit(key, val)
		end
	end)
else
	net.Receive("_primitive.net", function()
		local uid = net.ReadUInt(16)
		local ent = Entity(uid)
		local str = net.ReadString()

		if ent and ent:IsValid() then
			local physicsObject = ent:GetPhysicsObject()
			if physicsObject and physicsObject:IsValid() then
				physicsObject:SetMaterial(str)
				physicsObject:EnableMotion(false)
			end
		end
	end)
end

hook.Add("_primitive.postrebuild", "_primitive", function(ent, success, data)
	if SERVER then
		if data.physprops and data.physprops.Material ~= "" then
			net.Start("_primitive.net")
			net.WriteUInt(ent:EntIndex(), 16)
			net.WriteString(data.physprops and data.physprops.Material)
			net.Broadcast()
		end
	else
	end
end)


--
function ENT:CanPropery(pl, prop)
	if prop == "primitive_editor" then return true end
end

function ENT:SetupDataTables()
	if self._primitive_datatables then
		self:_primitive_datatables()

		local nwvars = self:GetNetworkVars()

		if nwvars then
			for k, v in pairs(nwvars) do
				self:NetworkVarNotify(k, self._primitive_NWNotify)
			end
		end
	end

	local category = "Debug"
	self:NetworkVar("Bool", 0, "_primitive_dbg", {KeyName = "_primitive_dbg", Edit = {global = true, order = -1, title = "Overlay", category = category, type = "Boolean"}})

	self._primitive_rebuild = CurTime()
end

function ENT:_primitive_NWNotify(name, old, new)
	if old == new then
		return
	end
	if self._primitive_safenw and self._primitive_safenw[name] then
		local safe = self._primitive_safenw[name](self, old, new)
		if safe and safe ~= new then
			self["Set" .. name](self, safe)
		else
			if self._primitive_onNWNotify then
				self:_primitive_onNWNotify(name, old, new)
			end
		end
	elseif self._primitive_onNWNotify then
		self:_primitive_onNWNotify(name, old, new)
	end
	self._primitive_rebuild = CurTime()
end


--
function ENT:Initialize()
	if self._primitive_preInit then
		self:_primitive_preInit()
	end

	if SERVER then
		self:SetModel("models/combine_helicopter/helicopter_bomb01.mdl")
		self:PhysicsInit(SOLID_VPHYSICS)
		self:SetMoveType(MOVETYPE_VPHYSICS)
		self:SetSolid(SOLID_VPHYSICS)
	end

	if self._primitive_postInit then
		self:_primitive_postInit()
	end
end


--
local CopyConstraints, ApplyConstraints
if SERVER then
	CopyConstraints = function(self, removeAll)
		local constraints = {}
		for _, v in pairs(constraint.GetTable(self)) do
			table.insert(constraints, v)
		end
		if removeAll then constraint.RemoveAll(self) end
		self.ConstraintSystem = nil
		return constraints
	end

	ApplyConstraints = function(self, constraints)
		if not istable(constraints) or next(constraints) == nil or not self:GetPhysicsObject():IsValid() then
			return
		end
		for _, constr in pairs(constraints) do
			local factory = duplicator.ConstraintType[constr.Type]
			if not factory then
				break
			end
			local args = {}
			for i = 1, #factory.Args do
				args[ i ] = constr[factory.Args[i]]
			end
			factory.Func(unpack(args))
		end
	end
end


--
function ENT:Think()
	if self._primitive_rebuild and CurTime() - self._primitive_rebuild > g_primitive.update_delay then
		self._primitive_rebuild = nil

		if hook.Run("_primitive.prerebuild", self) == false then
			return
		end

		local constraints, mass, physprops
		if SERVER then
			if self.EntityMods and self.EntityMods.mass then
				mass = self.EntityMods.mass.Mass
			else
				local physicsObject = self:GetPhysicsObject()
				if physicsObject and physicsObject:IsValid() then
					mass = physicsObject:GetMass()
				end
			end
			if self.BoneMods and self.BoneMods[0] then
				physprops = self.BoneMods[0].physprops
			end
			constraints = CopyConstraints(self, true)
		end

		local successful, rebuild
		if self._primitive_onRebuild then
			successful, rebuild = self:_primitive_onRebuild()
		end

		if not istable(rebuild) then rebuild = {} end

		if istable(rebuild.physics) then
			if #rebuild.physics == 1 then
				successful = self:PhysicsInitConvex(rebuild.physics[1])
			else
				successful = self:PhysicsInitMultiConvex(rebuild.physics)
			end
		end

		if successful then
			self:SetMoveType(MOVETYPE_VPHYSICS)
			self:SetSolid(SOLID_VPHYSICS)
			self:EnableCustomCollisions(true)
		else
			self:PhysicsInit(SOLID_VPHYSICS)
			self:SetMoveType(MOVETYPE_VPHYSICS)
			self:SetSolid(SOLID_VPHYSICS)
			self:EnableCustomCollisions(false)
		end

		if SERVER then
			local physicsObject = self:GetPhysicsObject()

			if mass then physicsObject:SetMass(mass) end
			if physprops then
				if physprops.Gravity ~= nil then physicsObject:EnableGravity(physprops.Gravity) end
				if physprops.Material ~= nil then physicsObject:SetMaterial(physprops.Material) end
			end

			physicsObject:EnableMotion(false)
			physicsObject:Sleep()

			if constraints and next(constraints) then
				timer.Simple(0, function()
					ApplyConstraints(self, constraints)
				end)
			end
		end

		if CLIENT then
			self:_primitive_setRenderMesh(rebuild.tris)
			self._primitive_render_verts = istable(rebuild.vertex) and rebuild.vertex or nil
			self:SetRenderBounds(self:GetCollisionBounds())
		end

		if self._primitive_postRebuild then
			self:_primitive_postRebuild()
		end

		hook.Run("_primitive.postrebuild", self, successful, {constraints = constraints, mass = mass, physprops = physprops})
	end
end


--
-- CLIENT ONLY
if not CLIENT then return end

local baseMaterial
if file.Exists("materials/sprops/sprops_grid_12x12.vtf", "GAME") then baseMaterial = Material("sprops/sprops_grid_12x12") else baseMaterial = Material("hunter/myplastic") end


--
function ENT:OnRemove()
	local render_mesh = self._primitive_render_mesh
	timer.Simple(0, function()
		if self and IsValid(self) then
			return
		end
		if render_mesh and render_mesh.Mesh and render_mesh.Mesh:IsValid() then
			render_mesh.Mesh:Destroy()
		end
	end)
end

function ENT:CalcAbsolutePosition()
	local physicsObject = self:GetPhysicsObject()
	local pos = self:GetPos()
	local ang = self:GetAngles()

	if physicsObject and physicsObject:IsValid() then
		physicsObject:SetPos(pos)
		physicsObject:SetAngles(ang)
		physicsObject:EnableMotion(false)
		physicsObject:Sleep()
	end

	return pos, ang
end


--
function ENT:_primitive_setRenderMesh(tris)
	if self._primitive_render_mesh and IsValid(self._primitive_render_mesh.Mesh) then
		self._primitive_render_mesh.Mesh:Destroy()
		self._primitive_render_mesh = nil
	end

	if not istable(tris) or #tris < 3 then
		return false
	end

	self._primitive_render_mesh = {Mesh = Mesh(), Material = baseMaterial}
	self._primitive_render_mesh.Mesh:BuildFromTriangles(tris)

	return true
end


--
local dbg_g = Color(0, 255, 0)
local dbg_r = Color(255, 0, 0)
local dbg_b = Color(0, 0, 255)
local dbg_y = Color(255, 255, 0, 50)

function ENT:Draw()
	self:DrawModel()

	if self:Get_primitive_dbg() then
		render.DrawLine(self:GetPos(), self:GetPos() + self:GetForward()*6, dbg_g)
		render.DrawLine(self:GetPos(), self:GetPos() + self:GetRight()*6, dbg_r)
		render.DrawLine(self:GetPos(), self:GetPos() + self:GetUp()*6, dbg_b)

		local min, max = self:GetCollisionBounds()
		render.DrawWireframeBox(self:GetPos(), self:GetAngles(), min, max, dbg_y)

		local render_verts = self._primitive_render_verts
		if render_verts then
			cam.Start2D()

			surface.SetFont("Default")
			surface.SetTextColor(dbg_y)
			surface.SetDrawColor(dbg_y)

			for i = 1, #render_verts do
				local pos = self:LocalToWorld(rawget(render_verts, i)):ToScreen()
				surface.SetTextPos(pos.x, pos.y)
				surface.DrawText(i)
				surface.DrawRect(pos.x, pos.y, 2, 2)
			end

			cam.End2D()
		end
	end
end

function ENT:GetRenderMesh()
	return self._primitive_render_mesh
end

