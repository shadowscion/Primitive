AddCSLuaFile()
DEFINE_BASECLASS("base_anim")

ENT.PrintName = "prop_primitive"
ENT.Author = "shadowscion"
ENT.AdminOnly = false
ENT.Spawnable = false
ENT.RenderGroup = RENDERGROUP_BOTH

cleanup.Register("prop_primitive")

local wireframe = Material("hunter/myplastic")

local typevars = {}
typevars.cube = { "dx", "dy", "dz" }
typevars.wedge = { "dx", "dy", "dz" }
typevars.wedge_corner = { "dx", "dy", "dz" }
typevars.pyramid = { "dx", "dy", "dz" }
typevars.cylinder = { "dx", "dy", "dz", "maxsegments", "numsegments" }
typevars.tube = { "dx", "dy", "dz", "maxsegments", "numsegments", "thickness" }
typevars.torus = { "dx", "dy", "dz", "maxsegments", "numsegments", "thickness", "numrings" }
for k, v in pairs(typevars) do
	local t = {}
	for i, j in pairs(v) do
		t["_primitive_" .. j] = j
	end
	typevars[k] = t
end

local defaults = {}
defaults.generic = {dx=48,dy=48,dz=48,maxsegments=32,numsegments=32,numrings=16,thickness=3,dbg=false}
defaults.torus = {dz=12,thickness=6}

if SERVER then

	local function spawn_setup(ply, args)
		if not IsValid(ply) or not scripted_ents.GetStored("prop_primitive") then return end
		if scripted_ents.GetMember("prop_primitive", "AdminOnly") and not ply:IsAdmin() then return end
		if not gamemode.Call("PlayerSpawnProp", ply, "prop_primitive") then return end

		local primitive_type = args[1]
		if not primitive_type or not typevars[primitive_type] then return end

		local vStart = ply:EyePos()
		local vForward = ply:GetAimVector()

		local tr = util.TraceLine({
			start = vStart,
			endpos = vStart + vForward*4096,
			filter = ply,
		})

		if not tr.Hit then return end

		local ent = ents.Create("prop_primitive")

		ent:Set_primitive_type(primitive_type)

		local typedef = defaults[primitive_type]
		for k, v in pairs(defaults.generic) do
			ent["Set_primitive_" .. k](ent, typedef and typedef[k] or v)
		end

		ent:SetModel("models/hunter/blocks/cube025x025x025.mdl")
		ent:SetPos(tr.HitPos + tr.HitNormal*(ent:Get_primitive_dz()*0.5 + 6))
		ent:Spawn()
		ent:Activate()

		if not IsValid(ent) then return end

		gamemode.Call("PlayerSpawnedProp", ply, nil, ent)

		undo.Create("Prop")
			undo.SetPlayer(ply)
			undo.AddEntity(ent)
			undo.SetCustomUndoText(string.format("Undone primitive (%s)", primitive_type))
		undo.Finish(string.format("primitive (%s)", primitive_type))

		ply:AddCleanup("props", ent)
		ent:SetVar("Player", ply)
	end

	concommand.Add("primitive_spawn", function(ply, cmd, args)
		spawn_setup(ply, args)
	end)

	duplicator.RegisterEntityClass("prop_primitive", function(ply, data)
		if scripted_ents.GetMember("prop_primitive", "AdminOnly") and not ply:IsAdmin() then
		 return false
		end
		if not gamemode.Call("PlayerSpawnProp", ply, "prop_primitive") then
			return false
		end

		local ent = ents.Create("prop_primitive")
		if not IsValid(ent) then
			return false
		end

		ent:SetModel("models/hunter/blocks/cube025x025x025.mdl")
		ent:Spawn()
		ent:Activate()

		if data then
			duplicator.DoGeneric(ent, data)
		end

		gamemode.Call("PlayerSpawnedProp", ply, nil, ent)

		ply:AddCleanup("props", ent)
		ent:SetVar("Player", ply)

		return ent
	end, "Data")

end

