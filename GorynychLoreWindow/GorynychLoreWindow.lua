-----------------------------------------------------------------------------------------------
-- Client Lua Script for GorynychLoreWindow
-- Copyright (c) NCsoft. All rights reserved
-----------------------------------------------------------------------------------------------

require "Window"
require "DatacubeLib"

local GorynychLoreWindow = {}

local bDockedOption = false
local kclrDefault = "ff62aec1"

local karContinents =
{
	Apollo.GetString("CRB_Eastern"),
	Apollo.GetString("CRB_Western"),
	Apollo.GetString("CRB_Central"),
	Apollo.GetString("Lore_Offworld"),
	Apollo.GetString("CRB_Dungeons"),
	Apollo.GetString("Lore_DefaultZone") -- TODO TEMP REMOVE
}

local ktZoneNameToContinent =  -- TODO TEMP
{
	[Apollo.GetString("Lore_Algoroc")] 						= Apollo.GetString("CRB_Eastern"),
	[Apollo.GetString("Lore_Celestion")] 					= Apollo.GetString("CRB_Eastern"),
	[Apollo.GetString("Lore_EverstarGrove")]				= Apollo.GetString("CRB_Eastern"),
	[Apollo.GetString("Lore_Galeras")] 						= Apollo.GetString("CRB_Eastern"),
	[Apollo.GetString("Lore_Murkmire")] 					= Apollo.GetString("CRB_Eastern"),
	[Apollo.GetString("Lore_NorthernWilds")] 				= Apollo.GetString("CRB_Eastern"),
	[Apollo.GetString("Lore_Whitevale")]					= Apollo.GetString("CRB_Eastern"),
	[Apollo.GetString("Lore_Thayd")]						= Apollo.GetString("CRB_Eastern"),

	[Apollo.GetString("Lore_Datascape")] 					= Apollo.GetString("CRB_Dungeons"),
	[Apollo.GetString("Lore_KelVoreth")] 					= Apollo.GetString("CRB_Dungeons"),
	[Apollo.GetString("Lore_SwordMaiden")] 					= Apollo.GetString("CRB_Dungeons"),
	[Apollo.GetString("Lore_Skullcano")] 					= Apollo.GetString("CRB_Dungeons"),
	[Apollo.GetString("Lore_Stormtalon")] 					= Apollo.GetString("CRB_Dungeons"),
	[Apollo.GetString("Lore_Simulations")] 					= Apollo.GetString("CRB_Dungeons"),

	[Apollo.GetString("Lore_Grimvault")] 					= Apollo.GetString("CRB_Central"),
	[Apollo.GetString("Lore_NMalgrave")] 					= Apollo.GetString("CRB_Central"), -- TODO: Remove string
	[Apollo.GetString("Lore_SMalgrave")] 					= Apollo.GetString("CRB_Central"), -- TODO: Remove string
	[Apollo.GetString("Lore_Malgrave")] 					= Apollo.GetString("CRB_Central"),
	[Apollo.GetString("Lore_NGrimvault")] 					= Apollo.GetString("CRB_Central"),
	[Apollo.GetString("Lore_SGrimvault")] 					= Apollo.GetString("CRB_Central"),
	[Apollo.GetString("Lore_WGrimvault")] 					= Apollo.GetString("CRB_Central"),

	[Apollo.GetString("Lore_Auroria")] 						= Apollo.GetString("CRB_Western"),
	[Apollo.GetString("Lore_CrimsonIsle")] 					= Apollo.GetString("CRB_Western"),
	[Apollo.GetString("Lore_Deradune")] 					= Apollo.GetString("CRB_Western"),
	[Apollo.GetString("Lore_Dreadmoor")] 					= Apollo.GetString("CRB_Western"),
	[Apollo.GetString("Lore_Ellevar")] 						= Apollo.GetString("CRB_Western"),
	[Apollo.GetString("Lore_Illium")] 						= Apollo.GetString("CRB_Western"),
	[Apollo.GetString("Lore_LeviathanBay")] 				= Apollo.GetString("CRB_Western"),
	[Apollo.GetString("Lore_LevianBay")] 					= Apollo.GetString("CRB_Western"),
	[Apollo.GetString("Lore_Wilderrun")] 					= Apollo.GetString("CRB_Western"),

	[Apollo.GetString("Lore_DominionArkship")] 				= Apollo.GetString("Lore_Offworld"), -- TODO: Remove String
	[Apollo.GetString("Lore_ExileArkship")] 				= Apollo.GetString("Lore_Offworld"), -- TODO: Remove String
	[Apollo.GetString("Lore_TheDestiny")] 					= Apollo.GetString("Lore_Offworld"),
	[Apollo.GetString("Lore_GamblersRuin")] 				= Apollo.GetString("Lore_Offworld"),
	[Apollo.GetString("Lore_Infestation")] 					= Apollo.GetString("Lore_Offworld"),
	[Apollo.GetString("Lore_Farside")] 						= Apollo.GetString("Lore_Offworld"),
	[Apollo.GetString("Lore_Graylight")] 					= Apollo.GetString("Lore_Offworld"),
	[Apollo.GetString("Lore_HalonRing")] 					= Apollo.GetString("Lore_Offworld"),
	[Apollo.GetString("Lore_ShiphandMissions")] 			= Apollo.GetString("Lore_Offworld"),
	[Apollo.GetString("Lore_ShiphandInfestation")] 			= Apollo.GetString("Lore_Offworld"),
}

