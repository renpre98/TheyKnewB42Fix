require 'NPCs/ZombiesZoneDefinition'

--[[
    They Knew [B42] - 42.19 Fix : Hazmat zombie spawn chance.

    The base mod registers the hazmat outfit in TheyKnew_ZombieDefinition.lua by
    reading SandboxVars.TheyKnew.HazmatSpawnChance on OnPostDistributionMerge.
    On a LOADED save that event fires BEFORE SandboxOptions.load(), so the saved
    value is not available yet and the mod captures the option default (0.3):

        OnPostDistributionMerge  -> reads 0.3   (DING / 0.3 in the log)
        SandboxOptions.load()    -> NOW the saved value (e.g. 20) is applied

    Result: the outfit is registered with a ~0.3% weight, so hazmat zombies
    effectively never spawn. (A freshly created world works because the new-game
    UI pushes the chosen values into SandboxVars before world load. Editing the
    sandbox via the debug tools turns the world into a save that is loaded, which
    is why the bug only shows up afterwards.)

    Fix: re-read the value on OnGameStart, which runs after SandboxOptions.load(),
    and correct the entry the base mod already inserted into
    ZombiesZoneDefinition.Default.
]]

local function TheyKnewFix_ApplyHazmatChance()
	if not ZombiesZoneDefinition or not ZombiesZoneDefinition.Default then return end
	if not SandboxVars.TheyKnew then return end
	local chance = SandboxVars.TheyKnew.HazmatSpawnChance
	if chance == nil then return end

	local found = false
	for _, entry in ipairs(ZombiesZoneDefinition.Default) do
		if entry.name == "TheyKnew_Hazmat" then
			entry.chance = chance
			found = true
		end
	end
	if not found then
		table.insert(ZombiesZoneDefinition.Default, { name = "TheyKnew_Hazmat", chance = chance })
	end
	print("[TheyKnew Fix] Hazmat spawn chance applied: " .. tostring(chance))
end

if isServer() then
	-- On a dedicated server the base reads at OnServerStarted (after sandbox load),
	-- so the value is usually correct there; re-applying is harmless.
	Events.OnServerStarted.Add(TheyKnewFix_ApplyHazmatChance)
else
	-- Single-player / host: OnGameStart fires after SandboxOptions.load().
	Events.OnGameStart.Add(TheyKnewFix_ApplyHazmatChance)
end
