local Screen = require "widgets/screen"
local AnimButton = require "widgets/animbutton"
local ImageButton = require "widgets/imagebutton"
local Spinner = require "widgets/spinner"
local Text = require "widgets/text"
local Image = require "widgets/image"
local Widget = require "widgets/widget"
local HoverText = require "widgets/hoverer"


local NumericSpinner = require "widgets/numericspinner"

local PopupDialogScreen = require "screens/popupdialog"

local levels = require "map/levels"
local customise = require("map/customise")
local options = {}

for k,v in pairs(customise.GROUP) do
	for kk, vv in pairs(v.items) do
		table.insert(options, {name = kk, image = vv.image, options = vv.desc or v.desc, default = vv.value, group = k, atlas = vv.atlas})
	end
end

local per_side = 7

local CustomizationScreen = Class(Screen, function(self, profile, cb, defaults)
    Widget._ctor(self, "CustomizationScreen")
	self.left_spinners = {}
	self.right_spinners = {}

    self.profile = profile
    self.defaults = defaults
	self.cb = cb
	
	if defaults then
		self.options = deepcopy(defaults)
		self.options.tweak = self.options.tweak or {}
		self.options.preset = self.options.preset or {}
	else
		self.options = 
		{ 
			preset = {},
			tweak = {}
		}
	end
	
    self.bg = self:AddChild(Image("images/ui.xml", "bg_plain.tex"))
    self.bg:SetTint(BGCOLOURS.RED[1],BGCOLOURS.RED[2],BGCOLOURS.RED[3], 1)

    self.bg:SetVRegPoint(ANCHOR_MIDDLE)
    self.bg:SetHRegPoint(ANCHOR_MIDDLE)
    self.bg:SetVAnchor(ANCHOR_MIDDLE)
    self.bg:SetHAnchor(ANCHOR_MIDDLE)
    self.bg:SetScaleMode(SCALEMODE_FILLSCREEN)
    
    self.root = self:AddChild(Widget("root"))
    self.root:SetVAnchor(ANCHOR_MIDDLE)
    self.root:SetHAnchor(ANCHOR_MIDDLE)
    self.root:SetScaleMode(SCALEMODE_PROPORTIONAL)
    
    local left_col =-RESOLUTION_X*.25 - 50
    local right_col = RESOLUTION_X*.25 - 75
    
    --menu buttons
    
    if not TheInput:ControllerAttached() then
		self.applybutton = self.root:AddChild(ImageButton())
	    self.applybutton:SetPosition(left_col, -185, 0)
	    self.applybutton:SetText(STRINGS.UI.CUSTOMIZATIONSCREEN.APPLY)
	    self.applybutton.text:SetColour(0,0,0,1)
	    self.applybutton:SetOnClick( function() self:Apply() end )
	    self.applybutton:SetFont(BUTTONFONT)
	    self.applybutton:SetTextSize(40)    
	    
		self.cancelbutton = self.root:AddChild(ImageButton())
	    self.cancelbutton:SetPosition(left_col, -260, 0)
	    self.cancelbutton:SetText(STRINGS.UI.CUSTOMIZATIONSCREEN.CANCEL)
	    self.cancelbutton.text:SetColour(0,0,0,1)
	    self.cancelbutton:SetOnClick( function() 
				if self:PendingChanges() then
					self:ConfirmRevert()
	    		else
	    			self:Cancel()
	    		end
	    	end )
	    self.cancelbutton:SetFont(BUTTONFONT)
	    self.cancelbutton:SetTextSize(40)
	end

	--set up the preset spinner

	self.presets = {}
	for i, level in pairs(levels.sandbox_levels) do
		table.insert(self.presets, {text=level.name, data=level.id, desc = level.desc, overrides = level.overrides})
	end
    
    self.presetpanel = self.root:AddChild(Widget("presetpanel"))
    self.presetpanel:SetScale(.9)
    self.presetpanel:SetPosition(left_col,50,0)
    self.presetpanelbg = self.presetpanel:AddChild(Image("images/globalpanels.xml", "presetbox.tex"))
    self.presetpanelbg:SetScale(1,.9, 1)

    self.presettitle = self.presetpanel:AddChild(Text(TITLEFONT, 50))
    self.presettitle:SetHAlign(ANCHOR_MIDDLE)
    self.presettitle:SetPosition(0, 105, 0)
	self.presettitle:SetRegionSize( 400, 70 )
    self.presettitle:SetString(STRINGS.UI.CUSTOMIZATIONSCREEN.PRESETTITLE)

    self.presetdesc = self.presetpanel:AddChild(Text(TITLEFONT, 35))
    self.presetdesc:SetHAlign(ANCHOR_MIDDLE)
    self.presetdesc:SetPosition(0, -60, 0)
	self.presetdesc:SetRegionSize( 300, 130 )
    self.presetdesc:SetString(self.presets[1].desc)
    self.presetdesc:EnableWordWrap(true)

	local w = 400
	self.presetspinner = self.presetpanel:AddChild(Spinner( self.presets, w, 50))
	self.presetspinner:SetPosition(0, 50, 0)
	self.presetspinner:SetTextColour(0,0,0,1)
	self.presetspinner.OnChanged =
		function( _, data )
		
			if self.presetdirty then
				TheFrontEnd:PushScreen(PopupDialogScreen(STRINGS.UI.CUSTOMIZATIONSCREEN.LOSECHANGESTITLE, STRINGS.UI.CUSTOMIZATIONSCREEN.LOSECHANGESBODY, 
					{{text=STRINGS.UI.CUSTOMIZATIONSCREEN.YES, cb = function() self.options.tweak = {} self:MakePresetClean() TheFrontEnd:PopScreen() end},
					{text=STRINGS.UI.CUSTOMIZATIONSCREEN.NO, cb = function() self:MakePresetDirty() TheFrontEnd:PopScreen() end}  }))
			else
				self:LoadPreset(data)
				self.options.tweak = {}				
			end
		end
		
	--add the custom options panel
	
	
	self.option_offset = 0
    self.optionspanel = self.root:AddChild(Widget("optionspanel"))
    self.optionspanel:SetScale(.9)
    self.optionspanel:SetPosition(right_col,20,0)
    self.optionspanelbg = self.optionspanel:AddChild(Image("images/globalpanels.xml", "panel_customization.tex"))

	self.rightbutton = self.optionspanel:AddChild(ImageButton("images/ui.xml", "scroll_arrow.tex", "scroll_arrow_over.tex", "scroll_arrow_disabled.tex"))
    self.rightbutton:SetPosition(340, 0, 0)
    self.rightbutton:SetOnClick( function() self:Scroll(per_side) end)
	--self.rightbutton:Hide()
	
	self.leftbutton = self.optionspanel:AddChild(ImageButton("images/ui.xml", "scroll_arrow.tex", "scroll_arrow_over.tex", "scroll_arrow_disabled.tex"))
    self.leftbutton:SetPosition(-340, 0, 0)
    self.leftbutton:SetScale(-1,1,1)
    self.leftbutton:SetOnClick( function() self:Scroll(-per_side) end)	
    self.leftbutton:Hide()
	
	self.optionwidgets = {}
	
	local preset = (self.defaults and self.defaults.preset) or self.presets[1].data

	self:LoadPreset(preset)
	if self.defaults and next(self.defaults.tweak) then
		self:MakePresetDirty()
	end

	self.hover = self:AddChild(HoverText(self))
	self.hover:SetScaleMode(SCALEMODE_PROPORTIONAL)
	self.hover.isFE = true


	self.default_focus = self.presetspinner
end)

