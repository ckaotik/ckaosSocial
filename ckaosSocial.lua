local addonName, addon, _ = ...
addon = CreateFrame('Frame')

local LDB     = LibStub('LibDataBroker-1.1')
local LibQTip = LibStub('LibQTip-1.0')
local strfind, strsub, strrev = strfind, strsub, strrev

-- GLOBALS: _G, LibStub, RGBTableToColorCode
-- GLOBALS: GuildRoster
-- GLOBALS: hooksecurefunc

-- GLOBALS: RED_FONT_COLOR_CODE, BATTLENET_FONT_COLOR_CODE, RAID_CLASS_COLORS, CHAT_FLAG_AFK, CHAT_FLAG_DND, BNET_CLIENT_WOW, REMOTE_CHAT, HIGHLIGHT_FONT_COLOR_CODE, GREEN_FONT_COLOR_CODE, NORMAL_FONT_COLOR, FriendsFrame
-- GLOBALS: FillLocalizedClassList, BNGetNumFriends, BNGetFriendInfo, BNGetNumFriendGameAccounts, BNGetFriendGameAccountInfo, BNGetFriendIndex, BNGetNumFriendInvites, GetQuestDifficultyColor, GetGuildInfo, GetGuildRosterMOTD, CanEditPublicNote, CanEditOfficerNote, SetGuildRosterSelection, SortGuildRoster, GetNumFriends, GetFriendInfo, GetNumGuildMembers, GetGuildRosterInfo, UnitFactionGroup, UnitInParty, UnitPlayerOrPetInRaid, SetItemRef, StaticPopup_Show, InviteUnit, IsAltKeyDown, IsControlKeyDown, ToggleFriendsFrame, ToggleGuildFrame
-- GLOBALS: pairs, ipairs, tonumber, strsplit, select

local playerFaction = UnitFactionGroup('player')
local playerRealm = GetRealmName()
local colorFormat = '|cff%02x%02x%02x%s|r'
local classColors = {} -- to map female/male class names to colors
local icons = { -- @see BNet_GetClientTexture(client)
	['NONE']           = '|TInterface\\FriendsFrame\\BattleNet-BattleNetIcon:0|t',
	[CHAT_FLAG_AFK]    = '|T'..FRIENDS_TEXTURE_AFK..':0|t',
	[CHAT_FLAG_DND]    = '|T'..FRIENDS_TEXTURE_DND..':0|t',
	['REMOTE']         = '|TInterface\\ChatFrame\\UI-ChatIcon-ArmoryChat:0|t',
	['BROADCAST']      = '|T'..FRIENDS_TEXTURE_BROADCAST..':0|t',
	['NOTE']           = '|TInterface\\FriendsFrame\\UI-FriendsFrame-Note:0|t',
	['CONTACT']        = '|TInterface\\FriendsFrame\\UI-Toast-FriendOnlineIcon:0|t',
}

local wrapWidth
local function WrapLine(text)
	local start = strfind(text, '[ -.,;]', -wrapWidth)
	if start then
		text = WrapLine(strsub(text, 1, start-1)) .. '\n' .. strsub(text, start)
	end
	return text
end
local function WrapText(text, maxChars)
	wrapWidth = maxChars
	text = strrev(text)
	text = text:gsub('([^\n]+)', WrapLine)
	text = strrev(text)
	return text
end

local function ShowTooltip(self)
	if not self.tiptext and not self.link then return end
	GameTooltip:SetOwner(self, 'ANCHOR_RIGHT')
	GameTooltip:SetText(self.tiptext, nil, nil, nil, nil, true)
	GameTooltip:Show()
end

local function OnLDBEnter() end
local function SortGuildList(self, sortType, btn, up)
	SortGuildRoster(sortType)
	OnLDBEnter()
end