function GorynychLoreWindow:new(o)
    o = o or {}
    setmetatable(o, self)
    self.__index = self
	self.ruTranslationLoreWindow = {}
    return o
end

function GorynychLoreWindow:Translate(str)
	local translationLib = Apollo.GetAddon("TranslationLib")
	if (translationLib ~= nil) then
		return translationLib:Traslate("RU", "LoreWindow", str)
	end
	return str
end

function GorynychLoreWindow:Init()
    Apollo.RegisterAddon(self)
end

function GorynychLoreWindow:OnLoad()
	Apollo.RegisterSlashCommand("compactlore", 						"OnCompactLore", self)
	Apollo.RegisterEventHandler("DatacubeUpdated", 					"OnDatacubeUpdated", self)
	Apollo.RegisterEventHandler("HudAlert_ToggleLoreWindow", 		"OnShowLoreWindow", self)
    Apollo.RegisterEventHandler("InterfaceMenu_ToggleLoreWindow", 	"OnToggleLoreWindow", self)

	Apollo.RegisterEventHandler("DatacubePlaybackEnded",			"OnDatacubeStopped", self)
	Apollo.RegisterEventHandler("GenericEvent_StopPlayingDatacube", "OnDatacubeStopped", self)
	Apollo.RegisterTimerHandler("LoreWindow_DatacubeStoppingTimer", "OnDatacubeTimer", self)

	-- used to make sure that the datachron can't be replayed while its still fading out
	Apollo.CreateTimer("LoreWindow_DatacubeStoppingTimer", 4.000, false)
	Apollo.StopTimer("LoreWindow_DatacubeStoppingTimer")

	self.ktNewEntries = {} -- Start tracking right away
end

function GorynychLoreWindow:Initialize()
	self.wndColDisplay = nil
	self.wndMain = Apollo.LoadForm("GorynychLoreWindow.xml", "GorynychLoreWindowForm", nil, self)
	self.wndMain:FindChild("MainNavGA"):AttachWindow(self.wndMain:FindChild("MainGAContainer"))
	self.wndMain:FindChild("MainNavCol"):AttachWindow(self.wndMain:FindChild("MainColContainer"))

	local wndMeasure = Apollo.LoadForm("GorynychLoreWindow.xml", "ColHeader", nil, self)
	self.knWndHeaderDefaultHeight = wndMeasure:GetHeight()
	wndMeasure:Destroy()

	local wndMeasure = Apollo.LoadForm("GorynychLoreWindow.xml", "ColJournalItem", nil, self)
	self.knWndJournalItemDefaultHeight = wndMeasure:GetHeight()
	wndMeasure:Destroy()

	Event_FireGenericEvent("ToggleGalacticArchiveWindow", self.wndMain:FindChild("MainGAContainer"), self.wndMain)

	self.wndMain:FindChild("ColTopDropdownBtn"):AttachWindow(self.wndMain:FindChild("ColTopDropdownBG"))
	self:InitializeCollections() -- Replace with a Generic Event if we pull this out of this file
end

