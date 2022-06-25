
---- left
local color_lcol_enabled = Color(230, 240, 230)
local color_lcol_disabled = Color(240, 230, 230)
local color_llbl_enabled = Color(75, 75, 75)
local color_llbl_disabled = Color(125, 115, 115)

---- right
local color_rcol_enabled = Color(235, 240, 235)
local color_rcol_disabled = Color(240, 235, 235)

---- misc
local color_col_strike = Color(0, 0, 0)
local color_dframe = Color(72, 72, 75)
local color_text_entry = Color(72, 72, 75, 50)

----
local function PaintRow(self, w, h)
	if not IsValid(self.Inner) then return end

	local Skin = self:GetSkin()
	local editing = self.Inner:IsEditing()
	local disabled = not self.Inner:IsEnabled() or not self:IsEnabled()

	if disabled then
		surface.SetDrawColor(color_lcol_disabled)
		surface.DrawRect(0, 0, w*0.45, h)

		surface.SetDrawColor(color_rcol_disabled)
		surface.DrawRect(w*0.45, 0, w, h)

		surface.SetDrawColor(color_col_strike)
		surface.DrawLine(0, h*0.5, w, h*0.5)

		self.Label:SetTextColor(color_llbl_disabled)
	elseif editing then
		surface.SetDrawColor(Skin.Colours.Properties.Column_Selected)
		surface.DrawRect(0, 0, w*0.45, h)

		self.Label:SetTextColor(Skin.Colours.Properties.Label_Selected)
	else
		surface.SetDrawColor(color_lcol_enabled)
		surface.DrawRect(0, 0, w*0.45, h)

		surface.SetDrawColor(color_rcol_enabled)
		surface.DrawRect(w*0.45, 0, w, h)

		self.Label:SetTextColor(color_llbl_enabled)
	end

	surface.SetDrawColor(Skin.Colours.Properties.Border)
	surface.DrawRect(w - 1, 0, 1, h)
	surface.DrawRect(w*0.45, 0, 1, h)
	surface.DrawRect(0, h - 1, w, 1)
end

----
local PANEL = {}

local icon_cache = {}

function PANEL:Init()
	self.PropertySheet = self:Add("DProperties")
	self.PropertySheet:Dock(FILL)

	self.PropertySheet.SetEntity = function(pnl, entity)
		if pnl.m_Entity == entity then
			return
		end
		pnl.m_Entity = entity
		pnl:RebuildControls()
	end

	self.PropertySheet.EntityLost = function(pnl)
		pnl:Clear()
		pnl:OnEntityLost()
	end

	self.PropertySheet.OnEntityLost = function(pnl)
		self:Remove()
	end

	self.PropertySheet.RebuildControls = function(pnl)
		pnl:Clear()

		if not IsValid(pnl.m_Entity) then return end
		if not isfunction(pnl.m_Entity.GetEditingData) then return end

		local editor = pnl.m_Entity:GetEditingData()

		local i = 1000
		for name, edit in pairs(editor) do
			if edit.order == nil then edit.order = i end
			i = i + 1
		end

		for name, edit in SortedPairsByMemberValue(editor, "order") do
			pnl:EditVariable(name, edit)
		end
	end

	self.PropertySheet.EditVariable = function(pnl, varname, editdata)
		if not istable(editdata) then return end
		if not isstring(editdata.type) then return end

		local row = pnl:CreateRow(editdata.category or "#entedit.general", editdata.title or varname)

		row:Setup(editdata.type, editdata)
		row.Paint = PaintRow
		row.Label:SetFont("DermaDefault")

		if editdata.type == "Combo" and editdata.icons then
			local combo_box = row.Inner:GetChildren()[1]

			for k, v in pairs(combo_box.Choices) do
				local path = string.format(editdata.icons, string.lower(v))
				local icon = icon_cache[path]

				if not icon then
					icon_cache[path] = file.Exists("materials/" .. path, "GAME") and path or "icon16/bullet_white.png"
					icon = icon_cache[path]
				end
				combo_box.Spacers[k] = true
				combo_box.ChoiceIcons[k] = icon
			end

			combo_box.OnSelect = function(_, id, val, data)
				row.Inner:ValueChanged(data, true)
				combo_box:SetImage(combo_box.ChoiceIcons[id])
			end

		elseif editdata.type == "Float" or editdata.type == "Int" then
			local slider = row.Inner:GetChildren()[1]

			slider.OnValueChanged = function(_, newval)
				if editdata.round then
					newval = editdata.round * math.Round(newval / editdata.round)
					slider:SetValue(newval)
				end

				if editdata.waitforenter and slider:IsEditing() then -- why isn't waitforenter a thing on every control
					row.SendQueue = SysTime()
				end

				row.Inner:ValueChanged(newval)
			end
		end

		row.DataUpdate = function(_)
			if not IsValid(pnl.m_Entity) then pnl:EntityLost() return end

			row:SetValue(pnl.m_Entity:GetNetworkKeyValue(varname))

			if editdata.enabled ~= nil and editdata.enabled ~= row:IsEnabled() then row:SetEnabled(editdata.enabled) end

			if row.SendQueue and SysTime() - row.SendQueue > 0.015 and row.SendValue then
				pnl.m_Entity:EditValue(varname, row.SendValue)
				row.SendQueue = nil
				row.SendValue = nil
			end
		end

		row.DataChanged = function(_, val)
			if not IsValid(pnl.m_Entity) then pnl:EntityLost() return end

			if row.SendQueue then
				row.SendValue = tostring(val)
				return
			end

			pnl.m_Entity:EditValue(varname, tostring(val))
		end
	end

	self.btnMinim:Remove()
	self.btnMaxim:Remove()
	self.btnClose:SetText("r")
	self.btnClose:SetFont("Marlett")
	self.btnClose.Paint = function(pnl, w, h)
		derma.SkinHook("Paint", "Button", pnl, w, h)
	end
	self.lblTitle:SetFont("DermaDefault")
