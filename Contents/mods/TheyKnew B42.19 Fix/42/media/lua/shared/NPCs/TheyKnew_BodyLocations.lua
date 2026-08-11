local group = BodyLocations.getGroup("Human")

local back2 = ItemBodyLocation.get(ResourceLocation.of("theyknew:Back2")) or ItemBodyLocation.register("theyknew:Back2")
group:getOrCreateLocation(back2)