function GorynychLoreWindow:OnDatacubeUpdated(idArg, bIsVolume)
	if self.wndMain and self.wndMain:IsValid() and self.wndMain:IsShown() then
		self.wndMain:FindChild("ColMainScroll"):DestroyChildren()
		self:MainRedrawCollections()

		-- Update dropdown
		for key, wndCurr in pairs(self.wndMain:FindChild("ColTopDropdownScroll"):GetChildren()) do
			if wndCurr:FindChild("DropdownZoneBtn") then
				local tCurrZone = wndCurr:FindChild("DropdownZoneBtn"):GetData()
				self:HelperDrawDropdownZoneProgress(wndCurr, tCurrZone.nZoneId, tCurrZone.strName)
			end
		end
		
		-- Update the selected zone total progress
		local wndColTopDropdownBtn = self.wndMain:FindChild("MainColContainer:ColTopBG:ColTopDropdownBtn")
		if wndColTopDropdownBtn ~= nil then
			local tSelectedZoneData = wndColTopDropdownBtn:GetData()
			if tSelectedZoneData ~= nil then
				self:HelperDrawDropdownZoneProgress(self.wndMain:FindChild("MainColContainer:ColTopBG:ColTopZoneProgressContainer"), tSelectedZoneData.nZoneId, tSelectedZoneData.strName)
			end
		end
	end

	if idArg then
		local tDatacube = DatacubeLib.GetLastUpdatedDatacube(idArg, bIsVolume) -- Nothing until it's unlocked anyways
		if not tDatacube then
			return
		end

		local bPartialTales = tDatacube.eDatacubeType == DatacubeLib.DatacubeType_Chronicle and not tDatacube.bIsComplete
		if not bPartialTales then
			self.ktNewEntries[tDatacube.nDatacubeId] = true -- GOTCHA: tDatacube.id can be different than nArgId (when nArgId is a volume)
			--self:OpenToSpecificArticle(idArg, bIsVolume)
		end
	end
end

function GorynychLoreWindow:OnShowLoreWindow(tArticleData)
	if not self.wndMain or not self.wndMain:IsValid() then
		self:Initialize()
	end
	
	self.wndMain:Show(true)
	self.wndMain:ToFront()
	Event_FireGenericEvent("LoreWindowHasBeenToggled")
	Event_ShowTutorial(GameLib.CodeEnumTutorial.General_Lore)

	if tArticleData then
		self:OpenToSpecificArticle(tArticleData.nDatacubeId)
	end
end

function GorynychLoreWindow:OnToggleLoreWindow(tArticleData)
	if not self.wndMain or not self.wndMain:IsValid() then
		self:Initialize()
	end

	if self.wndMain:IsShown() then
		self.wndMain:Show(false)
		Event_FireGenericEvent("LoreWindowHasBeenClosed")
	else
		self.wndMain:Show(true)
		self.wndMain:ToFront()
		Event_FireGenericEvent("LoreWindowHasBeenToggled")
		Event_ShowTutorial(GameLib.CodeEnumTutorial.General_Lore)
	end

	if tArticleData then
		self:OpenToSpecificArticle(tArticleData.nDatacubeId)
	end
end

function GorynychLoreWindow:OpenToSpecificArticle(idArg, bIsVolume)
	if not self.wndMain or not self.wndMain:IsValid() then
		return
	end
	
	-- Assume we'll be on the right zone page (or just don't care)
	local tArticleData = DatacubeLib.GetLastUpdatedDatacube(idArg, bIsVolume)
	self.wndMain:FindChild("MainNavGA"):SetCheck(false)
	self.wndMain:FindChild("MainNavCol"):SetCheck(true)
	self:SpawnAndDrawColReader(tArticleData, nil)
	self.wndColDisplay:FindChild("PlayPauseButton"):SetCheck(true)

	-- Try to find the correct wndOrigin (TODO HACKY)
	local wndOrigin = nil
	if tArticleData.eDatacubeType == DatacubeLib.DatacubeType_Chronicle then
		local wndParent = self.wndMain:FindChild("ColMainScroll"):FindChildByUserData("Tales"..idArg)
		if wndParent then
			wndParent:FindChild("ColTalesBtn"):SetCheck(true)
			self.wndColDisplay:SetData(wndParent:FindChild("ColTalesBtn"))
		end
	elseif tArticleData.eDatacubeType == DatacubeLib.DatacubeType_Journal then
		local wndParent = self.wndMain:FindChild("ColMainScroll"):FindChildByUserData("JournalArticle"..idArg)
		if wndParent then
			wndParent:FindChild("ColJournalChildBtn"):SetCheck(true)
			self.wndColDisplay:SetData(wndParent:FindChild("ColJournalChildBtn"))
		end
	elseif tArticleData.eDatacubeType == DatacubeLib.DatacubeType_Datacube then
		local wndParent = self.wndMain:FindChild("ColMainScroll"):FindChildByUserData("Datacube"..idArg)
		if wndParent then
			wndParent:FindChild("ColDatacubeBtn"):SetCheck(true)
			self.wndColDisplay:SetData(wndParent:FindChild("ColDatacubeBtn"))
		end
	end
end

function GorynychLoreWindow:OnCloseBtn(wndHandler, wndControl)
	self:OnDestroyColDisplay()
	Event_FireGenericEvent("GenericEvent_CloseGAReader")
	if self.wndMain and self.wndMain:IsValid() then
		self.wndMain:Destroy()
	end
