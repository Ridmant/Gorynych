-----------------------------------------------------------------------------------------------
-- Client Lua Script for GorynychQuestLog
-- Copyright (c) NCsoft. All rights reserved
-----------------------------------------------------------------------------------------------

require "Window"
require "Quest"
require "QuestLib"
require "QuestCategory"
require "Unit"
require "Episode"
require "Money"

local GorynychQuestLog = {}

function GorynychQuestLog:new(o)
    o = o or {}
    setmetatable(o, self)
    self.__index = self
	self.ruTranslationQuestLog = {}
	o.arLeftTreeMap = {}

    return o
end

function GorynychQuestLog:Translate(str)
	local translationLib = Apollo.GetAddon("TranslationLib")
	if (translationLib ~= nil) then
		return translationLib:Traslate("RU", "QuestLog", str)
	end
	return str
end

function GorynychQuestLog:Init()
    Apollo.RegisterAddon(self)
end

--[[ Quest States, For Reference:
	QuestState_Unknown);
	QuestState_Accepted);	-- 1
	QuestState_Achieved);	-- 2
	QuestState_Completed);	-- 3
	QuestState_Botched);	-- 4
	QuestState_Mentioned); 	-- 5
	QuestState_Abandoned);	-- 6
	QuestState_Ignored);	-- 7
]]--

-- Constants
local ktConToUI =
{
	{ "CRB_Basekit:kitFixedProgBar_1", "ff9aaea3", Apollo.GetString("QuestLog_Trivial") },
	{ "CRB_Basekit:kitFixedProgBar_2", "ff37ff00", Apollo.GetString("QuestLog_Easy") },
	{ "CRB_Basekit:kitFixedProgBar_3", "ff46ffff", Apollo.GetString("QuestLog_Simple") },
	{ "CRB_Basekit:kitFixedProgBar_4", "ff3052fc", Apollo.GetString("QuestLog_Standard") },
	{ "CRB_Basekit:kitFixedProgBar_5", "ffffffff", Apollo.GetString("QuestLog_Average") },
	{ "CRB_Basekit:kitFixedProgBar_6", "ffffd400", Apollo.GetString("QuestLog_Moderate") },
	{ "CRB_Basekit:kitFixedProgBar_7", "ffff6a00", Apollo.GetString("QuestLog_Tough") },
	{ "CRB_Basekit:kitFixedProgBar_8", "ffff0000", Apollo.GetString("QuestLog_Hard") },
	{ "CRB_Basekit:kitFixedProgBar_9", "fffb00ff", Apollo.GetString("QuestLog_Impossible") }
}

local ktValidCallButtonStats =
{
	[Quest.QuestState_Ignored] 		= true,
	[Quest.QuestState_Achieved] 	= true,
	[Quest.QuestState_Abandoned] 	= true,
	[Quest.QuestState_Botched] 		= true,
	[Quest.QuestState_Mentioned] 	= true,
}

local kcrSelectedColor = ApolloColor.new("UI_BtnTextGoldListPressed")
local kcrDeselectedColor = ApolloColor.new("UI_BtnTextGoldListNormal")

local karEvalColors =
{
	[Item.CodeEnumItemQuality.Inferior] 		= ApolloColor.new("ItemQuality_Inferior"),
	[Item.CodeEnumItemQuality.Average] 			= ApolloColor.new("ItemQuality_Average"),
	[Item.CodeEnumItemQuality.Good] 			= ApolloColor.new("ItemQuality_Good"),
	[Item.CodeEnumItemQuality.Excellent] 		= ApolloColor.new("ItemQuality_Excellent"),
	[Item.CodeEnumItemQuality.Superb] 			= ApolloColor.new("ItemQuality_Superb"),
	[Item.CodeEnumItemQuality.Legendary] 		= ApolloColor.new("ItemQuality_Legendary"),
	[Item.CodeEnumItemQuality.Artifact]		 	= ApolloColor.new("ItemQuality_Artifact"),
}

function GorynychQuestLog:OnLoad()
	Apollo.RegisterEventHandler("ShowQuestLog", "Initialize", self)
	Apollo.RegisterEventHandler("Dialog_QuestShare", "OnDialog_QuestShare", self)
	Apollo.RegisterTimerHandler("ShareTimeout", "OnShareTimeout", self)

	self.xmlDoc = XmlDoc.CreateFromFile("GorynychQuestLog.xml") -- GorynychQuestLog will always be kept in memory, so save parsing it over and over
end

function GorynychQuestLog:Initialize()
	if (self.wndMain and self.wndMain:IsValid()) or not g_wndProgressLog then
		return
	end

	Apollo.RegisterEventHandler("EpisodeStateChanged", 			"DestroyAndRedraw", self) -- Not sure if this can be made stricter
	Apollo.RegisterEventHandler("QuestStateChanged", 			"OnQuestStateChanged", self) -- Routes to OnDestroyQuestObject if completed/botched
	Apollo.RegisterEventHandler("QuestObjectiveUpdated", 		"OnQuestObjectiveUpdated", self)
	Apollo.RegisterEventHandler("GenericEvent_ShowQuestLog", 	"OnGenericEvent_ShowQuestLog", self)
	Apollo.RegisterTimerHandler("RedrawQuestLogInOneSec", 		"DestroyAndRedraw", self) -- TODO Remove if possible

    self.wndMain = Apollo.LoadForm(self.xmlDoc, "GorynychQuestLogForm", g_wndProgressLog:FindChild("ContentWnd_1"), self)
	self.wndLeftFilterActive = self.wndMain:FindChild("LeftSideFilterBtnsBG:LeftSideFilterBtnShowActive")
	self.wndLeftFilterFinished = self.wndMain:FindChild("LeftSideFilterBtnsBG:LeftSideFilterBtnShowFinished")
	self.wndLeftFilterHidden = self.wndMain:FindChild("LeftSideFilterBtnsBG:LeftSideFilterBtnShowHidden")

	-- Variables
	self.wndLastBottomLevelBtnSelection = nil -- Just for button pressed state faking of text color
	self.nQuestCountMax = QuestLib.GetMaxCount()

	-- Default states
	self.wndLeftFilterActive:SetCheck(true)
	self.wndMain:FindChild("QuestAbandonPopoutBtn"):AttachWindow(self.wndMain:FindChild("QuestAbandonConfirm"))
	self.wndMain:FindChild("QuestInfoMoreInfoToggleBtn"):AttachWindow(self.wndMain:FindChild("QuestInfoMoreInfoTextBG"))
	self.wndMain:FindChild("EpisodeSummaryExpandBtn"):AttachWindow(self.wndMain:FindChild("EpisodeSummaryPopoutTextBG"))

	-- Measure Windows
	local wndMeasure = Apollo.LoadForm(self.xmlDoc, "TopLevelItem", nil, self)
	self.knTopLevelHeight = wndMeasure:GetHeight()
	wndMeasure:Destroy()

	wndMeasure = Apollo.LoadForm(self.xmlDoc, "MiddleLevelItem", nil, self)
	self.knMiddleLevelHeight = wndMeasure:GetHeight()
	wndMeasure:Destroy()

	wndMeasure = Apollo.LoadForm(self.xmlDoc, "BottomLevelItem", nil, self)
	self.knBottomLevelHeight = wndMeasure:GetHeight()
	wndMeasure:Destroy()

	wndMeasure = Apollo.LoadForm(self.xmlDoc, "ObjectivesItem", nil, self)
	self.knObjectivesItemHeight = wndMeasure:GetHeight()
	wndMeasure:Destroy()

	self.knRewardRecListHeight = self.wndMain:FindChild("QuestInfoRewardRecFrame"):GetHeight()
	self.knRewardChoListHeight = self.wndMain:FindChild("QuestInfoRewardChoFrame"):GetHeight()
	self.knMoreInfoHeight = self.wndMain:FindChild("QuestInfoMoreInfoFrame"):GetHeight()
	self.knEpisodeInfoHeight = self.wndMain:FindChild("EpisodeInfo"):GetHeight()

	self:DestroyAndRedraw()