function CustomizationScreen:SetValueForOption(option, value)
	-- do we have a spinner for this guy?
 	for idx,v in ipairs(options) do
		if (options[idx].name == option) then
			local localindex = idx - self.option_offset
			if localindex > 0 and localindex <= per_side * 2 then
				-- we're on screen so must have a spinner
				local spinner
				if localindex <= per_side then
					spinner = self.left_spinners[localindex]
				else
					spinner = self.right_spinners[localindex-per_side]
				end
				spinner:SetSelected(value)
			end
		end
	end
	-- we don't...do it manually
	local overrides = {}
	for k,v in pairs(self.presets) do
		if self.preset == v.data then
			for k,v in pairs(v.overrides) do
				overrides[v[1]] = v[2]
			end
		end
	end

 	for idx,v in ipairs(options) do
		if (options[idx].name == option) then
			local default_value = overrides[options[idx].name] or options[idx].default
			local localindex = idx - self.option_offset
			if value ~= default_value then 
				if not self.options.tweak[options[idx].group] then
					self.options.tweak[options[idx].group] = {}
				end
				self.options.tweak[options[idx].group][options[idx].name] = value
				if localindex > 0 and localindex <= per_side * 2 then
					-- hilite changed
					local bg = self.optionwidgets[localindex].bg
					bg:Show()
				end
			else
				if not self.options.tweak[options[idx].group] then
					self.options.tweak[options[idx].group] = {}
				end
				self.options.tweak[options[idx].group][options[idx].name] = nil
				if localindex > 0 and localindex <= per_side * 2 then
					-- unhilite change
					local bg = self.optionwidgets[localindex].bg
					bg:Hide()
				end
				
			end
		end
	end