end

-----------------------------------------------------------------------------------------------
-- Formerly Collections
-----------------------------------------------------------------------------------------------

function GorynychLoreWindow:InitializeCollections()
	-- Build zone dropdown
	local tZonesAtLoad = {}
	for key, tCurrZone in pairs(DatacubeLib.GetZonesWithDatacubes()) do
		tZonesAtLoad[tCurrZone.nZoneId] = tCurrZone
	end

	for key, tCurrZone in pairs(DatacubeLib.GetZonesWithJournals()) do
		tZonesAtLoad[tCurrZone.nZoneId] = tCurrZone
	end

	for key, tCurrZone in pairs(DatacubeLib.GetZonesWithTales()) do
		tZonesAtLoad[tCurrZone.nZoneId] = tCurrZone
	end

	for key, strContinent in pairs(karContinents) do
		local wndHeader = Apollo.LoadForm("GorynychLoreWindow.xml", "DropdownZoneHeader", self.wndMain:FindChild("ColTopDropdownScroll"), self)
		wndHeader:FindChild("DropdownZoneHeaderText"):SetText(self:Translate(strContinent))
		wndHeader:SetData(strContinent)
	end

	local bPickedAZone = false
	for key, tCurrZone in pairs(tZonesAtLoad) do
		local wndCurr = Apollo.LoadForm("GorynychLoreWindow.xml", "DropdownZoneItem", self.wndMain:FindChild("ColTopDropdownScroll"), self)
		wndCurr:SetData(String_GetWeaselString(Apollo.GetString("Lore_ContinentZone"), (ktZoneNameToContinent[tCurrZone.strName] or Apollo.GetString("Lore_Other")), tCurrZone.strName))
		wndCurr:FindChild("DropdownZoneBtn"):SetData(tCurrZone)
		wndCurr:FindChild("DropdownZoneBtn"):SetText(self:Translate(tCurrZone.strName))
		self:HelperDrawDropdownZoneProgress(wndCurr, tCurrZone.nZoneId, tCurrZone.strName)

		-- Default the top dropdown to the current zone
		if not self.wndMain:FindChild("ColTopDropdownBtn"):GetData() and GameLib.IsInWorldZone(tCurrZone.nZoneId) then
			bPickedAZone = true
			self.wndMain:FindChild("ColTopDropdownBtn"):SetData(tCurrZone)
			self.wndMain:FindChild("ColTopDropdownBtn"):SetText(self:Translate(tCurrZone.strName))
			self:HelperDrawDropdownZoneProgress(self.wndMain:FindChild("ColTopZoneProgressContainer"), tCurrZone.nZoneId, tCurrZone.strName)
		end
	end

	-- Just pick the first one if we didn't match a default zone
	if not bPickedAZone then
		for key, wndCurr in pairs(self.wndMain:FindChild("ColTopDropdownScroll"):GetChildren()) do
			if wndCurr:FindChild("DropdownZoneBtn") then
				local tCurrZone = wndCurr:FindChild("DropdownZoneBtn"):GetData()
				self.wndMain:FindChild("ColTopDropdownBtn"):SetData(tCurrZone)
				self.wndMain:FindChild("ColTopDropdownBtn"):SetText(self:Translate(tCurrZone.strName))
				self:HelperDrawDropdownZoneProgress(self.wndMain:FindChild("ColTopZoneProgressContainer"), tCurrZone.nZoneId, tCurrZone.strName)
			end
		end
	end
	self.wndMain:FindChild("ColTopDropdownScroll"):ArrangeChildrenVert(0, function(a,b) return a:GetData() < b:GetData() end)

	self:MainRedrawCollections()
end