end

function GorynychQuestLog:OnGenericEvent_ShowQuestLog(queTarget)
	if not queTarget then
		return
	end

	self.wndLeftFilterActive:SetCheck(true)
	self.wndLeftFilterHidden:SetCheck(false)
	self.wndLeftFilterFinished:SetCheck(false)
	self.wndMain:FindChild("LeftSideScroll"):DestroyChildren()

	local qcTop = queTarget:GetCategory()
	local epiMid = queTarget:GetEpisode()

	self:RedrawLeftTree() -- Add categories

	if qcTop then
		local strCategoryKey = "C"..qcTop:GetId()
		local wndTop = self.wndMain:FindChild("LeftSideScroll"):FindChildByUserData(strCategoryKey)
		if wndTop then
			wndTop:FindChild("TopLevelBtn"):SetCheck(true)
			self:RedrawLeftTree() -- Add episodes

			if epiMid then
				local strEpisodeKey = strCategoryKey.."E"..epiMid:GetId()
				local wndMiddle = wndTop:FindChild("TopLevelItems"):FindChildByUserData(strEpisodeKey)
				if wndMiddle then
					wndMiddle:FindChild("MiddleLevelBtn"):SetCheck(true)
					self:RedrawLeftTree() -- Add quests

					local strQuestKey = strEpisodeKey.."Q"..queTarget:GetId()
					local wndBot = wndMiddle:FindChild("MiddleLevelItems"):FindChildByUserData(strQuestKey)
					if wndBot then
						wndBot:FindChild("BottomLevelBtn"):SetCheck(true)
						self:OnBottomLevelBtnCheck(wndBot:FindChild("BottomLevelBtn"), wndBot:FindChild("BottomLevelBtn"))
					end
				end
			end
		end
	end

	self:ResizeTree()
	self:RedrawRight()
end

function GorynychQuestLog:DestroyAndRedraw() -- TODO, remove as much as possible that calls this
	if self.wndMain and self.wndMain:IsValid() then
		self.wndMain:FindChild("LeftSideScroll"):DestroyChildren()
		self.wndMain:FindChild("LeftSideScroll"):SetVScrollPos(0)
	end

	self.arLeftTreeMap = {}

	self:RedrawLeftTree()-- Add categories

	-- Show first in Quest Log
	local wndTop = self.wndMain:FindChild("LeftSideScroll"):GetChildren()[1]
	if wndTop then
		wndTop:FindChild("TopLevelBtn"):SetCheck(true)
		self:RedrawLeftTree() -- Add episodes

		local wndMiddle = wndTop:FindChild("TopLevelItems"):GetChildren()[1]
		if wndMiddle then
			wndMiddle:FindChild("MiddleLevelBtn"):SetCheck(true)
			self:RedrawLeftTree() --Add quests

			local wndBot = wndMiddle:FindChild("MiddleLevelItems"):GetChildren()[1]
			if wndBot then
				wndBot:FindChild("BottomLevelBtn"):SetCheck(true)
				self:OnBottomLevelBtnCheck(wndBot:FindChild("BottomLevelBtn"), wndBot:FindChild("BottomLevelBtn"))
			end
		end
	end

	self:ResizeTree()
	self:RedrawRight()
end

function GorynychQuestLog:RedrawLeftTreeFromUI()
	self:RedrawLeftTree()
	self:ResizeTree()
end

function GorynychQuestLog:RedrawFromUI()
	self:RedrawEverything()
end

function GorynychQuestLog:RedrawEverything()
	self:RedrawLeftTree()
	self:ResizeTree()

	local bLeftSideHasResults = #self.wndMain:FindChild("LeftSideScroll"):GetChildren() ~= 0
	self.wndMain:FindChild("LeftSideScroll"):SetText(bLeftSideHasResults and "" or self:Translate(Apollo.GetString("QuestLog_NoResults")))
	self.wndMain:FindChild("QuestInfoControls"):Show(bLeftSideHasResults)
	self.wndMain:FindChild("RightSide"):Show(bLeftSideHasResults)

	if self.wndMain:FindChild("RightSide"):IsShown() and self.wndMain:FindChild("RightSide"):GetData() then
		self:DrawRightSide(self.wndMain:FindChild("RightSide"):GetData())
	end

	self:ResizeRight()
end

function GorynychQuestLog:RedrawRight()
	local bLeftSideHasResults = #self.wndMain:FindChild("LeftSideScroll"):GetChildren() ~= 0
	self.wndMain:FindChild("LeftSideScroll"):SetText(bLeftSideHasResults and "" or Apollo.GetString("QuestLog_NoResults"))
	self.wndMain:FindChild("QuestInfoControls"):Show(bLeftSideHasResults)
	self.wndMain:FindChild("RightSide"):Show(bLeftSideHasResults)

	if self.wndMain:FindChild("RightSide"):IsShown() and self.wndMain:FindChild("RightSide"):GetData() then
		self:DrawRightSide(self.wndMain:FindChild("RightSide"):GetData())
	end

	self:ResizeRight()
end

