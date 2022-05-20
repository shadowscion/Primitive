

----------------------------------------------------------------
include("shared.lua")

local material
if file.Exists("materials/sprops/sprops_grid_12x12.vtf", "GAME") then material = Material("sprops/sprops_grid_12x12") else material = Material("hunter/myplastic") end


----------------------------------------------------------------
function ENT:Initialize()
end


----------------------------------------------------------------
function ENT:Draw()
	self:DrawModel()

	/*
	render.DrawLine(self:GetPos(), self:GetPos() + self:GetForward()*6, Color(0, 255, 0))
	render.DrawLine(self:GetPos(), self:GetPos() + self:GetRight()*6, Color(255, 0, 0))
	render.DrawLine(self:GetPos(), self:GetPos() + self:GetUp()*6, Color(0, 0, 255))

	local min, max = self:GetCollisionBounds()
	render.DrawWireframeBox(self:GetPos(), self:GetAngles(), min, max, Color(255, 255, 0, 25))

	if self.primitive_render_vert then
		cam.Start2D()

		surface.SetFont("Default")
		surface.SetTextColor(255, 255, 0, 150)
		surface.SetDrawColor(255, 255, 0, 255)

		for k, v in pairs(self.primitive_render_vert) do
			--local pos = self:LocalToWorld(v + v:GetNormalized()*2):ToScreen()
			local pos = self:LocalToWorld(v):ToScreen()

			surface.SetTextPos(pos.x, pos.y)
			surface.DrawText(k)

			surface.DrawRect(pos.x, pos.y, 2, 2)
		end

		cam.End2D()
	end
	*/
end

function ENT:GetRenderMesh()
	return self.primitive_render_mesh
end


----------------------------------------------------------------
function ENT:_primitive_postupdate(success, shape, ret)
	self.primitive_render_vert = shape.vertex
	if not success then
		return
	end

	if self.primitive_render_mesh and IsValid(self.primitive_render_mesh.Mesh) then
		self.primitive_render_mesh.Mesh:Destroy()
		self.primitive_render_mesh.Mesh = nil
	end

	self.primitive_render_mesh = {Mesh = Mesh(), Material = material}
	self.primitive_render_mesh.Mesh:BuildFromTriangles(ret)
end


----------------------------------------------------------------
function ENT:OnRemove()
	local snapshot = self.primitive_render_mesh
	timer.Simple(0, function()
		if self and IsValid(self) then
			return
		end
		if snapshot and IsValid(snapshot.Mesh) then
			snapshot.Mesh:Destroy()
		end
	end)
end
