-----------------------------------------------------------------------------------------------
-- Client Lua Script for GorynychQuestTracker
-- Copyright (c) NCsoft. All rights reserved
-----------------------------------------------------------------------------------------------

require "Window"
require "QuestLib"

local GorynychQuestTracker = {}
local tMinimized = {}
local knMaxZombieEventCount 	= 7
local knQuestProgBarFadeoutTime = 10
local kstrPublicEventMarker 	= "Public Event"
local ktNumbersToLetters		=
{
	Apollo.GetString("QuestTracker_ObjectiveA"),
	Apollo.GetString("QuestTracker_ObjectiveB"),
	Apollo.GetString("QuestTracker_ObjectiveC"),
	Apollo.GetString("QuestTracker_ObjectiveD"),
	Apollo.GetString("QuestTracker_ObjectiveE"),
	Apollo.GetString("QuestTracker_ObjectiveF"),
	Apollo.GetString("QuestTracker_ObjectiveG"),
	Apollo.GetString("QuestTracker_ObjectiveH"),
	Apollo.GetString("QuestTracker_ObjectiveI"),
	Apollo.GetString("QuestTracker_ObjectiveJ"),
	Apollo.GetString("QuestTracker_ObjectiveK"),
	Apollo.GetString("QuestTracker_ObjectiveL")
}
local karPathToString =
{
	[PlayerPathLib.PlayerPathType_Soldier] 		= Apollo.GetString("CRB_Soldier"),
	[PlayerPathLib.PlayerPathType_Settler] 		= Apollo.GetString("CRB_Settler"),
	[PlayerPathLib.PlayerPathType_Scientist] 	= Apollo.GetString("CRB_Scientist"),
	[PlayerPathLib.PlayerPathType_Explorer] 	= Apollo.GetString("CRB_Explorer")
}

local kstrRed 		= "ffff4c4c"
local kstrGreen 	= "ff2fdc02"
local kstrYellow 	= "fffffc00"
local kstrLightGrey = "ffb4b4b4"
local kstrHighlight = "ffffe153"

local ktConToColor =
{
	[0] 												= "ffffffff",
	[Unit.CodeEnumLevelDifferentialAttribute.Grey] 		= "ff9aaea3",
	[Unit.CodeEnumLevelDifferentialAttribute.Green] 	= "ff37ff00",
	[Unit.CodeEnumLevelDifferentialAttribute.Cyan] 		= "ff46ffff",
	[Unit.CodeEnumLevelDifferentialAttribute.Blue] 		= "ff3052fc",
	[Unit.CodeEnumLevelDifferentialAttribute.White] 	= "ffffffff",
	[Unit.CodeEnumLevelDifferentialAttribute.Yellow] 	= "ffffd400", -- Yellow
	[Unit.CodeEnumLevelDifferentialAttribute.Orange] 	= "ffff6a00", -- Orange
	[Unit.CodeEnumLevelDifferentialAttribute.Red] 		= "ffff0000", -- Red
	[Unit.CodeEnumLevelDifferentialAttribute.Magenta] 	= "fffb00ff", -- Purp
}

local ktConToString =
{
	[0] 												= Apollo.GetString("Unknown_Unit"),
	[Unit.CodeEnumLevelDifferentialAttribute.Grey] 		= Apollo.GetString("QuestLog_Trivial"),
	[Unit.CodeEnumLevelDifferentialAttribute.Green] 	= Apollo.GetString("QuestLog_Easy"),
	[Unit.CodeEnumLevelDifferentialAttribute.Cyan] 		= Apollo.GetString("QuestLog_Simple"),
	[Unit.CodeEnumLevelDifferentialAttribute.Blue] 		= Apollo.GetString("QuestLog_Standard"),
	[Unit.CodeEnumLevelDifferentialAttribute.White] 	= Apollo.GetString("QuestLog_Average"),
	[Unit.CodeEnumLevelDifferentialAttribute.Yellow] 	= Apollo.GetString("QuestLog_Moderate"),
	[Unit.CodeEnumLevelDifferentialAttribute.Orange] 	= Apollo.GetString("QuestLog_Tough"),
	[Unit.CodeEnumLevelDifferentialAttribute.Red] 		= Apollo.GetString("QuestLog_Hard"),
	[Unit.CodeEnumLevelDifferentialAttribute.Magenta] 	= Apollo.GetString("QuestLog_Impossible")
}

local ktPvPEventTypes =
{
	[PublicEvent.PublicEventType_PVP_Arena] 					= true,
	[PublicEvent.PublicEventType_PVP_Warplot] 					= true,
	[PublicEvent.PublicEventType_PVP_Battleground_Cannon] 		= true,
	[PublicEvent.PublicEventType_PVP_Battleground_Vortex] 		= true,
	[PublicEvent.PublicEventType_PVP_Battleground_Sabotage] 	= true,
	[PublicEvent.PublicEventType_PVP_Battleground_HoldTheLine] 	= true,
}

function GorynychQuestTracker:new(o)
    o = o or {}
    setmetatable(o, self)
    self.__index = self
	self.ruTranslationQuestTracker = {}
    return o
end

function GorynychQuestTracker:Translate(str)
	local translationLib = Apollo.GetAddon("TranslationLib")
	if (translationLib ~= nil) then
		return translationLib:Traslate("RU", "QuestTracker", str)
	end
	return str
end

function GorynychQuestTracker:Init()
    Apollo.RegisterAddon(self)
end

function GorynychQuestTracker:OnLoad() -- OnLoad then GetAsyncLoad then OnRestore
	Apollo.RegisterEventHandler("OptionsUpdated_QuestTracker", 				"OnOptionsUpdated", self)
	self.xmlDoc = XmlDoc.CreateFromFile("GorynychQuestTracker.xml")
	
	tMinimized["quests"] = { }
	tMinimized["episode"] = { }
end

function GorynychQuestTracker:GetAsyncLoadStatus()
	if self.xmlDoc:IsLoaded() and g_InterfaceOptionsLoaded then
		self:Initialize()
		return Apollo.AddonLoadStatus.Loaded
	end
	return Apollo.AddonLoadStatus.Loading
end