function GorynychLoreWindow:MainRedrawCollections()
	local tCurrZone = self.wndMain:FindChild("ColTopDropdownBtn"):GetData()
	if not tCurrZone or not tCurrZone.nZoneId then
		return
	end

	for idx, strHeader in pairs({Apollo.GetString("Lore_Datacubes"), Apollo.GetString("Lore_Journals"), Apollo.GetString("Lore_Tales")}) do
		local wndHeader = self:FactoryProduce(self.wndMain:FindChild("ColMainScroll"), "ColHeader", strHeader)
		wndHeader:FindChild("ColHeaderBtn"):SetData(strHeader)
		if wndHeader:FindChild("ColHeaderBtn"):IsChecked() then
			wndHeader:FindChild("ColHeaderItems"):DestroyChildren()
			wndHeader:FindChild("ColHeaderBtnText"):SetText(String_GetWeaselString(self:Translate(Apollo.GetString("Lore_ClickToViewHeader")), strHeader))
		else
			local nNumFullyCompleted = self:DrawColHeaderItems(tCurrZone, wndHeader, strHeader)
			local nNumTotal = 0
			if idx == 1 then
				nNumTotal = DatacubeLib.GetTotalDatacubesForZone(tCurrZone.nZoneId) or 0
			elseif idx == 2 then
				nNumTotal = DatacubeLib.GetTotalJournalsForZone(tCurrZone.nZoneId) or 0
			elseif idx == 3 then
				nNumTotal = DatacubeLib.GetTotalTalesForZone(tCurrZone.nZoneId) or 0
			end
			wndHeader:FindChild("ColHeaderBtnText"):SetText(String_GetWeaselString(self:Translate(Apollo.GetString("FloatText_MissionProgress")), strHeader, nNumFullyCompleted, nNumTotal))

			if nNumTotal == 0 then
				wndHeader:Destroy()
			end
		end

		if wndHeader and wndHeader:IsValid() then
			wndHeader:SetAnchorOffsets(0,0,0, wndHeader:FindChild("ColHeaderItems"):ArrangeChildrenVert(0) + self.knWndHeaderDefaultHeight)
		end
	end

	self.wndMain:FindChild("ColMainScroll"):ArrangeChildrenVert(0)
	self.wndMain:FindChild("ColMainScroll"):Enable(true) -- for OnColTopDropdownToggle
end

function GorynychLoreWindow:RedrawFromUI()
	self:MainRedrawCollections()
end

