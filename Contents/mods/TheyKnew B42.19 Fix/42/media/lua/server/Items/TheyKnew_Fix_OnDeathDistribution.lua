--[[
    They Knew [B42] - 42.19 Fix
    Hazmat zombie death loot: multiplayer duplication fix.

    PROBLEM
    Project Zomboid loads media/lua/server/ on multiplayer CLIENTS as well
    (GameLoadingState.enter() calls LuaManager.LoadDirBase("server")
    unconditionally). The base mod's TheyKnew_OnDeathDistribution.Lua therefore
    hooks OnZombieDead on the server AND on every client, and IsoZombie.onKilled
    triggers that event on both sides.

    Each side then rolls its own ZombRand and calls inv:AddItems() on its own
    copy of the zombie inventory, so the loot roll happens twice:

        server roll hit + client roll hit  -> corpse shows 2 ampules,
                                              only 1 of them is real
        server roll miss + client roll hit -> corpse shows 1 ampule that does
                                              not exist and cannot be taken

    The client-side item is a phantom: it lives only in the client's local
    inventory object, the server knows nothing about it, so it cannot be looted
    and it can leak into the player's own corpse container after a local
    inventory move.

    Vanilla guards the same code path explicitly - IsoZombie.onKilled only calls
    DoZombieInventory() when GameClient.client is false.

    FIX
    Unhook the base mod's CheckDrops and do the roll once, authoritatively, on
    the server (or in singleplayer). Clients receive the corpse contents from
    the server as usual. A modData flag additionally guards against the event
    firing more than once for the same zombie.

    The drop chances and the ZombRand(1, 100) roll are kept identical to the
    base mod so loot rates do not change.
]]

local HAZMAT_OUTFIT = "TheyKnew_Hazmat"

local function TheyKnewFix_Roll(inv, chance, itemType)
	if chance == nil or chance <= 0 then return end
	if chance >= ZombRand(1, 100) then
		inv:AddItems(itemType, 1)
	end
end

-- Authoritative replacement for the base mod's CheckDrops().
function TheyKnewFix_CheckDrops(zombie)
	-- Server / singleplayer only. On a multiplayer client this would create
	-- phantom items that the server does not know about.
	if isClient() then return end
	if zombie == nil then return end
	if not instanceof(zombie, "IsoZombie") then return end

	local outfit = zombie:getOutfitName()
	if not outfit or tostring(outfit) ~= HAZMAT_OUTFIT then return end

	-- Guard against OnZombieDead firing twice for the same zombie.
	local modData = zombie:getModData()
	if modData.TheyKnewFix_DropsRolled then return end
	modData.TheyKnewFix_DropsRolled = true

	local inv = zombie:getInventory()
	if inv == nil then return end

	local base = SandboxVars.TheyKnew
	if base then
		TheyKnewFix_Roll(inv, base.ZomboxoloneLootChance, "TheyKnew.Zomboxolone")
		TheyKnewFix_Roll(inv, base.ZomboxycyclineLootChance, "TheyKnew.Zomboxycycline")
		TheyKnewFix_Roll(inv, base.ZomboxivirLootChance, "TheyKnew.Zomboxivir")
	end

	local fix = SandboxVars.TheyKnewFix
	if fix then
		TheyKnewFix_Roll(inv, fix.TestKitLootChance, "TheyKnew.ViralTestingKit")
	end
end

-- Drop the base mod's handler (and the fix's own older handler, in case an
-- outdated compiled copy is still registered). Both are plain globals, so the
-- registered function references are still reachable by name.
local function TheyKnewFix_UnhookBaseDrops()
	if CheckDrops ~= nil then
		Events.OnZombieDead.Remove(CheckDrops)
	end
	if CheckDrops_TKF ~= nil then
		Events.OnZombieDead.Remove(CheckDrops_TKF)
	end
end

TheyKnewFix_UnhookBaseDrops()
Events.OnZombieDead.Add(TheyKnewFix_CheckDrops)

-- Re-run the unhook once everything is loaded, in case this file was loaded
-- before the base mod's file for any reason. Remove() on a handler that is not
-- registered is a no-op, so this is safe to repeat.
if isServer() then
	Events.OnServerStarted.Add(TheyKnewFix_UnhookBaseDrops)
else
	Events.OnGameStart.Add(TheyKnewFix_UnhookBaseDrops)
end