function ENT:SetupDataTables()
	local cat = "Config"
	self:NetworkVar("String", 0, "_primitive_type", {KeyName="_primitive_type",Edit={order=100,category=cat,title="Type",type="Combo",colorOverride=true,text="cube",
		values={torus="torus",cube="cube",cylinder="cylinder",tube="tube",wedge="wedge",wedge_corner="wedge_corner",pyramid="pyramid"}}})
	self:NetworkVar("Bool", 0, "_primitive_dbg", {KeyName="_primitive_dbg",Edit={order=101,category=cat,title="Debug",type="Boolean",colorOverride=true}})

	local cat = "Dimensions"
	self:NetworkVar("Float", 0, "_primitive_dx", {KeyName="_primitive_dx",Edit={order=200,category=cat,title="Length X",type="Float",min=0.5,max=512}})
	self:NetworkVar("Float", 1, "_primitive_dy", {KeyName="_primitive_dy",Edit={order=201,category=cat,title="Length Y",type="Float",min=0.5,max=512}})
	self:NetworkVar("Float", 2, "_primitive_dz", {KeyName="_primitive_dz",Edit={order=202,category=cat,title="Length Z",type="Float",min=0.5,max=512}})

	local cat = "Modifiers"
	self:NetworkVar("Int", 0, "_primitive_maxsegments", {KeyName="_primitive_maxsegments",Edit={order=300,category=cat,title="Max Segments",type="Int",min=3,max=32}})
	self:NetworkVar("Int", 1, "_primitive_numsegments", {KeyName="_primitive_numsegments",Edit={order=301,category=cat,title="Num Segments",type="Int",min=1,max=32}})
	self:NetworkVar("Int", 2, "_primitive_numrings", {KeyName="_primitive_numrings",Edit={order=302,category=cat,title="Num Rings",type="Int",min=3,max=31}})
	self:NetworkVar("Float", 3, "_primitive_thickness", {KeyName="_primitive_thickness",Edit={order=303,category=cat,title="Thickness",type="Float",min=0,max=512}})

	self:NetworkVarNotify("_primitive_type", self._primitive_trigger_update)
	self:NetworkVarNotify("_primitive_dx", self._primitive_trigger_update)
	self:NetworkVarNotify("_primitive_dy", self._primitive_trigger_update)
	self:NetworkVarNotify("_primitive_dz", self._primitive_trigger_update)
	self:NetworkVarNotify("_primitive_maxsegments", self._primitive_trigger_update)
	self:NetworkVarNotify("_primitive_numsegments", self._primitive_trigger_update)
	self:NetworkVarNotify("_primitive_numrings", self._primitive_trigger_update)
	self:NetworkVarNotify("_primitive_thickness", self._primitive_trigger_update)

	self.queue_rebuild = CurTime()
end

function ENT:Get_primitive_typevars()
	return typevars[self:Get_primitive_type()]
end

function ENT:_primitive_trigger_update(name, old, new)
	if old == new then
		return
	end
	self.queue_rebuild = CurTime()
end

function ENT:RebuildPhysics(pmesh)
	if not pmesh then
		return
	end

	local contraints
	if SERVER then
		contraints = {}
		for _, v in pairs(constraint.GetTable(self) ) do
			table.insert(contraints, v)
		end
		constraint.RemoveAll(self)
		self.ConstraintSystem = nil
	end

	local move, sleep
	if SERVER then
		move = self:GetPhysicsObject():IsMoveable()
		sleep = self:GetPhysicsObject():IsAsleep()
	end

	self:PhysicsInitMultiConvex(pmesh)
	self:SetSolid(SOLID_VPHYSICS )
	self:SetMoveType(MOVETYPE_VPHYSICS)
	self:EnableCustomCollisions(true)

	local physobj = self:GetPhysicsObject()
	if not SERVER or not physobj or not physobj:IsValid() then
		return
	end

	local dx = self:Get_primitive_dx()
	local dy = self:Get_primitive_dy()
	local dz = self:Get_primitive_dz()

	local density = 0.001
	local mass = (dx * dy * dz)*density

	physobj:SetMass(mass)
	physobj:SetInertia(Vector(dx, dy, dz):GetNormalized()*mass)
	physobj:EnableMotion(move)

	if not sleep then
		physobj:Wake()
	end

	if #contraints > 0 then
		timer.Simple(0, function()
			for _, info in pairs(contraints) do
				local make = duplicator.ConstraintType[info.Type]
				if make then
					local args = {}
					for i = 1, #make.Args do
						args[i] = info[make.Args[i]]
					end
					local new, temp = make.Func(unpack(args))
				end
			end
		end)
	end
