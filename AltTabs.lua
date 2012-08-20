-- todo: support 3rd party tradeskill frames; eg. Skillet ATSW etc.
-- todo: support removal of toons from the DB... ctrl click on the tab perhaps for a popup menu... TBD
-- todo: support refresh of trades (for current player) in the DB... ctrl click on the tab perhaps for a popup menu... TBD

local AltTabs = CreateFrame("Frame","AltTabs")

local characterShown
local tradeTabs = {}

-- Spell order in this table determines the tab order of the UI
local tradeSkills = {
	28596, -- Alchemy
	29844, -- Blacksmithing
	28029, -- Enchanting
	30350, -- Engineering
	45357, -- Inscription
	28897, -- Jewel Crafting
	32549, -- Leatherworking
	53428, -- Runeforging
	2656,  -- Smelting/Mining
	26790, -- Tailoring
	
	33359, -- Cooking
	27028, -- First Aid
}
-- take a reference to the number of tradeskills, before the table is localized...
local numTradeSkills = #tradeSkills

-- Spell order in this table determines the tab order of the UI
local tradeSkillHelpers = {
	13262, -- Disenchant
	51005, -- Milling
	31252, -- Prospecting
	818,   -- Basic Campfire
}
-- take a reference to the number of tradeskill helpers, before the table is localized...
local numTradeSkillHelpers = #tradeSkillHelpers

-------------------------------------------------------------------------------
--
--    Character tab helper functions...
--
--

local function ShowTrades( character )
	if character == characterShown then
		-- nothing to do...
		return
	end

	-- hide the currently shown tabs...
	if characterShown and tradeTabs[characterShown] then
		for _, tab in pairs(tradeTabs[characterShown]) do
			tab:Hide()
		end

		characterShown = nil
	end

	-- show the new tabs...
	if character and tradeTabs[character] then
		for _, tab in pairs(tradeTabs[character]) do
			tab:Show()
		end

		characterShown = character
	end
end

local function OnCharacterEnter( self ) 
	local characters =  AltTabsDB[GetRealmName()]
	
	local tip
	local skills = characters[self.character]

	for skill in pairs(skills) do
		if not tip then
			tip = skill
		else
			tip = tip .. ", " .. skill
		end
	end

	if tip then
	    GameTooltip:SetOwner(self,"ANCHOR_RIGHT")
		GameTooltip:SetText(tip) 
	end
end

local function OnCharacterClick( self )
	PanelTemplates_SetTab(self:GetParent(), self.id)
	ShowTrades(self.character)

	-- select the default tradeskill (first tab as presented in the UI)...
	for i=1,numTradeSkills do
		local tradeName = tradeSkills[i]
		local tab = tradeTabs[self.character][tradeName]
		if tab then
			local hyperlink = AltTabsDB[GetRealmName()][self.character][tradeName]

			if tab.spellBookID then
				if not IsCurrentSpell(tab.spellBookID,"spell") then
					CastSpell(tab.spellBookID, "spell")
				end
			else
				if hyperlink then
					local linkdata = strmatch( hyperlink, "^|c%x+|H(.+)|h%[.*%]" )
					SetItemRef( linkdata, hyperlink, "LeftButton" )
				end
			end

			return
		end
	end
end

local function OnCharacterLeave( self ) 
    GameTooltip:Hide()
end   

local function UpdateCharacterSelection( self, event, ... )
	local parent = self:GetParent()

	if not parent:IsShown() then
		return
	end

	local characters = AltTabsDB[GetRealmName()]

	local player = GetUnitName("player")
	local isLinked, character = IsTradeSkillLinked()

	-- unregister the event now that this tab has seen it...
	if event == "CURRENT_SPELL_CAST_CHANGED" then
		self:UnregisterEvent("CURRENT_SPELL_CAST_CHANGED")
	end

	if isLinked then
		if not character or not characters[character] then
			-- deselect the character tab and hide the trade tabs only when absolutely necessary...
			PanelTemplates_SetTab(parent, 0)
			ShowTrades(nil)
		elseif character == self.character then
			PanelTemplates_SetTab(parent, self.id)
			ShowTrades(self.character)
		end
	else 
		if player == self.character then
			PanelTemplates_SetTab(parent, self.id)
			ShowTrades(self.character)
		end
	end
