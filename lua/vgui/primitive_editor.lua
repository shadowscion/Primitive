
local PANEL = {}

function PANEL:Init()
end

function PANEL:SetEntity(entity)
	if self.m_Entity == entity then
		return
	end
	self.m_Entity = entity
	self:RebuildControls()
end

function PANEL:RebuildControls()
	self:Clear()

	if not IsValid(self.m_Entity) then
		return
	end
	if not isfunction(self.m_Entity.GetEditingData) then
		return
	end

	local editor = self.m_Entity:GetEditingData()

	local i = 1000
	for name, edit in pairs(editor) do
		if edit.order == nil then
			edit.order = i
		end
		i = i + 1
	end

	for name, edit in SortedPairsByMemberValue(editor, "order") do
		self:EditVariable(name, edit)
	end
end

local color_valid = Color(200, 255, 210)

local function PaintRow(self, w, h)
	if not IsValid(self.Inner) then
		return
	end

	local Skin = self:GetSkin()
	local editing = self.Inner:IsEditing()
	local disabled = not self.Inner:IsEnabled() or not self:IsEnabled()

	if editing then
		surface.SetDrawColor(Skin.Colours.Properties.Column_Selected)
		surface.DrawRect(w * 0.45, 0, w, h)
		surface.DrawRect(0, 0, w * 0.45, h)
	elseif self.colorOverride or not disabled then
		surface.SetDrawColor(color_valid)
		surface.DrawRect(w * 0.45, 0, w, h)
		surface.DrawRect(0, 0, w * 0.45, h)
	end

	surface.SetDrawColor(Skin.Colours.Properties.Border)
	surface.DrawRect(w - 1, 0, 1, h)
	surface.DrawRect(w * 0.45, 0, 1, h)
	surface.DrawRect(0, h - 1, w, 1)

	if disabled then
		surface.SetDrawColor(color_black)
		surface.DrawLine(0, h/2, w, h/2)
	end

	if editing then
		self.Label:SetTextColor(Skin.Colours.Properties.Label_Selected)
	else
		self.Label:SetTextColor(Skin.Colours.Properties.Label_Normal)
	end
end

function PANEL:EditVariable(varname, editdata)
	if not istable(editdata) then return end
	if not isstring(editdata.type) then return end

	local row = self:CreateRow(editdata.category or "#entedit.general", editdata.title or varname)

	row:Setup(editdata.type, editdata)

	row.Paint = PaintRow

	row.colorOverride = editdata.colorOverride

	row.SetColorOverride = function(pnl)
		if editdata.enabled == nil then
			return
		end
		if editdata.enabled then
			if not row:IsEnabled() then
				row:SetEnabled(true)
			end
		else
			if row:IsEnabled() then
				row:SetEnabled(false)
			end
		end
	end

	row.DataUpdate = function(_)
		if not IsValid(self.m_Entity) then
			self:EntityLost()
			return
		end
		row:SetValue(self.m_Entity:GetNetworkKeyValue(varname))
		row:SetColorOverride()
	end

	row.DataChanged = function(_, val)
		if not IsValid(self.m_Entity) then
			self:EntityLost()
			return
		end
		self.m_Entity:EditValue(varname, tostring(val))
	end
end

function PANEL:EntityLost()
	self:Clear()
	self:OnEntityLost()
end

function PANEL:OnEntityLost()

end

PANEL.AllowAutoRefresh = true

function PANEL:PreAutoRefresh()
end

function PANEL:PostAutoRefresh()
	self:RebuildControls()
end

derma.DefineControl("primitive_editor", "", PANEL, "DProperties")