function GorynychQuestLog:RedrawLeftTree()
	local nQuestCount = QuestLib.GetCount()
	local strColor = "UI_BtnTextGreenNormal"
	if nQuestCount + 3 >= self.nQuestCountMax then
		strColor = "ffff0000"
	elseif nQuestCount + 10 >= self.nQuestCountMax then
		strColor = "ffffb62e"
	end

	local strActiveQuests = string.format("<T TextColor=\"%s\">%s</T>", strColor, nQuestCount)
	strActiveQuests = String_GetWeaselString(self:Translate(Apollo.GetString("QuestLog_ActiveQuests")), strActiveQuests, self.nQuestCountMax)
	self.wndMain:FindChild("QuestLogCountText"):SetAML(string.format("<P Font=\"CRB_InterfaceTiny_BB\" Align=\"Left\" TextColor=\"ffffffff\">%s</P>", strActiveQuests))

	local tCategoryEpisodeHaveQuestsCache = {}
	local tCategoryHaveQuestsCache = {}

	local fnDoesCategoryEpisodeHaveQuests = function(qcCategory, epiEpisode)
		local strEpisodeKey = "C"..qcCategory:GetId().."E"..epiEpisode:GetId()
		if tCategoryEpisodeHaveQuestsCache[strEpisodeKey] ~= nil then
			return tCategoryEpisodeHaveQuestsCache[strEpisodeKey]
		end

		for idx, queQuest in pairs(epiEpisode:GetAllQuests(qcCategory:GetId())) do
			if self:CheckLeftSideFilters(queQuest) then
				tCategoryEpisodeHaveQuestsCache[strEpisodeKey] = true
				return true
			end
		end
		tCategoryEpisodeHaveQuestsCache[strEpisodeKey] = false
		return false
	end

	local fnDoesCategoryHaveQuests = function(qcCategory)
		local strCategoryKey = "C"..qcCategory:GetId()
		if tCategoryHaveQuestsCache[strCategoryKey] ~= nil then
			return tCategoryHaveQuestsCache[strCategoryKey]
		end

		for idx, epiEpisode in pairs(qcCategory:GetEpisodes()) do
			if fnDoesCategoryEpisodeHaveQuests(qcCategory, epiEpisode) then
				tCategoryHaveQuestsCache[strCategoryKey] = true
				return true
			end
		end
		tCategoryHaveQuestsCache[strCategoryKey] = false
		return false
	end

	local wndLeftSideScroll = self.wndMain:FindChild("LeftSideScroll")
	for idx1, qcCategory in pairs(QuestLib.GetKnownCategories()) do
		if fnDoesCategoryHaveQuests(qcCategory) then
			local strCategoryKey = "C"..qcCategory:GetId()
			local wndTop = self:FactoryProduce(wndLeftSideScroll, "TopLevelItem", strCategoryKey)
			self:HelperSetupTopLevelWindow(wndTop, qcCategory)

			if wndTop:FindChild("TopLevelBtn"):IsChecked() then
				local wndTopLevelItems = wndTop:FindChild("TopLevelItems")
				for idx2, epiEpisode in pairs(qcCategory:GetEpisodes()) do
					if fnDoesCategoryEpisodeHaveQuests(qcCategory, epiEpisode) then
						local strEpisodeKey = strCategoryKey.."E"..epiEpisode:GetId()
						local wndMiddle = self:FactoryProduce(wndTopLevelItems, "MiddleLevelItem", strEpisodeKey)
						self:HelperSetupMiddleLevelWindow(wndMiddle, epiEpisode)

						if wndMiddle:FindChild("MiddleLevelBtn"):IsChecked() then
							local wndMiddleLevelItems = wndMiddle:FindChild("MiddleLevelItems")
							for idx3, queQuest in pairs(epiEpisode:GetAllQuests(qcCategory:GetId())) do
								if self:CheckLeftSideFilters(queQuest) then
									local strQuestKey = strEpisodeKey.."Q"..queQuest:GetId()
									local wndBot = self:FactoryProduce(wndMiddleLevelItems, "BottomLevelItem", strQuestKey)
									self:HelperSetupBottomLevelWindow(wndBot, queQuest)
								end
							end
						end
					end
				end
			end
		end
	end
end

function GorynychQuestLog:HelperSetupTopLevelWindow(wndTop, qcCategory)
	wndTop:FindChild("TopLevelBtnText"):SetText(self:Translate(qcCategory:GetTitle()))
end

function GorynychQuestLog:HelperSetupMiddleLevelWindow(wndMiddle, epiEpisode)
	local tEpisodeProgress = epiEpisode:GetProgress()
	local wndMiddleLevelIcon = wndMiddle:FindChild("MiddleLevelIcon")
	wndMiddle:FindChild("MiddleLevelProgBar"):SetMax(tEpisodeProgress.nTotal)
	wndMiddle:FindChild("MiddleLevelProgBar"):SetProgress(tEpisodeProgress.nCompleted)
	wndMiddle:FindChild("MiddleLevelBtnText"):SetText(self:Translate(epiEpisode:GetTitle()))
	wndMiddleLevelIcon:SetTooltip(self.wndLeftFilterFinished:IsChecked() and "" or Apollo.GetString("QuestLog_MoreQuestsToComplete"))
	wndMiddleLevelIcon:SetSprite(self.wndLeftFilterFinished:IsChecked() and "kitIcon_Holo_Checkbox" or "kitIcon_Holo_Exclamation")
end

function GorynychQuestLog:HelperSetupBottomLevelWindow(wndBot, queQuest)
	local wndBottomLevelBtn = wndBot:FindChild("BottomLevelBtn")
	local wndBottomLevelBtnText = wndBot:FindChild("BottomLevelBtnText")

	wndBottomLevelBtn:SetData(queQuest)
	wndBottomLevelBtnText:SetText(self:Translate(queQuest:GetTitle()))
	wndBottomLevelBtnText:SetTextColor(wndBottomLevelBtn:IsChecked() and kcrSelectedColor or kcrDeselectedColor)

	local strBottomLevelIconSprite = ""
	local bHasCall = queQuest:GetContactInfo()
	local eState = queQuest:GetState()
	if eState == Quest.QuestState_Botched then
		strBottomLevelIconSprite = "CRB_Basekit:kitIcon_Metal_CircleX"
	elseif eState == Quest.QuestState_Abandoned or eState == Quest.QuestState_Mentioned then
		strBottomLevelIconSprite = "CRB_Basekit:kitIcon_Metal_CircleExclamation"
	elseif eState == Quest.QuestState_Achieved and bHasCall then
		strBottomLevelIconSprite = "CRB_Basekit:kitIcon_Metal_CircleCheckmarkAccent"
	elseif eState == Quest.QuestState_Achieved and not bHasCall then
		strBottomLevelIconSprite = "CRB_Basekit:kitIcon_Metal_CircleCheckmark"
	end
	wndBot:FindChild("BottomLevelBtnIcon"):SetSprite(strBottomLevelIconSprite)
end

function GorynychQuestLog:ResizeTree()
	local wndDeepestSelected = nil

	local wndLeftSideScroll = self.wndMain:FindChild("LeftSideScroll")
	for idx1, wndTop in pairs(wndLeftSideScroll:GetChildren()) do
		local wndTopLevelBtn = wndTop:FindChild("TopLevelBtn")
		local wndTopLevelItems = wndTop:FindChild("TopLevelItems")

		if wndTopLevelBtn:IsChecked() then
			wndDeepestSelected = wndTop
			for idx2, wndMiddle in pairs(wndTopLevelItems:GetChildren()) do
				local wndMiddleLevelItems = wndMiddle:FindChild("MiddleLevelItems")

				if not wndMiddle:FindChild("MiddleLevelBtn"):IsChecked() then
					wndMiddleLevelItems:DestroyChildren()
				else
					wndDeepestSelected = wndMiddle
				end

				for idx3, wndBot in pairs(wndMiddleLevelItems:GetChildren()) do -- Resize if too long
					local wndBottomLevelBtnText = wndBot:FindChild("BottomLevelBtn:BottomLevelBtnText")
					if Apollo.GetTextWidth("CRB_InterfaceMedium_B", wndBottomLevelBtnText:GetText()) > wndBottomLevelBtnText:GetWidth() then
						local nBottomLeft, nBottomTop, nBottomRight, nBottomBottom = wndBot:GetAnchorOffsets()
						wndBot:SetAnchorOffsets(nBottomLeft, nBottomTop, nBottomRight, nBottomTop + (self.knBottomLevelHeight * 1.5))
						-- our resize code that happens later will account for this
					end

					if wndBot:FindChild("BottomLevelBtn"):IsChecked() then
						wndDeepestSelected = wndBot
					end
				end

				local nItemHeights = wndMiddleLevelItems:ArrangeChildrenVert(0)
				if nItemHeights > 0 then
					nItemHeights = nItemHeights + 15
				end

				local nMiddleLeft, nMiddleTop, nMiddleRight, nMiddleBottom = wndMiddle:GetAnchorOffsets()
				wndMiddle:SetAnchorOffsets(nMiddleLeft, nMiddleTop, nMiddleRight, nMiddleTop + self.knMiddleLevelHeight + nItemHeights)
			end
		else
			wndTopLevelItems:DestroyChildren()
		end
		wndTopLevelItems:SetSprite(wndTopLevelBtn:IsChecked() and "kitInnerFrame_MetalGold_FrameBright2" or "kitInnerFrame_MetalGold_FrameDull")

		local nItemHeights = wndTopLevelItems:ArrangeChildrenVert(0, function(a,b) return a:GetData() > b:GetData() end) -- Tasks to bottom
		if nItemHeights > 0 then
			nItemHeights = nItemHeights + 20
		end

		local nTopLeft, nTopTop, nTopRight, nTopBottom = wndTop:GetAnchorOffsets()
		wndTop:SetAnchorOffsets(nTopLeft, nTopTop, nTopRight, nTopTop + self.knTopLevelHeight + nItemHeights)
	end

	wndLeftSideScroll:ArrangeChildrenVert(0)
	wndLeftSideScroll:RecalculateContentExtents()

	if wndDeepestSelected ~= nil then
		wndLeftSideScroll:EnsureChildVisible(wndDeepestSelected)
	end
