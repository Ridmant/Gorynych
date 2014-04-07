-----------------------------------------------------------------------------------------------
-- Client Lua Script for GorynychLib
-- Copyright (c) NCsoft. All rights reserved
-----------------------------------------------------------------------------------------------
 
require "Window"
require "Apollo"
 
-----------------------------------------------------------------------------------------------
-- GorynychLib Module Definition
-----------------------------------------------------------------------------------------------
local GorynychLib = {} 

local mapLocaleToRadio = {
		["EN"] = 1,
		["RU"] = 2,
	}

local mapButtonToLocale = {
		["ButtonEN"] = "EN",
		["ButtonRU"] = "RU",
	}
-----------------------------------------------------------------------------------------------
-- Constants
-----------------------------------------------------------------------------------------------
-- e.g. local kiExampleVariableMax = 999
 
-----------------------------------------------------------------------------------------------
-- Initialization
-----------------------------------------------------------------------------------------------
function GorynychLib:new(o)
    o = o or {}
    setmetatable(o, self)
    self.__index = self 
	self.traslationBase = {}
	self.traslationBase.locales = {}
	self.traslationBase.errors = {}
	self.SAVELOCALEERRORS = true
	self.SAVEADDONNAMEERRORS = true
	self.SAVETEXTERRORS = true
	self.SAVETOTALERRORS = true
	self.bIsFirstLoad = true
	self.defaultLocale = "EN"
	self.tInterfaceText = nil


    -- initialize variables here

    return o
end

function GorynychLib:Init()
	local bHasConfigureFunction = false
	local strConfigureButtonText = ""
	local tDependencies = {
		-- "UnitOrPackageName",
	}
    Apollo.RegisterAddon(self, bHasConfigureButton, strConfigureButtonText, tDependencies)
end
 

-----------------------------------------------------------------------------------------------
-- GorynychLib OnLoad
-----------------------------------------------------------------------------------------------
function GorynychLib:OnLoad()
    -- load our form file
	self.xmlDoc = XmlDoc.CreateFromFile("GorynychLib.xml")
	self.xmlDoc:RegisterCallback("OnDocLoaded", self)
end

-----------------------------------------------------------------------------------------------
-- GorynychLib OnDocLoaded
-----------------------------------------------------------------------------------------------
function GorynychLib:OnDocLoaded()
	if (self.tInterfaceText == nil) then
		Apollo.AddAddonErrorText(self, "Could not load cache file GorynychLib_0_SaveData.xml")
		return
	end
	if self.xmlDoc ~= nil and self.xmlDoc:IsLoaded() then
	    self.wndMain = Apollo.LoadForm(self.xmlDoc, "GorynychLibForm", nil, self)
		if self.wndMain == nil then
			Apollo.AddAddonErrorText(self, "Could not load the main window for some reason.")
			return
		end
	    self.wndMain:Show(false, true)
		if (self.bIsFirstLoad) then
			self.wndMain:Show(true, true)
			self.bIsFirstLoad = false
		end
		for sButtonName,tButtonData in pairs(self.tInterfaceText.tButtons) do
			self.wndMain:FindChild("Window"..sButtonName):SetAML("<P Font=\"CRB_Interface16_BBO\" TextColor=\"ffff0000>\">"..tButtonData.sLang..
			"</P><P>"..tButtonData.sSite.."</P><P>"..tButtonData.sDescription.."</P>")
		end
		self.wndMain:SetRadioSel("SelectLocale",mapLocaleToRadio[self.defaultLocale])
		-- if the xmlDoc is no longer needed, you should set it to nil
		-- self.xmlDoc = nil
		
		-- Register handlers for events, slash commands and timer, etc.
		-- e.g. Apollo.RegisterEventHandler("KeyDown", "OnKeyDown", self)
		Apollo.RegisterSlashCommand("translationlib", "OnGorynychLibOn", self)
		Apollo.RegisterSlashCommand("tl", "OnGorynychLibOn", self)


		-- Do additional Addon initialization here
	end
end

function GorynychLib:OnSave(eType)	
	if (eType == GameLib.CodeEnumAddonSaveLevel.General) then
		local tSavedData = {}
		tSavedData.setting = {}
		tSavedData.setting["defaultLocale"] = self.defaultLocale
		tSavedData.setting["bIsFirstLoad"] = self.bIsFirstLoad
		if (self.tInterfaceText ~= nil) then
			tSavedData.tInterfaceText = {}	
			tSavedData.tInterfaceText.tButtons = {}
			for sButtonName,tButtonData in pairs(self.tInterfaceText.tButtons) do
				tSavedData.tInterfaceText.tButtons[sButtonName] = {}
				tSavedData.tInterfaceText.tButtons[sButtonName].sLang = tButtonData.sLang
				tSavedData.tInterfaceText.tButtons[sButtonName].sSite = tButtonData.sSite
				tSavedData.tInterfaceText.tButtons[sButtonName].sDescription = tButtonData.sDescription
			end
		end		
		tSavedData.tTraslationBase = {}	
		tSavedData.tTraslationBase.locales = {}
		for localeName, localeData in pairs(self.traslationBase.locales) do
			tSavedData.tTraslationBase.locales[localeName] = {}
			for addonName, addonData in pairs(localeData) do
				tSavedData.tTraslationBase.locales[localeName][addonName]={}
				for engString, translatedString in pairs(addonData) do
					tSavedData.tTraslationBase.locales[localeName][addonName][engString]=translatedString
				end				
			end			
		end		
		tSavedData.tTraslationBase.errors = {}
		for errorName, errorData in pairs(self.traslationBase.errors) do
			tSavedData.tTraslationBase.errors[errorName] = {}
			for addonName, addonData in pairs(errorData) do
				tSavedData.tTraslationBase.errors[errorName][addonName]={}
				for engString, translatedString in pairs(addonData) do
					tSavedData.tTraslationBase.errors[errorName][addonName][engString]=translatedString
				end				
			end	
		end
		return tSavedData
	end