function GorynychLoreWindow:DrawColHeaderItems(tCurrZone, wndHeader, strHeader)
	local nNumFullyCompleted = 0

	if strHeader == Apollo.GetString("Lore_Tales") then
		for idx, tListData in pairs(DatacubeLib.GetTalesForZone(tCurrZone.nZoneId) or {}) do
			local nMax = tListData.bIsComplete and 1 or tListData.nNumTotal
			local nComplete = tListData.bIsComplete and 1 or tListData.nNumCompleted
			local wndCurr = self:FactoryProduce(wndHeader:FindChild("ColHeaderItems"), "ColTalesItem", "Tales"..tListData.nDatacubeId)
			wndCurr:FindChild("NewIndicator"):Show(self.ktNewEntries[tListData.nDatacubeId])
			wndCurr:FindChild("ColTalesBtn"):SetData(tListData)
			wndCurr:FindChild("ColTalesBtn"):Show(tListData.bIsComplete)
			wndCurr:FindChild("ColListItemText"):SetText(self:Translate(tListData.strTitle))
			wndCurr:FindChild("ColTalesProgBar"):SetMax(nMax)
			wndCurr:FindChild("ColTalesProgBar"):SetProgress(nComplete)
			wndCurr:FindChild("ColTalesProgBar"):SetFullSprite("kitIProgBar_MetalInset_Fill" .. (tListData.bIsComplete and "Green" or "Blue"))
			wndCurr:FindChild("ColTalesProgText"):SetText(tListData.bIsComplete and "" or (String_GetWeaselString(self:Translate(Apollo.GetString("Lore_UnlockedProgress")), nComplete, nMax)))
			wndCurr:FindChild("ColTalesLockedIcon"):Show(not tListData.bIsComplete)
			wndCurr:FindChild("ColTalesCompleteIcon"):Show(tListData.bIsComplete)
			wndCurr:FindChild("ColTalesCompleteIconArt"):SetSprite(tListData.bIsComplete and tListData.strAsset or "")
			nNumFullyCompleted = tListData.bIsComplete and (nNumFullyCompleted + 1) or nNumFullyCompleted
		end
	elseif strHeader == Apollo.GetString("Lore_Datacubes") then
		for idx, tListData in pairs(DatacubeLib.GetDatacubesForZone(tCurrZone.nZoneId) or {}) do
			local wndCurr = self:FactoryProduce(wndHeader:FindChild("ColHeaderItems"), "ColDatacubeItem", "Datacube"..tListData.nDatacubeId)
			wndCurr:FindChild("NewIndicator"):Show(self.ktNewEntries[tListData.nDatacubeId])
			if wndCurr:FindChild("ColListItemText"):GetText() ~= tListData.strTitle then -- To avoid constantly setting the costume
				wndCurr:FindChild("ColDatacubeBtn"):SetData(tListData)
				wndCurr:FindChild("ColListItemText"):SetText(self:Translate(tListData.strTitle))
				wndCurr:FindChild("ColDatacubePortrait"):SetCostumeToCreatureId(11098) -- TODO Hardcoded
				wndCurr:FindChild("ColDatacubePortrait"):SetModelSequence(1120)
			end
			nNumFullyCompleted = tListData.bIsComplete and (nNumFullyCompleted + 1) or nNumFullyCompleted
		end
	elseif strHeader == Apollo.GetString("Lore_Journals") then
		for idx, tListData in pairs(DatacubeLib.GetJournalsForZone(tCurrZone.nZoneId) or {}) do
			local nMax = tListData.bIsComplete and 1 or tListData.nNumTotal
			local nComplete = tListData.bIsComplete and 1 or tListData.nNumCompleted
			local wndCurr = self:FactoryProduce(wndHeader:FindChild("ColHeaderItems"), "ColJournalItem", "Journal"..tListData.nDatacubeId)
			wndCurr:FindChild("ColListItemText"):SetText(self:Translate(tListData.title))
			wndCurr:FindChild("ColJournalPortrait"):SetCostumeToCreatureId((idx % 2 == 0) and 30728 or 30737) -- TODO Hardcoded
			wndCurr:FindChild("ColJournalPortrait"):SetModelSequence(150)
			wndCurr:FindChild("ColJournalProgBar"):SetMax(nMax)
			wndCurr:FindChild("ColJournalProgBar"):SetProgress(nComplete)
			wndCurr:FindChild("ColJournalProgBar"):SetFullSprite("kitIProgBar_MetalInset_Fill" .. (nComplete == nMax and "Green" or "Blue"))

			wndCurr:FindChild("ColJournalProgText"):SetText(self:Translate(tListData.isComplete) and "" or (String_GetWeaselString(self:Translate(Apollo.GetString("Lore_UnlockedProgress")), nComplete, nMax)))
			nNumFullyCompleted = (nMax == nComplete) and (nNumFullyCompleted + 1) or nNumFullyCompleted

			-- Children
			local bShowNewIndicator = false
			for idx3, tCurrArticleData in pairs(DatacubeLib.GetDatacubesForVolume(tListData.nDatacubeId)) do
				if tCurrArticleData.bIsComplete then
					local wndJournalChild = self:FactoryProduce(wndCurr:FindChild("ColJournalChildItems"), "ColJournalChildItem", "JournalArticle"..tCurrArticleData.nDatacubeId)
					wndJournalChild:FindChild("ColJournalChildBtn"):SetData(tCurrArticleData)
					wndJournalChild:FindChild("ColJournalChildBtnText"):SetText(self:Translate(tCurrArticleData.strTitle))
					bShowNewIndicator = self.ktNewEntries[tCurrArticleData.nDatachronId] and true or bShowNewIndicator
				end
			end
			wndCurr:FindChild("NewIndicator"):Show(bShowNewIndicator)
			wndCurr:SetAnchorOffsets(0,0,0, wndCurr:FindChild("ColJournalChildItems"):ArrangeChildrenVert(0) + self.knWndJournalItemDefaultHeight)
		end
	end

	if #wndHeader:FindChild("ColHeaderItems"):GetChildren() == 0 then -- GOTCHA: Not the same as nNumFullyCompleted == 0
		Apollo.LoadForm("GorynychLoreWindow.xml", "EmptyNotification", wndHeader:FindChild("ColHeaderItems"), self)
	end

	return nNumFullyCompleted
end

-----------------------------------------------------------------------------------------------
-- Collections Reader
-----------------------------------------------------------------------------------------------