end

-------------------------------------------------------------------------------
--
--    Trade tab helper functions...
--
--

local function OnTradeEnter( self )
	local parent = self:GetParent()

    GameTooltip:SetOwner(self,"ANCHOR_RIGHT")
	GameTooltip:SetText(parent.trade) 
    parent:LockHighlight()
end

local function OnTradeClick( self )
	local parent = self:GetParent()
	local hyperlink = AltTabsDB[GetRealmName()][parent.character][parent.trade]

	if IsShiftKeyDown() then
		if hyperlink then
			local activeWindow = ChatEdit_GetActiveWindow()

			if not activeWindow then
				activeWindow = ChatEdit_GetLastActiveWindow()
			end

			if not activeWindow:IsVisible() then
				activeWindow:Show()
			end

			activeWindow:Insert( parent.character .. " " .. hyperlink )
		end
	elseif IsControlKeyDown() then
		-- remove the trade from the list...
		local wasChecked = AltTabs:RemoveTrade( parent.character, parent.trade )
		-- relayout the tabs...
		AltTabs:AdjustTradesLayout( parent:GetParent(), parent.character )
		-- select the first tab in the list if necessary
		if wasChecked then
			AltTabs:SelectDefaultTrade( parent.character )
		end
	else
		if parent.spellBookID then
			if not IsCurrentSpell( parent.spellBookID, "spell" ) then
				CastSpell( parent.spellBookID, "spell" )
			end
		else
			if hyperlink then
				local linkdata = strmatch( hyperlink, "^|c%x+|H(.+)|h%[.*%]" )
				SetItemRef( linkdata, hyperlink, "LeftButton" )
			end
		end
	end
end

local function OnTradeLeave(self) 
	local parent = self:GetParent()

    GameTooltip:Hide()
    parent:UnlockHighlight()
end   

local function UpdateHyperlink( realm, character, trade, hyperlink )
	if hyperlink and not (AltTabsDB[realm][character][trade] and AltTabsDB[realm][character][trade] == hyperlink ) then
		AltTabsDB[realm][character][trade] = hyperlink
	end
end

local function UpdateTradeSelection( self, event, ... )
	local parent = self:GetParent()

	if not parent:IsShown() then
		return
	end

	-- unregister the event now that this tab has seen it...
	if event == "CURRENT_SPELL_CAST_CHANGED" then
		self:UnregisterEvent("CURRENT_SPELL_CAST_CHANGED")
	end

	if parent.spellBookID then
		if IsCurrentSpell(parent.spellBookID,"spell") then
			UpdateHyperlink( GetRealmName(), parent.character, parent.trade, GetTradeSkillListLink() )
			parent:SetChecked(true)
		else
			parent:SetChecked(false)
		end
	else
		local _, character = IsTradeSkillLinked()
		local trade = GetTradeSkillLine()

		if character == parent.character and trade == parent.trade then
			parent:SetChecked(true)
		else
			parent:SetChecked(false)
		end
	end
end

local function UpdateTradeHelper( self )
	local parent = self:GetParent()

	if not parent:IsShown() then
		return
	end

	-- clear the check on the helper tabs when they are done casting...
	if not IsCurrentSpell(self.spellBookID,"spell") then
		self:SetChecked(false)
	end
end

-------------------------------------------------------------------------------
--

function AltTabs:LocalizeTradeSkills()
	-- convert Trade Skill ID to localized text, and it's texture path...
	for i=1,numTradeSkills do
		local id = tradeSkills[i]
		local tradeName, _, icon = GetSpellInfo(id)

		local trade = {}
		trade["id"] = id
		trade["icon"] = icon

		tradeSkills[tradeName] = trade
		tradeSkills[i] = tradeName
	end
end

function AltTabs:LocalizeTradeSkillHelpers()
	-- do the same for the helper skills...
	for i=1,numTradeSkillHelpers do
		local id = tradeSkillHelpers[i]
		local tradeName, _, icon = GetSpellInfo(id)

		local trade = {}
		trade["id"] = id
		trade["icon"] = icon

		tradeSkillHelpers[tradeName] = trade
		tradeSkillHelpers[i] = tradeName
	end