end

function GorynychQuestLog:ResizeRight()
	local nWidth, nHeight, nLeft, nTop, nRight, nBottom

	-- Objectives Content
	for key, wndObj in pairs(self.wndMain:FindChild("QuestInfoObjectivesList"):GetChildren()) do
		nWidth, nHeight = wndObj:FindChild("ObjectivesItemText"):SetHeightToContentHeight()
		nHeight = wndObj:FindChild("QuestProgressItem") and nHeight + wndObj:FindChild("QuestProgressItem"):GetHeight() or nHeight
		nLeft, nTop, nRight, nBottom = wndObj:GetAnchorOffsets()
		wndObj:SetAnchorOffsets(nLeft, nTop, nRight, nTop + math.max(self.knObjectivesItemHeight, nHeight + 8)) -- TODO: Hardcoded formatting of text pad
	end

	-- Objectives Frame
	nHeight = self.wndMain:FindChild("QuestInfoObjectivesList"):ArrangeChildrenVert(0)
	nLeft, nTop, nRight, nBottom = self.wndMain:FindChild("QuestInfoObjectivesFrame"):GetAnchorOffsets()
	self.wndMain:FindChild("QuestInfoObjectivesFrame"):SetAnchorOffsets(nLeft, nTop, nRight, nTop + nHeight + 30)
	self.wndMain:FindChild("QuestInfoObjectivesFrame"):Show(#self.wndMain:FindChild("QuestInfoObjectivesList"):GetChildren() > 0)

	-- Rewards Recevived
	nHeight = self.wndMain:FindChild("QuestInfoRewardRecList"):ArrangeChildrenVert(0)
	nLeft, nTop, nRight, nBottom = self.wndMain:FindChild("QuestInfoRewardRecFrame"):GetAnchorOffsets()
	self.wndMain:FindChild("QuestInfoRewardRecFrame"):SetAnchorOffsets(nLeft, nTop, nRight, nTop + nHeight + self.knRewardRecListHeight)
	self.wndMain:FindChild("QuestInfoRewardRecFrame"):Show(#self.wndMain:FindChild("QuestInfoRewardRecList"):GetChildren() > 0)

	-- Rewards to Choose
	nHeight = self.wndMain:FindChild("QuestInfoRewardChoList"):ArrangeChildrenVert(0, function(a,b) return b:FindChild("RewardItemCantUse"):IsShown() end)
	nLeft, nTop, nRight, nBottom = self.wndMain:FindChild("QuestInfoRewardChoFrame"):GetAnchorOffsets()
	self.wndMain:FindChild("QuestInfoRewardChoFrame"):SetAnchorOffsets(nLeft, nTop, nRight, nTop + nHeight + self.knRewardChoListHeight)
	self.wndMain:FindChild("QuestInfoRewardChoFrame"):Show(#self.wndMain:FindChild("QuestInfoRewardChoList"):GetChildren() > 0)

	-- More Info
	nHeight = 0
	if self.wndMain:FindChild("QuestInfoMoreInfoToggleBtn"):IsChecked() then
		nWidth, nHeight = self.wndMain:FindChild("QuestInfoMoreInfoText"):SetHeightToContentHeight()
		nHeight = nHeight + 32
	end
	nLeft, nTop, nRight, nBottom = self.wndMain:FindChild("QuestInfoMoreInfoFrame"):GetAnchorOffsets()
	self.wndMain:FindChild("QuestInfoMoreInfoFrame"):SetAnchorOffsets(nLeft, nTop, nRight, nTop + nHeight + self.knMoreInfoHeight)

	-- Episode Summary
	nHeight = 0
	if self.wndMain:FindChild("EpisodeSummaryExpandBtn"):IsChecked() then
		nWidth, nHeight = self.wndMain:FindChild("EpisodeSummaryPopoutText"):SetHeightToContentHeight()
	end
	nLeft, nTop, nRight, nBottom = self.wndMain:FindChild("EpisodeInfo"):GetAnchorOffsets()
	if self.wndMain:FindChild("EpisodeInfo"):IsShown() then
		self.wndMain:FindChild("EpisodeInfo"):SetAnchorOffsets(nLeft, nTop, nRight, nTop + nHeight + self.knEpisodeInfoHeight)
	else
		self.wndMain:FindChild("EpisodeInfo"):SetAnchorOffsets(nLeft, nTop, nRight, nTop)
	end

	-- Resize
	local nLeft, nTop, nRight, nBottom = self.wndMain:FindChild("QuestInfo"):GetAnchorOffsets()
	self.wndMain:FindChild("QuestInfo"):SetAnchorOffsets(nLeft, nTop, nRight, nTop + self.wndMain:FindChild("QuestInfo"):ArrangeChildrenVert(0))

	self.wndMain:FindChild("RightSide"):ArrangeChildrenVert(0)
	self.wndMain:FindChild("RightSide"):RecalculateContentExtents()
end

-----------------------------------------------------------------------------------------------
-- Draw Quest Info
-----------------------------------------------------------------------------------------------

function GorynychQuestLog:DrawRightSide(queSelected)
	local wndRight = self.wndMain:FindChild("RightSide")
	local eQuestState = queSelected:GetState()

	-- Text Summary
	local strQuestSummary = ""
	if eQuestState == Quest.QuestState_Completed and string.len(queSelected:GetCompletedSummary()) > 0 then
		strQuestSummary = queSelected:GetCompletedSummary()
	elseif string.len(queSelected:GetSummary()) > 0 then
		strQuestSummary = queSelected:GetSummary()
	end

	local nDifficulty = queSelected:GetColoredDifficulty() or 0
	if eQuestState == Quest.QuestState_Completed then
		wndRight:FindChild("QuestInfoTitleIcon"):SetTooltip(Apollo.GetString("QuestLog_HasBeenCompleted"))
		wndRight:FindChild("QuestInfoTitleIcon"):SetSprite("CRB_Basekit:kitIcon_Green_Checkmark")
		wndRight:FindChild("QuestInfoTitle"):SetText(String_GetWeaselString(self:Translate(Apollo.GetString("QuestLog_Completed")), self:Translate(queSelected:GetTitle())))
		wndRight:FindChild("QuestInfoTitle"):SetTextColor(ApolloColor.new("ff7fffb9"))
	else
		if eQuestState == Quest.QuestState_Achieved then
			wndRight:FindChild("QuestInfoTitleIcon"):SetTooltip(Apollo.GetString("QuestLog_QuestReadyToTurnIn"))
			wndRight:FindChild("QuestInfoTitleIcon"):SetSprite("CRB_Basekit:kitIcon_Green_Checkmark")
		else
			wndRight:FindChild("QuestInfoTitleIcon"):SetTooltip(Apollo.GetString("QuestLog_ObjectivesNotComplete"))
			wndRight:FindChild("QuestInfoTitleIcon"):SetSprite("CRB_Basekit:kitIcon_Gold_Checkbox")
		end

		local tConData = ktConToUI[nDifficulty]
		if tConData then
			local strDifficulty = "<T Font=\"CRB_InterfaceMedium\" TextColor=\"" .. tConData[2] .. "\"> " .. tConData[3] .. "</T>"
			wndRight:FindChild("QuestInfoTitle"):SetText(self:Translate(queSelected:GetTitle()))
			wndRight:FindChild("QuestInfoDifficultyPic"):SetSprite(tConData[1])
			wndRight:FindChild("QuestInfoDifficultyPic"):SetTooltip(String_GetWeaselString(Apollo.GetString("QuestLog_IntendedLevel"), queSelected:GetTitle(), queSelected:GetConLevel()))

			wndRight:FindChild("QuestInfoDifficultyText"):SetAML("<P Font=\"CRB_InterfaceMedium_BB\" TextColor=\"ff7fffb9\">" .. String_GetWeaselString(self:Translate(Apollo.GetString("QuestLog_Difficulty")), strDifficulty) .. "</P>")
			wndRight:FindChild("QuestInfoTitle"):SetTextColor(ApolloColor.new("white"))
		end
	end

	local tConData = ktConToUI[nDifficulty]
	if tConData then
		local strDifficulty = "<T Font=\"CRB_InterfaceMedium\" TextColor=\"" .. tConData[2] .. "\"> " .. tConData[3] .. "</T>"
		wndRight:FindChild("QuestInfoTitle"):SetText(self:Translate(queSelected:GetTitle()))
		wndRight:FindChild("QuestInfoDifficultyPic"):SetSprite(tConData[1])
		wndRight:FindChild("QuestInfoDifficultyPic"):SetTooltip(String_GetWeaselString(Apollo.GetString("QuestLog_IntendedLevel"), queSelected:GetTitle(), queSelected:GetConLevel()))

		wndRight:FindChild("QuestInfoDifficultyText"):SetAML("<P Font=\"CRB_InterfaceMedium_B\" TextColor=\"ff7fffb9\">" .. String_GetWeaselString(self:Translate(Apollo.GetString("QuestLog_Difficulty")), strDifficulty) .. "</P>")
		wndRight:FindChild("QuestInfoTitle"):SetTextColor(ApolloColor.new("white"))
	end

	wndRight:FindChild("QuestInfoDescriptionText"):SetAML("<P Font=\"CRB_InterfaceMedium\" TextColor=\"ff56b381\">"..self:Translate(strQuestSummary).."</P>")
	wndRight:FindChild("QuestInfoDescriptionText"):SetHeightToContentHeight()

	-- Episode Summary
	local epiParent = queSelected:GetEpisode()
	local bIsTasks = epiParent:GetId() == 1
	--local nEpisodeMax, nEpisodeProgress = epiParent:GetProgress()
	local tEpisodeProgress = epiParent:GetProgress()
	local strEpisodeDesc = ""
	if not bIsTasks then
		if epiParent:GetState() == Episode.EpisodeState_Complete then
			strEpisodeDesc = epiParent:GetSummary()
		else
			strEpisodeDesc = epiParent:GetDesc()
		end
	end

	wndRight:FindChild("EpisodeSummaryTitle"):SetText(self:Translate(epiParent:GetTitle()))
	wndRight:FindChild("EpisodeSummaryProgText"):SetAML(string.format("<P Font=\"CRB_HeaderTiny\" Align=\"Center\">"..
	"(<T Font=\"CRB_HeaderTiny\" Align=\"Center\">%s</T>/%s)</P>", tEpisodeProgress.nCompleted, tEpisodeProgress.nTotal))
	wndRight:FindChild("EpisodeSummaryPopoutText"):SetAML("<P Font=\"CRB_InterfaceMedium\" TextColor=\"ff2f94ac\">"..self:Translate(strEpisodeDesc).."</P>")
	wndRight:FindChild("EpisodeSummaryPopoutText"):SetHeightToContentHeight()
	wndRight:FindChild("EpisodeSummaryExpandBtn"):Enable(not bIsTasks)

	-- More Info
	local strMoreInfo = ""
	local tMoreInfoText = queSelected:GetMoreInfoText()
	if #tMoreInfoText > 0 and self.wndMain:FindChild("QuestInfoMoreInfoToggleBtn"):IsChecked() then
		for idx, tValues in pairs(tMoreInfoText) do
			if string.len(tValues.strSay) > 0 or string.len(tValues.strResponse) > 0 then
				strMoreInfo = strMoreInfo .. "<P Font=\"CRB_InterfaceMedium_I\" TextColor=\"ff7fffb9\">"..self:Translate(tValues.strSay).."</P>"
				strMoreInfo = strMoreInfo .. "<P Font=\"CRB_InterfaceMedium_I\" TextColor=\"ff56b381\">"..self:Translate(tValues.strResponse).."</P>"
				if idx ~= #tMoreInfoText then
					strMoreInfo = strMoreInfo .. "<P TextColor=\"0\">.</P>"
				end
			end
		end
	else
		wndRight:FindChild("QuestInfoMoreInfoToggleBtn"):SetCheck(false)
	end
	wndRight:FindChild("QuestInfoMoreInfoText"):SetAML(strMoreInfo)
	wndRight:FindChild("QuestInfoMoreInfoText"):SetHeightToContentHeight()
	wndRight:FindChild("QuestInfoMoreInfoFrame"):Show(#tMoreInfoText > 0)

	-- Objectives
	wndRight:FindChild("QuestInfoObjectivesList"):DestroyChildren()
	if eQuestState == Quest.QuestState_Achieved then
		local wndObj = Apollo.LoadForm(self.xmlDoc, "ObjectivesItem", wndRight:FindChild("QuestInfoObjectivesList"), self)
		local strAchieved = string.format("<T Font=\"CRB_InterfaceMedium\" TextColor=\"ffffffff\">%s</T>", self:Translate(queSelected:GetCompletionObjectiveText()))
		wndObj:FindChild("ObjectivesItemText"):SetAML(strAchieved)
		wndRight:FindChild("QuestInfoObjectivesTitle"):SetText(self:Translate(Apollo.GetString("QuestLog_ReadyToTurnIn")))
	elseif eQuestState == Quest.QuestState_Completed then
		for key, tObjData in pairs(queSelected:GetVisibleObjectiveData()) do
			if tObjData.nCompleted < tObjData.nNeeded then
				local wndObj = Apollo.LoadForm(self.xmlDoc, "ObjectivesItem", wndRight:FindChild("QuestInfoObjectivesList"), self)
				wndObj:FindChild("ObjectivesItemText"):SetAML(self:HelperBuildObjectiveTitleString(queSelected, tObjData))
				self:HelperBuildObjectiveProgBar(queSelected, tObjData, wndObj, true)
				wndObj:FindChild("ObjectiveBullet"):SetSprite("CRB_Basekit:kitIcon_Holo_Checkmark")
				wndObj:FindChild("ObjectiveBullet"):SetBGColor("ffffff00")
			end
		end
		wndRight:FindChild("QuestInfoObjectivesTitle"):SetText(self:Translate(Apollo.GetString("QuestLog_CompletedObjectives")))
	elseif eQuestState ~= Quest.QuestState_Mentioned then
		for key, tObjData in pairs(queSelected:GetVisibleObjectiveData()) do
			if tObjData.nCompleted < tObjData.nNeeded then
				local wndObj = Apollo.LoadForm(self.xmlDoc, "ObjectivesItem", wndRight:FindChild("QuestInfoObjectivesList"), self)
				wndObj:FindChild("ObjectivesItemText"):SetAML(self:HelperBuildObjectiveTitleString(queSelected, tObjData))
				self:HelperBuildObjectiveProgBar(queSelected, tObjData, wndObj)
			end
		end
		wndRight:FindChild("QuestInfoObjectivesTitle"):SetText(self:Translate(Apollo.GetString("QuestLog_Objectives")))
	end

	-- Rewards Received
	local tRewardInfo = queSelected:GetRewardData()
	wndRight:FindChild("QuestInfoRewardRecList"):DestroyChildren()
	for key, tReward in pairs(tRewardInfo.arFixedRewards) do
		local wndReward = Apollo.LoadForm(self.xmlDoc, "RewardItem", wndRight:FindChild("QuestInfoRewardRecList"), self)
		self:HelperBuildRewardsRec(wndReward, tReward, true)
	end

	-- Rewards To Choose
	wndRight:FindChild("QuestInfoRewardChoList"):DestroyChildren()
	for key, tReward in pairs(tRewardInfo.arRewardChoices) do
		local wndReward = Apollo.LoadForm(self.xmlDoc, "RewardItem", wndRight:FindChild("QuestInfoRewardChoList"), self)
		self:HelperBuildRewardsRec(wndReward, tReward, false)
	end

	-- Special reward formatting for finished quests
	if eQuestState == Quest.QuestState_Completed then

		wndRight:FindChild("QuestInfoRewardRecTitle"):SetText(self:Translate(Apollo.GetString("QuestLog_YouReceived")))
		wndRight:FindChild("QuestInfoRewardChoTitle"):SetText(self:Translate(Apollo.GetString("QuestLog_YouChoseFrom")))
	else
		wndRight:FindChild("QuestInfoRewardRecTitle"):SetText(self:Translate(Apollo.GetString("QuestLog_WillReceive")))
		wndRight:FindChild("QuestInfoRewardChoTitle"):SetText(self:Translate(Apollo.GetString("QuestLog_CanChooseOne")))
	end

	-- Call Button
	if queSelected:GetContactInfo() and ktValidCallButtonStats[eQuestState] then
		local tContactInfo = queSelected:GetContactInfo()

		wndRight:FindChild("QuestInfoCallFrame"):Show(true)
		wndRight:FindChild("QuestInfoCostumeWindow"):SetCostumeToCreatureId(tContactInfo.idUnit)
		wndRight:FindChild("QuestInfoCallFrameText"):SetAML("<P Font=\"CRB_HeaderSmall\" TextColor=\"ff56b381\">" .. self:Translate(Apollo.GetString("QuestLog_ContactNPC")) .. "</P><P Font=\"CRB_HeaderSmall\">" .. self:Translate(tContactInfo.strName) .. "</P>")
	else
		wndRight:FindChild("QuestInfoCallFrame"):Show(false)
	end

	-- Bottom Buttons (outside of Scroll)
	self.wndMain:FindChild("QuestInfoControlsHideBtn"):Show(eQuestState == Quest.QuestState_Abandoned or eQuestState == Quest.QuestState_Mentioned)
	self.wndMain:FindChild("QuestInfoControlButtons"):Show(eQuestState == Quest.QuestState_Accepted or eQuestState == Quest.QuestState_Achieved or eQuestState == Quest.QuestState_Botched)
	if eQuestState ~= Quest.QuestState_Abandoned then
		local bCanShare = queSelected:CanShare()
		local bIsTracked = queSelected:IsTracked()
		self.wndMain:FindChild("QuestAbandonPopoutBtn"):Enable(queSelected:CanAbandon())
		self.wndMain:FindChild("QuestInfoControlsBGShare"):Show(bCanShare)
		self.wndMain:FindChild("QuestInfoControlsBGShare"):SetTooltip(bCanShare and Apollo.GetString("QuestLog_ShareQuest") or String_GetWeaselString(Apollo.GetString("QuestLog_ShareNotPossible"), Apollo.GetString("QuestLog_ShareQuest")))
		self.wndMain:FindChild("QuestTrackBtn"):Enable(eQuestState ~= Quest.QuestState_Botched)
		self.wndMain:FindChild("QuestTrackBtn"):SetText(bIsTracked and self:Translate(Apollo.GetString("QuestLog_Untrack")) or self:Translate(Apollo.GetString("QuestLog_Track")))
		self.wndMain:FindChild("QuestTrackBtn"):SetTooltip(bIsTracked and Apollo.GetString("QuestLog_RemoveFromTracker") or Apollo.GetString("QuestLog_AddToTracker"))
	end
	--self.wndMain:FindChild("QuestInfoControlButtons"):ArrangeChildrenHorz(1)

	-- Hide Pop Out CloseOnExternalClick windows
	self.wndMain:FindChild("QuestAbandonConfirm"):Show(false)
end

function GorynychQuestLog:OnTopLevelBtnCheck(wndHandler, wndControl)
	self:RedrawLeftTree()
	self:ResizeTree()
end

function GorynychQuestLog:OnTopLevelBtnUncheck(wndHandler, wndControl)
	self:ResizeTree()
end

function GorynychQuestLog:OnMiddleLevelBtnCheck(wndHandler, wndControl)
	wndHandler:SetCheck(true)
	self:RedrawLeftTree()
	self:ResizeTree()

	local wndBot = wndHandler:GetParent():FindChild("MiddleLevelItems"):GetChildren()[1] -- TODO hack
	if wndBot then
		wndBot:FindChild("BottomLevelBtn"):SetCheck(true)
		self:OnBottomLevelBtnCheck(wndBot:FindChild("BottomLevelBtn"), wndBot:FindChild("BottomLevelBtn"))
	end
end

function GorynychQuestLog:OnMiddleLevelBtnUncheck(wndHandler, wndControl)
	self:ResizeTree()
end

function GorynychQuestLog:OnBottomLevelBtnCheck(wndHandler, wndControl) -- From Button or OnQuestObjectiveUpdated
	-- Text Coloring
	if self.wndLastBottomLevelBtnSelection and self.wndLastBottomLevelBtnSelection:IsValid() then
		self.wndLastBottomLevelBtnSelection:FindChild("BottomLevelBtn:BottomLevelBtnText"):SetTextColor(kcrDeselectedColor)
	end

	wndHandler:FindChild("BottomLevelBtnText"):SetTextColor(kcrSelectedColor)
	self.wndLastBottomLevelBtnSelection = wndHandler

	self.wndMain:FindChild("RightSide"):Show(true)
	self.wndMain:FindChild("RightSide"):SetVScrollPos(0)
	self.wndMain:FindChild("RightSide"):RecalculateContentExtents()
	self.wndMain:FindChild("RightSide"):SetData(wndHandler:GetData())
	self:RedrawRight()
end

function GorynychQuestLog:OnBottomLevelBtnUncheck(wndHandler, wndControl)
	wndHandler:FindChild("BottomLevelBtnText"):SetTextColor(kcrDeselectedColor)
	self.wndMain:FindChild("QuestInfoControls"):Show(false)
	self.wndMain:FindChild("RightSide"):Show(false)
end

function GorynychQuestLog:OnBottomLevelBtnDown( wndHandler, wndControl, eMouseButton )
	if eMouseButton == GameLib.CodeEnumInputMouse.Right and Apollo.IsShiftKeyDown() then
		Event_FireGenericEvent("GenericEvent_QuestLink", wndControl:GetParent():FindChild("BottomLevelBtn"):GetData())
	end
end

-----------------------------------------------------------------------------------------------
-- Bottom Buttons and Quest Update Events
-----------------------------------------------------------------------------------------------

function GorynychQuestLog:OnQuestTrackBtn(wndHandler, wndControl) -- QuestTrackBtn
	local queSelected = self.wndMain:FindChild("RightSide"):GetData()
	local bNewTrackValue = not queSelected:IsTracked()
	queSelected:SetTracked(bNewTrackValue)
	self.wndMain:FindChild("QuestTrackBtn"):SetText(bNewTrackValue and self:Translate(Apollo.GetString("QuestLog_Untrack")) or self:Translate(Apollo.GetString("QuestLog_Track")))
	self.wndMain:FindChild("QuestTrackBtn"):SetTooltip(bNewTrackValue and Apollo.GetString("QuestLog_RemoveFromTracker") or Apollo.GetString("QuestLog_AddToTracker"))
	Event_FireGenericEvent("GenericEvent_GorynychQuestLog_TrackBtnClicked", queSelected)
end

function GorynychQuestLog:OnQuestShareBtn(wndHandler, wndControl) -- QuestShareBtn
	local queSelected = self.wndMain:FindChild("RightSide"):GetData()
	queSelected:Share()
end

function GorynychQuestLog:OnQuestCallBtn(wndHandler, wndControl) -- QuestCallBtn or QuestInfoCostumeWindow
	local queSelected = self.wndMain:FindChild("RightSide"):GetData()
	CommunicatorLib.CallContact(queSelected)
	Event_FireGenericEvent("ToggleCodex") -- Hide codex, not sure if we want this
end

function GorynychQuestLog:OnQuestAbandonBtn(wndHandler, wndControl) -- QuestAbandonBtn
	local queSelected = self.wndMain:FindChild("RightSide"):GetData()
	queSelected:Abandon()
	self:OnDestroyQuestObject(queUpdated)
	self:DestroyAndRedraw()
	self.wndMain:FindChild("RightSide"):Show(false)
	self.wndMain:FindChild("QuestInfoControls"):Show(false)
end

function GorynychQuestLog:OnQuestHideBtn(wndHandler, wndControl) -- QuestInfoControlsHideBtn
	local queSelected = self.wndMain:FindChild("RightSide"):GetData()
	queSelected:ToggleIgnored()
	self:OnDestroyQuestObject(queSelected)
	self:DestroyAndRedraw()
	self.wndMain:FindChild("RightSide"):Show(false)
	self.wndMain:FindChild("QuestInfoControls"):Show(false)
	Apollo.CreateTimer("RedrawQuestLogInOneSec", 1, false) -- TODO TEMP HACK, since Quest:ToggleIgnored() takes a while
end

function GorynychQuestLog:OnQuestAbandonPopoutClose(wndHandler, wndControl) -- QuestAbandonPopoutClose
	self.wndMain:FindChild("QuestAbandonConfirm"):Show(false)
end

-----------------------------------------------------------------------------------------------
-- State Updates
-----------------------------------------------------------------------------------------------

function GorynychQuestLog:OnQuestStateChanged(queUpdated, eState)
	if type(eState) == "boolean" then
		-- CODE ERROR! This is Quest Track Changed.
		return
	end

	if eState == Quest.QuestState_Abandoned or eState == Quest.QuestState_Completed then
		self:OnDestroyQuestObject(queUpdated)
	elseif eState == Quest.QuestState_Accepted or eState == Quest.QuestState_Achieved then
		self:OnDestroyQuestObject(queUpdated)
		self:DestroyAndRedraw()
	else -- Botched, Mentioned, Ignored, Unknown
		self:RedrawEverything()

		local queCurrent = self.wndMain:FindChild("RightSide"):GetData()
		if queCurrent and queCurrent:GetId() == queUpdated:GetId() then
			self.wndMain:FindChild("RightSide"):Show(false)
			self.wndMain:FindChild("QuestInfoControls"):Show(false)
		end
	end
end

function GorynychQuestLog:OnQuestObjectiveUpdated(queUpdated)
	local queCurrent = self.wndMain:FindChild("RightSide"):GetData()
	if queCurrent and queCurrent:GetId() == queUpdated:GetId() then
		self:RedrawEverything()
	end

	if queCurrent and queCurrent:GetState() == Quest.QuestState_Achieved then -- For some reason OnQuestStateChanged doesn't get called
		self:OnDestroyQuestObject(queUpdated)
		self:RedrawEverything()
	end
end

function GorynychQuestLog:OnDestroyQuestObject(queTarget) -- QuestStateChanged, QuestObjectiveUpdated
	if self.wndMain and self.wndMain:IsValid() and queTarget then
		local wndBot = self.wndMain:FindChild("LeftSideScroll"):FindChildByUserData("Q"..queTarget:GetId())
		if wndBot then
			wndBot:Destroy()
			self:RedrawEverything()
		end
	end
end

-----------------------------------------------------------------------------------------------
-- Quest Sharing
-----------------------------------------------------------------------------------------------

function GorynychQuestLog:OnDialog_QuestShare(queToShare, unitTarget)
	if self.wndShare == nil then
		self.wndShare = Apollo.LoadForm(self.xmlDoc, "ShareQuestNotice", nil, self)
	end
	self.wndShare:ToFront()
	self.wndShare:Show(true)
	self.wndShare:SetData(queToShare)
	self.wndShare:FindChild("NoticeText"):SetText(unitTarget:GetName() .. self:Translate(Apollo.GetString("CRB__wants_to_share_quest_")) .. self:Translate(queToShare:GetTitle()) .. self:Translate(Apollo.GetString("CRB__with_you")))

	Apollo.CreateTimer("ShareTimeout", Quest.kQuestShareAcceptTimeoutMs / 1000.0, false)
	Apollo.StartTimer("ShareTimeout")
end

function GorynychQuestLog:OnShareCancel(wndHandler, wndControl)
	local queToShare = self.wndShare:GetData()
	if queToShare then
		queToShare:RejectShare()
	end
	if self.wndShare then
		self.wndShare:Destroy()
		self.wndShare = nil
	end
	Apollo.StopTimer("ShareTimeout")
end

function GorynychQuestLog:OnShareAccept(wndHandler, wndControl)
	local queToShare = self.wndShare:GetData()
	if queToShare then
		queToShare:AcceptShare()
	end
	if self.wndShare then
		self.wndShare:Destroy()
		self.wndShare = nil
	end
	Apollo.StopTimer("ShareTimeout")
end

function GorynychQuestLog:OnShareTimeout()
	self:OnShareCancel()
end

-----------------------------------------------------------------------------------------------
-- Reward Building Helpers
-----------------------------------------------------------------------------------------------

function GorynychQuestLog:HelperBuildRewardsRec(wndReward, tRewardData, bReceived)
	local strText = ""
	local strSprite = ""

	if tRewardData.eType == Quest.Quest2RewardType_Item then
		strText = self:Translate(tRewardData.itemReward:GetName())
		strSprite = tRewardData.itemReward:GetIcon()
		self:HelperBuildItemTooltip(wndReward, tRewardData.itemReward)
		wndReward:FindChild("RewardItemCantUse"):Show(self:HelperPrereqFailed(tRewardData.itemReward))
		wndReward:FindChild("RewardItemText"):SetTextColor(karEvalColors[tRewardData.itemReward:GetItemQuality()])
		wndReward:FindChild("RewardIcon"):SetText(tRewardData.nAmount > 1 and tRewardData.nAmount or "")
	elseif tRewardData.eType == Quest.Quest2RewardType_Reputation then
		strText = String_GetWeaselString(Apollo.GetString("Dialog_FactionRepReward"), tRewardData.nAmount, tRewardData.strFactionName)
		strSprite = "Icon_ItemMisc_UI_Item_Parchment"
		wndReward:SetTooltip(strText)
	elseif tRewardData.eType == Quest.Quest2RewardType_TradeSkillXp then
		strText = String_GetWeaselString(self:Translate(Apollo.GetString("Dialog_TradeskillXPReward")), tRewardData.nXP, self:Translate(tRewardData.strTradeskill))
		strSprite = "Icon_ItemMisc_tool_0001"
		wndReward:SetTooltip(strText)
	elseif tRewardData.eType == Quest.Quest2RewardType_Money then
		if tRewardData.eCurrencyType == Money.CodeEnumCurrencyType.Credits then
			local nInCopper = tRewardData.nAmount
			if nInCopper >= 1000000 then
				strText = String_GetWeaselString(self:Translate(Apollo.GetString("CRB_Platinum")), math.floor(nInCopper / 1000000))
			end
			if nInCopper >= 10000 then
				strText = String_GetWeaselString(self:Translate(Apollo.GetString("CRB_Gold")), math.floor(nInCopper % 1000000 / 10000))
			end
			if nInCopper >= 100 then
				strText = String_GetWeaselString(self:Translate(Apollo.GetString("CRB_Silver")), math.floor(nInCopper % 10000 / 100))
			end
			strText = strText .. " " .. String_GetWeaselString(self:Translate(Apollo.GetString("CRB_Copper")), math.floor(nInCopper % 100))
			strSprite = "ClientSprites:Icon_ItemMisc_bag_0001"
			wndReward:SetTooltip(strText)
		else
			local tDenomInfo = GameLib.GetPlayerCurrency(tRewardData.eCurrencyType):GetDenomInfo()
			if tDenomInfo ~= nil then
				strText = tRewardData.nAmount .. " " .. self:Translate(tDenomInfo[1].strName)
				strSprite = "ClientSprites:Icon_ItemMisc_bag_0001"
				wndReward:SetTooltip(strText)
			end
		end
	end

	wndReward:FindChild("RewardIcon"):SetSprite(strSprite)
	wndReward:FindChild("RewardItemText"):SetText(strText)
end

-----------------------------------------------------------------------------------------------
-- Helpers
-----------------------------------------------------------------------------------------------

function GorynychQuestLog:HelperBuildObjectiveTitleString(queQuest, tObjective, bIsTooltip)
	local strResult = string.format("<T Font=\"CRB_InterfaceMedium\" TextColor=\"ffffffff\">%s</T>", self:Translate(tObjective.strDescription))

	-- Prefix Optional or Progress if it hasn't been finished yet
	if tObjective.nCompleted < tObjective.nNeeded then
		if tObjective and not tObjective.bIsRequired then
			strResult = string.format("<T Font=\"CRB_InterfaceMedium_B\" TextColor=\"ffffffff\">%s</T>%s", self:Translate(Apollo.GetString("QuestLog_Optional")), strResult)
		end

		if tObjective.nNeeded > 1 and queQuest:DisplayObjectiveProgressBar(tObjective.nIndex) then
			local nCompleted = queQuest:GetState() == Quest.QuestState_Completed and tObjective.nNeeded or tObjective.nCompleted
			local nPercentText = String_GetWeaselString(Apollo.GetString("CRB_Percent"), math.floor(nCompleted / tObjective.nNeeded * 100))
			strResult = string.format("<T Font=\"CRB_InterfaceMedium_B\" TextColor=\"ffffffff\">%s </T>%s", nPercentText, strResult)
		elseif tObjective.nNeeded > 1 then
			local nCompleted = queQuest:GetState() == Quest.QuestState_Completed and tObjective.nNeeded or tObjective.nCompleted
			local nPercentText = String_GetWeaselString(Apollo.GetString("QuestTracker_ValueComplete"), nCompleted, tObjective.nNeeded)
			strResult = string.format("<T Font=\"CRB_InterfaceMedium_B\" TextColor=\"ffffffff\">%s </T>%s", nPercentText, strResult)
		end
	end

	return strResult
end

function GorynychQuestLog:HelperBuildObjectiveProgBar(queQuest, tObjective, wndObjective, bComplete)
	if tObjective.nNeeded > 1 and queQuest:DisplayObjectiveProgressBar(tObjective.nIndex) then
		local wndObjectiveProg = self:FactoryProduce(wndObjective, "QuestProgressItem", "QuestProgressItem")
		local nCompleted = bComplete and tObjective.nNeeded or tObjective.nCompleted
		local nNeeded = tObjective.nNeeded
		wndObjectiveProg:FindChild("QuestProgressBar"):SetMax(nNeeded)
		wndObjectiveProg:FindChild("QuestProgressBar"):SetProgress(nCompleted)
		wndObjectiveProg:FindChild("QuestProgressBar"):EnableGlow(nCompleted > 0 and nCompleted ~= nNeeded)
	end
end

function GorynychQuestLog:CheckLeftSideFilters(queQuest)
	local bCompleteState = queQuest:GetState() == Quest.QuestState_Completed
	local bResult1 = self.wndLeftFilterActive:IsChecked() and not bCompleteState and not queQuest:IsIgnored()
	local bResult2 = self.wndLeftFilterFinished:IsChecked() and bCompleteState
	local bResult3 = self.wndLeftFilterHidden:IsChecked() and queQuest:IsIgnored()

	return bResult1 or bResult2 or bResult3
end

function GorynychQuestLog:HelperPrereqFailed(tCurrItem)
	return tCurrItem and tCurrItem:IsEquippable() and not tCurrItem:CanEquip()
end

function GorynychQuestLog:HelperPrefixTimeString(fTime, strAppend, strColorOverride)
	local fSeconds = fTime % 60
	local fMinutes = fTime / 60
	local strColor = "fffffc00"
	if strColorOverride then
		strColor = strColorOverride
	elseif fMinutes < 1 and fSeconds <= 30 then
		strColor = "ffff0000"
	end
	return string.format("<T Font=\"CRB_InterfaceMedium_B\" TextColor=\"%s\">(%d:%.02d) </T>%s", strColor, fMinutes, fSeconds, strAppend)
end

function GorynychQuestLog:HelperBuildItemTooltip(wndArg, item)
	wndArg:SetTooltipDoc(nil)
	wndArg:SetTooltipDocSecondary(nil)
	local itemEquipped = item:GetEquippedItemForItemType()
	Tooltip.GetItemTooltipForm(self, wndArg, item, {bPrimary = true, bSelling = false, itemCompare = itemEquipped})
end

function GorynychQuestLog:FactoryProduce(wndParent, strFormName, strKey)
	local wnd = self.arLeftTreeMap[strKey]
	if not wnd or not wnd:IsValid() then
		wnd = Apollo.LoadForm(self.xmlDoc, strFormName, wndParent, self)
		wnd:SetData(strKey)
		self.arLeftTreeMap[strKey] = wnd
	end
	return wnd
end

local GorynychQuestLogInst = GorynychQuestLog:new()
GorynychQuestLogInst:Init()