function GorynychLoreWindow:SpawnAndDrawColReader(tArticleData, wndOrigin) -- wndOrigin can be nil
	if not tArticleData then
		return
	end

	if self.ktNewEntries[tArticleData.id] then
		self.ktNewEntries[tArticleData.id] = nil -- Clear their new indicator right away
		self.wndMain:FindChild("ColMainScroll"):DestroyChildren()
		self:MainRedrawCollections()
	end

	if self.wndColDisplay and self.wndColDisplay:IsValid() then
		self:OnDestroyColDisplay()
	end

	local nColDisplayTop = 58
	local nColDisplayLeft = 16
	if not bDockedOption then
		local nLeft, nTop, nRight, nBot = self.wndMain:GetAnchorOffsets()
		nColDisplayTop = nTop + 67
		nColDisplayLeft = nRight - 8
	end

	self.wndColDisplay = Apollo.LoadForm("GorynychLoreWindow.xml", "MainColArticleDisplay", bDockedOption and self.wndMain, self)
	self.wndColDisplay:SetData(wndOrigin)
	self.wndColDisplay:SetSizingMinimum(200, 200)
	self.wndColDisplay:SetSizingMaximum(1024, 768)
	self.wndColDisplay:SetAnchorOffsets(nColDisplayLeft, nColDisplayTop, nColDisplayLeft + self.wndColDisplay:GetWidth(), nColDisplayTop + self.wndColDisplay:GetHeight())
	self.wndColDisplay:FindChild("PlayPauseButton"):AttachWindow(self.wndColDisplay:FindChild("NowPlayingIcon"))
	self.wndColDisplay:FindChild("PlayPauseButton"):SetData(tArticleData)
	self.wndColDisplay:FindChild("ArticleText"):SetAML("<P Font=\"CRB_InterfaceMedium\" TextColor=\""..kclrDefault.."\">"..
	self:Translate(tArticleData.strText):gsub("\\n", "<T TextColor=\"0\">.</T></P><P Font=\"CRB_InterfaceMedium\" TextColor=\""..kclrDefault.."\">").."</P>")
	self.wndColDisplay:FindChild("ArticleText"):SetHeightToContentHeight()

	local bValidTBFAsset = tArticleData.eDatacubeType == DatacubeLib.DatacubeType_Chronicle and tArticleData.strAsset and string.len(tArticleData.strAsset) > 0
	local strWndNameToUse = tArticleData.eDatacubeType == DatacubeLib.DatacubeType_Datacube and "ArticleDatacubeTitle" or "ArticleNonDatacubeTitle"
	self.wndColDisplay:FindChild(strWndNameToUse):SetText(self:Translate(tArticleData.strTitle))
	self.wndColDisplay:FindChild("TalesLargeCoverArt"):SetSprite(bValidTBFAsset and tArticleData.strAsset or "")
	self.wndColDisplay:FindChild("TalesLargeCover"):Show(bValidTBFAsset)
	self.wndColDisplay:FindChild("PlayPauseButton"):Show(tArticleData.eDatacubeType == DatacubeLib.DatacubeType_Datacube)

	self.wndColDisplay:FindChild("ArticleScroll"):ArrangeChildrenVert(0)
	self.wndColDisplay:FindChild("ArticleScroll"):RecalculateContentExtents()
end

function GorynychLoreWindow:OnDestroyColDisplay(wndHandler, wndControl)
	if self.wndColDisplay and self.wndColDisplay:IsValid() then
		local wndOrigin = self.wndColDisplay:GetData()
		if wndOrigin and wndOrigin:IsValid() then
			wndOrigin:SetCheck(false)
		end
		self.wndColDisplay:Destroy()

		DatacubeLib.StopDatacubeSound()
		Event_FireGenericEvent("GenericEvent_Collections_StopDatacube") -- To turn off the HUD Alert
	end
end

function GorynychLoreWindow:OnPlayPauseCheck(wndHandler, wndControl)
	local tArticleData = wndHandler:GetData()
	DatacubeLib.PlayDatacubeSound(tArticleData.nDatacubeId)
	Event_FireGenericEvent("GenericEvent_Collections_DatacubePlayFromPL", tArticleData) -- For the HUD Alert
end

function GorynychLoreWindow:OnPlayPauseUncheck(wndHandler, wndControl)
	local tArticleData = wndHandler:GetData()
	self.nEndingArticleId = tArticleData.nDatacubeId

	DatacubeLib.StopDatacubeSound()
	Event_FireGenericEvent("GenericEvent_Collections_StopDatacube") -- To turn off the HUD Alert

	self.wndColDisplay:FindChild("PlayPauseButton"):Enable(false)
	Apollo.StartTimer("LoreWindow_DatacubeStoppingTimer")
end

function GorynychLoreWindow:OnDatacubeStopped()
	if self.wndColDisplay and self.wndColDisplay:IsValid() then
		self.wndColDisplay:FindChild("PlayPauseButton"):SetCheck(false)
	end
end

function GorynychLoreWindow:OnDatacubeTimer()
	if self.wndColDisplay and self.wndColDisplay:IsValid() then
		self.wndColDisplay:FindChild("PlayPauseButton"):Enable(true)
	end
end

-----------------------------------------------------------------------------------------------
-- Interaction
-----------------------------------------------------------------------------------------------

function GorynychLoreWindow:OnDropdownZoneBtn(wndHandler, wndControl) -- wndHandler is "DropdownZoneBtn" and its data is tCurrZone
	local tCurrZone = wndHandler:GetData()
	self.wndMain:FindChild("ColTopDropdownBtn"):SetCheck(false)
	self.wndMain:FindChild("ColTopDropdownBtn"):SetData(tCurrZone)
	self.wndMain:FindChild("ColTopDropdownBtn"):SetText(self:Translate(tCurrZone.strName))
	self:HelperDrawDropdownZoneProgress(self.wndMain:FindChild("ColTopZoneProgressContainer"), tCurrZone.nZoneId, tCurrZone.strName)

	self.wndMain:FindChild("ColMainScroll"):DestroyChildren()
	self:MainRedrawCollections()
	self:OnDestroyColDisplay()
