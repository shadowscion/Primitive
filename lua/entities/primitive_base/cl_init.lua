
----
include("shared.lua")

----
function ENT:Draw()
	self:DrawModel()
end

function ENT:GetRenderMesh()
	return self._primitive_RenderMesh
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

function ENT:OnRemove()
	local render_mesh = self._primitive_RenderMesh
	timer.Simple(0, function()
		if self and IsValid(self) then
			return
		end
		if render_mesh and render_mesh.Mesh and render_mesh.Mesh:IsValid() then
			render_mesh.Mesh:Destroy()
		end
	end)
end

----
local baseMaterial
if file.Exists("materials/sprops/sprops_grid_12x12.vtf", "GAME") then baseMaterial = Material("sprops/sprops_grid_12x12") else baseMaterial = Material("hunter/myplastic") end
local ___error = Material("___error")
local ___physics = CreateMaterial("primitivephyswireframe", "Wireframe_DX9", {})
___physics:SetVector("$color", Vector(1, 0, 1))

local dbg_g = Color(0, 255, 0)
local dbg_r = Color(255, 0, 0)
local dbg_b = Color(0, 0, 255)
local dbg_y = Color(255, 255, 0, 50)
local dbg_text = Color(255, 255, 255, 255)
local dbg_vertex = Color(255, 255, 0, 255)

local function DrawNormal(self)
	self:DrawModel()
end

local function DrawError(self)
	render.ModelMaterialOverride(___error)
	self:DrawModel()
	render.ModelMaterialOverride(nil)

	dbg_text.a = EyePos():Distance(self:GetPos()) > 200 and 0 or 255

	cam.Start2D()
	local pos = (self:GetPos() + Vector(0, 0, 6)):ToScreen()
	draw.DrawText("Error constructing primitive.\nCheck console for details!", shadowscion_standard_font or "Default", pos.x, pos.y, dbg_text, TEXT_ALIGN_CENTER)
	cam.End2D()
end

local function DrawDebug(self)
	if self:Get_primitive_debug_physics() and self._primitive_RenderPhysics then
		local mat = self:GetWorldTransformMatrix()
		cam.PushModelMatrix(mat)
		render.SetMaterial(___physics)
		self._primitive_RenderPhysics:Draw()
		cam.PopModelMatrix()
	else
		self:DrawModel()
	end

	if self:Get_primitive_debug_hitbox() then
		render.DrawLine(self:GetPos(), self:GetPos() + self:GetForward()*6, dbg_g)
		render.DrawLine(self:GetPos(), self:GetPos() + self:GetRight()*6, dbg_r)
		render.DrawLine(self:GetPos(), self:GetPos() + self:GetUp()*6, dbg_b)

		local min, max = self:GetCollisionBounds()
		render.DrawWireframeBox(self:GetPos(), self:GetAngles(), min, max, dbg_y)
	end

	if self:Get_primitive_debug_vertex() and self._primitive_RenderVertex then
		cam.Start2D()
		surface.SetFont(shadowscion_standard_font or "Default")
		surface.SetTextColor(dbg_vertex)
		surface.SetDrawColor(dbg_vertex)

		for i = 1, #self._primitive_RenderVertex do
			local pos = self:LocalToWorld(rawget(self._primitive_RenderVertex, i)):ToScreen()
			surface.SetTextPos(pos.x, pos.y)
			surface.DrawText(i)
			surface.DrawRect(pos.x, pos.y, 2, 2)
		end
		cam.End2D()
	end
end

function ENT:_primitive_NotifyDebug(name, old, new)
	if self.Draw == DrawError then
		return
	end

	local enable = tobool(new)
	if not enable then
		for k, v in pairs({"_primitive_debug_hitbox","_primitive_debug_vertex","_primitive_debug_physics"}) do
			if name ~= v and self["Get" .. v](self) then
				enable = true
				break
			end
		end
	end

	local enablePhysics
	if name == "_primitive_debug_physics" then enablePhysics = new else enablePhysics = self:Get_primitive_debug_physics() end

	if not enablePhysics and self._primitive_RenderPhysics and self._primitive_RenderPhysics:IsValid() then
		self._primitive_RenderPhysics:Destroy()
	end

	if enablePhysics then
		local physicsObject = self:GetPhysicsObject()
		if physicsObject and physicsObject:IsValid() then
			local physicsMesh = physicsObject:GetMesh()
			if physicsMesh and #physicsMesh >= 3 then
				self._primitive_RenderPhysics = Mesh()
				self._primitive_RenderPhysics:BuildFromTriangles(physicsMesh)
			end
		end
	end

	self.Draw = enable and DrawDebug or DrawNormal
end

function ENT:_primitive_UpdateRender(primitive)
	if self._primitive_RenderMesh and self._primitive_RenderMesh.Mesh and self._primitive_RenderMesh.Mesh:IsValid() then
		self._primitive_RenderMesh.Mesh:Destroy()
		self._primitive_RenderMesh = nil
		self.Draw = DrawNormal
	end

	if primitive.triangle then
		self._primitive_RenderMesh = { Mesh = Mesh(), Material = baseMaterial }
		self._primitive_RenderMesh.Mesh:BuildFromTriangles(primitive.triangle)
	end

	self._primitive_RenderVertex = primitive.vertex

	local min, max = self:GetCollisionBounds()
	self:SetRenderBounds(min, max)

	if primitive.iserror then
		self.Draw = DrawError
	else
		self:_primitive_NotifyDebug()
	end
end
