local Screen = require "widgets/screen"
local Button = require "widgets/button"
local AnimButton = require "widgets/animbutton"
local Menu = require "widgets/menu"
local Text = require "widgets/text"
local Image = require "widgets/image"
local UIAnim = require "widgets/uianim"
local Widget = require "widgets/widget"

local PopupDialogScreen = require "screens/popupdialog"
require "os"

local SlotDetailsScreen = Class(Screen, function(self, slotnum)
	Screen._ctor(self, "LoadGameScreen")
    self.profile = Profile
    self.saveslot = slotnum

	local mode = SaveGameIndex:GetCurrentMode(slotnum)
	local day = SaveGameIndex:GetSlotDay(slotnum)
	local world = SaveGameIndex:GetSlotWorld(slotnum)
	local character = SaveGameIndex:GetSlotCharacter(slotnum) or "wilson"
	self.character = character

    
	self.scaleroot = self:AddChild(Widget("scaleroot"))
    self.scaleroot:SetVAnchor(ANCHOR_MIDDLE)
    self.scaleroot:SetHAnchor(ANCHOR_MIDDLE)
    self.scaleroot:SetPosition(0,0,0)
    self.scaleroot:SetScaleMode(SCALEMODE_PROPORTIONAL)
    self.root = self.scaleroot:AddChild(Widget("root"))
    self.root:SetScale(.9)
    self.bg = self.root:AddChild(Image("images/fepanels.xml", "panel_saveslots.tex"))

    self.text = self.root:AddChild(Text(TITLEFONT, 60))
    self.text:SetPosition( 75, 135, 0)
    self.text:SetRegionSize(250,60)
    self.text:SetHAlign(ANCHOR_LEFT)


	self.portraitbg = self.root:AddChild(Image("images/saveslot_portraits.xml", "background.tex"))
	self.portraitbg:SetPosition(-120, 135, 0)	
	self.portraitbg:SetClickable(false)	

	self.portrait = self.root:AddChild(Image())
	self.portrait:SetClickable(false)		
	local atlas = (table.contains(MODCHARACTERLIST, character) and "images/saveslot_portraits/"..character..".xml") or "images/saveslot_portraits.xml"
	self.portrait:SetTexture(atlas, character..".tex")
	self.portrait:SetPosition(-120, 135, 0)
      
    self.menu = self.root:AddChild(Menu(nil, -70))
	self.menu:SetPosition(0, -50, 0)
	
	self.default_focus = self.menu
end)

function SlotDetailsScreen:OnBecomeActive()
	self:BuildMenu()
	SlotDetailsScreen._base.OnBecomeActive(self)
end

function SlotDetailsScreen:BuildMenu()


	local mode = SaveGameIndex:GetCurrentMode(self.saveslot)
	local day = SaveGameIndex:GetSlotDay(self.saveslot)
	local world = SaveGameIndex:GetSlotWorld(self.saveslot)
	local character = SaveGameIndex:GetSlotCharacter(self.saveslot) or "wilson"

    local menuitems = 
    {
		{name = STRINGS.UI.SLOTDETAILSSCREEN.CONTINUE, fn = function() self:Continue() end, offset = Vector3(0,20,0)},
		{name = STRINGS.UI.SLOTDETAILSSCREEN.DELETE, fn = function() self:Delete() end},
		{name = STRINGS.UI.SLOTDETAILSSCREEN.CANCEL, fn = function() TheFrontEnd:PopScreen(self) end},
	}

	if mode == "adventure" then
		self.text:SetString(string.format("%s %d-%d",STRINGS.UI.LOADGAMESCREEN.ADVENTURE, world, day))
	elseif mode == "survival" then
		self.text:SetString(string.format("%s %d-%d",STRINGS.UI.LOADGAMESCREEN.SURVIVAL, world, day))
	elseif mode == "cave" then
		self.text:SetString(string.format("%s %d-%d",STRINGS.UI.LOADGAMESCREEN.CAVE, world, day))
	else
		--This should only happen if the user has run a mod that created a new type of game mode.
		self.text:SetString(string.format("%s",STRINGS.UI.LOADGAMESCREEN.MODDED))
	end 
    
	self.menu:Clear()

    for k,v in pairs(menuitems) do
    	self.menu:AddItem(v.name, v.fn, v.offset)
    end
end

function SlotDetailsScreen:OnControl( control, down )
	if SlotDetailsScreen._base.OnControl(self, control, down) then return true end
	
	if control == CONTROL_CANCEL and not down then
		TheFrontEnd:PopScreen(self)
		return true
	end
end


function SlotDetailsScreen:Delete()

	local menu_items = 
	{
		-- ENTER
		{
			text=STRINGS.UI.MAINSCREEN.DELETE, 
			cb = function()
				TheFrontEnd:PopScreen()
				SaveGameIndex:DeleteSlot(self.saveslot, function() TheFrontEnd:PopScreen() end)
			end
		},
		-- ESC
		{text=STRINGS.UI.MAINSCREEN.CANCEL, cb = function() TheFrontEnd:PopScreen() self.menu:SetFocus() end},
	}

	TheFrontEnd:PushScreen(
		PopupDialogScreen(STRINGS.UI.MAINSCREEN.DELETE.." "..STRINGS.UI.MAINSCREEN.SLOT.." "..self.saveslot, STRINGS.UI.MAINSCREEN.SURE, menu_items ) )

end

function SlotDetailsScreen:Continue()
	self.root:Disable()
	TheFrontEnd:Fade(false, 1, function() 
		StartNextInstance({reset_action=RESET_ACTION.LOAD_SLOT, save_slot = self.saveslot})
	 end)
end

function SlotDetailsScreen:GetHelpText()
	local controller_id = TheInput:GetControllerID()
	return TheInput:GetLocalizedControl(controller_id, CONTROL_CANCEL) .. " " .. STRINGS.UI.HELP.BACK
end

return SlotDetailsScreen