local function OnCharacterClick(self, character, btn, up)
	local contactType, contactInfo = strsplit(':', character)
	if IsAltKeyDown() then
		-- invite
		if contactType == 'bnet' then
			-- contactInfo contains presenceID
			local friendIndex = BNGetFriendIndex(contactInfo)
			contactInfo = nil

			local toonName, realmName, faction, client
			for toonIndex = 1, BNGetNumFriendGameAccounts(friendIndex) do
				_, toonName, client, realmName, _, faction = BNGetFriendGameAccountInfo(friendIndex, toonIndex)
				if client == BNET_CLIENT_WOW and faction == playerFaction then
					contactInfo = toonName .. '-' .. realmName
					break
				end
			end
		end
		if contactInfo and contactInfo ~= '' then
			InviteUnit(contactInfo)
		end
	elseif IsControlKeyDown() then
		-- edit notes
		if contactType == 'guild' then
			for index = 1, GetNumGuildMembers() do
				local name = GetGuildRosterInfo(index)
				if name == contactInfo then
					SetGuildRosterSelection(index)
					break
				end
			end
			if btn == 'RightButton' and CanEditOfficerNote() then
				StaticPopup_Show('SET_GUILDOFFICERNOTE')
			elseif CanEditPublicNote() then
				StaticPopup_Show('SET_GUILDPLAYERNOTE')
			end
		elseif contactType == 'friend' then
			for index = 1, select(2, GetNumFriends()) do
				local name = GetFriendInfo(index)
				if name == contactInfo then
					FriendsFrame.NotesID = index
					break
				end
			end
			StaticPopup_Show('SET_FRIENDNOTE', GetFriendInfo(FriendsFrame.NotesID))
		elseif contactType == 'bnet' then
			FriendsFrame.NotesID = contactInfo
			StaticPopup_Show('SET_BNFRIENDNOTE')
		end
	else
		-- whisper and /who
		local prefix = 'player:'
		if contactType == 'bnet' then
			local friendIndex = BNGetFriendIndex(contactInfo)
			local presenceID, presenceName = BNGetFriendInfo(friendIndex)
			contactInfo = presenceName..':'..presenceID
			prefix = 'BN'..prefix
		end
		SetItemRef(prefix..contactInfo, '|H'..prefix..contactInfo..'|h['..contactInfo..']|h', 'LeftButton')
	end
end