function GorynychQuestTracker:Initialize()
    Apollo.RegisterTimerHandler("QuestTrackerMainTimer", 					"OnQuestTrackerMainTimer", self)
	Apollo.RegisterTimerHandler("QuestTrackerBlinkTimer", 					"OnQuestTrackerBlinkTimer", self)

	Apollo.CreateTimer("QuestTrackerMainTimer", 1, true)
	Apollo.CreateTimer("QuestTrackerBlinkTimer", 4, false)
	Apollo.StopTimer("QuestTrackerBlinkTimer")

	-- Code events, mostly to remove completed/finished quests
	-- TODO: an event needs to wndQuest:FindChild("ObjectiveContainer"):DestroyChildren() when moving to complete/botched
	Apollo.RegisterEventHandler("EpisodeStateChanged", 						"DestroyAndRedraw", self)
	Apollo.RegisterEventHandler("QuestStateChanged", 						"OnQuestStateChanged", self)
	Apollo.RegisterEventHandler("QuestObjectiveUpdated", 					"OnQuestObjectiveUpdated", self)
	Apollo.RegisterEventHandler("GenericEvent_QuestLog_TrackBtnClicked", 	"OnDestroyQuestObject", self) -- This is an event from QuestLog
	Apollo.RegisterEventHandler("Tutorial_RequestUIAnchor", 				"OnTutorial_RequestUIAnchor", self)

	-- Public Events
	Apollo.RegisterEventHandler("PublicEventEnd", 							"OnPublicEventEnd", self)
	Apollo.RegisterEventHandler("PublicEventLeave", 						"OnPublicEventEnd", self)
	Apollo.RegisterEventHandler("PublicEventStart", 						"OnPublicEventStart", self)
	Apollo.RegisterEventHandler("PublicEventObjectiveUpdate", 				"OnPublicEventUpdate", self)
	Apollo.RegisterEventHandler("PVPMatchFinished", 						"OnLeavePvP", self)
	Apollo.RegisterEventHandler("MatchExited", 								"OnLeavePvP", self)

	-- Legacy, Not sure if all of these are relevant anymore
	Apollo.RegisterEventHandler("QuestInit", 								"DestroyAndRedraw", self)
	Apollo.RegisterEventHandler("QuestTrackChanged", 						"OnDestroyQuestObject", self) -- TODO, Investigate if this does anything

	-- Not 100% necessary
	Apollo.RegisterEventHandler("Communicator_ShowQuestMsg", 				"OnQuestTrackerMainTimer", self)
	Apollo.RegisterEventHandler("Communicator_UpdateCallback", 				"OnQuestTrackerMainTimer", self)

	-- Formatting events
	Apollo.RegisterEventHandler("DatachronRestored", 						"OnDatachronRestored", self)
	Apollo.RegisterEventHandler("DatachronMinimized", 						"OnDatachronMinimized", self)
	Apollo.RegisterEventHandler("QuestLog_ToggleLongQuestText", 			"OnToggleLongQuestText", self)

	-- Checking Player Death (can't turn in quests if dead)
	Apollo.RegisterEventHandler("PlayerResurrected", 						"OnPlayerResurrected", self)
	Apollo.RegisterEventHandler("ShowResurrectDialog", 						"OnShowResurrectDialog", self)

	Apollo.RegisterTimerHandler("UpdateInOneSecond", 						"OnQuestTrackerMainTimer")
	Apollo.RegisterTimerHandler("QuestTracker_EarliestProgBarTimer", 		"OnGorynychQuestTracker_EarliestProgBarTimer", self)

    self.wndMain = Apollo.LoadForm(self.xmlDoc, "GorynychQuestTrackerForm", "FixedHudStratum", self)

	self.bQuestTrackerByDistance 		= g_InterfaceOptions.Carbine.bQuestTrackerByDistance
	self.nQuestCounting 				= 0
	self.strPlayerPath 					= ""
	self.nFlashThisQuest 				= nil
	self.bPlayerIsDead 					= GameLib.GetPlayerUnit() and GameLib.GetPlayerUnit():IsDead() or false
	self.bDrawPvPScreenOnly 			= false
	self.bDrawDungeonScreenOnly 		= false
	self.bPublicEventUpdateTimerStarted = false -- TODO get rid of this
	self.tZombiePublicEvents 			= {}
	self.tActiveProgBarQuests 			= {}
	self.ZombieTimerMax					= 120 -- Time it takes for a zombie PE to dissapear
	self.tClickBlinkingQuest			= nil
	self.tHoverBlinkingQuest			= nil
	
	if g_wndDatachron and g_wndDatachron:IsShown() then
		self:OnDatachronRestored(g_wndDatachron:GetHeight() - 50)
	end
	

	
	self:OnQuestTrackerMainTimer()
end

function GorynychQuestTracker:DelayedInitialize_WindowMeasuring() -- Try not to run these OnLoad as they may be expensive
	local wndMeasure = Apollo.LoadForm(self.xmlDoc, "EpisodeItem", nil, self)
	self.knInitialEpisodeHeight = wndMeasure:GetHeight()
	wndMeasure:Destroy()

	wndMeasure = Apollo.LoadForm(self.xmlDoc, "QuestItem", nil, self)
	self.knInitialQuestControlBackerHeight = wndMeasure:FindChild("ControlBackerBtn"):GetHeight()
	wndMeasure:Destroy()

	wndMeasure = Apollo.LoadForm(self.xmlDoc, "QuestObjectiveItem", nil, self)
	self.knInitialQuestObjectiveHeight = wndMeasure:GetHeight()
	wndMeasure:Destroy()

	wndMeasure = Apollo.LoadForm(self.xmlDoc, "SpellItem", nil, self)
	self.knInitialSpellItemHeight = wndMeasure:GetHeight()
	wndMeasure:Destroy()

	wndMeasure = Apollo.LoadForm(self.xmlDoc, "EventItem", nil, self)
	self.knMinHeightEventItem = wndMeasure:GetHeight()
	wndMeasure:Destroy()

	if self.strPlayerPath == "" then
		local ePlayPathType = PlayerPathLib.GetPlayerPathType()
		if ePlayPathType then
			self.strPlayerPath = karPathToString[ePlayerPathType]
		end
	end
end

function GorynychQuestTracker:OnOptionsUpdated()
	self.bQuestTrackerByDistance = g_InterfaceOptions.Carbine.bQuestTrackerByDistance
end

function GorynychQuestTracker:OnQuestTrackerMainTimer()
	self.bPublicEventUpdateTimerStarted = false -- TODO get rid of this

	if not self.wndMain or not self.wndMain:IsValid() then
		return
	end

	if not self.knInitialEpisodeHeight then
		self:DelayedInitialize_WindowMeasuring()
	end

	-- Resize List
	for idx, wndEpisode in pairs(self.wndMain:FindChild("QuestTrackerScroll"):GetChildren()) do
		if wndEpisode:GetName() == "EpisodeItem" then
			self:OnResizeEpisode(wndEpisode)
		end
	end

	-- Sort
	local function HelperSortEpisodes(a,b)
		if a:FindChild("EpisodeTitle") and b:FindChild("EpisodeTitle") then
			return a:FindChild("EpisodeTitle"):GetData() < b:FindChild("EpisodeTitle"):GetData()
		elseif b:GetName() == "SwapToQuests" then
			return true
		end
		return false
	end
	self.wndMain:FindChild("QuestTrackerScroll"):ArrangeChildrenVert(2, HelperSortEpisodes)

	self:RedrawAll()
end

function GorynychQuestTracker:OnQuestTrackerBlinkTimer()
	self.tClickBlinkingQuest:SetActiveQuest(false)
	self.tClickBlinkingQuest = nil

	if self.tHoverBlinkingQuest then
		self.tHoverBlinkingQuest:ToggleActiveQuest()
	end
end

-----------------------------------------------------------------------------------------------
-- Main Redraw Methods
-----------------------------------------------------------------------------------------------

function GorynychQuestTracker:UpdateUIFromXML()
	self:OnQuestTrackerMainTimer()
end

function GorynychQuestTracker:DestroyAndRedraw()
	self.wndMain:FindChild("QuestTrackerScroll"):DestroyChildren()
	self:OnQuestTrackerMainTimer()
end

function GorynychQuestTracker:RedrawAll()
	if #self.tZombiePublicEvents > 0 then
		self:DrawPublicEpisodes()
	elseif #PublicEvent.GetActiveEvents() > 0 then
		self:DrawPublicEpisodes()
	elseif self.wndMain:FindChild("QuestTrackerScroll"):FindChildByUserData(kstrPublicEventMarker) then
		self.bDrawDungeonScreenOnly = false
		self.bDrawPvPScreenOnly = false
		self:DestroyAndRedraw()
		self:OnQuestTrackerMainTimer() -- TODO: TEMP, can remove, call timer immediately
		return
	end

	if not self.bDrawPvPScreenOnly and not self.bDrawDungeonScreenOnly then
		self.nQuestCounting = 0
		for idx, epiEpisode in pairs(QuestLib.GetTrackedEpisodes(self.bQuestTrackerByDistance)) do
			self:DrawEpisode(idx, epiEpisode)
		end
	end
end

function GorynychQuestTracker:DrawEpisode(idx, epiEpisode)
	local wndEpisode = self:FactoryProduce(self.wndMain:FindChild("QuestTrackerScroll"), "EpisodeItem", epiEpisode)
	wndEpisode:FindChild("EpisodeTitle"):SetData(idx) -- For sorting
	wndEpisode:FindChild("EpisodeMinimizeBtn"):SetData(epiEpisode:GetId())

	if tMinimized["episode"][epiEpisode:GetId()] then
		wndEpisode:FindChild("EpisodeMinimizeBtn"):SetCheck(true)
	end

	if wndEpisode:FindChild("EpisodeMinimizeBtn") and wndEpisode:FindChild("EpisodeMinimizeBtn"):IsChecked() then
		wndEpisode:FindChild("EpisodeTitle"):SetText("> " .. self:Translate(epiEpisode:GetTitle()))
		wndEpisode:FindChild("EpisodeTitle"):SetTextColor(ApolloColor.new("cc21a5a1"))

		-- Flash if we are told to
		if self.nFlashThisQuest then
			for key, queQuest in pairs(epiEpisode:GetTrackedQuests()) do
				if self.nFlashThisQuest == queQuest then
					self.nFlashThisQuest = nil
					wndEpisode:FindChild("EpisodeTitle"):SetSprite("sprTrk_ObjectiveUpdatedAnim")
				end
			end
		end
	elseif wndEpisode:FindChild("EpisodeMinimizeBtn") then
		wndEpisode:FindChild("EpisodeTitle"):SetText(self:Translate(epiEpisode:GetTitle()))
		wndEpisode:FindChild("EpisodeTitle"):SetTextColor(ApolloColor.new("ff31fcf6"))

		-- Quests
		for nIdx, queQuest in pairs(epiEpisode:GetTrackedQuests(0, self.bQuestTrackerByDistance)) do
			self.nQuestCounting = self.nQuestCounting + 1 -- TODO replace with nIdx or something eventually
			self:DrawQuest(self.nQuestCounting, queQuest, wndEpisode:FindChild("EpisodeQuestContainer"))
		end

		-- Inline Sort Method
		local function SortQuestTrackerScroll(a, b)
			if not a or not b or not a:FindChild("QuestNumber") or not b:FindChild("QuestNumber") then return true end
			return (tonumber(a:FindChild("QuestNumber"):GetText()) or 0) < (tonumber(b:FindChild("QuestNumber"):GetText()) or 0)
		end

		wndEpisode:FindChild("EpisodeQuestContainer"):ArrangeChildrenVert(0, SortQuestTrackerScroll)
	end
end

function GorynychQuestTracker:DrawPublicEpisodes()
	local tPublicEvents = PublicEvent.GetActiveEvents()
	if self.bDrawPvPScreenOnly or self.bDrawDungeonScreenOnly then
		self:FactoryProduce(self.wndMain:FindChild("QuestTrackerScroll"), "SwapToQuests", "SwapToQuests")
	elseif not self.wndMain:FindChild("SwapToPvP") and not self.wndMain:FindChild("SwapToDungeons") then
		for key, peEvent in pairs(tPublicEvents) do
			if not self.bDrawPvPScreenOnly and ktPvPEventTypes[peEvent:GetEventType()] then
				self.bDrawPvPScreenOnly = true
				self.wndMain:FindChild("QuestTrackerScroll"):DestroyChildren()
				self:FactoryProduce(self.wndMain:FindChild("QuestTrackerScroll"), "SwapToQuests", "SwapToQuests")
				return
			end
			if not self.bDrawDungeonScreenOnly and peEvent:GetEventType() == PublicEvent.PublicEventType_Dungeon then
				self.bDrawDungeonScreenOnly = true
				self.wndMain:FindChild("QuestTrackerScroll"):DestroyChildren()
				self:FactoryProduce(self.wndMain:FindChild("QuestTrackerScroll"), "SwapToQuests", "SwapToQuests")
				return
			end
		end
	end

	local wndEpisode = self:FactoryProduce(self.wndMain:FindChild("QuestTrackerScroll"), "EpisodeItem", kstrPublicEventMarker)
	wndEpisode:FindChild("EpisodeTitle"):SetData(-1) -- For sorting, will compare vs Quests

	if wndEpisode:FindChild("EpisodeMinimizeBtn") and wndEpisode:FindChild("EpisodeMinimizeBtn"):IsChecked() then
		wndEpisode:FindChild("EpisodeTitle"):SetText("> " .. self:Translate(Apollo.GetString("QuestTracker_Events")))
		wndEpisode:FindChild("EpisodeTitle"):SetTextColor(ApolloColor.new("cc21a5a1"))
		return
	end

	wndEpisode:FindChild("EpisodeTitle"):SetText(self:Translate(Apollo.GetString("QuestTracker_Events")))
	wndEpisode:FindChild("EpisodeTitle"):SetTextColor(ApolloColor.new("ff31fcf6"))

	-- Events
	local nAlphabetNumber = 0
	for key, peEvent in pairs(tPublicEvents) do
		nAlphabetNumber	= nAlphabetNumber + 1
		self:DrawEvent(wndEpisode:FindChild("EpisodeQuestContainer"), peEvent, nAlphabetNumber)
	end

	-- Trim zombies to max size
	if #self.tZombiePublicEvents > knMaxZombieEventCount then
		table.remove(self.tZombiePublicEvents, 1)
	end

	-- Check Zombie Timer
	for key, tZombieEvent in pairs(self.tZombiePublicEvents) do
		tZombieEvent["nTimer"] = tZombieEvent["nTimer"] - 1
		if tZombieEvent["nTimer"] <= 0 then
			table.remove(self.tZombiePublicEvents, key)
			self:DestroyAndRedraw()
			return
		end
	end

	-- Now Draw Completed Events
	for key, tZombieEvent in pairs(self.tZombiePublicEvents) do
		nAlphabetNumber	= nAlphabetNumber + 1
		self:DrawZombieEvent(wndEpisode:FindChild("EpisodeQuestContainer"), tZombieEvent, nAlphabetNumber)
	end

	-- Inline Sort Method
	local function SortEventTrackerScroll(a, b)
		if not Window.is(a) or not Window.is(b) or not a:IsValid() or not b:IsValid() then
			return false
		end
		return a:FindChild("EventLetter"):GetText() < b:FindChild("EventLetter"):GetText()
	end

	wndEpisode:FindChild("EpisodeQuestContainer"):ArrangeChildrenVert(0, SortEventTrackerScroll)
end

function GorynychQuestTracker:DrawQuest(nIdx, queQuest, wndParent)
	local wndQuest = self:FactoryProduce(wndParent, "QuestItem", queQuest)
	--RU xml
	wndQuest:FindChild("ControlBackerBtn"):SetTooltip(self:Translate(Apollo.GetString("QuestTracker_GuideTooltip")))
	wndQuest:FindChild("ControlBackerBtn"):FindChild("MinimizeBtn"):SetTooltip(self:Translate(Apollo.GetString("QuestTracker_MinimizeTooltip")))
	wndQuest:FindChild("ControlBackerBtn"):FindChild("QuestCloseBtn"):SetTooltip(self:Translate(Apollo.GetString("QuestTracker_StopTracking")))
	wndQuest:FindChild("QuestNumberBacker"):FindChild("QuestOpenLogBtn"):SetTooltip(self:Translate(Apollo.GetString("QuestTracker_OpenLogTooltip")))


	-- Only once
	if not wndQuest:FindChild("QuestOpenLogBtn"):GetData() then
		wndQuest:FindChild("QuestOpenLogBtn"):SetData(queQuest)
		wndQuest:FindChild("QuestCallbackBtn"):SetData(queQuest)
		wndQuest:FindChild("ControlBackerBtn"):SetData(wndQuest)
		wndQuest:FindChild("QuestCloseBtn"):SetData({["wndQuest"] = wndQuest, ["tQuest"] = queQuest})
		wndQuest:FindChild("MinimizeBtn"):SetData(queQuest:GetId())
	end

	-- Flash if we are told to
	if self.nFlashThisQuest == queQuest then
		self.nFlashThisQuest = nil
		wndQuest:SetSprite("sprWinAnim_BirthSmallTemp")
	end

	-- Quest Title
	local strTitle = queQuest:GetTitle()

	if tMinimized["quests"][queQuest:GetId()] then
		wndQuest:FindChild("MinimizeBtn"):SetCheck(true)
	end

	local eQuestState = queQuest:GetState()
	if eQuestState == Quest.QuestState_Botched then
		strTitle = string.format("<T Font=\"CRB_InterfaceMedium_B\" TextColor=\"%s\">%s</T>", kstrRed, String_GetWeaselString(Apollo.GetString("QuestTracker_Failed"), self:Translate(strTitle)))
	elseif eQuestState == Quest.QuestState_Achieved then
		strTitle = string.format("<T Font=\"CRB_InterfaceMedium_B\" TextColor=\"%s\">%s</T>", kstrGreen,String_GetWeaselString(Apollo.GetString("QuestTracker_Complete"), self:Translate(strTitle)))
	elseif (eQuestState == Quest.QuestState_Accepted or eQuestState == Quest.QuestState_Achieved) and queQuest:IsQuestTimed() then
		strTitle = string.format("<T Font=\"CRB_InterfaceMedium\" TextColor=\"%s\">%s</T>", kstrLightGrey, self:Translate(strTitle))
		strTitle = self:HelperPrefixTimeString(math.max(0, math.floor(queQuest:GetQuestTimeRemaining() / 1000)), strTitle)
	else
		local strColor = self.tActiveProgBarQuests[queQuest:GetId()] and "ffffffff" or kstrLightGrey
		--local strColor = kstrLightGrey
		strTitle = string.format("<T Font=\"CRB_InterfaceMedium\" TextColor=\"%s\">%s</T>", strColor, String_GetWeaselString(Apollo.GetString("QuestTracker_ConDisplay"), self:Translate(strTitle), queQuest:GetConLevel()))
	end
	wndQuest:FindChild("TitleText"):SetAML(strTitle)
	wndQuest:FindChild("TitleText"):SetHeightToContentHeight()

	-- Quest spell
	if queQuest:GetSpell() then
		local wndSpellItem = self:FactoryProduce(wndQuest:FindChild("ObjectiveContainer"), "SpellItem", "SpellItem")
		wndSpellItem:FindChild("SpellItemBtn"):Show(true)
		wndSpellItem:FindChild("SpellItemBtn"):SetContentId(queQuest) -- GOTCHA: Normally we use the spell id, but here we use the quest object
		wndSpellItem:FindChild("SpellItemText"):SetText(String_GetWeaselString(self:Translate(Apollo.GetString("QuestTracker_UseQuestAbility")), GameLib.GetKeyBinding("CastObjectiveAbility")))
	end

	-- Conditional drawing
	wndQuest:FindChild("QuestNumberUpdateHighlight"):Show(self.tActiveProgBarQuests[queQuest:GetId()] ~= nil)
	wndQuest:FindChild("QuestNumber"):SetText(nIdx)
	wndQuest:FindChild("QuestNumber"):SetTextColor(ApolloColor.new("ff31fcf6"))
	wndQuest:FindChild("QuestCompletedBacker"):Show(false)
	wndQuest:FindChild("QuestNumberBackerArt"):SetBGColor(CColor.new(1,1,1,1))
	wndQuest:FindChild("QuestNumberBackerArt"):SetSprite("sprQT_NumBackerNormal")
	wndQuest:FindChild("ObjectiveContainer"):Show(not wndQuest:FindChild("MinimizeBtn"):IsChecked())

	-- State depending drawing
	if wndQuest:FindChild("MinimizeBtn"):IsChecked() then
		wndQuest:FindChild("QuestNumber"):SetTextColor(CColor.new(.5, .5, .5, .8))
		wndQuest:FindChild("QuestNumberBackerArt"):SetBGColor(CColor.new(.5, .5, .5, .8))

	elseif eQuestState == Quest.QuestState_Botched then
		self:HelperShowQuestCallbackBtn(wndQuest, queQuest, "sprQT_NumBackerFailed", "CRB_QuestTrackerSprites:btnQT_QuestFailed")
		wndQuest:FindChild("QuestNumber"):SetTextColor(ApolloColor.new(kstrRed))

	elseif eQuestState == Quest.QuestState_Achieved then
		self:HelperShowQuestCallbackBtn(wndQuest, queQuest, "sprQT_NumBackerCompleted", "CRB_QuestTrackerSprites:btnQT_QuestRedeem")
		wndQuest:FindChild("QuestNumber"):SetTextColor(ApolloColor.new("ff7fffb9"))

		-- Achieve objective only has one
		local wndObjective = self:FactoryProduce(wndQuest:FindChild("ObjectiveContainer"), "QuestObjectiveItem", "ObjectiveCompleted")
		wndObjective:FindChild("QuestObjectiveBtn"):SetTooltip(self:BuildObjectiveTitleString(queQuest, tObjective, true))
		wndObjective:FindChild("QuestObjectiveBtn"):SetData({["queOwner"] = queQuest, ["nObjectiveIdx"] = nil})
		wndObjective:FindChild("QuestObjectiveText"):SetAML(self:BuildObjectiveTitleString(queQuest))

	else
		-- Potentially multiple objectives if not minimized or in the achieved/botched state
		for idObjective, tObjective in pairs(queQuest:GetVisibleObjectiveData()) do
			if tObjective.nCompleted < tObjective.nNeeded then
				local wndObjective = self:FactoryProduce(wndQuest:FindChild("ObjectiveContainer"), "QuestObjectiveItem", idObjective)
				self:DrawQuestObjective(wndQuest, wndObjective, queQuest, tObjective)
			end
		end
	end

	wndQuest:FindChild("ObjectiveContainer"):ArrangeChildrenVert(0)
end

function GorynychQuestTracker:DrawEvent(wndParent, peEvent, nAlphabetNumber)
	local wndEvent = self:FactoryProduce(wndParent, "EventItem", peEvent)
	--RU xml
	wndEvent:FindChild("ControlBackerBtn"):SetTooltip(self:Translate(Apollo.GetString("QuestTracker_GuideTooltip")))
	wndEvent:FindChild("ControlBackerBtn"):FindChild("MinimizeBtn"):SetTooltip(self:Translate(Apollo.GetString("QuestTracker_MinimizeTooltip")))
	wndEvent:FindChild("EventStatsBacker"):FindChild("ShowEventStatsBtn"):SetTooltip(self:Translate(Apollo.GetString("QuestTracker_ShowEventStats")))
	
	wndEvent:FindChild("ShowEventStatsBtn"):SetData(peEvent)
	wndEvent:FindChild("QuestMouseCatcher"):SetData(wndEvent)

	-- Event Title
	local strTitle = string.format("<T Font=\"CRB_InterfaceMedium\" TextColor=\"%s\">%s</T>", kstrLightGrey, self:Translate(peEvent:GetName()))
	if peEvent:GetTotalTime() > 0 and peEvent:IsActive() then
		strTitle = self:HelperPrefixTimeString(math.max(0, math.floor((peEvent:GetTotalTime() - peEvent:GetElapsedTime()) / 1000)), strTitle)
	end
	wndEvent:FindChild("TitleText"):SetAML(strTitle)
	wndEvent:FindChild("TitleText"):SetHeightToContentHeight()

	-- Conditional Drawing
	wndEvent:FindChild("EventStatsBacker"):Show(peEvent:HasLiveStats())
	wndEvent:FindChild("EventLetter"):SetText(ktNumbersToLetters[nAlphabetNumber])
	wndEvent:FindChild("EventLetter"):SetTextColor(ApolloColor.new("ff31fcf6"))
	wndEvent:FindChild("EventLetterBacker"):SetBGColor(CColor.new(1,1,1,1))

	if wndEvent:FindChild("MinimizeBtn"):IsChecked() then
		wndEvent:FindChild("EventLetter"):SetTextColor(CColor.new(.5, .5, .5, .8))
		wndEvent:FindChild("EventLetterBacker"):SetBGColor(CColor.new(.5, .5, .5, .8))
	else
		-- Draw the Objective, or delete if it's still around
		for idObjective, peoObjective in pairs(peEvent:GetObjectives()) do
			if peoObjective:GetStatus() == PublicEventObjective.PublicEventStatus_Active and not peoObjective:IsHidden() then
				local wndObjective = self:FactoryProduce(wndEvent:FindChild("ObjectiveContainer"), "QuestObjectiveItem", peoObjective)
				self:DrawEventObjective(wndObjective, peEvent, idObjective, peoObjective)
			elseif wndEvent:FindChild("ObjectiveContainer"):FindChildByUserData(peoObjective) then
				wndEvent:FindChild("ObjectiveContainer"):FindChildByUserData(peoObjective):Destroy()
			end
		end

		-- Inline Sort Method
		local function SortEventObjectivesTrackerScroll(a, b)
			if not Window.is(a) or not Window.is(b) or not a:IsValid() or not b:IsValid() or not a:GetData() or not b:GetData() then
				return false
			end
			return a:GetData():GetCategory() < b:GetData():GetCategory()
		end

		wndEvent:FindChild("ObjectiveContainer"):ArrangeChildrenVert(0, SortEventObjectivesTrackerScroll)
	end
end

function GorynychQuestTracker:DrawZombieEvent(wndParent, tZombieEvent, nAlphabetNumber)
	local wndEvent = self:FactoryProduce(wndParent, "ZombieEventItem", tZombieEvent.peEvent)
	--RU xml
	wndEvent:FindChild("EventControlBacker"):SetTooltip(self:Translate(Apollo.GetString("QuestTracker_GuideTooltip")))
	
	wndEvent:FindChild("QuestCallbackBtn"):SetData(wndEvent)
	wndEvent:FindChild("QuestMouseCatcher"):SetData(wndEvent)

	-- Conditional Drawing
	wndEvent:FindChild("EventLetter"):SetText(ktNumbersToLetters[nAlphabetNumber])
	wndEvent:FindChild("EventLetterBacker"):SetBGColor("white")

	if wndEvent:FindChild("MinimizeBtn"):IsChecked() then
		wndEvent:FindChild("EventLetter"):SetTextColor(CColor.new(.5, .5, .5, .8))
		wndEvent:FindChild("EventLetterBacker"):SetBGColor(CColor.new(.5, .5, .5, .8))
	end

	-- Win or Loss formatting here
	local strTitle = string.format("<T Font=\"CRB_InterfaceMedium_B\">%s</T>", self:Translate(tZombieEvent.peEvent:GetName()))
	if tZombieEvent.eReason == PublicEvent.PublicEventParticipantRemoveReason_CompleteFailure then
		wndEvent:FindChild("EventLetter"):SetTextColor(ApolloColor.new(kstrRed))
		wndEvent:FindChild("EventLetterBacker"):SetSprite("sprQT_NumBackerFailedPE")
		wndEvent:FindChild("QuestCallbackBtn"):ChangeArt("CRB_QuestTrackerSprites:btnQT_QuestFailed")
		wndEvent:FindChild("TitleText"):SetAML(string.format("<T Font=\"CRB_InterfaceMedium_B\" TextColor=\"%s\">%s</T>", kstrRed, String_GetWeaselString(Apollo.GetString("QuestTracker_Failed"), strTitle)))

	elseif tZombieEvent.eReason == PublicEvent.PublicEventParticipantRemoveReason_CompleteSuccess then
		wndEvent:FindChild("EventLetter"):SetTextColor(ApolloColor.new(kstrGreen))
		wndEvent:FindChild("EventLetterBacker"):SetSprite("sprQT_NumBackerCompletedPE")
		wndEvent:FindChild("QuestCallbackBtn"):ChangeArt("CRB_QuestTrackerSprites:btnQT_QuestRedeem")
		wndEvent:FindChild("TitleText"):SetAML(string.format("<T Font=\"CRB_InterfaceMedium_B\" TextColor=\"%s\">%s</T>", kstrGreen, String_GetWeaselString(Apollo.GetString("QuestTracker_Complete"), strTitle)))
	end
end

function GorynychQuestTracker:DrawQuestObjective(wndQuest, wndObjective, queQuest, tObjective)
	wndObjective:FindChild("QuestObjectiveBtn"):SetData({["queOwner"] = queQuest, ["nObjectiveIdx"] = tObjective.nIndex})
	wndObjective:FindChild("QuestObjectiveBtn"):SetTooltip(self:BuildObjectiveTitleString(queQuest, tObjective, true))
	wndObjective:FindChild("QuestObjectiveText"):SetAML(self:BuildObjectiveTitleString(queQuest, tObjective))

	-- Progress
	if self.tActiveProgBarQuests[queQuest:GetId()] and queQuest:DisplayObjectiveProgressBar(tObjective.nIndex) then
		local wndObjectiveProg = self:FactoryProduce(wndObjective, "QuestProgressItem", "QuestProgressItem")
		local nCompleted = tObjective.nCompleted
		local nNeeded = tObjective.nNeeded
		wndObjectiveProg:FindChild("QuestProgressBar"):SetMax(nNeeded)
		wndObjectiveProg:FindChild("QuestProgressBar"):SetProgress(nCompleted)
		wndObjectiveProg:FindChild("QuestProgressBar"):EnableGlow(nCompleted > 0 and nCompleted ~= nNeeded)
	elseif wndObjective:FindChild("QuestProgressItem") then
		wndObjective:FindChild("QuestProgressItem"):Destroy()
		self:OnQuestTrackerMainTimer()
	end

	-- Objective Spell Item
	if queQuest:GetSpell(tObjective.nIndex) then
		local wndSpellBtn = self:FactoryProduce(wndObjective, "SpellItemObjectiveBtn", "SpellItemObjectiveBtn"..tObjective.nIndex)
		wndSpellBtn:SetContentId(queQuest, tObjective.nIndex)
		wndObjective:FindChild("QuestObjectiveIcon"):Show(false) -- TODO REMOVE: HACK
	end
end

function GorynychQuestTracker:DrawEventObjective(wndObjective, queQuest, idObjective, peoObjective)
	wndObjective:FindChild("QuestObjectiveBtn"):SetData({["peoObjective"] = peoObjective })
	wndObjective:FindChild("QuestObjectiveBtn"):SetTooltip(self:BuildEventObjectiveTitleString(queQuest, peoObjective, true))
	wndObjective:FindChild("QuestObjectiveText"):SetAML(self:BuildEventObjectiveTitleString(queQuest, peoObjective))

	-- Progress Bar
	if peoObjective:GetObjectiveType() == PublicEventObjective.PublicEventObjectiveType_ContestedArea then
		local nPercent = peoObjective:GetContestedAreaRatio()
		if peoObjective:GetContestedAreaOwningTeam() == 0 then
			nPercent = (nPercent + 100.0) * 0.5
		end

		local wndObjectiveProg = self:FactoryProduce(wndObjective, "PublicProgressItem", "PublicProgressItem")
		wndObjectiveProg:FindChild("PublicProgressBar"):SetMax(100)
		wndObjectiveProg:FindChild("PublicProgressBar"):SetProgress(nPercent)
		wndObjectiveProg:FindChild("PublicProgressBar"):EnableGlow(false)
		wndObjectiveProg:FindChild("PublicProgressText"):SetText(String_GetWeaselString(self:Translate(Apollo.GetString("CRB_Percent")), math.floor(nPercent)))

	elseif peoObjective:ShowPercent() or peoObjective:ShowHealthBar() then
		local wndObjectiveProg = self:FactoryProduce(wndObjective, "PublicProgressItem", "PublicProgressItem")
		local nCompleted = peoObjective:GetCount()
		local nNeeded = peoObjective:GetRequiredCount()
		wndObjectiveProg:FindChild("PublicProgressBar"):SetMax(nNeeded)
		wndObjectiveProg:FindChild("PublicProgressBar"):SetProgress(nCompleted)
		wndObjectiveProg:FindChild("PublicProgressBar"):EnableGlow(nCompleted > 0 and nCompleted ~= nNeeded)
		wndObjectiveProg:FindChild("PublicProgressText"):SetText(String_GetWeaselString(self:Translate(Apollo.GetString("CRB_Percent")), math.floor(nCompleted / nNeeded * 100)))
	end

	-- Objective Spell Item
	if peoObjective:GetSpell() then
		local wndSpellBtn = self:FactoryProduce(wndObjective, "SpellItemObjectiveBtn", idObjective)
		wndSpellBtn:SetContentId(peoObjective)
		wndObjective:FindChild("QuestObjectiveIcon"):Show(false) -- TODO REMOVE: HACK
	end
end

-----------------------------------------------------------------------------------------------
-- Main Resize Method
-----------------------------------------------------------------------------------------------

function GorynychQuestTracker:OnResizeEpisode(wndEpisode)
	local nOngoingTopCount = self.knInitialEpisodeHeight
	if not wndEpisode:FindChild("EpisodeMinimizeBtn"):IsChecked() then
		for idx2, wndQuest in pairs(wndEpisode:FindChild("EpisodeQuestContainer"):GetChildren()) do
			local nQuestTextWidth, nQuestTextHeight = wndQuest:FindChild("TitleText"):SetHeightToContentHeight()
			local nResult = math.max(self.knInitialQuestControlBackerHeight, nQuestTextHeight + 4) -- for lower g height
			if wndQuest:FindChild("ControlBackerBtn") then
				local nLeft, nTop, nRight, nBottom = wndQuest:FindChild("ControlBackerBtn"):GetAnchorOffsets()
				wndQuest:FindChild("ControlBackerBtn"):SetAnchorOffsets(nLeft, nTop, nRight, nTop + nResult)
			end

			if wndQuest:FindChild("ObjectiveContainer") then -- Todo refactor
				local nLeft, nTop, nRight, nBottom = wndQuest:FindChild("ObjectiveContainer"):GetAnchorOffsets()
				wndQuest:FindChild("ObjectiveContainer"):SetAnchorOffsets(nLeft, nResult, nRight, nBottom)
				wndQuest:FindChild("ObjectiveContainer"):Show(not wndQuest:FindChild("MinimizeBtn"):IsChecked())
				wndQuest:FindChild("ObjectiveContainer"):ArrangeChildrenVert(0)
			end

			-- If expanded and valid, make it bigger
			if wndQuest:FindChild("ObjectiveContainer") and not wndQuest:FindChild("MinimizeBtn"):IsChecked() then
				for idx3, wndObj in pairs(wndQuest:FindChild("ObjectiveContainer"):GetChildren()) do
					local nObjTextHeight = self.knInitialQuestObjectiveHeight

					-- If there's the spell icon is bigger, use that instead
					if wndObj:FindChild("SpellItemObjectiveBtn") or wndObj:GetName() == "SpellItem" then
						nObjTextHeight = math.max(nObjTextHeight, self.knInitialSpellItemHeight)
					end

					-- If the text is bigger, use that instead
					if wndObj:FindChild("QuestObjectiveText") then
						local nLocalWidth, nLocalHeight = wndObj:FindChild("QuestObjectiveText"):SetHeightToContentHeight()
						nObjTextHeight = math.max(nObjTextHeight, nLocalHeight + 4) -- for lower g height

						-- Fake V-Align to match the button if it's just one line of text
						if wndObj:FindChild("SpellItemObjectiveBtn") and nLocalHeight < 20 then
							local nLeft, nTop, nRight, nBottom = wndObj:FindChild("QuestObjectiveText"):GetAnchorOffsets()
							wndObj:FindChild("QuestObjectiveText"):SetAnchorOffsets(nLeft, 9, nRight, nBottom)
						end
					end

					-- Also add extra height for Progress Bars
					if wndObj:FindChild("QuestProgressItem") then
						nObjTextHeight = nObjTextHeight + wndObj:FindChild("QuestProgressItem"):GetHeight()
					elseif wndObj:FindChild("PublicProgressItem") then
						nObjTextHeight = nObjTextHeight + wndObj:FindChild("PublicProgressItem"):GetHeight()
					end

					local nLeft, nTop, nRight, nBottom = wndObj:GetAnchorOffsets()
					wndObj:SetAnchorOffsets(nLeft, nTop, nRight, nTop + nObjTextHeight)
					nResult = nResult + nObjTextHeight
				end
			elseif wndQuest:FindChild("ObjectiveContainer") then
				nResult = nResult + 4 -- Minimized needs +4
			end

			local nLeft, nTop, nRight, nBottom = wndQuest:GetAnchorOffsets()
			wndQuest:SetAnchorOffsets(nLeft, nTop, nRight, nTop + math.max(nResult, self.knMinHeightEventItem))
			nOngoingTopCount = nOngoingTopCount + math.max(nResult, self.knMinHeightEventItem)
		end
	end

	local nLeft, nTop, nRight, nBottom = wndEpisode:GetAnchorOffsets()
	wndEpisode:SetAnchorOffsets(nLeft, nTop, nRight, nTop + nOngoingTopCount)
	wndEpisode:FindChild("EpisodeQuestContainer"):Show(not wndEpisode:FindChild("EpisodeMinimizeBtn"):IsChecked())
end

-----------------------------------------------------------------------------------------------
-- UI Interaction
-----------------------------------------------------------------------------------------------

function GorynychQuestTracker:OnQuestCloseBtn(wndHandler, wndControl) -- wndHandler is "QuestCloseBtn" and its data is { wndQuest, tQuest }
	local queQuest = wndHandler:GetData().tQuest
	queQuest:SetActiveQuest(false)

	if queQuest:GetState() == Quest.QuestState_Botched then
		queQuest:Abandon()
	else
		queQuest:ToggleTracked()
		wndHandler:GetData().wndQuest:Destroy()
		-- TODO: Handle Quest Log Untracking
	end

	self:DestroyAndRedraw() -- Destroy incase there are empty episodes
end

function GorynychQuestTracker:OnMinimizedBtnChecked(wndHandler, wndControl, eMouseButton)
	tMinimized["quests"][wndHandler:GetData()] = true

	self:UpdateUIFromXML()
end

function GorynychQuestTracker:OnMinimizedBtnUnChecked(wndHandler, wndControl, eMouseButton)
	tMinimized["quests"][wndHandler:GetData()] = nil

	self:UpdateUIFromXML()
end

function GorynychQuestTracker:OnEpisodeMinimizedBtnChecked(wndHandler, wndControl, eMouseButton)
	tMinimized["episode"][wndHandler:GetData()] = true

	self:UpdateUIFromXML()
end

function GorynychQuestTracker:OnEpisodeMinimizedBtnUnChecked(wndHandler, wndControl, eMouseButton)
	tMinimized["episode"][wndHandler:GetData()] = nil

	self:UpdateUIFromXML()
end

function GorynychQuestTracker:OnQuestOpenLogBtn(wndHandler, wndControl) -- wndHandler should be "QuestOpenLogBtn" and its data is tQuest
	Event_FireGenericEvent("ShowQuestLog", wndHandler:GetData()) -- Codex (todo: deprecate this)
	Event_FireGenericEvent("GenericEvent_ShowQuestLog", wndHandler:GetData()) -- QuestLog
end

function GorynychQuestTracker:OnQuestCallbackBtn(wndHandler, wndControl) -- wndHandler is "QuestCallbackBtn" and its data is tQuest
	CommunicatorLib.CallContact(wndHandler:GetData())
end

function GorynychQuestTracker:OnShowEventStatsBtn(wndHandler, wndControl) -- wndHandler is "ShowEventStatsBtn" and its data is tEvent
	local peEvent = wndHandler:GetData() -- GOTCHA: Event Object is set up differently than the tZombieEvent table
	if peEvent and peEvent:HasLiveStats() then
		local tLiveStats = peEvent:GetLiveStats()
		Event_FireGenericEvent("GenericEvent_OpenEventStats", peEvent, peEvent:GetMyStats(), tLiveStats.arTeamStats, tLiveStats.arParticipantStats)
	end
end

function GorynychQuestTracker:OnEventCallbackBtn(wndHandler, wndControl) -- wndHandler is "QuestCallbackBtn" and its data is wndEvent
	for idx, tZombieEvent in pairs(self.tZombiePublicEvents) do
		local wndEvent = wndHandler:GetData() -- To destroy later
		if tZombieEvent.peEvent and tZombieEvent.peEvent == wndEvent:GetData() then
			if tZombieEvent.peEvent:GetEventType() == PublicEvent.PublicEventType_WorldEvent then
				Event_FireGenericEvent("GenericEvent_OpenEventStatsZombie", tZombieEvent)
			end

			wndEvent:Destroy()
			self.tZombiePublicEvents[idx] = nil
			self:OnQuestTrackerMainTimer()
			return
		end
	end
end

function GorynychQuestTracker:OnQuestHintArrow(wndHandler, wndControl, eMouseButton) -- wndHandler is "ControlBackerBtn" (can be from EventItem) and its data is wndQuest
	local wndQuest = wndHandler:GetData()

	if not wndQuest:FindChild("MinimizeBtn"):ContainsMouse() and (not wndQuest:FindChild("QuestCloseBtn") or not wndQuest:FindChild("QuestCloseBtn"):ContainsMouse()) then
		if eMouseButton == GameLib.CodeEnumInputMouse.Right and Apollo.IsShiftKeyDown() then
			Event_FireGenericEvent("GenericEvent_QuestLink", wndQuest:GetData())
		else
			wndQuest:GetData():ShowHintArrow()

			if self.tClickBlinkingQuest then
				Apollo.StopTimer("QuestTrackerBlinkTimer")
				self.tClickBlinkingQuest:SetActiveQuest(false)
			elseif self.tHoverBlinkingQuest then
				self.tHoverBlinkingQuest:SetActiveQuest(false)
			end

			if Quest.is(wndQuest:GetData()) then
				self.tClickBlinkingQuest = wndQuest:GetData()
				self.tClickBlinkingQuest:ToggleActiveQuest()
				Apollo.StartTimer("QuestTrackerBlinkTimer")
			end
		end
	end
end

function GorynychQuestTracker:OnQuestObjectiveHintArrow(wndHandler, wndControl) -- "QuestObjectiveBtn" (can be from EventItem), data is { tQuest, tObjective.index }
	local tData = wndHandler:GetData()

	if tData and tData.peoObjective then
		tData.peoObjective:ShowHintArrow() -- Objectives do NOT default to parent if it fails
	elseif tData and tData.queOwner then
		tData.queOwner:ShowHintArrow(tData.nObjectiveIdx)

		if self.tClickBlinkingQuest then
			Apollo.StopTimer("QuestTrackerBlinkTimer")
			self.tClickBlinkingQuest:SetActiveQuest(false)
		elseif self.tHoverBlinkingQuest then
			self.tHoverBlinkingQuest:SetActiveQuest(false)
		end

		if Quest.is(tData.queOwner) then
			self.tClickBlinkingQuest = tData.queOwner
			self.tClickBlinkingQuest:ToggleActiveQuest()
			Apollo.StartTimer("QuestTrackerBlinkTimer")
		end
	end

	return true -- Stop Propagation so the Quest Hint Arrow won't eat this call
end

-----------------------------------------------------------------------------------------------
-- Mouse Enter/Exits
-----------------------------------------------------------------------------------------------

function GorynychQuestTracker:OnQuestItemMouseEnter(wndHandler, wndControl)
	if wndHandler == wndControl and wndHandler:GetData() and Quest.is(wndHandler:GetData()) then
		self.tHoverBlinkingQuest = wndHandler:GetData()

		if self.tClickBlinkingQuest == nil then
			self.tHoverBlinkingQuest:ToggleActiveQuest()
		end
	end
end

function GorynychQuestTracker:OnQuestItemMouseExit(wndHandler, wndControl)
	if wndHandler == wndControl and wndHandler:GetData() and Quest.is(wndHandler:GetData()) then
		if self.tClickBlinkingQuest == nil and self.tHoverBlinkingQuest then
			self.tHoverBlinkingQuest:SetActiveQuest(false)
		end

		self.tHoverBlinkingQuest = nil
	end
end

function GorynychQuestTracker:OnQuestNumberBackerMouseEnter(wndHandler, wndControl)
	if wndHandler == wndControl then
		wndHandler:FindChild("QuestNumberBackerGlow"):Show(true)
	end
end

function GorynychQuestTracker:OnQuestNumberBackerMouseExit(wndHandler, wndControl)
	if wndHandler == wndControl then
		wndHandler:FindChild("QuestNumberBackerGlow"):Show(false)
	end
end

function GorynychQuestTracker:OnControlBackerMouseEnter(wndHandler, wndControl) -- "ControlBackerBtn" of Quest or Event
	if wndHandler == wndControl then
		local wndQuest = wndHandler:GetData()
		local queQuest = wndQuest and wndQuest:GetData() or nil
		wndHandler:FindChild("MinimizeBtn"):Show(not queQuest or queQuest:GetState() ~= Quest.QuestState_Botched )
		if wndHandler:FindChild("QuestCloseBtn") then
			wndHandler:FindChild("QuestCloseBtn"):Show(true)
		end
	end
end

function GorynychQuestTracker:OnControlBackerMouseExit(wndHandler, wndControl)
	if wndHandler == wndControl then
		wndHandler:FindChild("MinimizeBtn"):Show(false)
		if wndHandler:FindChild("QuestCloseBtn") then
			wndHandler:FindChild("QuestCloseBtn"):Show(false)
		end
	end
end

function GorynychQuestTracker:OnEpisodeControlBackerMouseEnter(wndHandler, wndControl)
	if wndHandler == wndControl then
		wndHandler:FindChild("EpisodeMinimizeBtn"):Show(true)
	end
end

function GorynychQuestTracker:OnEpisodeControlBackerMouseExit(wndHandler, wndControl)
	if wndHandler == wndControl then
		wndHandler:FindChild("EpisodeMinimizeBtn"):Show(false)
	end
end

-----------------------------------------------------------------------------------------------
-- Code Events (mostly removing zombies)
-----------------------------------------------------------------------------------------------

function GorynychQuestTracker:OnShowResurrectDialog()
	unitPlayer = GameLib.GetPlayerUnit()
	if unitPlayer then
		self.bPlayerIsDead = unitPlayer:IsDead()
	end
end

function GorynychQuestTracker:OnPlayerResurrected()
	self.bPlayerIsDead = false
end

function GorynychQuestTracker:OnToggleLongQuestText(bToggle)
	self.bShowLongQuestText = bToggle
end

function GorynychQuestTracker:OnQuestStateChanged(queQuest, eState)
	if not self.wndMain then
		return
	end

	if eState == Quest.QuestState_Completed or eState == Quest.QuestState_Abandoned or eState == Quest.QuestState_Botched then
		self:HelperFindAndDestroyQuest(queQuest)
	else
		self.nFlashThisQuest = queQuest
	end

	self:OnQuestTrackerMainTimer()
end

function GorynychQuestTracker:OnQuestObjectiveUpdated(queQuest, nObjective)
	if not queQuest or queQuest:ObjectiveIsVisible(nObjective) == false then
		return
	end

	self.tActiveProgBarQuests[queQuest:GetId()] = os.clock()
	Apollo.CreateTimer("QuestTracker_EarliestProgBarTimer", knQuestProgBarFadeoutTime, false)
	-- GOTCHA: Apollo quirk, if you don't StopTimer before this, only the earliest is caught. So check and refire event in the handler.

	self:OnDestroyQuestObject(queQuest)
end

function GorynychQuestTracker:OnGorynychQuestTracker_EarliestProgBarTimer()
	-- GOTCHA: Apollo quirk, only the earliest is caught. So check and refire event if applicable.
	local nComparisonTime = os.clock()
	local nLowestTime = 9000
	for nCurrQuestId, nCurrTime in pairs(self.tActiveProgBarQuests) do
		if (nCurrTime + knQuestProgBarFadeoutTime) < (nComparisonTime + 1) then -- Plus one for safety
			self.tActiveProgBarQuests[nCurrQuestId] = nil
		else
			local nDifference = (nCurrTime + knQuestProgBarFadeoutTime) - nComparisonTime
			nLowestTime = nDifference < nLowestTime and nDifference or nLowestTime
		end
	end

	if nLowestTime ~= 9000 then
		Apollo.CreateTimer("QuestTracker_EarliestProgBarTimer", nLowestTime, false)
	end
end

function GorynychQuestTracker:OnDestroyQuestObject(queQuest)
	self.nFlashThisQuest = queQuest
	self:HelperFindAndDestroyQuest(queQuest)
	self:OnQuestTrackerMainTimer()
end

function GorynychQuestTracker:OnDatachronRestored(nDatachronShift)
	if not self.wndMain then return end
	local nLeft, nTop, nRight, nBottom = self.wndMain:GetAnchorOffsets()
	self.wndMain:SetAnchorOffsets(nLeft, nTop, nRight, nBottom - nDatachronShift)
	self:OnQuestTrackerMainTimer()
end

function GorynychQuestTracker:OnDatachronMinimized(nDatachronShift)
	if not self.wndMain then return end
	local nLeft, nTop, nRight, nBottom = self.wndMain:GetAnchorOffsets()
	self.wndMain:SetAnchorOffsets(nLeft, nTop, nRight, nBottom + nDatachronShift)
	self:OnQuestTrackerMainTimer()
end

-----------------------------------------------------------------------------------------------
-- Public Events
-----------------------------------------------------------------------------------------------

function GorynychQuestTracker:OnPublicEventStart(peEvent)
	-- Remove from zombie list if we're restarting it
	for idx, tZombieEvent in pairs(self.tZombiePublicEvents) do
		if tZombieEvent.peEvent == peEvent then
			self.tZombiePublicEvents[idx] = nil
			if self.wndMain:FindChild("QuestTrackerScroll"):FindChildByUserData(kstrPublicEventMarker) then
				local wndEvent = self.wndMain:FindChild("QuestTrackerScroll"):FindChildByUserData(kstrPublicEventMarker):FindChildByUserData(peEvent)
				if wndEvent then
					wndEvent:Destroy()
				end
			end
			break
		end
	end
	self:OnQuestTrackerMainTimer()
end

function GorynychQuestTracker:OnPublicEventEnd(peEvent, eReason, tStats)
	-- Add to list, or delete if we left the area
	if (eReason == PublicEvent.PublicEventParticipantRemoveReason_CompleteSuccess or eReason == PublicEvent.PublicEventParticipantRemoveReason_CompleteFailure)
	and peEvent:GetEventType() ~= PublicEvent.PublicEventType_SubEvent then
		table.insert(self.tZombiePublicEvents, {["peEvent"] = peEvent, ["eReason"] = eReason, ["tStats"] = tStats, ["nTimer"] = self.ZombieTimerMax})
	end

	-- Delete existing
	if self.wndMain:FindChild("QuestTrackerScroll"):FindChildByUserData(kstrPublicEventMarker) then
		local wndEvent = self.wndMain:FindChild("QuestTrackerScroll"):FindChildByUserData(kstrPublicEventMarker):FindChildByUserData(peEvent)
		if wndEvent then
			wndEvent:Destroy()
		end
	end
	self:OnQuestTrackerMainTimer()
end

function GorynychQuestTracker:OnPublicEventUpdate(tObjective)
	-- TODO Temp gate, in case this gets spammed a billion times a second.
	if not self.bPublicEventUpdateTimerStarted then
		self.bPublicEventUpdateTimerStarted = true
		Apollo.CreateTimer("UpdateInOneSecond", 1, false)
	end
end

-----------------------------------------------------------------------------------------------
-- String Building
-----------------------------------------------------------------------------------------------

function GorynychQuestTracker:HelperShowQuestCallbackBtn(wndQuest, queQuest, strNumberBackerArt, strCallbackBtnArt)
	wndQuest:FindChild("QuestNumberBackerArt"):SetSprite(strNumberBackerArt)

	local tContactInfo = queQuest:GetContactInfo()

	if not tContactInfo or not tContactInfo.strName or string.len(tContactInfo.strName) <= 0 then
		return
	end

	wndQuest:FindChild("QuestCompletedBacker"):Show(true)
	wndQuest:FindChild("QuestCallbackBtn"):ChangeArt(strCallbackBtnArt)
	wndQuest:FindChild("QuestCallbackBtn"):Enable(not self.bPlayerIsDead)
	wndQuest:FindChild("QuestCallbackBtn"):SetTooltip(string.format("<P Font=\"CRB_InterfaceMedium\">%s</P>", String_GetWeaselString(self:Translate(Apollo.GetString("QuestTracker_ContactName")), self:Translate(tContactInfo.strName))))
end

function GorynychQuestTracker:BuildObjectiveTitleString(queQuest, tObjective, bIsTooltip)
	local strResult = ""

	-- Early exit for completed
	if queQuest:GetState() == Quest.QuestState_Achieved then
		strResult = queQuest:GetCompletionObjectiveShortText()
		if self.bShowLongQuestText or not strResult or string.len(strResult) <= 0 then
			strResult = queQuest:GetCompletionObjectiveText()
		end
		return string.format("<T Font=\"CRB_InterfaceMedium\">%s</T>", self:Translate(strResult))
	end

	-- Use short form or reward text if possible
	local strShortText = queQuest:GetObjectiveShortDescription(tObjective.nIndex)
	if self.bShowLongQuestText or bIsTooltip then
		strResult = string.format("<T Font=\"CRB_InterfaceMedium\">%s</T>", self:Translate(tObjective.strDescription))
	elseif strShortText and string.len(strShortText) > 0 then
		strResult = string.format("<T Font=\"CRB_InterfaceMedium\">%s</T>", self:Translate(strShortText))
	end

	-- Prefix Optional or Progress if it hasn't been finished yet
	if tObjective.nCompleted < tObjective.nNeeded then
		local strPrefix = ""
		if tObjective and not tObjective.bIsRequired then
			strPrefix = string.format("<T Font=\"CRB_InterfaceMedium\">%s</T>", self:Translate(Apollo.GetString("QuestLog_Optional")))
			strResult = String_GetWeaselString(Apollo.GetString("QuestTracker_BuildText"), strPrefix, strResult)
		end

		-- Use Percent if Progress Bar
		if tObjective.nNeeded > 1 and queQuest:DisplayObjectiveProgressBar(tObjective.nIndex) then
			local strColor = self.tActiveProgBarQuests[queQuest:GetId()] and kstrHighlight or "ffffffff"
			local strPercentComplete = String_GetWeaselString(Apollo.GetString("QuestTracker_PercentComplete"), tObjective.nCompleted)
			strPrefix = string.format("<T Font=\"CRB_InterfaceMedium_B\" TextColor=\"%s\">%s</T>", strColor, strPercentComplete)
			strResult = String_GetWeaselString(Apollo.GetString("QuestTracker_BuildText"), strPrefix, strResult)
		elseif tObjective.nNeeded > 1 then
			strPrefix = string.format("<T Font=\"CRB_InterfaceMedium_B\">%s</T>", String_GetWeaselString(Apollo.GetString("QuestTracker_ValueComplete"), tObjective.nCompleted, tObjective.nNeeded))
			strResult = String_GetWeaselString(Apollo.GetString("QuestTracker_BuildText"), strPrefix, strResult)
		end
	end

	-- Prefix time for timed objectives
	if queQuest:IsObjectiveTimed(tObjective.nIndex) then
		strResult = self:HelperPrefixTimeString(math.max(0, math.floor(queQuest:GetObjectiveTimeRemaining(tObjective.nIndex) / 1000)), strResult)
	end

	return strResult
end

function GorynychQuestTracker:BuildEventObjectiveTitleString(queQuest, peoObjective, bIsTooltip)
	-- Use short form or reward text if possible
	local strResult = ""
	local strShortText = peoObjective:GetShortDescription()
	if strShortText and string.len(strShortText) > 0 and not bIsTooltip then
		strResult = string.format("<T Font=\"CRB_InterfaceMedium\">%s</T>", self:Translate(strShortText))
	else
		strResult = string.format("<T Font=\"CRB_InterfaceMedium\">%s</T>", self:Translate(peoObjective:GetDescription()))
	end

	-- Progress Brackets and Time if Active
	if peoObjective:GetStatus() == PublicEventObjective.PublicEventStatus_Active then
		local nCompleted = peoObjective:GetCount()
		local eCategory = peoObjective:GetCategory()
		local eType = peoObjective:GetObjectiveType()
		local nNeeded = peoObjective:GetRequiredCount()

		-- Prefix Brackets
		local strPrefix = ""
		if nNeeded == 0 and (eType == PublicEventObjective.PublicEventObjectiveType_Exterminate or eType == PublicEventObjective.PublicEventObjectiveType_DefendObjectiveUnits) then
			strPrefix = string.format("<T Font=\"CRB_InterfaceMedium_B\">%s </T>", String_GetWeaselString(Apollo.GetString("QuestTracker_Remaining"), nCompleted))
		elseif eType == PublicEventObjective.PublicEventObjectiveType_DefendObjectiveUnits and not peoObjective:ShowPercent() and not peoObjective:ShowHealthBar() then
			strPrefix = string.format("<T Font=\"CRB_InterfaceMedium_B\">%s </T>", String_GetWeaselString(Apollo.GetString("QuestTracker_Remaining"), (nCompleted - nNeeded + 1)))
		elseif eType == PublicEventObjective.PublicEventObjectiveType_Turnstile then
			strPrefix = string.format("<T Font=\"CRB_InterfaceMedium_B\">%s </T>", String_GetWeaselString(Apollo.GetString("QuestTracker_WaitingForMore"), math.abs(nCompleted - nNeeded)))
		elseif eType == PublicEventObjective.PublicEventObjectiveType_ParticipantsInTriggerVolume then
			strPrefix = string.format("<T Font=\"CRB_InterfaceMedium_B\">%s </T>",  String_GetWeaselString(Apollo.GetString("QuestTracker_WaitingForMore"), math.abs(nCompleted - nNeeded)))
		elseif eType == PublicEventObjective.PublicEventObjectiveType_TimedWin then
			-- Do Nothing
		elseif nNeeded > 1 and not peoObjective:ShowPercent() and not peoObjective:ShowHealthBar() then
			strPrefix = string.format("<T Font=\"CRB_InterfaceMedium_B\">%s </T>", String_GetWeaselString(Apollo.GetString("QuestTracker_ValueComplete"), nCompleted, nNeeded))
		end

		if strPrefix ~= "" then
			strResult = String_GetWeaselString(Apollo.GetString("QuestTracker_BuildText"), strPrefix, strResult)
			strPrefix = ""
		end

		-- Prefix Time
		if peoObjective:IsBusy() then
			strPrefix = string.format("<T Font=\"CRB_InterfaceMedium_B\" TextColor=\"%s\">%s </T>", kstrYellow, self:Translate(Apollo.GetString("QuestTracker_Paused")))
			strResult = String_GetWeaselString(Apollo.GetString("QuestTracker_BuildText"), strPrefix, strResult)
			strPrefix = ""
		elseif peoObjective:GetTotalTime() > 0 then
			local strColorOverride = nil
			if peoObjective:GetObjectiveType() == PublicEventObjective.PublicEventObjectiveType_TimedWin then
				strColorOverride = kstrGreen
			end
			strResult = self:HelperPrefixTimeString(math.max(0, math.floor((peoObjective:GetTotalTime() - peoObjective:GetElapsedTime()) / 1000)), strResult, strColorOverride)
		end

		-- Extra formatting
		if eCategory == PublicEventObjective.PublicEventObjectiveCategory_PlayerPath then
			strPrefix = string.format("<T Font=\"CRB_InterfaceMedium_B\">%s </T>", String_GetWeaselString(Apollo.GetString("CRB_ProgressSimple"), self:Translate(self.strPlayerPath or Apollo.GetString("CRB_Path"))))
		elseif eCategory == PublicEventObjective.PublicEventObjectiveCategory_Optional then
			strPrefix = string.format("<T Font=\"CRB_InterfaceMedium_B\">%s </T>", self:Translate(Apollo.GetString("QuestTracker_OptionalTag")))
		elseif eCategory == PublicEventObjective.PublicEventObjectiveCategory_Challenge then
			strPrefix = string.format("<T Font=\"CRB_InterfaceMedium_B\">%s </T>", self:Translate(Apollo.GetString("QuestTracker_ChallengeTag")))
		end

		if strPrefix ~= "" then
			strResult = String_GetWeaselString(Apollo.GetString("QuestTracker_BuildText"), strPrefix, strResult)
		end
	end
	return strResult
end

-----------------------------------------------------------------------------------------------
-- PvP
-----------------------------------------------------------------------------------------------

function GorynychQuestTracker:OnLeavePvP()
	self.bDrawPvPScreenOnly = false
	if self.wndMain:FindChild("SwapToPvP") and self.wndMain:FindChild("SwapToPvP"):IsValid() then
		self.wndMain:FindChild("SwapToPvP"):Destroy()
	end
	if self.wndMain:FindChild("SwapToQuests") and self.wndMain:FindChild("SwapToQuests"):IsValid() then
		self.wndMain:FindChild("SwapToQuests"):Destroy()
	end
end

function GorynychQuestTracker:OnSwapToPvPBtn() -- Also from code
	self.bDrawPvPScreenOnly = true
	if self.wndMain:FindChild("SwapToPvP") and self.wndMain:FindChild("SwapToPvP"):IsValid() then
		self.wndMain:FindChild("SwapToPvP"):Destroy()
	end
	self:FactoryProduce(self.wndMain:FindChild("QuestTrackerScroll"), "SwapToQuests", "SwapToQuests")
	self:DestroyAndRedraw()
end

function GorynychQuestTracker:OnSwapToDungeonsBtn() -- Also from code
	self.bDrawDungeonScreenOnly = true
	if self.wndMain:FindChild("SwapToDungeons") and self.wndMain:FindChild("SwapToDungeons"):IsValid() then
		self.wndMain:FindChild("SwapToDungeons"):Destroy()
	end
	self:FactoryProduce(self.wndMain:FindChild("QuestTrackerScroll"), "SwapToQuests", "SwapToQuests")
	self:DestroyAndRedraw()
end

function GorynychQuestTracker:OnSwapToQuestsBtn()
	if self.bDrawPvPScreenOnly then
		self.bDrawPvPScreenOnly = false
		self:FactoryProduce(self.wndMain:FindChild("QuestTrackerScroll"), "SwapToPvP", "SwapToPvP")
	end

	if self.bDrawDungeonScreenOnly then -- TODO investigate what happens when both are active
		self.bDrawDungeonScreenOnly = false
		self:FactoryProduce(self.wndMain:FindChild("QuestTrackerScroll"), "SwapToDungeons", "SwapToDungeons")
	end

	if self.wndMain:FindChild("SwapToQuests") and self.wndMain:FindChild("SwapToQuests"):IsValid() then
		self.wndMain:FindChild("SwapToQuests"):Destroy()
	end
	self:OnQuestTrackerMainTimer() -- GOTCHA: Don't destroy, we check for SwapToPvPBtn being valid later
end

-----------------------------------------------------------------------------------------------
-- Helpers
-----------------------------------------------------------------------------------------------

function GorynychQuestTracker:HelperPrefixTimeString(fTime, strAppend, strColorOverride)
	local fSeconds = fTime % 60
	local fMinutes = fTime / 60
	local strColor = kstrYellow
	if strColorOverride then
		strColor = strColorOverride
	elseif fMinutes < 1 and fSeconds <= 30 then
		strColor = kstrRed
	end
	local strPrefix = string.format("<T Font=\"CRB_InterfaceMedium_B\" TextColor=\"%s\">(%d:%.02d)</T>", strColor, fMinutes, fSeconds)
	return String_GetWeaselString(Apollo.GetString("QuestTracker_BuildText"), strPrefix, strAppend)
end

function GorynychQuestTracker:HelperFindAndDestroyQuest(queQuest)
	for idx, wndEp in pairs(self.wndMain:FindChild("QuestTrackerScroll"):GetChildren()) do
		if wndEp:FindChild("EpisodeQuestContainer") and wndEp:FindChild("EpisodeQuestContainer"):FindChildByUserData(queQuest) then
			wndEp:FindChild("EpisodeQuestContainer"):FindChildByUserData(queQuest):Destroy()

			if wndEp:GetData() ~= kstrPublicEventMarker and #wndEp:GetData():GetTrackedQuests() == 0 then
				wndEp:Destroy()
			end

			return
		end
	end
end

function GorynychQuestTracker:FactoryProduce(wndParent, strFormName, tObject)
	local wnd = wndParent:FindChildByUserData(tObject)
	if not wnd then
		wnd = Apollo.LoadForm(self.xmlDoc, strFormName, wndParent, self)
		wnd:SetData(tObject)
	end
	return wnd
end

---------------------------------------------------------------------------------------------------
-- Tutorial anchor request
---------------------------------------------------------------------------------------------------
function GorynychQuestTracker:OnTutorial_RequestUIAnchor(eAnchor, idTutorial, strPopupText)
	if eAnchor == GameLib.CodeEnumTutorialAnchor.GorynychQuestTracker or eAnchor == GameLib.CodeEnumTutorialAnchor.QuestCommunicatorReceived then

	local tRect = {}
	tRect.l, tRect.t, tRect.r, tRect.b = self.wndMain:GetRect()

	Event_FireGenericEvent("Tutorial_RequestUIAnchorResponse", eAnchor, idTutorial, strPopupText, tRect)
	end
end

local GorynychQuestTrackerInst = GorynychQuestTracker:new()
GorynychQuestTrackerInst:Init()
