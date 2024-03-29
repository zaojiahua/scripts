local Widget = require "widgets/widget"
local Image = require "widgets/image"
local Tab = require "widgets/tab"

local TabGroup = Class(Widget, function(self)
    Widget._ctor(self, "TabGroup")
    self.tabs = {}
    self.spacing = 70
    self.offset = Vector3(0,-1,0)
    self.hideoffset = Vector3(-64, 0, 0)
    self.selected = nil
    self.base_pos = {}
    self.shown = {}
end)

function TabGroup:GetNumTabs()
    return #self.tabs
end

function TabGroup:HideTab(tab)
	if self.shown[tab] then
		if self.base_pos[tab] then
			tab:MoveTo(self.base_pos[tab], (self.base_pos[tab] + self.hideoffset), .33)
			self.shown[tab] = false
		end
	end
end

function TabGroup:GetNextIdx()

    local idx = self:GetCurrentIdx() or 1
    while idx < #self.tabs do
        idx = idx + 1
        local tab = self.tabs[idx]
        
        if tab and self.shown[tab] then
            return idx
        end
    end
    return self:GetCurrentIdx()

end

function TabGroup:GetPrevIdx()

    local idx = self:GetCurrentIdx() or 1
    while idx > 1 do
        idx = idx - 1
        local tab = self.tabs[idx]
        
        if tab and self.shown[tab] then
            return idx
        end
    end
    return self:GetCurrentIdx()

end


function TabGroup:GetCurrentIdx()
	for k,v in pairs(self.tabs) do
		if v.selected then
			return k
		end
	end
end

function TabGroup:ShowTab(tab)
	if not self.shown[tab] then
		if self.base_pos[tab] then
			tab:MoveTo((self.base_pos[tab] + self.hideoffset), self.base_pos[tab], .33)
			self.shown[tab] = true
		end
	end
end

function TabGroup:OpenTab(idx)
	local tab = self.tabs[idx]
	if tab then
		if self.shown[tab] then
			tab:Select()
            return tab
		end
	end
end


function TabGroup:AddTab(name, atlas, icon_atlas, icon, imnorm, imselected, imhighlight, imoverlay, highlightpos, onselect, ondeselect)

    local tab = self:AddChild(Tab(self, name, atlas, icon_atlas, icon, imnorm, imselected, imhighlight, imoverlay, highlightpos, onselect, ondeselect))
    table.insert(self.tabs, tab)
    
    local numtabs = #self.tabs
    
    local scalar = -self.spacing*(numtabs-1)*.5
    local offset = self.offset*scalar
    
    for k,v in ipairs(self.tabs) do

        v:SetPosition(offset.x, offset.y, offset.z)
        self.base_pos[v] = Vector3(offset.x, offset.y, offset.z)
        offset = offset + self.offset*self.spacing
    end
    
    self.shown[tab] = true
    return tab
end


function TabGroup:OnTabsChanged()
    local selected = nil
    for k,v in pairs(self.tabs) do
        if v.selected then
            selected = v
            break
        end
    end
    
    if self.selected ~= selected then
        
        if self.selected and not selected then
            if self.onclose then self:onclose() end
        elseif not self.selected and selected then
            if self.onopen then self:onopen() end
        else
            if self.onchange then self:onchange() end
        end
        
        self.selected = selected
    end
end

function TabGroup:DeselectAll()
    for k,v in ipairs(self.tabs) do
        v:Deselect()
    end
    
end

return TabGroup