local function TooltipAddBNetContacts(tooltip)
	local _, numBNetOnline = BNGetNumFriends()
	local numColumns, lineNum = tooltip:GetColumnCount()
	local currentBNContact

	if numBNetOnline > 0 then
		tooltip:SetCell(tooltip:AddHeader(), 1, _G.FRIENDS, 'LEFT', numColumns)
	end

	for friendIndex = 1, numBNetOnline do
		local presenceID, presenceName, battleTag, isBattleTag, toonName, toonID, client, isOnline, lastOnline, isAFK, isDND, broadcastText, noteText = BNGetFriendInfo(friendIndex)
		local status = isAFK and icons[CHAT_FLAG_AFK] or isDND and icons[CHAT_FLAG_DND] or ''
		broadcastText = (broadcastText and broadcastText ~= '') and broadcastText or nil

		local numToons = BNGetNumFriendGameAccounts(friendIndex) or 0
		if client == BNET_CLIENT_APP and numToons <= 1 then
			lineNum = tooltip:AddLine(status, BNet_GetClientEmbeddedTexture(client, 0), presenceName)
			tooltip:SetLineScript(lineNum, 'OnMouseUp', OnCharacterClick, ('bnet:%s'):format(presenceID))
		else
			for toonIndex = 1, numToons do
				local _, toonName, client, realmName, _, faction, race, class, _, zoneName, level, gameText = BNGetFriendGameAccountInfo(friendIndex, toonIndex)
				if client  ~= BNET_CLIENT_APP then
					realmName = (realmName or '') ~= '' and realmName or nil
					zoneName  = (zoneName  or '') ~= '' and  zoneName or nil
					gameText  = (gameText  or '') ~= '' and  gameText or nil
					noteText  = (noteText  or '') ~= '' and  noteText or nil

					local friendName = client == BNET_CLIENT_HEROES and presenceName or toonName
					if class and classColors[class] then
						friendName = RGBTableToColorCode(classColors[class])..toonName..'|r'
					end
					local infoText = noteText and (icons['NOTE']..noteText) or (icons['CONTACT']..presenceName)

					lineNum = tooltip:AddLine(status, BNet_GetClientEmbeddedTexture(client, 0),
						friendName .. (broadcastText and (' '..icons['BROADCAST']) or ''),
						nil, nil, infoText)

					if client == BNET_CLIENT_WOW then
						level = RGBTableToColorCode(GetQuestDifficultyColor(tonumber(level or '') or 0))..level..'|r'
						if not realmName and not zoneName and gameText then
							zoneName, realmName = strsplit('-', gameText)
							zoneName, realmName = zoneName and zoneName:trim() or '', realmName and realmName:trim() or ''
						end

						local color = (faction == 'Horde' and RED_FONT_COLOR_CODE)
							or (faction == 'Alliance' and BATTLENET_FONT_COLOR_CODE) or ''
						tooltip:SetCell(lineNum, 2, level)
						tooltip:SetCell(lineNum, 4, color .. realmName .. '|r')
						tooltip:SetCell(lineNum, 5, zoneName)
					else
						tooltip:SetCell(lineNum, 4, gameText, 2)
					end

					if broadcastText then
						tooltip.lines[lineNum].tiptext = broadcastText
						tooltip:SetLineScript(lineNum, 'OnEnter', ShowTooltip)
						tooltip:SetLineScript(lineNum, 'OnLeave', GameTooltip_Hide)
					end

					if realmName == playerRealm and faction == playerFaction then
						tooltip:SetLineScript(lineNum, 'OnMouseUp', OnCharacterClick, ('friend:%s'):format(toonName))
					else
						tooltip:SetLineScript(lineNum, 'OnMouseUp', OnCharacterClick, ('bnet:%s'):format(presenceID))
					end
				end
			end
		end
	end

	return numBNetOnline
end

local function TooltipAddContacts(tooltip, needsSeparator)
	local _, numFriendsOnline = GetNumFriends()
	local numColumns, lineNum = #tooltip.columns

	for index = 1, numFriendsOnline do
		if index == 1 then
			if needsSeparator then
				tooltip:AddLine()
				-- tooltip:AddSeparator(2)
			else
				tooltip:SetCell(tooltip:AddHeader(), 1, _G.FRIENDS, 'LEFT', numColumns)
			end
		end
		local name, level, class, area, connected, status, note, RAF = GetFriendInfo(index)

		local status     = icons[status] or ''
		local levelColor = GetQuestDifficultyColor(level)
		local classColor = classColors[class]
		local inMyGroup  = UnitInParty(name) or UnitPlayerOrPetInRaid(name)

		lineNum = tooltip:AddLine(
			(inMyGroup and '|TInterface\\Buttons\\UI-CheckBox-Check:0|t ' or '') .. status,
			colorFormat:format(levelColor.r*255, levelColor.g*255, levelColor.b*255, level),
			colorFormat:format(classColor.r*255, classColor.g*255, classColor.b*255, name),
			'',
			area,
			note
		)
		tooltip:SetLineScript(lineNum, 'OnMouseUp', OnCharacterClick, ('friend:%s'):format(name))
	end
	return numFriendsOnline
end