end

function GorynychLib:OnRestore(eType, tSavedData)
	if (eType == GameLib.CodeEnumAddonSaveLevel.General) then		
		self.traslationBase = {}
		self.traslationBase.locales = {}
		self.traslationBase.errors = {}
		if (tSavedData.tTraslationBase ~= nil) then 
			if (tSavedData.tTraslationBase.locales ~= nil) then 
				for localeName, localeData in pairs(tSavedData.tTraslationBase.locales) do
					self.traslationBase.locales[localeName] = {}
					for addonName, addonData in pairs(localeData) do
						self.traslationBase.locales[localeName][addonName]={}
						for engString, translatedString in pairs(addonData) do
							self.traslationBase.locales[localeName][addonName][engString]=translatedString
						end				
					end			
				end		
			end			
			if (tSavedData.tTraslationBase.errors ~= nil) then 
				for errorName, errorData in pairs(tSavedData.tTraslationBase.errors) do
					self.traslationBase.errors[errorName] = {}
					for addonName, addonData in pairs(errorData) do
						self.traslationBase.errors[errorName][addonName]={}
						for engString, translatedString in pairs(addonData) do
							self.traslationBase.errors[errorName][addonName][engString]=translatedString
						end				
					end	
				end	
			end	
		end
		if (tSavedData.setting ~= nil) then
			self.defaultLocale = tSavedData.setting["defaultLocale"]
			self.bIsFirstLoad = tSavedData.setting["bIsFirstLoad"]
		end	
		if (tSavedData.tInterfaceText ~= nil and tSavedData.tInterfaceText.tButtons ~= nil) then
			self.tInterfaceText = {}	
			self.tInterfaceText.tButtons = {}
			for sButtonName,tButtonData in pairs(tSavedData.tInterfaceText.tButtons) do
				self.tInterfaceText.tButtons[sButtonName] = {}
				self.tInterfaceText.tButtons[sButtonName].sLang = tButtonData.sLang
				self.tInterfaceText.tButtons[sButtonName].sSite = tButtonData.sSite
				self.tInterfaceText.tButtons[sButtonName].sDescription = tButtonData.sDescription
			end
		end
	end
end

function GorynychLib:LocaleError(locale, addonName, text)
	if (self.SAVELOCALEERRORS)then
		if (self.SAVETOTALERRORS) then
			self:TextError(locale, addonName, text)
			return
		end
		if (self.traslationBase.errors[locale] == nil)then
			self.traslationBase.errors[locale] = {}
		end
	end
end

function GorynychLib:AddonNameError(locale, addonName, text)
	if (self.SAVEADDONNAMEERRORS)then
		if (self.SAVETOTALERRORS) then
			self:TextError(locale, addonName, text)
			return
		end
		if (self.traslationBase.errors[locale] == nil)then
			self.traslationBase.errors[locale] = {}
		end
		if (self.traslationBase.errors[locale][addonName] == nil)then
			self.traslationBase.errors[locale][addonName] = {}
		end

	end
end

function GorynychLib:TextError(locale, addonName, text)
	if (self.SAVETEXTERRORS)then
		if (self.traslationBase.errors[locale] == nil)then
			self.traslationBase.errors[locale] = {}
		end
		if (self.traslationBase.errors[locale][addonName] == nil)then
			self.traslationBase.errors[locale][addonName] = {}
		end
		if (self.traslationBase.errors[locale][addonName][text] == nil)then
			self.traslationBase.errors[locale][addonName][text] = text
		end
	end
end

function GorynychLib:Traslate(locale, addonName, text)
	if (text == nil or text == "") then
		return text
	end
	if (locale == nil) then
		locale = self.defaultLocale
	end
	if (locale == "EN") then
		return text
	end
	text = string.gsub(string.gsub(text, '\n', ""), '\r', "")
	if (self.traslationBase.locales[locale] == nil)then
		self:LocaleError(locale, addonName, text)
		return text
	end
	if (self.traslationBase.locales[locale][addonName] == nil)then
		self:AddonNameError(locale, addonName, text)
		return text
	end
	if (self.traslationBase.locales[locale][addonName][text] == nil)then
		self:TextError(locale, addonName, text)
		return text
	end
	return self.traslationBase.locales[locale][addonName][text]
end

-----------------------------------------------------------------------------------------------
-- GorynychLib Functions
-----------------------------------------------------------------------------------------------
-- Define general functions here

-- on SlashCommand "/translationlib"
function GorynychLib:OnGorynychLibOn()
	self.wndMain:Show(true) -- show the window
end


-----------------------------------------------------------------------------------------------
-- GorynychLibForm Functions
-----------------------------------------------------------------------------------------------
-- when the OK button is clicked
function GorynychLib:OnOK()
	self.wndMain:Show(false) -- hide the window
end

-- when the Cancel button is clicked
function GorynychLib:OnCancel()
	self.wndMain:Show(false) -- hide the window
end


function GorynychLib:OnSelectLocale( wndHandler, wndControl, eMouseButton )
	local sButtonName = wndControl:GetName()
	self.defaultLocale = mapButtonToLocale[sButtonName]
	self.bIsFirstLoad = true
	RequestReloadUI()
end

-----------------------------------------------------------------------------------------------
-- GorynychLib Instance
-----------------------------------------------------------------------------------------------
local GorynychLibInst = GorynychLib:new()
GorynychLibInst:Init()
