local Widget = require "widgets/widget"
local AnimButton = require "widgets/animbutton"
local ImageButton = require "widgets/imagebutton"


local Menu = Class(Widget, function(self, menuitems, offset, horizontal)
    Widget._ctor(self, "MENU")
    self.offset = offset
    self.items = {}
    self.horizontal = horizontal

    if menuitems then
    	for k,v in ipairs(menuitems) do
    		self:AddItem(v.text, v.cb, v.offset)
	    end
	end
end)

function Menu:Clear()
	for k,v in pairs(self.items) do
		v:Kill()
	end
	self.items = {}
end

function Menu:GetNumberOfItems()
	return #self.items
end

function Menu:SetFocus(index)
	index = index or (self.reverse and -1 or 1)
	if index < 0 then
		index = index + #self.items +1 
	end

	if self.items[index] then
		self.items[index]:SetFocus()
	end
end

function Menu:DoFocusHookups()
	
	local fwd = self.horizontal and ( self.offset > 0 and MOVE_RIGHT or MOVE_LEFT) or (self.offset > 0 and MOVE_UP or MOVE_DOWN)
	local back = self.horizontal and ( self.offset > 0 and MOVE_LEFT or MOVE_RIGHT) or (self.offset > 0 and MOVE_DOWN or MOVE_UP)

	for k,v in ipairs(self.items) do
		if k > 1 then
			self.items[k]:SetFocusChangeDir(back, self.items[k-1])
		end		
		
		if k < #self.items then
			self.items[k]:SetFocusChangeDir(fwd, self.items[k+1])
		end
	end

	--[[if #self.items > 1 then
		self.items[1]:SetFocusChangeDir(back, self.items[#self.items])
		self.items[#self.items]:SetFocusChangeDir(fwd, self.items[1])
	end--]]
end

function Menu:SetVRegPoint(valign)
	local pos = Vector3(0,0,0) -- ANCHOR_TOP
	if valign == ANCHOR_MIDDLE then
		pos = Vector3(0, (#self.items-1)*-0.5, 0)
	elseif valign == ANCHOR_BOTTOM then
		pos = Vector3(0, (#self.items-1)*-1, 0)
	end

	for i,v in ipairs(self.items) do
		self.items[i]:SetVAlign(valign)
		self.items[i]:SetPosition(pos)
		pos.y = pos.y + self.offset
	end
end

function Menu:SetHRegPoint(halign)
	local pos = Vector3(0,0,0) -- ANCHOR_LEFT
	if halign == ANCHOR_MIDDLE then
		pos = Vector3(self.offset*(#self.items-1)*-0.5, 0,  0)
	elseif halign == ANCHOR_RIGHT then
		pos = Vector3(self.offset*(#self.items-1)*-1, 0, 0)
	end

	for i,v in ipairs(self.items) do
		local width, height = self.items[i].image:GetSize()
		self.items[i]:SetPosition(pos)
		--if halign == ANCHOR_MIDDLE then
			--local b_pos = pos + Vector3(-width*0.5, 0, 0)
			--self.items[i]:SetPosition(b_pos)
		--elseif halign == ANCHOR_RIGHT then
			--local b_pos = pos + Vector3(-width, 0, 0)
			--self.items[i]:SetPosition(b_pos)
		--else
			--self.items[i]:SetPosition(pos)
		--end
		pos.x = pos.x + self.offset
	end
end

function Menu:AddCustomItem(widget)
	local pos = Vector3(0,0,0)
	if self.horizontal then
		pos.x = pos.x + self.offset * #self.items
	else
		pos.y = pos.y + self.offset * #self.items
	end
	self:AddChild(widget)
	widget:SetPosition(pos)
	table.insert(self.items, widget)
	self:DoFocusHookups()
	return widget
end

function Menu:AddItem(text, cb, offset)
	local pos = Vector3(0,0,0)
	if self.horizontal then
		pos.x = pos.x + self.offset * #self.items
	else
		pos.y = pos.y + self.offset * #self.items
	end
	
	if offset then
		pos = pos + offset	
	end
	

	local button = self:AddChild(ImageButton())
	button:SetPosition(pos)
	button:SetText(text)
	button.text:SetColour(0,0,0,1)
	button:SetOnClick( cb )
	button:SetFont(BUTTONFONT)
	button:SetTextSize(40)    

	table.insert(self.items, button)

	self:DoFocusHookups()
	return button
end

return Menu
