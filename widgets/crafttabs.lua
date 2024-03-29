require "class"

local TileBG = require "widgets/tilebg"
local InventorySlot = require "widgets/invslot"
local Image = require "widgets/image"
local ImageButton = require "widgets/imagebutton"
local Widget = require "widgets/widget"
local TabGroup = require "widgets/tabgroup"
local UIAnim = require "widgets/uianim"
local Text = require "widgets/text"
local MouseCrafting = require "widgets/mousecrafting"
local ControllerCrafting = require "widgets/controllercrafting"

local base_scale = .75
local selected_scale = .9
local HINT_UPDATE_INTERVAL = 2.0 -- once per second

local tab_bg = 
{
    normal = "tab_normal.tex",
    selected = "tab_selected.tex",
    highlight = "tab_highlight.tex",
    overlay = "tab_researchable.tex",
}


local CraftTabs = Class(Widget, function(self, owner, top_root)
    
    Widget._ctor(self, "CraftTabs")
    self.owner = GetPlayer()    
	self.owner = owner


	self.craft_idx_by_tab = {}

    self:SetPosition(0,0,0)

    --[[self.craftroot = self:AddChild(Widget("craftroot"))
	self.craftroot:SetVAnchor(ANCHOR_TOP)
    self.craftroot:SetHAnchor(ANCHOR_MIDDLE)
    self.craftroot:SetScaleMode(SCALEMODE_PROPORTIONAL)
    
    self.controllercrafting = self.craftroot:AddChild(ControllerCrafting())
    --]]
    self.controllercrafting = self:AddChild(ControllerCrafting())
	self.controllercrafting:Hide()

    self.crafting = self:AddChild(MouseCrafting(self))
    self.crafting:Hide()
    self.bg = self:AddChild(Image("images/hud.xml", "craft_bg.tex"))      
    
    self.tabs = self:AddChild(TabGroup())
    self.tabs:SetPosition(-16,0,0)
    
    self.bg_cover = self:AddChild(Image("images/hud.xml", "craft_bg_cover.tex"))
    self.bg_cover:SetPosition(-38, 0, 0)
    self.bg_cover:SetClickable(false)

    self.tabs.onopen = function() self.owner.SoundEmitter:PlaySound("dontstarve/HUD/craft_open") end
    self.tabs.onchange = function() self.owner.SoundEmitter:PlaySound("dontstarve/HUD/craft_open") end
    self.tabs.onclose = function() self.owner.SoundEmitter:PlaySound("dontstarve/HUD/craft_close") end
    self.tabs.onhighlight = function() self.owner.SoundEmitter:PlaySound("dontstarve/HUD/recipe_ready") return .2 end
    self.tabs.onoverlay = function() self.owner.SoundEmitter:PlaySound("dontstarve/HUD/research_available") return .2 end
    
    local tabnames = {}
    for k,v in pairs(RECIPETABS) do
        table.insert(tabnames, v)
    end

    for k,v in pairs(owner.components.builder.custom_tabs) do
        table.insert(tabnames, v)
    end

    table.sort(tabnames, function(a,b) return a.sort < b.sort end)
    
    self.tab_order = {}

    self.tabs.spacing = 750/#tabnames
    
    self.tabbyfilter = {}
    for k,v in ipairs(tabnames) do
        local tab = self.tabs:AddTab(STRINGS.TABS[v.str], resolvefilepath("images/hud.xml"), v.icon_atlas or resolvefilepath("images/hud.xml"), v.icon, tab_bg.normal, tab_bg.selected, tab_bg.highlight, tab_bg.overlay,
            
            function() --select fn
                if not self.controllercraftingopen then
	                
            		if self.craft_idx_by_tab[k] then
            			self.crafting.idx = self.craft_idx_by_tab[k]
            		end

	                self.crafting:SetFilter( 
	                    function(recipe)
	                        local rec = GetRecipe(recipe)
	                        return rec and rec.tab == v
	                    end)
                
															                
					self.crafting:Open()
                end
            end, 

            function() --deselect fn
            	self.craft_idx_by_tab[k] = self.crafting.idx
                self.crafting:Close()
            end)
        tab.filter = v
        tab.icon = v.icon
        tab.icon_atlas = v.icon_atlas or resolvefilepath("images/hud.xml")
        tab.tabname = STRINGS.TABS[v.str]
        self.tabbyfilter[v] = tab
        
        table.insert(self.tab_order, tab)
    end
    
    self.inst:ListenForEvent("techtreechange", function(inst, data) self:UpdateRecipes() end, self.owner)
    self.inst:ListenForEvent("itemget", function(inst, data) self:UpdateRecipes() end, self.owner)
    self.inst:ListenForEvent("itemlose", function(inst, data) self:UpdateRecipes() end, self.owner)
    self.inst:ListenForEvent("stacksizechange", function(inst, data) self:UpdateRecipes() end, self.owner)
    self.inst:ListenForEvent("unlockrecipe", function(inst, data) self:UpdateRecipes() end, self.owner)
    self:DoUpdateRecipes()
    self:SetScale(base_scale, base_scale, base_scale)
    self:StartUpdating()
    
	self.openhint = self:AddChild(Text(UIFONT, 40))
	self.openhint:SetPosition(10+150, 430, 0)
	self.openhint:SetRegionSize(300, 45, 0)
	self.openhint:SetHAlign(ANCHOR_LEFT)

    self.hint_update_check = HINT_UPDATE_INTERVAL
    
end)