end

----
function PANEL:SetEntity(ent)
	self:SetTitle(tostring(ent))
	self.PropertySheet:SetEntity(ent)
end

----
function PANEL:PerformLayout()
	local titlePush = 0
	if IsValid(self.imgIcon) then
		self.imgIcon:SetPos(5, 5)
		self.imgIcon:SetSize(16, 16)
		titlePush = 16
	end

	local w, h = self:GetSize()

	self.btnClose:SetPos(w - 49, 3)
	self.btnClose:SetSize(45, 22)

	self.lblTitle:SetPos(6 + titlePush, 3)
	self.lblTitle:SetSize(w - 25 - titlePush, 22)
end

----
function PANEL:Paint(w, h)
	surface.SetDrawColor(color_dframe)
	surface.DrawRect(0, 0, w, h)
	surface.SetDrawColor(0, 0, 0)
	surface.DrawOutlinedRect(0, 0, w, h)
end

----
vgui.Register("primitive_editor", PANEL, "DFrame")

----
do
	local function PaintEntry(self, w, h)
		surface.SetDrawColor(color_text_entry)
		surface.DrawRect(0, 0, w, h)
		self:DrawTextEntryText(self:GetTextColor(), self:GetHighlightColor(), self:GetCursorColor())
	end

	local PANEL = {}

	function PANEL:Init()
	end

	function PANEL:Setup(vars)
		self:Clear()

		vars = vars or {}

		local wfe = not vars.waitforenter

		local x = self:Add("DTextEntry")
		x:SetNumeric(true)
		if not wfe then x:SetUpdateOnType(true) end

		local y = self:Add("DTextEntry")
		y:SetNumeric(true)
		if not wfe then y:SetUpdateOnType(true) end

		local z = self:Add("DTextEntry")
		z:SetNumeric(true)
		if not wfe then z:SetUpdateOnType(true) end

		local min = vars.min or 0
		local max = vars.max or 1

		x.OnValueChange = function(entry, val)
			val = tonumber(val)
			if val < min then val = min elseif val > max then val = max end
			self:ValueChanged(string.format("%s %s %s", val, y:GetText(), z:GetText()))
		end
		y.OnValueChange = function(entry, val)
			val = tonumber(val)
			if val < min then val = min elseif val > max then val = max end
			self:ValueChanged(string.format("%s %s %s", x:GetText(), val, z:GetText()))
		end
		z.OnValueChange = function(entry, val)
			val = tonumber(val)
			if val < min then val = min elseif val > max then val = max end
			self:ValueChanged(string.format("%s %s %s", x:GetText(), y:GetText(), val))
		end

		x.Paint = PaintEntry
		y.Paint = PaintEntry
		z.Paint = PaintEntry

		self.PerformLayout = function(_, w, h)
			local w = w / 3 - 2

			x:SetPos(0, 1)
			y:SetPos(w + 1, 1)
			z:SetPos(w + w + 2, 1)

			x:SetSize(w, h - 3)
			y:SetSize(w, h - 3)
			z:SetSize(w, h - 3)
		end

		self.IsEditing = function( self )
			return x:IsEditing() or y:IsEditing() or z:IsEditing()
		end

		self.IsEnabled = function( self )
			return x:IsEnabled()
		end

		self.SetEnabled = function( self, b )
			x:SetEnabled(b)
			y:SetEnabled(b)
			z:SetEnabled(b)
		end

		self.SetValue = function( self, val )
			x:SetText(string.format("%.2f", val.x))
			y:SetText(string.format("%.2f", val.y))
			z:SetText(string.format("%.2f", val.z))
		end
	end

	derma.DefineControl( "DProperty_PrimVec", "", PANEL, "DProperty_Generic" )
end