end


function AltTabs:Initialize()
	if self.initialized then
		return
	elseif InCombatLockdown() then
		self:RegisterEvent( "PLAYER_REGEN_ENABLED" )
		return
	end

	local realm = GetRealmName()
	local player = GetUnitName("player")
	local parent = TradeSkillFrame

	-- tweak the TradeSkill Frame to our liking...
	TradeSkillFrame:SetScript("OnMouseDown", TradeSkillFrame.StartMoving)
	TradeSkillFrame:SetScript("OnMouseUp", TradeSkillFrame.StopMovingOrSizing)

	if not AltTabsDB then
		AltTabsDB = {}
	end

	if not AltTabsDB[realm] then
		AltTabsDB[realm] = {}
	end

	if not AltTabsDB[realm][player] then
		AltTabsDB[realm][player] = {}
	end

	self:LocalizeTradeSkills()
	self:LocalizeTradeSkillHelpers()

	self:InitCharacterTabs( realm, parent )
	self:InitTradeTabs( realm, player, parent )

	self.initialized = true
end

function AltTabs:InitCharacterTabs( realm, parent )
	local numTabs, characters = 0, AltTabsDB[realm]
	local prev, relPoint, x, y = parent,"BOTTOMLEFT",12,1

	for character,_ in pairs(characters) do
		numTabs = numTabs + 1

		local tab = self:CreateCharacterTab( character, numTabs, parent )

		tab:SetPoint( "TOPLEFT", prev, relPoint, x, y )
		prev, relPoint, x, y = tab, "TOPRIGHT", -12, 0
	end

	if numTabs > 0 then
		PanelTemplates_SetNumTabs( parent, numTabs );
		-- dont select a tab just yet, but dont leave it unset either; set it to 0 for now
		PanelTemplates_SetTab( parent, 0 )
	end
end

function AltTabs:CreateCharacterTab( character, index, parent )
    local button = CreateFrame("Button", parent:GetName() .. "Tab" .. index,parent,"CharacterFrameTabButtonTemplate,SecureActionButtonTemplate")

    button:SetText(character)
	button.id = index
	button.character = character
	
	button:SetScript( "OnEvent", UpdateCharacterSelection )
    button:SetScript( "OnEnter", OnCharacterEnter )
	button:SetScript( "OnClick", OnCharacterClick )
    button:SetScript( "OnLeave", OnCharacterLeave )
	button:RegisterEvent( "TRADE_SKILL_UPDATE" )
	button:Show()

	return button
end

function AltTabs:InitTradeTabs( realm, player, frame )
	local characters = AltTabsDB[realm]

	-- iterrate through the characters in the db...
	for character in pairs(characters)	do
		local tabs = { }

		if character == player then
			-- look though the player's spellbook for the associated spell book ids...
			for i=1,MAX_SPELLS do
				local spellName = GetSpellBookItemName(i,"spell")
				if tradeSkills[spellName] or tradeSkillHelpers[spellName] then
					tabs[spellName] = self:CreateTradeTab( character, spellName, i, frame )
				end
			end
		else
			local trades = characters[character]

			-- loop through the cached db of character tradeskill hyperlinks...
			for tradeName, hyperlink in pairs(trades) do
				tabs[tradeName] = self:CreateTradeTab( character, tradeName, nil, frame )
			end
		end

		tradeTabs[character] = tabs

		-- reposition the tabs, following the order of the spell IDs in the trades tables...
		AltTabs:AdjustTradesLayout( frame, character )
	end
end

function AltTabs:CreateClickStopper( parent )
    local f = CreateFrame("Button",nil,parent,"SecureActionButtonTemplate ")

    f:SetAllPoints(parent)
    f:EnableMouse(true)

	f:SetScript( "OnEvent", UpdateTradeSelection )
    f:SetScript( "OnEnter", OnTradeEnter )
	f:SetScript( "OnClick", OnTradeClick )
    f:SetScript( "OnLeave", OnTradeLeave )

	-- listen for update events
	f:RegisterEvent( "TRADE_SKILL_UPDATE" )

	return f