local function TooltipAddGuildMembers(tooltip, needsSeparator)
	GuildRoster() -- need this so GetGuildRosterInfo returns live data

	local guildName = GetGuildInfo('player')
	local numColumns, lineNum = tooltip:GetColumnCount()

	if guildName then
		if needsSeparator then
			lineNum = tooltip:AddLine()
			-- tooltip:AddSeparator(2)
		end
		tooltip:SetCell(tooltip:AddHeader(), 1, guildName or '', 'LEFT', numColumns)

		local guildMOTD = GetGuildRosterMOTD()
		if guildMOTD then
			guildMOTD = guildMOTD:gsub('(%s%s+)', '\n')
			guildMOTD = WrapText(guildMOTD, 75)
			tooltip:SetCell(tooltip:AddLine(' '), 1, guildMOTD or '', 'LEFT', numColumns)
		end

		lineNum = tooltip:AddLine()
		lineNum = tooltip:AddLine('', _G.ITEM_LEVEL_ABBR, _G.CALENDAR_EVENT_NAME, _G.RANK, _G.ZONE, _G.LABEL_NOTE)

		-- also available: class, wideName, online, weeklyxp, totalxp, arenarating, bgrating, achievement
		tooltip:SetCellScript(lineNum, 2, 'OnMouseUp', SortGuildList, 'level')
		tooltip:SetCellScript(lineNum, 3, 'OnMouseUp', SortGuildList, 'name')
		tooltip:SetCellScript(lineNum, 4, 'OnMouseUp', SortGuildList, 'rank')
		tooltip:SetCellScript(lineNum, 5, 'OnMouseUp', SortGuildList, 'zone')
		tooltip:SetCellScript(lineNum, 6, 'OnMouseUp', SortGuildList, 'note')
		tooltip:AddSeparator(2)

		local numGuildMembers = GetNumGuildMembers()
		for index = 1, numGuildMembers do
			local fullName, rank, rankIndex, level, class, zone, note, officernote, online, status, classFileName, achievementPoints, achievementRank, isMobile, canSoR, _ = GetGuildRosterInfo(index)
			local name = strsplit('-', fullName)

			if online or isMobile then
				isMobile = isMobile and not online
				status = status == 1 and CHAT_FLAG_AFK or status == 2 and CHAT_FLAG_DND or ''
				status = icons[status] or (isMobile and icons['REMOTE']) or ''
				zone = isMobile and REMOTE_CHAT or zone
				local levelColor = GetQuestDifficultyColor(level)
				local classColor = RAID_CLASS_COLORS[classFileName]
				local inMyGroup  = UnitInParty(name) or UnitPlayerOrPetInRaid(name) -- TODO: check if this still works with 'char-realm'

				note        = note and note ~= '' and (HIGHLIGHT_FONT_COLOR_CODE .. note .. '|r') or ''
				officernote = officernote and officernote ~= '' and (GREEN_FONT_COLOR_CODE .. officernote .. '|r') or nil
				local noteText = note .. (officernote and ' '..officernote or '')

				lineNum = tooltip:AddLine(
					(inMyGroup and '|TInterface\\Buttons\\UI-CheckBox-Check:0|t ' or '') .. status,
					colorFormat:format(levelColor.r*255, levelColor.g*255, levelColor.b*255, level),
					colorFormat:format(classColor.r*255, classColor.g*255, classColor.b*255, name),
					rank,
					zone,
					noteText
				)
				tooltip:SetLineScript(lineNum, 'OnMouseUp', OnCharacterClick, ('guild:%s'):format(fullName))
			end
		end
	end
	return 0
end

local tooltip
local function OnLDBEnter(self)
	if LibQTip:IsAcquired(addonName) then
		tooltip:Clear()
	else
		tooltip = LibQTip:Acquire(addonName, 6)
		tooltip:SmartAnchorTo(self)
		tooltip:SetAutoHideDelay(0.25, self)
		-- tooltip:Clear()
		tooltip:GetFont():SetTextColor(NORMAL_FONT_COLOR.r, NORMAL_FONT_COLOR.g, NORMAL_FONT_COLOR.b)
	end

	-- battle.net friends
	local numBNetOnline = TooltipAddBNetContacts(tooltip)

	-- regular friends
	local numFriendsOnline = TooltipAddContacts(tooltip, numBNetOnline > 0)

	-- guild roster
	local numGuildOnline = TooltipAddGuildMembers(tooltip, numFriendsOnline == 0 or numBNetOnline > 0)

	tooltip:Show()
	-- tooltip:UpdateScrolling(maxHeight)
end

