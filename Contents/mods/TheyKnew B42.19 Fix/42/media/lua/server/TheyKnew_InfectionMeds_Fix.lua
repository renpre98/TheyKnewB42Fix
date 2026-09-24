--[[
    They Knew [B42] - 42.19 Fix
    InfectionMeds compatibility patch.

]]

if TheyKnew == nil then TheyKnew = {} end

-- BodyPartSyncPacket.BD_IsInfected
local BD_IsInfected = 512

-- Capture the base mod's handlers before we overwrite the table entries, so we
-- can unregister exactly those functions later.
local baseMonitorBuffs = TheyKnew.MonitorBuffs
local baseBuffTick = TheyKnew.BuffTick

-- Players this side of the connection is responsible for.
local function TheyKnewFix_ForEachPlayer(fn)
	if isServer() then
		local players = getOnlinePlayers()
		if players == nil then return end
		for i = 0, players:size() - 1 do
			local player = players:get(i)
			if player ~= nil and not player:isDead() then fn(player) end
		end
	else
		for i = 0, getNumActivePlayers() - 1 do
			local player = getSpecificPlayer(i)
			if player ~= nil and not player:isDead() then fn(player) end
		end
	end
end

-- Server -> owning client push for the two stats that drive the counter.
local function TheyKnewFix_SyncInfectionStats(player)
	if not isServer() then return end
	if syncPlayerStats == nil or SyncPlayerStatsPacket == nil then return end
	if not player:isExistInTheWorld() then return end
	local mask = SyncPlayerStatsPacket.getBitMaskForStat(CharacterStat.ZOMBIE_INFECTION)
		+ SyncPlayerStatsPacket.getBitMaskForStat(CharacterStat.ZOMBIE_FEVER)
	syncPlayerStats(player, mask)
end

-- Server -> owning client push for a single body part's infection flag.
local function TheyKnewFix_SyncBodyPart(bodyPart)
	if not isServer() then return end
	if syncBodyPart == nil then return end
	syncBodyPart(bodyPart, BD_IsInfected)
end

-- Zero out the stats that drive the visible infection counter.
TheyKnew.ResetInfectionStats = function (player)
	local stats = player:getStats()
	if stats == nil then return end
	stats:set(CharacterStat.ZOMBIE_INFECTION, 0)
	stats:set(CharacterStat.ZOMBIE_FEVER, 0)
end

-- Full cure. Mirrors what BodyDamage.RestoreToFullHealth() does for infection.
TheyKnew.ClearInfection = function (player)
	local bodyDamage = player:getBodyDamage()
	local bodyParts = bodyDamage:getBodyParts()
	for i = bodyParts:size() - 1, 0, -1 do
		local bodyPart = bodyParts:get(i)
		if bodyPart:IsInfected() then
			bodyPart:SetInfected(false)
			TheyKnewFix_SyncBodyPart(bodyPart)
		end
	end
	bodyDamage:setInfected(false)
	bodyDamage:setInfectionTime(-1)
	bodyDamage:setInfectionMortalityDuration(-1)
	TheyKnew.ResetInfectionStats(player)
	TheyKnewFix_SyncInfectionStats(player)
end

TheyKnew.ZomboxoloneTakePills = function (food, player, percent)
	local bodyDamage = player:getBodyDamage()
	if bodyDamage:IsInfected() then
		-- Stays infected on purpose: -1 makes BodyDamage.Update() restart the
		-- mortality clock (GameTime.checkHours(-1, now) == now) and re-roll the
		-- duration, which is what "buys you more time" means here.
		bodyDamage:setInfected(true)
		bodyDamage:setInfectionMortalityDuration(-1)
		bodyDamage:setInfectionTime(-1)
		local bodyParts = bodyDamage:getBodyParts()
		for i = bodyParts:size() - 1, 0, -1 do
			bodyParts:get(i):SetInfected(true)
		end
		bodyDamage:setInfected(true)
		if not isServer() then
			HaloTextHelper.addText(player, getText("UI_ZomboxoloneBuff"))
		end
	elseif not isServer() then
		HaloTextHelper.addBadText(player, getText("UI_ZomboxoloneNotInfected"))
	end
end