end

function AltTabs:CreateTradeTab( character, spell, spellBookID, frame )
	local texture
	local button = CreateFrame("CheckButton",nil,frame,"SpellBookSkillLineTabTemplate,SecureActionButtonTemplate")

    button:SetAttribute("type","spell")
    button:SetAttribute("spell",spell)

	-- handle the trade helper skills, like disenchanting, differently from the trades themselves...
	if tradeSkillHelpers[spell] then
		-- we want to be able to clear the check once the spell has been cast...
		button:SetScript( "OnEvent", UpdateTradeHelper )
		button:RegisterEvent( "CURRENT_SPELL_CAST_CHANGED" )
		texture = tradeSkillHelpers[spell]["icon"] 
	else
		-- we dont actually want the button to handle the clicks directly, so create another button to sit in-between...
		button.clickStopper = self:CreateClickStopper( button )
		texture = tradeSkills[spell]["icon"] 
	end

    button:SetNormalTexture( texture )

    button.tooltip = spell
    button.trade = spell
	button.spellBookID = spellBookID
	button.character = character

	return button
end

function AltTabs:AdjustTradesLayout( frame, character )
	if tradeTabs[character] then
		local prev, relPoint, x, y = frame, "TOPRIGHT",1,-44

		-- handle the primary and secondary skills..
		for i=1,numTradeSkills do
			local tab = tradeTabs[character][tradeSkills[i]]

			if tab then
				tab:SetPoint("TOPLEFT",prev,relPoint,x,y)
				prev = tab
				relPoint,x,y = "BOTTOMLEFT",0,-17
			end
		end

		-- try to space the first helper a little farther apart...
		if prev ~= frame then
			y = -34
		end

		-- rinse and repeat for the trade helper skills...
		for i=1,numTradeSkillHelpers do
			local tab = tradeTabs[character][tradeSkillHelpers[i]]

			if tab then
				tab:SetPoint("TOPLEFT",prev,relPoint,x,y)
				prev = tab
				relPoint,x,y = "BOTTOMLEFT",0,-17
			end
		end
	end
end

function AltTabs:SelectDefaultTrade( character )
	if tradeTabs[character] then
		-- select the default tradeskill (first tab as presented in the UI)...
		for i=1,numTradeSkills do
			local tradeName = tradeSkills[i]
			local tab = tradeTabs[character][tradeName]

			if tab then
				if tab.spellBookID then
					if not IsCurrentSpell(tab.spellBookID,"spell") then
						CastSpell(tab.spellBookID, "spell")
					end
				else
					local hyperlink = AltTabsDB[GetRealmName()][character][tradeName]

					if hyperlink then
						local linkdata = strmatch( hyperlink, "^|c%x+|H(.+)|h%[.*%]" )
						SetItemRef( linkdata, hyperlink, "LeftButton" )
					end
				end

				return
			end
		end
	end
end

function AltTabs:RemoveTrade( character, trade )
	local characters = AltTabsDB[GetRealmName()]
	local bRetVal = false;

	if tradeTabs[character] then
		characters[character][trade] = nil

		if tradeTabs[character][trade] then
	 		bRetVal = tradeTabs[character][trade]:GetChecked()

			if tradeTabs[character][trade].clickStopper then
				tradeTabs[character][trade].clickStopper:Hide()
				tradeTabs[character][trade].clickStopper:UnregisterAllEvents()
				tradeTabs[character][trade].clickStopper = nil
			end

			tradeTabs[character][trade]:Hide()
			tradeTabs[character][trade]:UnregisterAllEvents()
			tradeTabs[character][trade] = nil
		end
	end

	return bRetVal
end

function AltTabs:OnEvent( event, name, ... )
	if event == "ADDON_LOADED" and name == "AltTabs" then
		self:UnregisterEvent("ADDON_LOADED")
		self:Initialize()
	elseif event == "PLAYER_REGEN_ENABLED" then
		self:UnregisterEvent("PLAYER_REGEN_ENABLED")
		self:Initialize()
	end
end

AltTabs:SetScript( "OnEvent", AltTabs.OnEvent )
AltTabs:RegisterEvent("ADDON_LOADED")