local function OnLDBClick(self, btn, up)
	if btn == 'RightButton' then
		ToggleFriendsFrame(1)
	else
		local _, numFriendsOnline = GetNumFriends()
		local _, _, numGuildMembers = GetNumGuildMembers()

		if numGuildMembers > 1 or numFriendsOnline == 0 then
			ToggleGuildFrame()
		else
			ToggleFriendsFrame(1)
		end
	end
end

local function Update(event)
	local ldb = LDB:GetDataObjectByName(addonName)
	if ldb then
		local text = ''

		local numFriends, numFriendsOnline = GetNumFriends()
		local numBNFriends, numBNFriendsOnline = BNGetNumFriends()
		local numInvites = BNGetNumFriendInvites()
		numFriends = numFriends + numBNFriends
		numFriendsOnline = numFriendsOnline + numBNFriendsOnline

		if numFriends > 0 or numInvites > 0 then
			text = text .. BATTLENET_FONT_COLOR_CODE
				.. numFriendsOnline .. (numInvites > 0 and '+'..numInvites or '')
				.. '/' .. numFriends .. '|r'
		end

		GuildRoster() -- need this so GetGuildRosterInfo returns live data
		local numGuildMembers, numOnline, numOnlineAndMobile = GetNumGuildMembers()
		if numGuildMembers and numGuildMembers > 0 then
			-- show guild info
			text = (text ~= '' and text..' ' or '') .. GREEN_FONT_COLOR_CODE
				.. numOnline .. (numOnlineAndMobile > numOnline and '+'..(numOnlineAndMobile - numOnline) or '')
				.. '/' .. numGuildMembers .. '|r'
		end
		ldb.text = text

		-- update tooltip, if shown
		if LibQTip:IsAcquired(addonName) then
			OnLDBEnter(ldb)
		end
	end
end

-- --------------------------------------------------------

addon:SetScript('OnEvent', function(self, event, ...)
	(self[event] or Update)(self, event, ...)
end)

function addon:NEUTRAL_FACTION_SELECT_RESULT(event)
	playerFaction = UnitFactionGroup('player')
	self:UnregisterEvent(event)
end

function addon:ADDON_LOADED(event, arg1)
	if arg1 ~= addonName then return end
	local ldb = LDB:NewDataObject(addonName, {
		type	= 'data source',
		icon    = 'Interface\\FriendsFrame\\UI-Toast-ChatInviteIcon',
		label	= _G.SOCIAL_LABEL,
		text 	= _G.SOCIAL_LABEL,

		OnClick = OnLDBClick,
		OnEnter = OnLDBEnter,
		OnLeave = function() end,	-- needed for e.g. NinjaPanel
	})

	local classes = {}
	FillLocalizedClassList(classes, false) -- male names
	for class, localizedName in pairs(classes) do
		classColors[localizedName] = RAID_CLASS_COLORS[class]
	end
	FillLocalizedClassList(classes, true) -- female names
	for class, localizedName in pairs(classes) do
		classColors[localizedName] = RAID_CLASS_COLORS[class]
	end

	for _, event in ipairs({'GUILD_ROSTER_UPDATE', 'FRIENDLIST_UPDATE', -- 'IGNORELIST_UPDATE', 'MUTELIST_UPDATE',
		'BN_CONNECTED', 'BN_DISCONNECTED', 'BN_FRIEND_LIST_SIZE_CHANGED',
		'BN_FRIEND_TOON_ONLINE', 'BN_FRIEND_TOON_OFFLINE', 'BN_FRIEND_ACCOUNT_ONLINE', 'BN_FRIEND_ACCOUNT_OFFLINE',
		'BATTLETAG_INVITE_SHOW', 'BN_FRIEND_INVITE_LIST_INITIALIZED', 'BN_FRIEND_INVITE_ADDED', 'BN_FRIEND_INVITE_REMOVED'}) do
		self:RegisterEvent(event)
	end
	self:RegisterEvent('NEUTRAL_FACTION_SELECT_RESULT')
	self:UnregisterEvent('ADDON_LOADED')
end
addon:RegisterEvent('ADDON_LOADED')