end


function CustomizationScreen:GetValueForOption(option)
	local overrides = {}
	for k,v in pairs(self.presets) do
		if self.preset == v.data then
			for k,v in pairs(v.overrides) do
				overrides[v[1]] = v[2]
			end
		end
	end

 	for idx,v in ipairs(options) do
		if (options[idx].name == option) then
			local value = overrides[options[idx].name] or options[idx].default
			if self.options.tweak[options[idx].group] then
				local possiblevalue = self.options.tweak[options[idx].group][options[idx].name]
				value = possiblevalue or value
			end
			return value
		end
	end
	return nil
end


function CustomizationScreen:SetOptionEnabled(option, enabled)
	local newEnabled = false
	local oldEnabled = false
	-- do we have a spinner for this guy?
 	for idx,v in ipairs(options) do
		if (options[idx].name == option) then
			local localindex = idx - self.option_offset
			if localindex > 0 and localindex <= per_side * 2 then
				-- we're on screen so must have a spinner
				local spinner
				if localindex <= per_side then
					spinner = self.left_spinners[localindex]
				else
					spinner = self.right_spinners[localindex-per_side]
				end
				oldEnabled = spinner.enabled
				if enabled then
					spinner:Enable()		
				else
					spinner:Disable()
				end
				newEnabled = spinner.enabled
			end
		end
	end
	return newEnabled ~= oldEnabled
end

function CustomizationScreen:ValidateOptionCombinations()
	local dirty = false
	local seasonOption = self:GetValueForOption("season")
	if (seasonOption == "onlysummer") then
		-- set the season start and disable the spinner
		local oldValue = self:GetValueForOption( "season_start" )
		if oldValue ~= "summer" then
			if not self.oldSeasonStart then -- already overriding
				self.oldSeasonStart = oldValue
			end
			self:SetValueForOption("season_start","summer")
		end
		dirty = self:SetOptionEnabled("season_start",false)
	elseif (seasonOption == "onlywinter") then
		-- set the season start and disable the spinner
		local oldValue = self:GetValueForOption( "season_start" )
		if oldValue ~= "winter" then
			if not self.oldSeasonStart then -- already overriding
				self.oldSeasonStart = oldValue
			end
			self:SetValueForOption("season_start","winter")
		end
		dirty = self:SetOptionEnabled("season_start",false)
	else
		if self.oldSeasonStart then
			self:SetValueForOption("season_start",self.oldSeasonStart)
			self.oldSeasonStart = nil
		end
		dirty = self:SetOptionEnabled("season_start", true)
	end
	if dirty then
		self:HookupFocusMoves()
	end


end