end

function GorynychLoreWindow:OnColTopDropdownToggle(wndHandler, wndControl) -- ColTopDropdownBtn Zone Picker
	self.wndMain:FindChild("ColMainScroll"):Enable(not wndHandler:IsChecked())
end

function GorynychLoreWindow:OnColTopDropdownClosed(wndHandler, wndControl) -- ColTopDropdownBtn Zone Picker Window
	self.wndMain:FindChild("ColMainScroll"):Enable(true)
end

function GorynychLoreWindow:OnColHeaderToggle(wndHandler, wndControl) -- E.G. "Datacubes (1/6)"
	if wndHandler:IsChecked() then
		wndHandler:GetParent():FindChild("ColHeaderItems"):DestroyChildren()
		self:OnDestroyColDisplay()
	end
	self:MainRedrawCollections()
end

function GorynychLoreWindow:OnColBtnToSpawnReader(wndHandler, wndControl) -- ColDatacubeBtn, ColTalesBtn, ColJournalChildBtn
	self:SpawnAndDrawColReader(wndHandler:GetData(), wndHandler)
end

function GorynychLoreWindow:OnColBtnToDespawnReader(wndHandler, wndControl) -- ColDatacubeBtn, ColTalesBtn, ColJournalChildBtn, MainColArticleDisplay
	self:OnDestroyColDisplay()
end

function GorynychLoreWindow:OnMainNavGACheck(wndHandler, wndControl)
	self:OnDestroyColDisplay()
end

function GorynychLoreWindow:OnMainNavColCheck(wndHandler, wndControl)
	Event_FireGenericEvent("GenericEvent_CloseGAReader")
end

function GorynychLoreWindow:OnCompactLore()
	bDockedOption = not bDockedOption
end

-----------------------------------------------------------------------------------------------
-- Helpers
-----------------------------------------------------------------------------------------------

function GorynychLoreWindow:HelperDrawDropdownZoneProgress(wndCurr, idCurrZone, strCurrZoneName) -- wndCurr is "DropdownZoneItem" -- TODO: Refactor if possible
	local nTotalDatacubes = DatacubeLib.GetTotalDatacubesForZone(idCurrZone) or 0
	local nTotalJournals = DatacubeLib.GetTotalJournalsForZone(idCurrZone) or 0
	local nTotalTales = DatacubeLib.GetTotalTalesForZone(idCurrZone) or 0
	local nTotalSum = nTotalDatacubes + nTotalTales + nTotalJournals

	local nCurrent = 0
	for key, tCurrTable in pairs({ DatacubeLib.GetDatacubesForZone(idCurrZone), DatacubeLib.GetTalesForZone(idCurrZone), DatacubeLib.GetJournalsForZone(idCurrZone) }) do
		for key2, tCurrEntry in pairs(tCurrTable) do
			if tCurrEntry.bIsComplete then
				nCurrent = nCurrent + 1
			end
		end
	end

	if wndCurr:FindChild("ZoneProgressProgText") then
		wndCurr:FindChild("ZoneProgressProgText"):SetText(String_GetWeaselString(self:Translate(Apollo.GetString("Lore_TotalProgress")), nCurrent, nTotalSum))
		wndCurr:FindChild("ZoneProgressProgBar"):SetFullSprite("kitIProgBar_MetalInset_Fill" .. (nCurrent == nTotalSum and "Green" or "Blue"))
	end
	
	wndCurr:FindChild("ZoneProgressProgBar"):SetMax(nTotalSum)
	wndCurr:FindChild("ZoneProgressProgBar"):SetProgress(nCurrent)
	wndCurr:FindChild("ZoneProgressProgBar"):EnableGlow(nCurrent == nTotalSum)
	wndCurr:SetTooltip(string.format("<P Font=\"CRB_InterfaceSmall\" TextColor=\"ff31fcf6\">%s</P>", String_GetWeaselString(Apollo.GetString("Lore_ZoneProgress"), strCurrZoneName, nCurrent, nTotalSum)))
end

function GorynychLoreWindow:FactoryProduce(wndParent, strFormName, tObject)
	local wndNew = wndParent:FindChildByUserData(tObject)
	if not wndNew then
		wndNew = Apollo.LoadForm("GorynychLoreWindow.xml", strFormName, wndParent, self)
		wndNew:SetData(tObject)
	end
	return wndNew
end

local GorynychLoreWindowInst = GorynychLoreWindow:new()
GorynychLoreWindowInst:Init()
