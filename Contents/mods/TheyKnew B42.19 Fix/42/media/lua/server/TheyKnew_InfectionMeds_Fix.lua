--[[
    They Knew [B42] - 42.19 Fix
    InfectionMeds compatibility patch.

    Build 42 removed BodyDamage:setInfectionLevel(float). The original mod still
    calls it in several places, which throws "Object tried to call nil" and aborts
    the eat/buff action (see TheyKnew_InfectionMeds.lua:94 -> OnEat_Zomboxivir).

    This file loads after the base mod (require=\TheyKnewB42) and overrides the
    affected functions in the shared TheyKnew table. The broken setInfectionLevel
    calls are simply dropped; infection is fully cleared by setInfected(false),
    setInfectionTime(-1), setInfectionMortalityDuration(-1) and per-bodypart
    SetInfected(false), all of which still exist in B42.

    In addition, the visible infection counter is the ZOMBIE_INFECTION /
    ZOMBIE_FEVER character stats (the health panel reads ZOMBIE_FEVER, and
    getApparentInfectionLevel() = max(ZOMBIE_FEVER, ZOMBIE_INFECTION, FOOD_SICKNESS)).
    setInfected(false) only stops these stats from growing, it does not reset them,
    so the counter froze instead of dropping to 0. The old setInfectionLevel(0) used
    to clear it. TheyKnew.ResetInfectionStats() restores that behaviour for B42.
]]

if TheyKnew == nil then TheyKnew = {} end

-- Zero out the stats that drive the visible infection counter.
TheyKnew.ResetInfectionStats = function (player)
	local stats = player:getStats()
	if stats == nil then return end
	stats:set(CharacterStat.ZOMBIE_INFECTION, 0)
	stats:set(CharacterStat.ZOMBIE_FEVER, 0)
end

TheyKnew.ZomboxoloneTakePills = function (food, player, percent)
	local bodyDamage = player:getBodyDamage()
	local infected = bodyDamage:IsInfected()
	if infected then
		bodyDamage:setInfected(true)
		bodyDamage:setInfectionMortalityDuration(-1)
		bodyDamage:setInfectionTime(-1)
		local bodyParts = bodyDamage:getBodyParts()
		for i=bodyParts:size()-1, 0, -1  do
			local bodyPart = bodyParts:get(i)
			bodyPart:SetInfected(true)
		end
		bodyDamage:setInfected(true)
		HaloTextHelper.addText(player, getText("UI_ZomboxoloneBuff"))
	else
		HaloTextHelper.addBadText(player, getText("UI_ZomboxoloneNotInfected"))
	end
end

TheyKnew.ZomboxycyclineBuff = function (player)
	local playerdata = player:getModData()
	local playerBody = player:getBodyDamage()
	local infectionStatus = playerBody:IsInfected()
	if playerdata.ZomboxycyclineHours > 0 and infectionStatus and not playerdata.ShouldBeInfected then
		print("Player Infected, Zomboxycycline taking effect.")
		local bodyParts = playerBody:getBodyParts()
		for i=bodyParts:size()-1, 0, -1  do
			local bodyPart = bodyParts:get(i)
			bodyPart:SetInfected(false)
		end
		playerBody:setInfected(false)
		playerBody:setInfectionTime(-1)
		TheyKnew.ResetInfectionStats(player)
		--verify
		if playerBody:IsInfected() == false then
			print("Infection Removed")
		end
	end
end

TheyKnew.OnEat_Zomboxivir = function (food, player, percent)
	local playerdata = player:getModData()
	local bodyDamage = player:getBodyDamage();
	bodyDamage:setInfected(false);
	bodyDamage:setInfectionMortalityDuration(-1);
	bodyDamage:setInfectionTime(-1);
	local bodyParts = bodyDamage:getBodyParts();
	for i=bodyParts:size()-1, 0, -1  do
		local bodyPart = bodyParts:get(i);
		bodyPart:SetInfected(false);
	end
	bodyDamage:setInfected(false);
	TheyKnew.ResetInfectionStats(player);
	--verify
	if bodyDamage:IsInfected() == false then
		print("Infection Removed");
	end
	--case for Zomboxydine
	if playerdata.ShouldBeInfected ~= nil then
		playerdata.ShouldBeInfected = false;
	end
end

TheyKnew.OnEat_ViralTestingStrip = function (food, player, percent)
	print("Testing for Knox Infection...");
	local playerBody = player:getBodyDamage();
	local infectionStatus = playerBody:IsInfected();
	if infectionStatus then
		print("Player is infected.");
		local item = player:getInventory():AddItem("TheyKnew.ViralTestingStripPositive");
	else
		print("Player is not infected.");
		local item = player:getInventory():AddItem("TheyKnew.ViralTestingStripNegative");
	end
		
end