function CraftTabs:Close()
	self.crafting:Close()
	self.controllercrafting:Close()

	self.tabs:DeselectAll()
	self.controllercraftingopen = false
end

function CraftTabs:CloseControllerCrafting()
	if self.controllercraftingopen then
		self:ScaleTo(selected_scale, base_scale, .15)
		--self.blackoverlay:Hide()
		self.controllercraftingopen = false
		self.tabs:DeselectAll()
		self.controllercrafting:Close()
	end
end

function CraftTabs:OpenControllerCrafting()
	--self.parent:AddChild(self.controllercrafting)
	
	if not self.controllercraftingopen then
		self:ScaleTo(base_scale, selected_scale, .15)
		--self.blackoverlay:Show()
		self.controllercraftingopen = true
		self.crafting:Close()	
		self.controllercrafting:Open()	
	end
end

function CraftTabs:OnUpdate(dt)
	
	self.hint_update_check = self.hint_update_check - dt
	if 0 > self.hint_update_check then	
	   	if not TheInput:ControllerAttached() then
			self.openhint:Hide()
		else
			self.openhint:Show()
		    self.openhint:SetString(TheInput:GetLocalizedControl(TheInput:GetControllerID(), CONTROL_OPEN_CRAFTING))
		end
	    self.hint_update_check = HINT_UPDATE_INTERVAL
	end
	
	if self.crafting.open then
		local x = TheInput:GetScreenPosition().x
		local w,h = TheSim:GetScreenSize()
		if x > w*.33 then
			self.crafting:Close()
			self.tabs:DeselectAll()
		end

	end

	if self.needtoupdate then
		self:DoUpdateRecipes()
	end
	
end

function CraftTabs:OpenTab(idx)
	return self.tabs:OpenTab(idx)
end


function CraftTabs:GetCurrentIdx()
	return self.tabs:GetCurrentIdx()
end

function CraftTabs:GetNextIdx()
	return self.tabs:GetNextIdx()
end

function CraftTabs:GetPrevIdx()
	return self.tabs:GetPrevIdx()
end


function CraftTabs:UpdateRecipes()
    self.needtoupdate = true
end

function CraftTabs:DoUpdateRecipes()
	if self.needtoupdate then

		self.needtoupdate = false	
		local tabs_to_highlight = {}
		local tabs_to_overlay = {}
		local valid_tabs = {}
	    
		for k,v in pairs(self.tabbyfilter) do
			tabs_to_highlight[v] = 0
			tabs_to_overlay[v] = 0
			valid_tabs[v] = false
		end
	    
		if self.owner.components.builder then
			local current_research_level = self.owner.components.builder.accessible_tech_trees or NO_TECH
			
			
			local recipes = GetAllRecipes()
			for k,rec in pairs(recipes) do

				local tab = self.tabbyfilter[rec.tab]
				local has_researched = self.owner.components.builder:KnowsRecipe(rec.name)
				
				local can_see = has_researched or CanPrototypeRecipe(rec.level, current_research_level)
				local can_build = self.owner.components.builder:CanBuild(rec.name)
				local can_research = false
				
				can_research = not has_researched and can_build and CanPrototypeRecipe(rec.level, current_research_level)
	            
	            valid_tabs[tab] = valid_tabs[tab] or can_see
	            
				if can_build and has_researched then
					if tab then
						tabs_to_highlight[tab] = 1 + (tabs_to_highlight[tab] or 0)
					end
				end
	            
				if can_research then
					if tab then
						tabs_to_overlay[tab] = 1 + (tabs_to_overlay[tab] or 0)
					end
				end
				
			end
		end

		local to_select = nil
		local current_open = nil

		
		for k,v in pairs(valid_tabs) do
			if v then
				self.tabs:ShowTab(k)
			else
				self.tabs:HideTab(k)
			end
		end
		

		for k,v in pairs(tabs_to_highlight) do    
			if v > 0 then
				k:Highlight(v)
			else
				k:UnHighlight()
			end
	        
		end
	    
		for k,v in pairs(tabs_to_overlay) do    
			if v > 0 then
				k:Overlay()
			else
				k:HideOverlay()
			end
		end    
	    
		if self.crafting and self.crafting.shown then
			self.crafting:UpdateRecipes()
		end
	end
end

return CraftTabs