end

function ENT:Think()
	if self.queue_rebuild and CurTime() - self.queue_rebuild > 0.015 then
		self.queue_rebuild = nil

		local pmesh, vmesh, verts = PRIMITIVE.Build(self:GetNetworkVars())

		self:RebuildPhysics(pmesh)

		if CLIENT then
			local primitive_type = self:Get_primitive_type()
			local editor = self:GetEditingData()

			for k, v in pairs(editor) do
				if not v.colorOverride then
					v.enabled = typevars[primitive_type][k] and true or false
				end
			end

			self.mesh_verts = verts or nil
			self.mesh_tris = vmesh or nil

			if vmesh and #vmesh >= 3 then
				if self.mesh_object and self.mesh_object:IsValid() then
					self.mesh_data = nil
					self.mesh_object:Destroy()
				end
				self.mesh_object = Mesh()
				self.mesh_object:BuildFromTriangles(vmesh)
				self.mesh_data = { Mesh = self.mesh_object, Material = wireframe }
			end

			local maxs = Vector(self:Get_primitive_dx(), self:Get_primitive_dy(), self:Get_primitive_dz())*0.5
			local mins = maxs * -1

			self:SetRenderBounds(mins, maxs)
			self:SetCollisionBounds(mins, maxs)
		end

		return
	end

	if CLIENT then
		local physobj = self:GetPhysicsObject()
		if physobj:IsValid() then
			physobj:SetPos(self:GetPos())
			physobj:SetAngles(self:GetAngles())
			physobj:EnableMotion(false)
			physobj:Sleep()
		end
	end
end

function ENT:Initialize()
	if SERVER then
		self:DrawShadow(false)
		self:PhysicsInit(SOLID_VPHYSICS)
		self:SetMoveType(MOVETYPE_VPHYSICS)
		self:SetSolid(SOLID_VPHYSICS)

		return
	end

	if self.mesh_object and self.mesh_object:IsValid() then
		self.mesh_data = nil
		self.mesh_object:Destroy()
	end
end

if CLIENT then
	function ENT:OnRemove()
		timer.Simple(0, function()
			if self and self:IsValid() then
				return
			end
			if self.mesh_object and self.mesh_object:IsValid() then
				self.mesh_data = nil
				self.mesh_object:Destroy()
			end
		end)
	end

	function ENT:GetRenderMesh()
		return self.mesh_data
	end

	local c_red = Color(255, 0, 0, 150)
	local c_grn = Color(0, 255, 0, 150)
	local c_blu = Color(0, 0, 255, 150)
	local c_yel = Color(255, 255, 0, 150)
	local c_cya = Color(0, 255, 255, 10)

	function ENT:Draw()
		self:DrawModel()

		if self:Get_primitive_dbg() then
			local pos = self:GetPos()

			render.DrawLine(pos, pos + self:GetForward()*16, c_grn)
			render.DrawLine(pos, pos + self:GetRight()*16, c_red)
			render.DrawLine(pos, pos + self:GetUp()*16, c_blu)

			local min, max = self:GetRenderBounds()
			render.DrawWireframeBox(pos, self:GetAngles(), min, max, c_cya)

			if self.mesh_verts then
				cam.Start2D()

				surface.SetFont("Default")
				surface.SetTextColor(c_yel)

				local pos = self:LocalToWorld(max * 1.1):ToScreen()

				surface.SetTextPos(pos.x, pos.y)
				surface.DrawText(string.format("verts (%d)", #self.mesh_verts))

				if self.mesh_tris then
					surface.SetTextPos(pos.x, pos.y + 14)
					surface.DrawText(string.format("tris (%d)", #self.mesh_tris / 3))
				end

				for k, v in ipairs(self.mesh_verts) do
					local pos = self:LocalToWorld(v):ToScreen()
					surface.SetTextPos(pos.x, pos.y)
					surface.DrawText(k)
				end

				cam.End2D()
			end
		end
	end
end
