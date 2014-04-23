local Screen = require "widgets/screen"
local Button = require "widgets/button"
local AnimButton = require "widgets/animbutton"
local ImageButton = require "widgets/imagebutton"
local Menu = require "widgets/menu"
local Text = require "widgets/text"
local Image = require "widgets/image"
local UIAnim = require "widgets/uianim"
local Widget = require "widgets/widget"
require "os"

local WorldGenScreen = require "screens/worldgenscreen"
local CustomizationScreen = require "screens/customizationscreen"
local CharacterSelectScreen = require "screens/characterselectscreen"

local NewGameScreen = Class(Screen, function(self, slotnum)
	Screen._ctor(self, "LoadGameScreen")
    self.profile = Profile
    self.saveslot = slotnum
    self.character = "wilson"

   	self.scaleroot = self:AddChild(Widget("scaleroot"))
    self.scaleroot:SetVAnchor(ANCHOR_MIDDLE)
    self.scaleroot:SetHAnchor(ANCHOR_MIDDLE)
    self.scaleroot:SetScaleMode(SCALEMODE_PROPORTIONAL)
    self.root = self.scaleroot:AddChild(Widget("root"))
    self.root:SetScale(.9)

    self.bg = self.root:AddChild(Image("images/fepanels.xml", "panel_saveslots.tex"))
    
	--[[self.cancelbutton = self.root:AddChild(ImageButton())
	self.cancelbutton:SetScale(.8,.8,.8)
    self.cancelbutton:SetText(STRINGS.UI.NEWGAMESCREEN.CANCEL)
    self.cancelbutton:SetOnClick( function() TheFrontEnd:PopScreen(self) end )
    self.cancelbutton:SetFont(BUTTONFONT)
    self.cancelbutton:SetTextSize(35)
    self.cancelbutton.text:SetVAlign(ANCHOR_MIDDLE)
    self.cancelbutton.text:SetColour(0,0,0,1)
    self.cancelbutton:SetPosition( 0, -235, 0)
    --]]

    self.title = self.root:AddChild(Text(TITLEFONT, 60))
    self.title:SetPosition( 75, 135, 0)
    self.title:SetRegionSize(250,60)
    self.title:SetHAlign(ANCHOR_LEFT)
	self.title:SetString(STRINGS.UI.NEWGAMESCREEN.TITLE)

	self.portraitbg = self.root:AddChild(Image("images/saveslot_portraits.xml", "background.tex"))
	self.portraitbg:SetPosition(-120, 135, 0)	
	self.portraitbg:SetClickable(false)	

	self.portrait = self.root:AddChild(Image())
	self.portrait:SetClickable(false)		
	local atlas = (table.contains(MODCHARACTERLIST, self.character) and "images/saveslot_portraits/"..self.character..".xml") or "images/saveslot_portraits.xml"
	self.portrait:SetTexture(atlas, self.character..".tex")
	self.portrait:SetPosition(-120, 135, 0)
      

    local menuitems = 
    {
		{text = STRINGS.UI.NEWGAMESCREEN.START, cb = function() self:Start() end, offset = Vector3(0,20,0)},
		{text = STRINGS.UI.NEWGAMESCREEN.CHANGECHARACTER, cb = function() self:ChangeCharacter() end},
		{text = STRINGS.UI.NEWGAMESCREEN.CUSTOMIZE, cb = function() self:Customize() end},
		{text = STRINGS.UI.NEWGAMESCREEN.CANCEL, cb = function() TheFrontEnd:PopScreen(self) end},
    }

    self.menu = self.root:AddChild(Menu(menuitems, -70))
	self.menu:SetPosition(0, 0, 0)

	self.default_focus = self.menu
    
end)

function NewGameScreen:OnGainFocus()
	NewGameScreen._base.OnGainFocus(self)
	self.menu:SetFocus()
end

function NewGameScreen:OnControl(control, down)
    if Screen.OnControl(self, control, down) then return true end
    if not down and control == CONTROL_CANCEL then
        TheFrontEnd:PopScreen(self)
        return true
    end
end

function NewGameScreen:Customize( )
	
	local function onSet(options)
		TheFrontEnd:PopScreen()
		if options then
			self.customoptions = options
		end
	end
	TheFrontEnd:PushScreen(CustomizationScreen(Profile, onSet, self.customoptions))
end

function NewGameScreen:ChangeCharacter(  )
	
	local function onSet(character)
		TheFrontEnd:PopScreen()
		if character then

			self.character = character

			local atlas = (table.contains(MODCHARACTERLIST, character) and "images/saveslot_portraits/"..character..".xml") or "images/saveslot_portraits.xml"
			self.portrait:SetTexture(atlas, self.character..".tex")
		end
	end
	TheFrontEnd:PushScreen(CharacterSelectScreen(Profile, onSet, false, self.character))
end



function NewGameScreen:Start()
	local function onsaved()
	    StartNextInstance({reset_action=RESET_ACTION.LOAD_SLOT, save_slot = self.saveslot})
	end

	self.root:Disable()
	TheFrontEnd:Fade(false, 1, function() SaveGameIndex:StartSurvivalMode(self.saveslot, self.character, self.customoptions, onsaved) end )
end


function NewGameScreen:GetHelpText()
	local controller_id = TheInput:GetControllerID()
	return TheInput:GetLocalizedControl(controller_id, CONTROL_CANCEL) .. " " .. STRINGS.UI.HELP.BACK
end

return NewGameScreen