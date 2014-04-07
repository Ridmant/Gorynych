-----------------------------------------------------------------------------------------------
-- Client Lua Script for GorynychGalacticArchive
-- Copyright (c) NCsoft. All rights reserved
-----------------------------------------------------------------------------------------------

require "Window"
require "GalacticArchiveArticle"
require "GalacticArchiveEntry"

local GorynychGalacticArchive = {}

local kclrDefault = "ff62aec1"

function GorynychGalacticArchive:new(o)
    o = o or {}
    setmetatable(o, self)
    self.__index = self
	self.ruTranslationGalacticArchive = {}
    return o
end

function GorynychGalacticArchive:Translate(str)
	local translationLib = Apollo.GetAddon("TranslationLib")
	if (translationLib ~= nil) then
		return translationLib:Traslate(nil, "GalacticArchive", str)
	end
	return str
end

function GorynychGalacticArchive:TranslateStatic()
	local topRowShowAllFilter = self.wndArchiveIndexForm:FindChild("ArchiveContent"):FindChild("TopRow"):FindChild("TopRowShowAllFilter")
	topRowShowAllFilter:SetText(self:Translate(Apollo.GetString("Archive_ShowAllArticles")))	
	topRowShowAllFilter:SetTooltip("<P Font=\"CRB_InterfaceSmall\" TextColor=\"ff9d9d9d\">"..self:Translate(Apollo.GetString("Archive_ShowAllTooltip")).."</P>")
	local topRowUpdatedFilter = self.wndArchiveIndexForm:FindChild("ArchiveContent"):FindChild("TopRow"):FindChild("TopRowUpdatedFilter")
	topRowUpdatedFilter:SetTooltip("<P Font=\"CRB_InterfaceSmall\" TextColor=\"ff9d9d9d\">"..self:Translate(Apollo.GetString("Archive_UpdatedTooltip")).."</P>")
	local emptyLabelBtn = self.wndArchiveIndexForm:FindChild("EmptyLabel"):FindChild("EmptyLabelBtn")
	emptyLabelBtn:SetText(self:Translate(Apollo.GetString("Archive_ShowAllArticles")))
	local articleScroll = self.wndArticleDisplay:FindChild("ArticleScroll"):FindChild("EntriesContainer")
	local tOptions = articleScroll:GetPixieInfo(1)
	tOptions.strText = self:Translate(Apollo.GetString("Archive_ArticlesLabel"))
	tOptions.flagsText = {
		  DT_CENTER = true,
			DT_BOTTOM= true,
		  DT_VCENTER = false
		}
	articleScroll:UpdatePixie(1, tOptions)
	--self.wndArchiveIndexForm:GetPixieInfo
	--self.wndArchiveIndexForm:AddPixie( nil, 0, false, "1","CRB_InterfaceLarge_B",nil,"",0,
end

function GorynychGalacticArchive:Init()
    Apollo.RegisterAddon(self)
end

function GorynychGalacticArchive:OnLoad()
	Apollo.RegisterEventHandler("ToggleGalacticArchiveWindow", 	"OnToggleGalacticArchiveWindow", self)
	Apollo.RegisterEventHandler("GenericEvent_CloseGAReader", 	"OnBack", self)
end

function GorynychGalacticArchive:Initialize(wndParent, wndMostTopLevel)
	Apollo.RegisterEventHandler("GalacticArchiveArticleAdded", 	"OnGalacticArchiveArticleAdded", self)
	Apollo.RegisterEventHandler("GalacticArchiveEntryAdded", 	"OnGalacticArchiveEntryAdded", self)
	Apollo.RegisterEventHandler("GalacticArchiveRefresh", 		"OnGalacticArchiveRefresh", self)

	self.wndArchiveIndexForm = 	Apollo.LoadForm("GorynychGalacticArchive.xml", "ArchiveIndex", wndParent, self)
	self.wndArticleDisplay = 	Apollo.LoadForm("GorynychGalacticArchive.xml", "ArticleDisplay", nil, self)
	self.wndHeaderContainer = 	self.wndArchiveIndexForm:FindChild("HeaderContainer")
	self.wndFilterShowAll = 	self.wndArchiveIndexForm:FindChild("TopRowShowAllFilter")
	self.wndFilterUpdated = 	self.wndArchiveIndexForm:FindChild("TopRowUpdatedFilter")

	self.tArticles = {}
	self.artDisplayed = nil
	self.wndMostTopLevel = wndMostTopLevel
	self.wndArticleDisplay:Show(false, true)
	--self.wndArchiveIndexForm:SetSizingMinimum(362, 300)
	--self.wndArchiveIndexForm:SetSizingMaximum(362, 1200)

	-- My variables
	self.tSkipHeaders = {}
	self.tListOfLetters = {}
	self.tWndTopFilters = {}
	self.strCurrTypeFilter = ""

	self.nEntryLeft, self.nEntryTop, self.nEntryRight, self.nEntryBottom = self.wndArticleDisplay:FindChild("ArticleScroll"):FindChild("EntriesContainer"):GetAnchorOffsets()

	-- Set up top filters
	self.wndFilterShowAll:SetData(Apollo.GetString("Archive_ShowAll"))
	self.wndFilterUpdated:SetData(Apollo.GetString("Archive_Updated"))

	-- Default is Updated if possible, else Show All
	if self:HelperIsThereAnyNew() then
		self.wndFilterUpdated:SetCheck(true)
		self.strCurrTypeFilter = Apollo.GetString("Archive_Updated")
	else
		self.wndFilterShowAll:SetCheck(true)
		self.strCurrTypeFilter = Apollo.GetString("Archive_ShowAll")
	end

	-- Set up rest of filters
	for idx, strCurrCategory in ipairs(GalacticArchiveArticle.GetAllCategories()) do
		local wndCurr = Apollo.LoadForm("GorynychGalacticArchive.xml", "FilterTypeItem", self.wndArchiveIndexForm:FindChild("TypeFilterContainer"), self)
		wndCurr:FindChild("FilterIcon"):SetTooltip(string.format(
			"<P Font=\"CRB_InterfaceSmall\" TextColor=\"ff9d9d9d\">%s<P TextColor=\"ffffffff\">%s</P></P>", self:Translate(Apollo.GetString("Archive_ShowArticlesOnTopic")), self:Translate(strCurrCategory)))
		self:HelperDrawTypeIcon(wndCurr:FindChild("FilterIcon"), nil, strCurrCategory)
		wndCurr:FindChild("FilterTypeBtn"):SetData(strCurrCategory)
		table.insert(self.tWndTopFilters, wndCurr)
	end
	self.wndArchiveIndexForm:FindChild("TypeFilterContainer"):ArrangeChildrenTiles()
	
	self:TranslateStatic()
end

function GorynychGalacticArchive:OnToggleGalacticArchiveWindow(wndParent, wndMostTopLevel)
	if not self.wndArchiveIndexForm or not self.wndArchiveIndexForm:IsValid() then
		self:Initialize(wndParent, wndMostTopLevel)
	end

	if self.strCurrTypeFilter ~= Apollo.GetString("Archive_Updated") and self:HelperIsThereAnyNew() then
		for idx, wndCurr in ipairs(self.tWndTopFilters) do
			if wndCurr then
				wndCurr:FindChild("FilterTypeBtn"):SetCheck(false)
			end
		end

		self.strCurrTypeFilter = Apollo.GetString("Archive_Updated")
		self.wndFilterUpdated:SetCheck(true)
		self.wndFilterShowAll:SetCheck(false)
	end

	self:PopulateArchiveIndex()
	self.wndArchiveIndexForm:Show(not self.wndArchiveIndexForm:IsShown())
end

function GorynychGalacticArchive:OnFilterShowAllSelect(wndHandler, wndControl)
	if wndHandler and wndHandler:GetData() then
		self.strCurrTypeFilter = wndHandler:GetData()
	end
	self:PopulateArchiveIndex()
end

function GorynychGalacticArchive:OnFilterTypeSelect(wndHandler, wndControl)
	if wndHandler and wndHandler:GetData() then
		self.strCurrTypeFilter = wndHandler:GetData()
	end

	wndHandler:SetCheck(true)

	self.wndFilterShowAll:SetCheck(false)
	self:PopulateArchiveIndex()


end

function GorynychGalacticArchive:OnFilterTypeUnselect(wndHandler, wndControl)
	-- All filters have this, including Recently Updated, except "Show All" (which can't deselect)
	for idx, wndCurr in ipairs(self.tWndTopFilters) do
		if wndCurr then
			wndCurr:FindChild("FilterTypeBtn"):SetCheck(false)
		end
	end

	wndHandler:SetCheck(false)

	self.strCurrTypeFilter = Apollo.GetString("Archive_ShowAll")
	self.wndFilterShowAll:SetCheck(true)
	self:PopulateArchiveIndex()
end

function GorynychGalacticArchive:OnNameFilterChanged()
	self:PopulateArchiveIndex()
end

function GorynychGalacticArchive:OnHeaderBtnItemClick(wndHandler, wndControl)
	if wndHandler and wndHandler:GetData() then
		local strLetter = wndHandler:GetData():lower()
		if self.tSkipHeaders[strLetter] == nil or self.tSkipHeaders[strLetter] == false then
			self.tSkipHeaders[strLetter] = true
		else
			self.tSkipHeaders[strLetter] = false
		end

		local nScrollPos = self.wndHeaderContainer:GetVScrollPos()
		self:PopulateArchiveIndex()
		self.wndHeaderContainer:SetVScrollPos(nScrollPos)
	end

	return true -- stop propogation
end

-----------------------------------------------------------------------------------------------
-- ArchiveIndex Functions
-----------------------------------------------------------------------------------------------

-- Static
function GorynychGalacticArchive:BuildArchiveList()
	-- If nil, we will skip this filter later on
	local strNameChoice = self.wndArchiveIndexForm:FindChild("SearchFilter"):GetText()
    if strNameChoice == "" then
		strNameChoice = nil
	end

	local strCatChoice = self.strCurrTypeFilter
	if strCatChoice == "" then
		strCatChoice = nil
	end

    self.tArticles = GalacticArchiveArticle.GetArticles()
	local tResult = {}
    for idx, artCurr in ipairs(self.tArticles) do
		local strTitle = self:GetTitleMinusThe(artCurr)
		local bPass = true

		if strCatChoice and strCatChoice ~= Apollo.GetString("Archive_ShowAll") and strCatChoice ~= Apollo.GetString("Archive_Updated") and not artCurr:GetCategories()[strCatChoice] then
			bPass = false
		elseif strCatChoice and strCatChoice == Apollo.GetString("Archive_Updated") and not self:HelperIsNew(artCurr) then
			bPass = false
		end

		-- Find the first character of a word or an exact match from the start
		if bPass and strNameChoice then
			local strNameChoiceLower = strNameChoice:lower()
			if not (strTitle:lower():find(" "..strNameChoiceLower) or string.sub(strTitle, 0, string.len(strNameChoice)):lower() == strNameChoiceLower) then
				bPass = false
			end
		end

		if bPass then
			table.insert(tResult, artCurr)
		end
    end

	-- Sort alphabetically
	table.sort(tResult, function (a,b) return (self:GetTitleMinusThe(a) < self:GetTitleMinusThe(b)) end)
	return tResult
end

function GorynychGalacticArchive:OnHeaderBtnMouseEnter(wndHandler, wndControl)
	wndHandler:FindChild("HeaderBtnText"):SetTextColor(ApolloColor.new("ff31fcf6"))
end

function GorynychGalacticArchive:OnHeaderBtnMouseExit(wndHandler, wndControl)
	wndHandler:FindChild("HeaderBtnText"):SetTextColor(ApolloColor.new("ff9aaea3"))
end

function GorynychGalacticArchive:OnEmptyLabelBtn(wndHandler, wndControl)
	-- Simulate clicking "Show All" and clear search
	self.wndArchiveIndexForm:FindChild("SearchFilter"):SetText("")
	self.wndArchiveIndexForm:FindChild("SearchFilter"):Enable(false)
	self.wndArchiveIndexForm:FindChild("SearchFilter"):Enable(true) -- HACK: Deselect the search box
	for key, wndCurr in pairs(self.wndArchiveIndexForm:FindChild("TypeFilterContainer"):GetChildren()) do
		wndCurr:FindChild("FilterTypeBtn"):SetCheck(false)
	end
	self.wndFilterUpdated:SetCheck(false)
	self.wndFilterShowAll:SetCheck(true)
	self.strCurrTypeFilter = Apollo.GetString("Archive_ShowAll")
	self:PopulateArchiveIndex()
end

function GorynychGalacticArchive:PopulateArchiveIndex()
	if not self.wndArchiveIndexForm or not self.wndArchiveIndexForm:IsValid() then
		return
	end

	self.wndHeaderContainer:DestroyChildren()
	self.tListOfLetters = {}

	local tArticlesToAdd = self:BuildArchiveList()
	for idx, artCurr in ipairs(tArticlesToAdd) do
		self:BuildAHeader(artCurr)
	end

	-- Count number of new articles
	local nNumOfNewArticles = 0
	for idx, artCurr in ipairs(GalacticArchiveArticle.GetArticles()) do --for nIdx, article in ipairs(tArticlesToAdd) do
		if self:HelperIsNew(artCurr) then
			nNumOfNewArticles = nNumOfNewArticles + 1
		end
	end

	-- Empty Label and etc. formatting
	self.wndArchiveIndexForm:FindChild("EmptyLabel"):Show(#self.wndHeaderContainer:GetChildren() == 0)
	self.wndArchiveIndexForm:FindChild("EmptyLabel"):SetText(String_GetWeaselString(self:Translate(Apollo.GetString("Archive_NoEntriesFound")), self.strCurrTypeFilter))
	self.wndArchiveIndexForm:FindChild("BGTitleText"):SetText(String_GetWeaselString(self:Translate(Apollo.GetString("Archive_TitleWithFilter")), self.strCurrTypeFilter))

	if nNumOfNewArticles == 0 then

		self.wndFilterUpdated:SetText(self:Translate(Apollo.GetString("Archive_UpdatedArticles")))
	else
		self.wndFilterUpdated:SetText(String_GetWeaselString(self:Translate(Apollo.GetString("Archive_UpdatedArticlesNumber")), nNumOfNewArticles))
	end

	self.wndHeaderContainer:ArrangeChildrenVert()
end

function GorynychGalacticArchive:BuildAHeader(artBuilding)
	local strLetter = string.sub(self:GetTitleMinusThe(artBuilding), 0, 1):lower()
	if strLetter == nil or strLetter == "" then
		strLetter = Apollo.GetString("Archive_Unspecified")
	end

	-- Draw the header (try to find it via FindChild and our List before making a new one)
	-- Try to find it first
	local wndHeader = self.wndHeaderContainer:FindChildByUserData(strLetter:lower())
	for strIdxLetter, wndCurr in pairs(self.tListOfLetters) do	-- GOTCHA: This is necessary incase FindChild's target doesn't update quick enough
		if strIdxLetter:lower() == strLetter and wndCurr ~= nil then
			wndHeader = wndCurr
		end
	end

	if wndHeader == nil then
		wndHeader = Apollo.LoadForm("GorynychGalacticArchive.xml", "HeaderItem", self.wndHeaderContainer, self)
	end

	wndHeader:SetData(strLetter)
	wndHeader:FindChild("HeaderBtn"):SetData(strLetter) -- Used by OnHeaderBtnItemClick
	wndHeader:FindChild("HeaderBtnText"):SetText(strLetter:upper()) -- Add children in a separate method since we need FindChild detection
	self.tListOfLetters[strLetter] = wndHeader

	-- Load children
	if self.tSkipHeaders[strLetter] == nil or self.tSkipHeaders[strLetter] == false then
		wndHeader:FindChild("HeaderBtn"):SetCheck(true)
		self:AddArticleToIndex(artBuilding, wndHeader:FindChild("HeaderItemContainer"))

		local nLeft, nTop, nRight, nBottom = wndHeader:GetAnchorOffsets()
		wndHeader:SetAnchorOffsets(nLeft, nTop, nRight, nTop + wndHeader:FindChild("HeaderItemContainer"):ArrangeChildrenVert(0) + 35)
	else
		wndHeader:FindChild("HeaderBtn"):SetCheck(false)
	end
end

-----------------------------------------------------------------------------------------------
-- Add Article
-----------------------------------------------------------------------------------------------

function GorynychGalacticArchive:AddArticleToIndex(artData, wndParent)
	local wndArticle = wndParent:FindChildByUserData(artData)
	if wndArticle then
		return
	end

	wndArticle = Apollo.LoadForm("GorynychGalacticArchive.xml", "ArchiveIndexItem", wndParent, self)

	local nLockCount = 0
	local nEntryCount = 1 -- Base article will artificially count
	for idx, entCurr in ipairs(artData:GetEntries()) do
		if entCurr:IsUnlocked() then
			nEntryCount = nEntryCount + 1
		else
			nLockCount = nLockCount + 1
		end
	end
	local nMaxCount = nEntryCount + nLockCount
	local bHasCostume = artData:GetHeaderCreature() and artData:GetHeaderCreature() ~= 0

	if bHasCostume then
		wndArticle:FindChild("ArticlePortrait"):SetCostumeToCreatureId(artData:GetHeaderCreature())
	elseif string.len(artData:GetHeaderIcon()) > 0 then
		wndArticle:FindChild("ArticleIcon"):SetSprite(artData:GetHeaderIcon())
	else
		wndArticle:FindChild("ArticleIcon"):SetSprite("Icon_Mission_Explorer_PowerMap")
	end
	wndArticle:FindChild("ArticleIcon"):Show(not bHasCostume)
	wndArticle:FindChild("ArticlePortrait"):Show(bHasCostume)

	wndArticle:SetData(artData)
	wndArticle:FindChild("ArticleProgress"):SetMax(nMaxCount)
	wndArticle:FindChild("ArticleProgress"):SetProgress(nEntryCount)
	wndArticle:FindChild("ArticleProgress"):SetFullSprite("kitIProgBar_MetalInset_Fill" .. (nEntryCount == nMaxCount and "Green" or "Blue"))
	wndArticle:FindChild("ArticleProgressText"):SetText(nEntryCount == nMaxCount and "" or String_GetWeaselString(self:Translate(Apollo.GetString("Archive_UnlockedCount")), nEntryCount, nMaxCount))
	wndArticle:FindChild("NewIndicator"):Show(self:HelperIsNew(artData))
	wndArticle:FindChild("ArchiveIndexItemTitle"):SetText(self:Translate(artData:GetTitle()))
	self:HelperDrawTypeIcon(wndArticle:FindChild("ArticleTypeIcon"), artData)
end

function GorynychGalacticArchive:HelperIsNew(artCurr)
	local bIsNew = false

	if artCurr and artCurr:IsViewed() then	-- Incase it is viewed, check entries too
		for idx, entCurr in ipairs(artCurr:GetEntries()) do
			if entCurr:IsUnlocked() and not entCurr:IsViewed() then
				bIsNew = true
			end
		end
	elseif artCurr then
		bIsNew = true
	end

	return bIsNew
end

function GorynychGalacticArchive:HelperIsThereAnyNew()
    for idx, artCurr in ipairs(GalacticArchiveArticle.GetArticles()) do
		if self:HelperIsNew(artCurr) then
			return true
		end
	end
	return false
end

function GorynychGalacticArchive:HelperDrawTypeIcon(wndArg, artCheck, strCategory)
	-- TODO This is all hard coded temporary
	local strSprite = ""
	local artCheckCategories = artCheck and artCheck:GetCategories() or nil
	if (strCategory and strCategory == "Lore") or (artCheck and artCheckCategories["Lore"]) then
		strSprite = "CRB_GuildSprites:sprGuild_Flute"
	elseif (strCategory and strCategory == "Tech") or (artCheck and artCheckCategories["Tech"]) then
		strSprite = "ClientSprites:Icon_Guild_UI_Guild_Syringe"
	elseif (strCategory and strCategory == "Plants") or (artCheck and artCheckCategories["Plants"]) then
		strSprite = "CRB_GuildSprites:sprGuild_Leaf"
	elseif (strCategory and strCategory == "Allies") or (artCheck and artCheckCategories["Allies"]) then
		strSprite = "CRB_GuildSprites:sprGuild_Lopp"
	elseif (strCategory and strCategory == "Enemies") or (artCheck and artCheckCategories["Enemies"]) then
		strSprite = "CRB_GuildSprites:sprGuild_Skull"
	elseif (strCategory and strCategory == "Minerals") or (artCheck and artCheckCategories["Minerals"]) then
		strSprite = "ClientSprites:Icon_Guild_UI_Guild_Pearl"
	elseif (strCategory and strCategory == "Factions") or (artCheck and artCheckCategories["Factions"]) then
		strSprite = "ClientSprites:Icon_Guild_UI_Guild_Candles"
	elseif (strCategory and strCategory == "Creatures") or (artCheck and artCheckCategories["Creatures"]) then
		strSprite = "ClientSprites:Icon_Guild_UI_Guild_Hand"
	elseif (strCategory and strCategory == "Locations") or (artCheck and artCheckCategories["Locations"]) then
		strSprite = "ClientSprites:Icon_Guild_UI_Guild_Blueprint"
	elseif (strCategory and strCategory == "Sentient Species") or (artCheck and artCheckCategories["Sentient Species"]) then
		strSprite = "ClientSprites:Icon_Guild_UI_Guild_Key"
	elseif (strCategory and strCategory == "The Nexus Project") or (artCheck and artCheckCategories["The Nexus Project"]) then
		strSprite = "CRB_GuildSprites:sprGuild_Potion"
	elseif (strCategory and strCategory == "Notable Individuals") or (artCheck and artCheckCategories["Notable Individuals"]) then
		strSprite = "ClientSprites:Icon_Guild_UI_Guild_Blueprint" -- Doubled with Location
	else
		strSprite = "ClientSprites:Icon_Guild_UI_Guild_Blueprint"
		wndArg:SetTooltip(self:Translate(Apollo.GetString("Archive_ArticleNotClassified")))
	end

	wndArg:SetSprite(strSprite)
end

-----------------------------------------------------------------------------------------------
-- Transition Between The Two Classes Functions
-----------------------------------------------------------------------------------------------

-- when a archive item is selected
function GorynychGalacticArchive:OnIndexItemUncheck(wndHandler, wndControl) -- ArchiveIndexItem
	if not wndHandler:IsChecked() then
		self:OnBack()
	end
end

function GorynychGalacticArchive:OnIndexItemCheck(wndHandler, wndControl) -- ArchiveIndexItem
	if wndHandler and wndHandler:FindChild("NewIndicator") then
		wndHandler:FindChild("NewIndicator"):Show(false)
	end
	self:DisplayArticle(wndHandler:GetData())
end

function GorynychGalacticArchive:OnGalacticArchiveArticleAdded(artNew)
	if not self.wndArchiveIndexForm:IsVisible() then
		return
	end

	if not self.artDisplayed then
		self:PopulateArchiveIndex()
		return
	elseif self.artDisplayed and self.artDisplayed == artNew then
		self:DisplayArticle(artNew)
		return
	end

	-- Else we don't have one displayed, so search for it
	for idx, artLinked in ipairs(self.artDisplayed:GetLinks(GalacticArchiveArticle.LinkQueryType_All)) do
		if artNew == artLinked then
			self:DisplayArticle(self.artDisplayed)
			return
		end
	end
end

function GorynychGalacticArchive:OnGalacticArchiveEntryAdded(artParent, entNew)
	if not self.wndArchiveIndexForm:IsVisible() then
		return
	end

	if not self.artDisplayed then
		self:PopulateArchiveIndex()
	elseif self.artDisplayed and self.artDisplayed == artParent then
		self:DisplayArticle(artParent)
	end
end

function GorynychGalacticArchive:OnGalacticArchiveRefresh()
	if not self.wndArchiveIndexForm:IsVisible() then
		return
	end

	if self.artDisplayed then
		self:OnBack()
	else
		self:PopulateArchiveIndex()
	end
end

-----------------------------------------------------------------------------------------------
-- GorynychGalacticArchiveForm Functions
-----------------------------------------------------------------------------------------------

function GorynychGalacticArchive:DisplayArticle(artDisplay)
	-- TODO Tons of hard coded formatting and strings for translation
    if not artDisplay then
		return
	end

	self.artDisplayed = artDisplay
	artDisplay:SetViewed()

	self.wndArchiveIndexForm:FindChild("SearchFilter"):Enable(false)
	self.wndArchiveIndexForm:FindChild("SearchFilter"):Enable(true) -- HACK: Deselect the search box

	-- Top
	local wndArticle = self.wndArticleDisplay
	local strCategories = ""
	for strCurr, value in pairs(artDisplay:GetCategories()) do
		if strCategories == "" then
			strCategories = self:Translate(strCurr)
		else
			strCategories = String_GetWeaselString(self:Translate(Apollo.GetString("Archive_TextList")), strCategories, self:Translate(strCurr))
		end
	end

	if artDisplay:GetWorldZone() and artDisplay:GetWorldZone() ~= "" then
		strCategories = String_GetWeaselString(self:Translate(Apollo.GetString("Archive_ZoneCategories")), self:Translate(artDisplay:GetWorldZone()), strCategories)
	end

	local bHasCostume = artDisplay:GetHeaderCreature() and artDisplay:GetHeaderCreature() ~= 0
	if bHasCostume then
		wndArticle:FindChild("ArticleDisplayCostumeWindow"):SetCostumeToCreatureId(artDisplay:GetHeaderCreature())
	elseif string.len(artDisplay:GetHeaderIcon()) > 0 then
		wndArticle:FindChild("ArticleDisplayIcon"):SetSprite(artDisplay:GetHeaderIcon())
	else
		wndArticle:FindChild("ArticleDisplayIcon"):SetSprite("Icon_Mission_Explorer_PowerMap")
	end
	wndArticle:FindChild("ArticleDisplayIcon"):Show(not bHasCostume)
	wndArticle:FindChild("ArticleDisplayCostumeWindow"):Show(bHasCostume)
	-- End Top

	wndArticle:FindChild("ArticleScientistOnlyIcon"):Show(false)
	wndArticle:FindChild("ArticleTitle"):SetText(self:Translate(artDisplay:GetTitle()))
	wndArticle:FindChild("ArticleSubtitle"):SetText(strCategories)
	wndArticle:FindChild("ArticleText"):SetAML("<P Font=\"CRB_InterfaceMedium\" TextColor=\""..kclrDefault.."\">"..self:ReplaceLineBreaks(self:Translate(artDisplay:GetText())).."</P>")
	wndArticle:FindChild("ArticleText"):SetHeightToContentHeight()

	local nLockCount = 0
	local nEntryCount = 0
	local nAdditionalHeight = 0
	wndArticle:FindChild("EntriesContainerList"):DestroyChildren()
	wndArticle:FindChild("EntriesContainer"):SetAnchorOffsets(0, 0, 0, 0)

	for idx, entCurr in ipairs(artDisplay:GetEntries()) do
		local tResults = self:DrawEntry(entCurr, wndArticle)
		nLockCount = nLockCount + tResults[1]
		nEntryCount = nEntryCount + tResults[2]
		nAdditionalHeight = nAdditionalHeight + tResults[3]
	end

	-- Middle
	wndArticle:FindChild("TitleContainer"):Show(artDisplay:GetCompletionTitle())
	wndArticle:FindChild("TitleProgressBar"):SetText(String_GetWeaselString(self:Translate(Apollo.GetString("CRB_Progress")), nEntryCount, nEntryCount + nLockCount))
	wndArticle:FindChild("TitleProgressBar"):SetProgress(nEntryCount / (nEntryCount + nLockCount))
	wndArticle:FindChild("TitleProgressBar"):EnableGlow(nEntryCount > 0)

	local tCompletionTitle = artDisplay:GetCompletionTitle()
	local bFemale = GameLib.GetPlayerUnit() and GameLib.GetPlayerUnit():GetGender() and GameLib.GetPlayerUnit():GetGender() == Unit.CodeEnumGender.Female
	if tCompletionTitle and bFemale then
		wndArticle:FindChild("TitleEarned"):SetText(self:Translate(tCompletionTitle:GetFemaleTitle()))
	elseif artDisplay:GetCompletionTitle() then
		wndArticle:FindChild("TitleEarned"):SetText(self:Translate(tCompletionTitle:GetMaleTitle()))
	end

	if artDisplay:GetCompletionTitle() and artDisplay:GetCompletionTitle():GetSpell() then
		wndArticle:FindChild("TitleSpell"):SetSprite(artDisplay:GetCompletionTitle():GetSpell():GetIcon())
		wndArticle:FindChild("TitleSpell"):SetTooltip(self:Translate(artDisplay:GetCompletionTitle():GetSpell():GetName()))
	else
		wndArticle:FindChild("TitleSpell"):SetSprite("CRB_GuildSprites:sprGuild_Glave")
		wndArticle:FindChild("TitleSpell"):SetTooltip(self:Translate(Apollo.GetString("Archive_UncoverArticle")))
	end
	-- End Middle

	-- Always open relevant to the LoreWindow parent (TODO HACKY)
	local nLeft, nTop, nRight, nBot = self.wndMostTopLevel:GetAnchorOffsets() -- GOTCHA: Use LoreWindow not LoreWindow:FindChild("MainGAContainer")
	wndArticle:SetAnchorOffsets(nRight - 8, nTop + 67, nRight - 8 + wndArticle:GetWidth(), nTop + 67 + wndArticle:GetHeight())

	wndArticle:FindChild("EntriesContainer"):SetAnchorOffsets(self.nEntryLeft, self.nEntryTop, self.nEntryRight, self.nEntryBottom + nAdditionalHeight)
	wndArticle:FindChild("EntriesContainerList"):ArrangeChildrenVert(0)

	wndArticle:FindChild("ArticleScroll"):SetVScrollPos(0)
	wndArticle:FindChild("ArticleScroll"):RecalculateContentExtents()
	wndArticle:FindChild("ArticleScroll"):ArrangeChildrenVert(0)

	self.wndArchiveIndexForm:Show(true)
	self.wndArticleDisplay:Show(true) -- wndArticle
	self.wndArticleDisplay:ToFront() -- wndArticle
end

function GorynychGalacticArchive:DrawEntry(entDraw, wndArticle)
	local wndEntry = Apollo.LoadForm("GorynychGalacticArchive.xml", "EntryDisplayItem", wndArticle:FindChild("EntriesContainerList"), self)
	local nLockCount = 0
	local nEntryCount = 0

	local strHeaderStyle = entDraw:GetHeaderStyle()
	if strHeaderStyle == GalacticArchiveEntry.ArchiveEntryHeaderEnum_TextWithPortrait then
		wndEntry:FindChild("EntryCostumeWindow"):SetCostumeToCreatureId(entDraw:GetHeaderCreature())
	elseif strHeaderStyle == GalacticArchiveEntry.ArchiveEntryHeaderEnum_TextWithIcon then
		wndEntry:FindChild("EntryIcon"):SetSprite(entDraw:GetHeaderIcon())
	elseif not entDraw:IsUnlocked() then
		wndEntry:FindChild("EntryIcon"):SetSprite("Icon_Windows_UI_CRB_Lock_Holo")
	else
		wndEntry:FindChild("EntryIcon"):SetSprite("Icon_Mission_Scientist_ReverseEngineering")
	end

	-- Costume Window only when TextWithPortrait, else Entry Icon
	wndEntry:FindChild("EntryIcon"):Show(strHeaderStyle ~= GalacticArchiveEntry.ArchiveEntryHeaderEnum_TextWithPortrait)
	wndEntry:FindChild("EntryCostumeWindow"):Show(strHeaderStyle == GalacticArchiveEntry.ArchiveEntryHeaderEnum_TextWithPortrait)

	if entDraw:IsUnlocked() then
		nEntryCount = nEntryCount + 1
		wndEntry:FindChild("EntryTitle"):SetText(self:Translate(entDraw:GetTitle()))
		wndEntry:SetTooltip("")
	else
		nLockCount = nLockCount + 1
		wndEntry:FindChild("EntryTitle"):SetText(self:Translate(Apollo.GetString("Archive_Locked")))
		wndEntry:SetTooltip(string.format("<T Font=\"CRB_InterfaceSmall_O\">%s</T>", self:Translate(Apollo.GetString("Archive_ExploreWorld"))))
	end

	-- Text
	local strEntryText = ""
	if string.len(entDraw:GetText()) > 0 then
		strEntryText = entDraw:GetText()
	end
	if string.len(entDraw:GetScientistText()) > 0 then
		wndEntry:FindChild("EntryScientistOnlyIcon"):Show(true)
		wndArticle:FindChild("ArticleScientistOnlyIcon"):Show(true)
		strEntryText = strEntryText .."</P>\\n<P Font=\"CRB_InterfaceMedium\" TextColor=\"ffffb97f\">"..entDraw:GetScientistText().."</P>"
	end
	wndEntry:FindChild("EntryText"):SetAML("<P Font=\"CRB_InterfaceMedium\" TextColor=\""..kclrDefault.."\">"..self:ReplaceLineBreaks(self:Translate(strEntryText)).."</P>")
	wndEntry:FindChild("EntryText"):SetHeightToContentHeight()

	local nTextLeft, nTextTop, nTextRight, nTextBottom = wndEntry:FindChild("EntryText"):GetAnchorOffsets()
	local nLeft, nTop, nRight, nBottom = wndEntry:GetAnchorOffsets()
	wndEntry:SetAnchorOffsets(nLeft, nTop, nRight, nTextBottom + 8) -- The +8 is extra padding below the text and frame
	return { nLockCount, nEntryCount, nTextBottom + 8 }
end

function GorynychGalacticArchive:OnBack()
	if not self.artDisplayed then
		return
	end

	local nScrollPos = self.wndHeaderContainer:GetVScrollPos()
	self:PopulateArchiveIndex()
	self.wndHeaderContainer:SetVScrollPos(nScrollPos)

	self.artDisplayed = nil

	self.wndArchiveIndexForm:Show(true)
	self.wndArticleDisplay:Show(false)
end

-----------------------------------------------------------------------------------------------
-- Helpers
-----------------------------------------------------------------------------------------------

function GorynychGalacticArchive:ReplaceLineBreaks(strArg)
	return strArg:gsub("\\n", "<T TextColor=\"0\">.</T></P><P Font=\"CRB_InterfaceMedium\" TextColor=\""..kclrDefault.."\">")
end

function GorynychGalacticArchive:GetTitleMinusThe(artTitled)
	if string.sub(artTitled:GetTitle(), 0, 4) == Apollo.GetString("Archive_DefiniteArticle") then
		return string.sub(artTitled:GetTitle(), 5)
	else
		return artTitled:GetTitle()
	end
end

local GorynychGalacticArchiveInst = GorynychGalacticArchive:new()
GorynychGalacticArchiveInst:Init()