function CustomizationScreen:HookupFocusMoves()
	local GetFirstEnabledSpinnerAbove = function(k, tbl)
		for i=k-1,1,-1 do
			if tbl[i].enabled then
				return tbl[i]
			end
		end
		return nil
	end
	local GetFirstEnabledSpinnerBelow = function(k, tbl)
		for i=k+1,#tbl do
			if tbl[i].enabled then
				return tbl[i]
			end
		end
		return nil
	end

	for k = 1, #self.left_spinners do
		local abovespinner = GetFirstEnabledSpinnerAbove(k, self.left_spinners)
		if abovespinner then
			self.left_spinners[k]:SetFocusChangeDir(MOVE_UP, abovespinner)
		end
		
		self.left_spinners[k]:SetFocusChangeDir(MOVE_LEFT, self.presetspinner)

		local belowspinner = GetFirstEnabledSpinnerBelow(k, self.left_spinners)
		if belowspinner	then
			self.left_spinners[k]:SetFocusChangeDir(MOVE_DOWN, belowspinner)
		end

		if self.right_spinners[k] then
			self.left_spinners[k]:SetFocusChangeDir(MOVE_RIGHT, self.right_spinners[k])
		end

	end

	self.presetspinner:SetFocusChangeDir(MOVE_RIGHT, self.left_spinners[math.floor(#self.left_spinners/2)])


	for k = 1, #self.right_spinners do
		local abovespinner = GetFirstEnabledSpinnerAbove(k, self.right_spinners)
		if abovespinner then
			self.right_spinners[k]:SetFocusChangeDir(MOVE_UP, abovespinner)
		end

		local belowspinner = GetFirstEnabledSpinnerBelow(k, self.right_spinners)
		if belowspinner	then
			self.right_spinners[k]:SetFocusChangeDir(MOVE_DOWN,belowspinner)
		end

		if self.left_spinners[k] then
			self.right_spinners[k]:SetFocusChangeDir(MOVE_LEFT, self.left_spinners[k])
		end

	end
end

function CustomizationScreen:RefreshOptions()

	local focus = self:GetDeepestFocus()
	local old_column = focus and focus.column
	local old_idx = focus and focus.idx
	
	for k,v in pairs(self.optionwidgets) do
		v.root:Kill()
	end
	self.optionwidgets = {}
	
	--these are in kind of a weird format, so convert it to something useful...
	local overrides = {}
	for k,v in pairs(self.presets) do
		if self.preset.data == v.data then
			for k,v in pairs(v.overrides) do
				overrides[v[1]] = v[2]
			end
		end
	end



	self.left_spinners = {}
	self.right_spinners = {}

	for k = 1, per_side*2 do
	
		local idx = self.option_offset+k
		
		if options[idx] then
			
			local spin_options = {} --{{text="default"..tostring(idx), data="default"},{text="2", data="2"}, }
			for k,v in ipairs(options[idx].options) do
				table.insert(spin_options, {text=v.text, data=v.data})
			end
			
			local opt = self.optionspanel:AddChild(Widget("option"))
			
			local bg = opt:AddChild(Image("images/ui.xml", "nondefault_customization.tex"))
			bg:Hide()
			local image = opt:AddChild(Image(options[idx].atlas or "images/customisation.xml", options[idx].image))
			
			local imscale = .5
			image:SetScale(imscale,imscale,imscale)
		    image:SetTooltip(options[idx].name)

			
			
			local spin_height = 50
			local w = 220
			local spinner = opt:AddChild(Spinner( spin_options, w, spin_height))
			spinner:SetTextColour(0,0,0,1)
			local default_value = overrides[options[idx].name] or options[idx].default
			
			spinner.OnChanged =
				function( _, data )
					if data ~= default_value then 
						bg:Show()
						if not self.options.tweak[options[idx].group] then
							self.options.tweak[options[idx].group] = {}
						end
						self.options.tweak[options[idx].group][options[idx].name] = data
					else
						bg:Hide()
						self.options.tweak[options[idx].group][options[idx].name] = nil
						if not next(self.options.tweak[options[idx].group]) then
							self.options.tweak[options[idx].group] = nil
						end
					end
					self:MakePresetDirty()
				end
				
			if self.options.tweak[options[idx].group] and self.options.tweak[options[idx].group][options[idx].name] then
				spinner:SetSelected(self.options.tweak[options[idx].group][options[idx].name])
				bg:Show()
			else
				spinner:SetSelected(default_value)
				bg:Hide()
			end
			
			
			spinner:SetPosition(35,0,0 )
			image:SetPosition(-105,0,0)
			local spacing = 75
			
			if k <= per_side then
				opt:SetPosition(-150, (per_side-1)*spacing*.5 - (k-1)*spacing - 10, 0)
				table.insert(self.left_spinners, spinner)
				spinner.column = "left"
				spinner.idx = #self.left_spinners
			else
				opt:SetPosition(150, (per_side-1)*spacing*.5 - (k-1-per_side)*spacing- 10, 0)
				table.insert(self.right_spinners, spinner)
				spinner.column = "right"
				spinner.idx = #self.right_spinners
			end
			
			table.insert(self.optionwidgets, {root = opt, bg = bg})
		end
	end
	
	-- call this before the focus moves so we can check if spinners are accessible
	self:ValidateOptionCombinations()

	--hook up all of the focus moves
	self:HookupFocusMoves()

	if old_column and old_idx then
		local list = old_column == "right" and self.right_spinners or self.left_spinners
		if #list == 0 then
			self.presetspinner:SetFocus()
		else
			list[math.min(#list, old_idx)]:SetFocus()	
		end
		
	else
		self.presetspinner:SetFocus()
	end
	
end

function CustomizationScreen:Scroll(dir)
	if (dir > 0 and (self.option_offset + per_side*2) < #options) or
		(dir < 0 and self.option_offset + dir >= 0) then
	
		self.option_offset = self.option_offset + dir
	end
	
	if self.option_offset > 0 then
		self.leftbutton:Show()
	else
		self.leftbutton:Hide()
	end
	
	if self.option_offset + per_side*2 < #options then
		self.rightbutton:Show()
	else
		self.rightbutton:Hide()
	end
	
	self:RefreshOptions()

end

function CustomizationScreen:MakePresetDirty()
	self.presetdirty = true
	
	for k,v in pairs(self.presets) do
		if self.preset.data == v.data then
			self.presetdesc:SetString(STRINGS.UI.CUSTOMIZATIONSCREEN.CUSTOMDESC)
			self.presetspinner:UpdateText(v.text .. " " .. STRINGS.UI.CUSTOMIZATIONSCREEN.CUSTOM)
		end
	end
	self:ValidateOptionCombinations()
end

function CustomizationScreen:MakePresetClean()
	self:LoadPreset(self.presetspinner:GetSelectedData())
end

function CustomizationScreen:LoadPreset(preset)
	for k,v in pairs(self.presets) do
		if preset == v.data then
			self.presetdesc:SetString(v.desc)
			self.presetspinner:SetSelectedIndex(k)
			self.presetdirty = false
			self.preset = v
			self.options.preset = v.data
			self:RefreshOptions()	
			return
		end
	end
end

function CustomizationScreen:Cancel()
	self.cb()
end

function CustomizationScreen:OnControl(control, down)
    
    if CustomizationScreen._base.OnControl(self, control, down) then return true end
    if not down then
    	if control == CONTROL_CANCEL then 
    		
			if self:PendingChanges() then
				self:ConfirmRevert()
    		else
    			self:Cancel()
    		end
    	elseif control == CONTROL_ACCEPT and TheInput:ControllerAttached() then 
    		if self:PendingChanges() then
    			self:Apply()
    		end
    	elseif control == CONTROL_PAGELEFT then
    		if self.leftbutton.shown then
    			TheFrontEnd:GetSound():PlaySound("dontstarve/HUD/click_move")
    			self:Scroll(-per_side)
    		end

    	elseif control == CONTROL_PAGERIGHT then
    		if self.rightbutton.shown then
    			TheFrontEnd:GetSound():PlaySound("dontstarve/HUD/click_move")
    			self:Scroll(per_side)
    		end
    	else
    		return false
    	end 

    	return true
    end

end


function CustomizationScreen:Apply()
	self.cb(self.options)
end

function CustomizationScreen:GetHelpText()
    local controller_id = TheInput:GetControllerID()
    local t = {}
    
    if self.leftbutton.shown then 
    	table.insert(t,  TheInput:GetLocalizedControl(controller_id, CONTROL_PAGELEFT) .. " " .. STRINGS.UI.HELP.SCROLLBACK)
    end

    if self.rightbutton.shown then
    	table.insert(t,  TheInput:GetLocalizedControl(controller_id, CONTROL_PAGERIGHT) .. " " .. STRINGS.UI.HELP.SCROLLFWD)
    end

	if self:PendingChanges() then
		table.insert(t,  TheInput:GetLocalizedControl(controller_id, CONTROL_ACCEPT) .. " " .. STRINGS.UI.HELP.ACCEPT)
	end

	table.insert(t,  TheInput:GetLocalizedControl(controller_id, CONTROL_CANCEL) .. " " .. STRINGS.UI.HELP.BACK)
    

    return table.concat(t, "  ")
end


function CustomizationScreen:ConfirmRevert()

	TheFrontEnd:PushScreen(
		PopupDialogScreen( STRINGS.UI.CUSTOMIZATIONSCREEN.BACKTITLE, STRINGS.UI.CUSTOMIZATIONSCREEN.BACKBODY,
		  { 
		  	{ 
		  		text = STRINGS.UI.CUSTOMIZATIONSCREEN.YES, 
		  		cb = function()
					TheFrontEnd:PopScreen()
					self:Cancel()
				end
			},
			
			{ 
				text = STRINGS.UI.CUSTOMIZATIONSCREEN.NO, 
				cb = function()
					TheFrontEnd:PopScreen()					
				end
			}
		  }
		)
	)		
end

function CustomizationScreen:PendingChanges()
	if not self.defaults then
		return self.presetdirty or self.presetspinner:GetSelectedIndex() ~= 1
	end
	
	if self.defaults.preset ~= self.options.preset then return true end

	local tables_to_compare = {}
	for k,v in pairs(self.options.tweak) do
		tables_to_compare[k] = true
	end

	for k,v in pairs(self.defaults.tweak) do
		tables_to_compare[k] = true
	end

	for k,v in pairs(tables_to_compare) do
		local t1 = self.options.tweak[k]
		local t2 = self.defaults.tweak[k]

		if not t1 or not t2 or not type(t1) == "table" or not type(t2) == "table" then return true end

		for k,v in pairs(t1) do
			if t2[k] ~= v then return true end
		end
		for k,v in pairs(t2) do
			if t1[k] ~= v then return true end
		end
	end
end 

return CustomizationScreen