-- Arms the 24 in-game-hour prophylactic. Defined here (not only in the base
-- mod's client file) so the dedicated server has it when Eat() looks it up.
TheyKnew.ZomboxycyclineTakePills = function (food, player, percent)
	local playerdata = player:getModData()
	playerdata.ZomboxycyclineHours = 24
	playerdata.Zomboxycycline = true
	-- An infection the player already had is not cured by this pill.
	playerdata.ShouldBeInfected = player:getBodyDamage():IsInfected()
	if not isServer() then
		HaloTextHelper.addText(player, getText("UI_ZomboxycyclineBuff"))
	end
end

TheyKnew.ZomboxycyclineBuff = function (player)
	local playerdata = player:getModData()
	local playerBody = player:getBodyDamage()
	if (playerdata.ZomboxycyclineHours or 0) > 0
		and playerBody:IsInfected()
		and not playerdata.ShouldBeInfected then
		print("Player Infected, Zomboxycycline taking effect.")
		TheyKnew.ClearInfection(player)
		--verify
		if playerBody:IsInfected() == false then
			print("Infection Removed")
		end
	end
end

TheyKnew.MonitorBuffs = function (player)
	if player == nil then return end
	local playerdata = player:getModData()
	--Sanity Check
	if playerdata.ZomboxoloneHours == nil then
		playerdata.ZomboxoloneHours = 0
	end
	if playerdata.ZomboxycyclineHours == nil then
		playerdata.ZomboxycyclineHours = 0
	end
	if playerdata.ZomboxycyclineHours > 0 then
		TheyKnew.ZomboxycyclineBuff(player)
	end
end

TheyKnew.RemoveBuff = function (_buff, _player)
	local playerdata = _player:getModData()
	playerdata[_buff] = false
	if not isServer() then
		HaloTextHelper.addBadText(_player, getText(string.format("UI_%sBuffExpire", _buff)))
	end
end

TheyKnew.BuffTickForPlayer = function (player)
	local playerdata = player:getModData()
	local hours = playerdata.ZomboxycyclineHours
	if hours ~= nil and hours > 0 then
		hours = hours - 1
		playerdata.ZomboxycyclineHours = hours
		if hours > 0 then
			print("Zomboxycycline is still active.")
		else
			-- Do not leave a stale ShouldBeInfected behind: it would block the
			-- next dose from ever curing anything.
			playerdata.ShouldBeInfected = nil
			if playerdata.Zomboxycycline == true then
				TheyKnew.RemoveBuff("Zomboxycycline", player)
			end
		end
	end
end

-- Replaces the base mod's BuffTick(), which used getPlayer() and therefore
-- could not work on a server.
TheyKnew.BuffTick = function ()
	TheyKnewFix_ForEachPlayer(TheyKnew.BuffTickForPlayer)
end

TheyKnew.OnEat_Zomboxivir = function (food, player, percent)
	local playerdata = player:getModData()
	TheyKnew.ClearInfection(player)
	--verify
	if player:getBodyDamage():IsInfected() == false then
		print("Infection Removed")
	end
	--case for Zomboxydine
	if playerdata.ShouldBeInfected ~= nil then
		playerdata.ShouldBeInfected = false
	end
end

TheyKnew.OnEat_ViralTestingStrip = function (food, player, percent)
	-- In multiplayer OnEat runs on the server (from Eat()) and again on the
	-- client (from EatOnClient()). Only the server may create the result strip,
	-- otherwise the client adds a second, phantom one that the server does not
	-- know about and that cannot be picked up again.
	if isClient() then return end
	print("Testing for Knox Infection...")
	local infected = player:getBodyDamage():IsInfected()
	if infected then
		print("Player is infected.")
	else
		print("Player is not infected.")
	end
	local inventory = player:getInventory()
	local item = inventory:AddItem(infected
		and "TheyKnew.ViralTestingStripPositive"
		or "TheyKnew.ViralTestingStripNegative")
	if isServer() and item ~= nil then
		sendAddItemToContainer(inventory, item)
	end
end

-- The base mod drives the buff from Events.OnPlayerUpdate, which a dedicated
-- server never fires, and from an EveryHours handler that uses getPlayer().
-- Drop both and run our own on every side.
local function TheyKnewFix_UnhookBaseBuffs()
	if baseMonitorBuffs ~= nil then
		Events.OnPlayerUpdate.Remove(baseMonitorBuffs)
	end
	if baseBuffTick ~= nil then
		Events.EveryHours.Remove(baseBuffTick)
	end
end

local function TheyKnewFix_MonitorTick()
	TheyKnewFix_ForEachPlayer(TheyKnew.MonitorBuffs)
end

TheyKnewFix_UnhookBaseBuffs()
Events.OnTick.Add(TheyKnewFix_MonitorTick)
Events.EveryHours.Add(TheyKnew.BuffTick)

-- Remove() on a handler that is not registered is a no-op, so repeating the
-- unhook once everything is loaded is safe.
if isServer() then
	Events.OnServerStarted.Add(TheyKnewFix_UnhookBaseBuffs)
else
	Events.OnGameStart.Add(TheyKnewFix_UnhookBaseBuffs)
end
