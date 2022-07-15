require "ABPretty"

-- chances out of 100000 enables fractional chances. Chances passed to abch/AB_get_chance are still out of 100
ABLoot_DIVISOR = 100000
AB_LOOT_PLUGINS = {}

local DEBUG = false

-- provided `chance`, a double representing the chance out of 100 (which can be a decimal between 0 and 1),
-- return an integer chance out of 100,000 (ABLoot_DIVISOR) with mod multipliers applied.
-- sandboxMultiplier is a percentage integer to apply where 100 is 100% or 1x, 200 is 200% or 2x, etc
function AB_get_chance(chance, multiplier1, multiplier2)
  local globalMultiplier = SandboxVars.AirbobbelzLoot.GlobalMultiplier or 100
  local baseChance = chance * (ABLoot_DIVISOR / 100)
  if multiplier1 ~= nil then
    baseChance = baseChance * (multiplier1 / 100)
  end
  if multiplier2 ~= nil then
    baseChance = baseChance * (multiplier2 / 100)
  end
  return baseChance * (globalMultiplier / 100)
end

-- shortcut
local abch = AB_get_chance

-- why is this not built into lua?
-- https://stackoverflow.com/questions/1426954/split-string-in-lua
local function split(inputstr, sep)
  if sep == nil then
    sep = "%s"
  end
  local t = {}
  for str in string.gmatch(inputstr, "([^" .. sep .. "]+)") do
    table.insert(t, str)
  end
  return t
end

local function unserializeCustomItem(itemString)
  local splitByComma = split(itemString, ",")
  -- item string
  local item = nil
  -- chance to roll item
  local chance = 1 -- default 1%
  -- number of additional items (same as parent item) to roll
  local more = 0
  -- chance of each individual additional item
  local moreChance = 50 -- default 50%
  for _, block in pairs(splitByComma) do
    local splitByCol = split(block, ":")
    local k = splitByCol[1]
    local v = splitByCol[2]
    if k and v ~= nil then
      if k == "item" then
        item = v
      end
      if k == "chance" then
        chance = tonumber(v)
      end
      if k == "more" then
        more = tonumber(v)
      end
      if k == "moreChance" then
        moreChance = tonumber(v)
      end
    end
  end

  local myItem = {
    item = item,
    chance = abch(chance, SandboxVars.AirbobbelzLoot.ExtraMultiplier)
  }

  if more and more > 0 then
    myItem.alsoRollEach = {
      {
        item = item,
        chance = abch(moreChance),
        times = more
      }
    }
  end

  return myItem
end

-- build a table of items and chances from a serialized string representing that table
-- ie
-- Base.Axe:0.1;Crowbar:2;Paper:0.001
-- becomes
-- { {item="Base.Axe", chance=abch(0.1,ExtraMultiplier)}, {item="Crowbar", chance=abch(2,ExtraMultiplier)}, {item="Newspaper", chance=abch(0.001,ExtraMultiplier)} }
-- AND
-- item:Base.Axe,chance:0.1;item:Newspaper,chance:0.001,more:10,,moreChance:50
-- becomes
-- { {item="Base.Axe",chance=0.1 }, {item="Newspaper", chance=0.001, alsoRollEach={{ item="Newspaper", chance=50, times=10 }}}}
--
-- both 'item formats' are acceptable
local function unserializePairs(str)
  if string.len(str) == 0 then
    return {}
  end

  local splitString = split(str, ";")
  local mytable = {}
  for _, v in pairs(splitString) do
    if string.find(v, ",") then
      -- if extra format: item:Money,chance:1,more:10,moreChance:50
      local customItem = unserializeCustomItem(v)
      if customItem.item and customItem.chance then
        table.insert(mytable, customItem)
      else
        print("AB Loot -- invalid custom item: " .. v)
      end
    elseif string.find(v, ":") then
      -- if simple format: Money:1
      local kv = split(v, ":")
      if kv[1] and kv[2] ~= nil then
        table.insert(
          mytable,
          {item = kv[1], chance = abch(tonumber(kv[2]), SandboxVars.AirbobbelzLoot.ExtraMultiplier)}
        )
      else
        print("AB Loot -- invalid custom item: " .. v)
      end
    end
  end
  return mytable
end

-- mutates t1 by appending all of t2's values into t1
function AB_merge_into(t1, t2)
  for _, v in pairs(t2) do
    t1[#t1 + 1] = v
  end
end

-- given a vanilla distro such as those in SuburbsDistributions,
-- build an item list read by this mod
-- accepts a multiplier (100 = 1x, 200 = 2x, 50 = 0.5x etc) to apply to each item in the returned distro
function AB_get_distro_for_vanilla_table(vanillaTable, multiplier)
  local rolls = vanillaTable.rolls
  local items = vanillaTable.items
  local myDistro = {}

  for i, itemName in pairs(items) do
    if i % 2 == 1 then
      -- vanilla tables alternate between item name and its chance
      local itemChance = items[i + 1]
      if itemChance > 0 then
        myDistro[#myDistro + 1] = {
          item = itemName,
          chance = abch(itemChance, multiplier)
        }
      end
    end
  end

  return myDistro
end

local LootTables = nil

function AB_is_valid_item(itemString)
  -- special item strings
  if itemString == "[LOOSE_BULLETS]" then
    return true
  end
  if itemString == "[GUN_MAG]" then
    return true
  end
  local createdItem = InventoryItemFactory.CreateItem(itemString)
  return createdItem ~= nil
end

local function getItemRemovalMap()
  local RemoveItems = SandboxVars.AirbobbelzLoot.RemoveItems or ""
  local removeItemsMap = {}
  for _, itemCode in pairs(split(RemoveItems, ";")) do
    removeItemsMap[itemCode] = true
  end
  return removeItemsMap
end

function AB_table_cleanup(distroTable, removeItemsMap)
  local newTable = {}
  for index, value in pairs(distroTable) do
    if type(value) == "table" then
      if value.item ~= nil then
        if AB_is_valid_item(value.item) and removeItemsMap[value.item] == nil then
          -- if item is valid, add it to the new table.
          -- use table.insert here instead of using index because items always
          -- appear in indexed arrays and should be added sequentially
          table.insert(newTable, AB_table_cleanup(value, removeItemsMap))
        else
          -- if item wasn't valid or in the removal map, just don't re-add it
          if DEBUG then
            print("AB LOOT -- cleaning up invalid item: " .. value.item)
          end
        end
      else
        newTable[index] = AB_table_cleanup(value, removeItemsMap)
      end
    else
      newTable[index] = value
    end
  end
  return newTable
end

-- where items is a collection of item names, get a distribution
-- of each of those items, each with the same chance as `chance`,
-- `chance` should already be passed through `abch()`
local function multiplyDistro(items, chance)
  local finalDistro = {}
  for _, item in pairs(items) do
    finalDistro[#finalDistro + 1] = {
      item = item,
      chance = chance
    }
  end
  return finalDistro
end

function ABGetLootTables()
  if LootTables == nil then
    local AmmoMultiplier = SandboxVars.AirbobbelzLoot.AmmoMultiplier or 100
    local AmmoBoxMultiplier = SandboxVars.AirbobbelzLoot.AmmoBoxMultiplier or 100
    local MeleeMultiplier = SandboxVars.AirbobbelzLoot.MeleeMultiplier or 100
    local PistolMultiplier = SandboxVars.AirbobbelzLoot.PistolMultiplier or 100
    local LongGunsMultiplier = SandboxVars.AirbobbelzLoot.LongGunMultiplier or 100
    local CannedFoodMultiplier = SandboxVars.AirbobbelzLoot.CannedFoodMultiplier or 100
    local OtherFoodMultiplier = SandboxVars.AirbobbelzLoot.OtherFoodMultiplier or 100
    local ResourceMultiplier = SandboxVars.AirbobbelzLoot.ResourceMultiplier or 100
    local JunkMultiplier = SandboxVars.AirbobbelzLoot.JunkMultiplier or 100
    local BagMultiplier = SandboxVars.AirbobbelzLoot.BagMultiplier or 100
    local GunBagMultiplier = SandboxVars.AirbobbelzLoot.GunBagMultiplier or 100
    local ExtraMultiplier = SandboxVars.AirbobbelzLoot.ExtraMultiplier or 100
    local OutfitMultiplier = SandboxVars.AirbobbelzLoot.OutfitMultiplier or 100

    local GunLooseBulletsRolls = SandboxVars.AirbobbelzLoot.GunLooseBulletsRolls or 6
    local GunLooseBulletsMultiplier = SandboxVars.AirbobbelzLoot.GunLooseBulletsMultiplier or 100

    local itemSets = {
      -- some items from 'better flashlights' mod
      flashlightsArmy = {"HandTorch", "Torch", "HandTorch_Army2", "HandTorch_Army1"},
      flashlightsRegular = {"HandTorch", "Torch", "Torch1", "Torch2", "Torch3", "Torch7"},
      flashlightsScience = {"HandTorch", "Torch", "Torch1", "Torch2", "Torch3", "Torch7", "BF_EgenerexLite"},
      flashlightsToy = {"Torch4", "Torch5", "Torch6"},
      seeds = {
        "farming.BroccoliBagSeed",
        "farming.CabbageBagSeed",
        "farming.CarrotBagSeed",
        "farming.RedRadishBagSeed",
        "farming.StrewberrieBagSeed",
        "farming.TomatoBagSeed"
      },
      -- compass mod
      compasses = {"CliponCompass", "Compass", "Compass2"},
      chips = {"Crisps", "Crisps2", "Crisps3", "Crisps4"},
      -- porno mags mod
      pornoMags = {"HottieZ", "PornoMag1", "PornoMag2", "PornoMag3", "PornoMag4", "PornoMag5"},
      pop = {"Pop", "Pop2", "Pop3"},
      wine = {"Wine", "Wine2"},
      drugs = {"CheapSpeed", "CokeBaggie"},
      -- leatherdad mod
      multiTools = {"P38", "Leatherdad"},
      cake = {"Cupcake", "ChocoCakes", "CakeSlice", "CakeCarrot", "CakeChocolate", "CakeRedVelvet"},
      donuts = {"DoughnutChocolate", "DoughnutPlain", "DoughnutFrosted", "DoughnutJelly"}
    }

    LootTables = {
      byOutfit = {
        AirCrew = {
          rollEach = {},
          rollOne = {
            multiplyDistro(itemSets.flashlightsArmy, abch(3, OutfitMultiplier, ResourceMultiplier))
          }
        },
        AmbulanceDriver = {
          rollEach = {
            {item = "FirstAidKit", chance = abch(10, OutfitMultiplier, BagMultiplier)},
            {item = "Gloves_Surgical", chance = abch(15, OutfitMultiplier, JunkMultiplier)},
            {item = "Hat_SurgicalMask_Blue", chance = abch(20, OutfitMultiplier, JunkMultiplier)},
            {item = "SutureNeedleHolder", chance = abch(10, OutfitMultiplier, JunkMultiplier)}
          },
          rollOne = {
            multiplyDistro(itemSets.flashlightsRegular, abch(3, OutfitMultiplier, ResourceMultiplier))
          }
        },
        ArmyCamoDesert = {
          rollEach = {
            {item = "TitaniumSpork", chance = abch(5, OutfitMultiplier, JunkMultiplier)},
            {item = "PornoMag6", chance = abch(1, OutfitMultiplier, JunkMultiplier)},
            {item = "PLGR", chance = abch(1, OutfitMultiplier, JunkMultiplier)}
          },
          rollOne = {
            {
              {
                item = "556Bullets",
                chance = abch(15, OutfitMultiplier, AmmoMultiplier),
                alsoRollEach = {
                  {
                    item = "556Bullets",
                    chance = abch(50, GunLooseBulletsMultiplier),
                    times = GunLooseBulletsRolls
                  }
                }
              },
              {item = "556Box", chance = abch(15, OutfitMultiplier, AmmoBoxMultiplier)}
            },
            multiplyDistro(itemSets.flashlightsArmy, abch(3, OutfitMultiplier, ResourceMultiplier)),
            multiplyDistro(itemSets.multiTools, abch(10, OutfitMultiplier, JunkMultiplier))
          }
        },
        ArmyCamoGreen = {
          rollEach = {
            {item = "TitaniumSpork", chance = abch(5, OutfitMultiplier, JunkMultiplier)},
            {item = "PornoMag6", chance = abch(1, OutfitMultiplier, JunkMultiplier)},
            {item = "PLGR", chance = abch(1, OutfitMultiplier, JunkMultiplier)}
          },
          rollOne = {
            {
              {
                item = "556Bullets",
                chance = abch(15, OutfitMultiplier, AmmoMultiplier),
                alsoRollEach = {
                  {
                    item = "556Bullets",
                    chance = abch(50, GunLooseBulletsMultiplier),
                    times = GunLooseBulletsRolls
                  }
                }
              },
              {item = "556Box", chance = abch(15, OutfitMultiplier, AmmoBoxMultiplier)}
            },
            multiplyDistro(itemSets.flashlightsArmy, abch(3, OutfitMultiplier, ResourceMultiplier)),
            multiplyDistro(itemSets.multiTools, abch(10, OutfitMultiplier, JunkMultiplier))
          }
        },
        ArmyServiceUniform = {
          rollEach = {
            {item = "LabKeycard", chance = abch(5, OutfitMultiplier, JunkMultiplier)},
            {item = "IntelFolder", chance = abch(5, OutfitMultiplier, JunkMultiplier)}
          },
          rollOne = {
            multiplyDistro(itemSets.flashlightsArmy, abch(3, OutfitMultiplier, ResourceMultiplier))
          }
          -- example of override for all junk distros when zombie has this outfit
          -- junk = {
          --   rollEach = {
          --     { item = "PaperclipBox", chance = abch(5,OutfitMultiplier) }
          --   }
          -- }
        },
        Bandit = {
          rollEach = {
            {item = "Knuckleduster", chance = abch(10, OutfitMultiplier, MeleeMultiplier)},
            {item = "PornoMag6", chance = abch(5, OutfitMultiplier, JunkMultiplier)},
            {item = "WhiskeyFull", chance = abch(10, OutfitMultiplier, JunkMultiplier)}
          },
          rollOne = {
            multiplyDistro(itemSets.drugs, abch(10, OutfitMultiplier, JunkMultiplier))
          }
        },
        BaseballPlayer_KY = {
          rollEach = {
            {item = "Baseball", chance = abch(10, OutfitMultiplier, JunkMultiplier)}
          }
        },
        BaseballPlayer_Rangers = {
          rollEach = {
            {item = "Baseball", chance = abch(10, OutfitMultiplier, JunkMultiplier)}
          }
        },
        BaseballPlayer_Z = {
          rollEach = {
            {item = "Baseball", chance = abch(10, OutfitMultiplier, JunkMultiplier)}
          }
        },
        Bathrobe = {
          rollEach = {
            {item = "Rubberducky", chance = abch(16, OutfitMultiplier, JunkMultiplier)},
            {item = "Soap2", chance = abch(16, OutfitMultiplier, JunkMultiplier)},
            {item = "Toothbrush", chance = abch(15, OutfitMultiplier, JunkMultiplier)},
            {item = "Toothpaste", chance = abch(15, OutfitMultiplier, JunkMultiplier)},
            {item = "Razor", chance = abch(5, OutfitMultiplier, JunkMultiplier)}
          },
          rollOne = {
            multiplyDistro(itemSets.pornoMags, abch(5, OutfitMultiplier, JunkMultiplier))
          }
        },
        Bedroom = {
          rollEach = {
            {item = "PillsSleepingTablets", chance = abch(10, OutfitMultiplier, JunkMultiplier)},
            {item = "AlarmClock2", chance = abch(10, OutfitMultiplier, JunkMultiplier)}
          }
        },
        Biker = {
          rollEach = {
            {item = "Knuckleduster", chance = abch(10, OutfitMultiplier, MeleeMultiplier)},
            {item = "WhiskeyFull", chance = abch(10, OutfitMultiplier, JunkMultiplier)},
            {item = "Molotov", chance = abch(5, OutfitMultiplier, JunkMultiplier)}
          },
          rollOne = {
            multiplyDistro(itemSets.drugs, abch(15, OutfitMultiplier, JunkMultiplier))
          }
        },
        Camper = {
          rollEach = {
            {item = "FlareGun", chance = abch(5, OutfitMultiplier, JunkMultiplier)},
            {item = "SAK", chance = abch(10, OutfitMultiplier, JunkMultiplier)},
            {item = "TitaniumSpork", chance = abch(10, OutfitMultiplier, JunkMultiplier)},
            {item = "FlintKnife", chance = abch(5, OutfitMultiplier, MeleeMultiplier)},
            {item = "SharpedStone", chance = abch(5, OutfitMultiplier, JunkMultiplier)},
            {item = "AxeStone", chance = abch(5, OutfitMultiplier, MeleeMultiplier)}
          },
          rollOne = {
            multiplyDistro(
              {
                "BerryBlack",
                "BerryBlue",
                "BerryGeneric1",
                "BerryGeneric2",
                "BerryGeneric3",
                "BerryGeneric4",
                "BerryGeneric5"
              },
              abch(8, OutfitMultiplier, OtherFoodMultiplier)
            ),
            multiplyDistro(
              {"PlantainCataplasm", "ComfreyCataplasm", "WildGarlicCataplasm"},
              abch(8, OutfitMultiplier, JunkMultiplier)
            ),
            multiplyDistro(itemSets.compasses, abch(10, OutfitMultiplier, JunkMultiplier)),
            multiplyDistro(itemSets.flashlightsRegular, abch(1, OutfitMultiplier, ResourceMultiplier))
          }
        },
        Classy = {
          rollEach = {},
          rollOne = {
            multiplyDistro(itemSets.wine, abch(5, OutfitMultiplier, OtherFoodMultiplier))
          }
        },
        Cook_Generic = {
          rollEach = {
            {item = "Dishcloth", chance = abch(20, OutfitMultiplier, JunkMultiplier)},
            {item = "Notebook", chance = abch(15, OutfitMultiplier, JunkMultiplier)},
            {item = "Pencil", chance = abch(15, OutfitMultiplier, JunkMultiplier)}
          }
        },
        ConstructionWorker = {
          rollEach = {
            {item = "Measuring_Tape", chance = abch(15, OutfitMultiplier, JunkMultiplier)},
            {item = "MetalSnips", chance = abch(5, OutfitMultiplier, JunkMultiplier)},
            {
              item = "Nails",
              chance = abch(10, OutfitMultiplier, ResourceMultiplier),
              alsoRollEach = {
                {
                  item = "Nails",
                  chance = abch(50),
                  times = 12
                }
              }
            },
            {item = "Pencil", chance = abch(10, OutfitMultiplier, JunkMultiplier)},
            {item = "Pliers", chance = abch(15, OutfitMultiplier, JunkMultiplier)},
            {
              item = "Screws",
              chance = abch(10, OutfitMultiplier, ResourceMultiplier),
              alsoRollEach = {
                {
                  item = "Screws",
                  chance = abch(50),
                  times = 12
                }
              }
            },
            {item = "NailsBox", chance = abch(5, OutfitMultiplier, ResourceMultiplier)}
          },
          rollOne = {
            multiplyDistro(
              {"spraypaint.SpraycanOrange", "spraypaint.SpraycanRed"},
              abch(8, OutfitMultiplier, ResourceMultiplier)
            ),
            {
              {item = "DuctTape", chance = abch(3, OutfitMultiplier, ResourceMultiplier)},
              {item = "Woodglue", chance = abch(3, OutfitMultiplier, ResourceMultiplier)},
              {item = "Glue", chance = abch(6, OutfitMultiplier, ResourceMultiplier)},
              {item = "Scotchtape", chance = abch(6, OutfitMultiplier, ResourceMultiplier)}
            }
          }
        },
        Cyclist = {
          rollEach = {
            {item = "Banana", chance = abch(10, OutfitMultiplier, OtherFoodMultiplier)},
            {item = "Apple", chance = abch(10, OutfitMultiplier, OtherFoodMultiplier)},
            {item = "WaterBottleFull", chance = abch(10, OutfitMultiplier, JunkMultiplier)}
          }
        },
        Doctor = {
          rollEach = {
            {item = "Gloves_Surgical", chance = abch(15, OutfitMultiplier, JunkMultiplier)},
            {item = "Hat_SurgicalMask_Blue", chance = abch(15, OutfitMultiplier, JunkMultiplier)},
            {item = "Lollipop", chance = abch(5, OutfitMultiplier, OtherFoodMultiplier)},
            {item = "Scalpel", chance = abch(5, OutfitMultiplier, MeleeMultiplier)},
            {item = "SutureNeedleHolder", chance = abch(10, OutfitMultiplier, JunkMultiplier)}
          },
          rollOne = {
            multiplyDistro(
              {"SyringeEmpty", "SyringeZombieBlood", "SyringeBlood"},
              abch(5, OutfitMultiplier, JunkMultiplier)
            )
          }
        },
        DressLong = {
          rollEach = {
            {item = "SewingKit", chance = abch(5, OutfitMultiplier, BagMultiplier)},
            {item = "HairDyeBlack", chance = abch(5, OutfitMultiplier, JunkMultiplier)}
          }
        },
        DressNormal = {
          rollEach = {},
          rollOne = {
            multiplyDistro({"HairDyeBlack", "HairDyeBlonde"}, abch(8, OutfitMultiplier, JunkMultiplier))
          }
        },
        DressShort = {
          rollEach = {},
          rollOne = {
            multiplyDistro({"HairDyePink", "HairDyeBlonde"}, abch(8, OutfitMultiplier, JunkMultiplier))
          }
        },
        Farmer = {
          rollEach = {
            {item = "FarmingMag1", chance = abch(5, OutfitMultiplier, JunkMultiplier)},
            {item = "SeedBag", chance = abch(5, OutfitMultiplier, BagMultiplier)}
          },
          rollOne = {
            multiplyDistro(itemSets.seeds, abch(10, OutfitMultiplier, ResourceMultiplier))
          }
        },
        Fireman = {
          rollEach = {
            {item = "Axe", chance = abch(5, OutfitMultiplier, MeleeMultiplier)},
            {item = "Extinguisher", chance = abch(5, OutfitMultiplier, JunkMultiplier)}
          }
        },
        FiremanFullSuit = {
          rollEach = {
            {item = "Axe", chance = abch(5, OutfitMultiplier, MeleeMultiplier)},
            {item = "Extinguisher", chance = abch(5, OutfitMultiplier, JunkMultiplier)},
            {item = "FirstAidKit", chance = abch(8, OutfitMultiplier, BagMultiplier)}
          }
        },
        Foreman = {
          rollEach = {
            {item = "BluePen", chance = abch(15, OutfitMultiplier, JunkMultiplier)},
            {item = "Measuring_Tape", chance = abch(10, OutfitMultiplier, JunkMultiplier)},
            {item = "Notebook", chance = abch(15, OutfitMultiplier, JunkMultiplier)}
          },
          rollOne = {
            {
              {item = "DuctTape", chance = abch(5, OutfitMultiplier, ResourceMultiplier)},
              {item = "Woodglue", chance = abch(5, OutfitMultiplier, ResourceMultiplier)},
              {item = "Glue", chance = abch(8, OutfitMultiplier, ResourceMultiplier)},
              {item = "Scotchtape", chance = abch(8, OutfitMultiplier, ResourceMultiplier)}
            }
          }
        },
        Fisherman = {
          rollEach = {
            {item = "FishingLine", chance = abch(10, OutfitMultiplier, ResourceMultiplier)},
            {item = "FishingNet", chance = abch(5, OutfitMultiplier, ResourceMultiplier)},
            {item = "FishingMag1", chance = abch(5, OutfitMultiplier, JunkMultiplier)},
            {item = "FishingMag2", chance = abch(5, OutfitMultiplier, JunkMultiplier)},
            {item = "FishingTackle", chance = abch(15, OutfitMultiplier, ResourceMultiplier)},
            {item = "FishingTackle2", chance = abch(15, OutfitMultiplier, ResourceMultiplier)}
          }
        },
        FitnessInstructor = {
          rollEach = {
            {item = "DumbBell", chance = abch(10, OutfitMultiplier, MeleeMultiplier)}
          }
        },
        Fossoil = {
          rollEach = {
            {item = "RippedSheetsDirty", chance = abch(15, OutfitMultiplier, JunkMultiplier)}
          }
        },
        Gas2Go = {
          rollEach = {
            {item = "RippedSheetsDirty", chance = abch(15, OutfitMultiplier, JunkMultiplier)}
          }
        },
        Golfer = {
          rollEach = {
            {item = "GolfBall", chance = abch(20, OutfitMultiplier, JunkMultiplier)},
            {item = "Notebook", chance = abch(15, OutfitMultiplier, JunkMultiplier)},
            {item = "Pencil", chance = abch(15, OutfitMultiplier, JunkMultiplier)}
          }
        },
        HazardSuit = {
          rollEach = {
            {item = "LabKeycard", chance = abch(10, OutfitMultiplier, JunkMultiplier)}, -- mod item
            {item = "Scalpel", chance = abch(15, OutfitMultiplier, MeleeMultiplier)}
          },
          rollOne = {
            multiplyDistro(itemSets.flashlightsScience, abch(5, OutfitMultiplier, ResourceMultiplier)),
            multiplyDistro(
              {"SyringeEmpty", "SyringeZombieBlood", "SyringeBlood"}, -- modded
              abch(20, OutfitMultiplier, JunkMultiplier)
            )
          }
        },
        HospitalPatient = {
          rollEach = {
            {item = "BandageDirty", chance = abch(30, OutfitMultiplier, JunkMultiplier), times = 2}
          }
        },
        Hunter = {
          rollEach = {
            {item = "BeefJerky", chance = abch(5, OutfitMultiplier, OtherFoodMultiplier)},
            {item = "Brushkit", chance = abch(5, OutfitMultiplier, JunkMultiplier)},
            {item = "FlareGun", chance = abch(5, OutfitMultiplier, PistolMultiplier)},
            {item = "SAK", chance = abch(5, OutfitMultiplier, JunkMultiplier)},
            {item = "TitaniumSpork", chance = abch(5, OutfitMultiplier, JunkMultiplier)}
          },
          rollOne = {
            multiplyDistro(itemSets.flashlightsRegular, abch(3, OutfitMultiplier, ResourceMultiplier)),
            multiplyDistro(itemSets.compasses, abch(5, OutfitMultiplier, JunkMultiplier)),
            {
              {
                item = "223Bullets",
                chance = abch(20, OutfitMultiplier, GunLooseBulletsMultiplier),
                alsoRollEach = {
                  {item = "223Bullets", chance = abch(50, GunLooseBulletsMultiplier), times = GunLooseBulletsRolls}
                }
              },
              {
                item = "308Bullets",
                chance = abch(20, OutfitMultiplier, GunLooseBulletsMultiplier),
                alsoRollEach = {
                  {item = "308Bullets", chance = abch(50, GunLooseBulletsMultiplier), times = GunLooseBulletsRolls}
                }
              },
              {
                item = "ShotgunShells",
                chance = abch(20, OutfitMultiplier, GunLooseBulletsMultiplier),
                alsoRollEach = {
                  {item = "ShotgunShells", chance = abch(50, GunLooseBulletsMultiplier), times = GunLooseBulletsRolls}
                }
              }
            }
          }
        },
        Inmate = {
          rollEach = {
            {item = "IcePick", chance = abch(10, OutfitMultiplier, JunkMultiplier)}
          }
        },
        InmateKhakhi = {
          rollEach = {
            {item = "IcePick", chance = abch(10, OutfitMultiplier, JunkMultiplier)}
          }
        },
        McCoys = {
          rollEach = {
            {item = "Saw", chance = abch(5, OutfitMultiplier, ResourceMultiplier)}
          },
          rollOne = {
            {
              {item = "DuctTape", chance = abch(5, OutfitMultiplier, ResourceMultiplier)},
              {item = "Woodglue", chance = abch(5, OutfitMultiplier, ResourceMultiplier)}
            }
          }
        },
        Mechanic = {
          rollEach = {
            {item = "RippedSheetsDirty", chance = abch(15, OutfitMultiplier, JunkMultiplier)},
            {item = "Wrench", chance = abch(1, OutfitMultiplier, MeleeMultiplier)},
            {item = "Measuring_Tape", chance = abch(16, OutfitMultiplier, JunkMultiplier)},
            {item = "Pencil", chance = abch(16, OutfitMultiplier, JunkMultiplier)},
            {item = "Pliers", chance = abch(16, OutfitMultiplier, JunkMultiplier)},
            {
              item = "Screws",
              chance = abch(5, OutfitMultiplier, ResourceMultiplier),
              alsoRollEach = {
                {item = "Screws", chance = abch(50), times = 12}
              }
            },
            {
              item = "EngineParts",
              chance = abch(5, OutfitMultiplier, ResourceMultiplier),
              alsoRollEach = {
                {
                  item = "EngineParts",
                  chance = abch(50),
                  times = 2
                }
              }
            },
            {item = "CarBatteryCharger", chance = abch(1, OutfitMultiplier, ResourceMultiplier)},
            {item = "spraypaint.SpraycanRed", chance = abch(10, OutfitMultiplier, ResourceMultiplier)}
          }
        },
        Metalworker = {
          rollEach = {
            {item = "RippedSheetsDirty", chance = abch(15, OutfitMultiplier, JunkMultiplier)},
            {item = "Measuring_Tape", chance = abch(16, OutfitMultiplier, JunkMultiplier)},
            {item = "MetalSnips", chance = abch(8, OutfitMultiplier, JunkMultiplier)},
            {item = "Pencil", chance = abch(16, OutfitMultiplier, JunkMultiplier)},
            {item = "spraypaint.SpraycanWhite", chance = abch(10, OutfitMultiplier, ResourceMultiplier)},
            {
              item = "Screws",
              chance = abch(10, OutfitMultiplier, ResourceMultiplier),
              alsoRollEach = {
                {
                  item = "Screws",
                  chance = abch(50),
                  times = 12
                }
              }
            },
            {item = "BlowTorch", chance = abch(2, OutfitMultiplier, ResourceMultiplier)},
            {item = "SmallSheetMetal", chance = abch(5, OutfitMultiplier, ResourceMultiplier)}
          }
        },
        Nurse = {
          rollEach = {
            {item = "FirstAidKit", chance = abch(5, OutfitMultiplier, BagMultiplier)},
            {item = "Gloves_Surgical", chance = abch(15, OutfitMultiplier, JunkMultiplier)},
            {item = "HandTorch", chance = abch(15, OutfitMultiplier, ResourceMultiplier)},
            {item = "Hat_SurgicalMask_Blue", chance = abch(15, OutfitMultiplier, JunkMultiplier)},
            {item = "SutureNeedleHolder", chance = abch(10, OutfitMultiplier, JunkMultiplier)}
          }
        },
        OfficeWorker = {
          rollEach = {
            {item = "BluePen", chance = abch(10, OutfitMultiplier, JunkMultiplier)},
            {item = "Notebook", chance = abch(10, OutfitMultiplier, JunkMultiplier)},
            {item = "Paperclip", chance = abch(15, OutfitMultiplier, JunkMultiplier)}
          }
        },
        Party = {
          rollEach = {},
          rollOne = {
            multiplyDistro(itemSets.chips, abch(15, OutfitMultiplier, OtherFoodMultiplier)),
            multiplyDistro(itemSets.pop, abch(15, OutfitMultiplier, OtherFoodMultiplier)),
            multiplyDistro(itemSets.cake, abch(10, OutfitMultiplier, OtherFoodMultiplier))
          }
        },
        PokerDealer = {
          rollEach = {
            {item = "CardDeck", chance = abch(35, OutfitMultiplier, JunkMultiplier)}
          }
        },
        Priest = {
          rollEach = {
            {item = "Necklace_Crucifix", chance = abch(50, OutfitMultiplier, JunkMultiplier)},
            {item = "Lollipop", chance = abch(10, OutfitMultiplier, OtherFoodMultiplier)}
          }
        },
        Police = {
          rollEach = {},
          rollOne = {
            multiplyDistro(itemSets.flashlightsRegular, abch(5, OutfitMultiplier, ResourceMultiplier)),
            multiplyDistro(itemSets.donuts, abch(5, OutfitMultiplier, OtherFoodMultiplier))
          }
        },
        Punk = {
          rollEach = {
            {item = "BeerBottle", chance = abch(10, OutfitMultiplier, JunkMultiplier)},
            {item = "Hairgel", chance = abch(15, OutfitMultiplier, JunkMultiplier)},
            {item = "Molotov", chance = abch(5, OutfitMultiplier, ResourceMultiplier)},
            {item = "spraypaint.SpraycanBlack", chance = abch(10, OutfitMultiplier, ResourceMultiplier)}
          }
        },
        Raider = {
          rollEach = {
            {item = "Knuckleduster", chance = abch(20, OutfitMultiplier, MeleeMultiplier)},
            {item = "PornoMag6", chance = abch(5, OutfitMultiplier, JunkMultiplier)},
            {item = "WhiskeyFull", chance = abch(5, OutfitMultiplier, OtherFoodMultiplier)},
            {item = "Molotov", chance = abch(5, OutfitMultiplier, ResourceMultiplier)}
          },
          rollOne = {
            multiplyDistro(itemSets.drugs, abch(15, OutfitMultiplier, JunkMultiplier))
          }
        },
        Ranger = {
          rollEach = {},
          rollOne = {
            multiplyDistro(itemSets.flashlightsRegular, abch(5, OutfitMultiplier, ResourceMultiplier))
          }
        },
        Redneck = {
          rollEach = {
            {item = "BeefJerky", chance = abch(5, OutfitMultiplier, OtherFoodMultiplier)}
          },
          rollOne = {
            multiplyDistro({"BeerCan", "WhiskeyFull"}, abch(8, OutfitMultiplier, OtherFoodMultiplier)),
            multiplyDistro(itemSets.drugs, abch(5, OutfitMultiplier, JunkMultiplier))
          }
        },
        Rocker = {
          rollEach = {
            {item = "Molotov", chance = abch(2, OutfitMultiplier, ResourceMultiplier)}
          },
          rollOne = {
            multiplyDistro(itemSets.drugs, abch(5, OutfitMultiplier, JunkMultiplier)),
            multiplyDistro({"BeerCan", "WhiskeyFull"}, abch(15, OutfitMultiplier, CannedFoodMultiplier))
          }
        },
        Santa = {
          rollEach = {
            {item = "Candycane", chance = abch(20, OutfitMultiplier, OtherFoodMultiplier), times = 4}
          }
        },
        SantaGreen = {
          rollEach = {
            {item = "Candycane", chance = abch(20, OutfitMultiplier, OtherFoodMultiplier), times = 4}
          }
        },
        SportsFan = {
          rollEach = {
            {item = "TennisBall", chance = abch(15, OutfitMultiplier, JunkMultiplier)},
            {item = "TennisRacket", chance = abch(15, OutfitMultiplier, MeleeMultiplier)}
          }
        },
        Student = {
          rollEach = {
            {item = "BeerCan", chance = abch(5, OutfitMultiplier, CannedFoodMultiplier)},
            {item = "Cube", chance = abch(5, OutfitMultiplier, JunkMultiplier)},
            {item = "Notebook", chance = abch(15, OutfitMultiplier, JunkMultiplier)},
            {item = "Firecracker", chance = abch(5, OutfitMultiplier, JunkMultiplier)},
            {item = "Pencil", chance = abch(15, OutfitMultiplier, JunkMultiplier)}
          },
          rollOne = {
            multiplyDistro(
              {"Book", "VideoGame", "Radio.CDplayer", "ComicBook"},
              abch(10, OutfitMultiplier, JunkMultiplier)
            ),
            multiplyDistro(itemSets.flashlightsToy, abch(2, OutfitMultiplier, ResourceMultiplier)),
            multiplyDistro(itemSets.pornoMags, abch(5, OutfitMultiplier, JunkMultiplier))
          }
        },
        Survivalist = {
          rollEach = {
            {item = "FlareGun", chance = abch(5, OutfitMultiplier, PistolMultiplier)},
            {item = "Leatherdad", chance = abch(5, OutfitMultiplier, JunkMultiplier)},
            {item = "MRE", chance = abch(5, OutfitMultiplier, OtherFoodMultiplier)},
            {item = "PLGR", chance = abch(1, OutfitMultiplier, JunkMultiplier)},
            {item = "TitaniumSpork", chance = abch(5, OutfitMultiplier, JunkMultiplier)},
            {item = "HerbalistMag", chance = abch(3, OutfitMultiplier, JunkMultiplier)}
          },
          rollOne = {
            multiplyDistro(itemSets.compasses, abch(5, OutfitMultiplier, JunkMultiplier))
          }
        },
        Survivalist02 = {
          rollEach = {
            {item = "FlareGun", chance = abch(5, OutfitMultiplier, PistolMultiplier)},
            {item = "Leatherdad", chance = abch(5, OutfitMultiplier, JunkMultiplier)},
            {item = "MRE", chance = abch(5, OutfitMultiplier, OtherFoodMultiplier)},
            {item = "PLGR", chance = abch(1, OutfitMultiplier, JunkMultiplier)},
            {item = "TitaniumSpork", chance = abch(5, OutfitMultiplier, JunkMultiplier)},
            {item = "HerbalistMag", chance = abch(3, OutfitMultiplier, JunkMultiplier)}
          },
          rollOne = {
            multiplyDistro(itemSets.compasses, abch(5, OutfitMultiplier, JunkMultiplier))
          }
        },
        Survivalist03 = {
          rollEach = {
            {item = "FlareGun", chance = abch(5, OutfitMultiplier, PistolMultiplier)},
            {item = "Leatherdad", chance = abch(5, OutfitMultiplier, JunkMultiplier)},
            {item = "MRE", chance = abch(5, OutfitMultiplier, OtherFoodMultiplier)},
            {item = "PLGR", chance = abch(1, OutfitMultiplier, JunkMultiplier)},
            {item = "HerbalistMag", chance = abch(3, OutfitMultiplier, JunkMultiplier)}
          },
          rollOne = {
            multiplyDistro(itemSets.compasses, abch(5, OutfitMultiplier, JunkMultiplier))
          }
        },
        Teacher = {
          rollEach = {
            {item = "Book", chance = abch(10, OutfitMultiplier, JunkMultiplier)},
            {item = "BluePen", chance = abch(15, OutfitMultiplier, JunkMultiplier)},
            {item = "Notebook", chance = abch(15, OutfitMultiplier, JunkMultiplier)},
            {item = "Pencil", chance = abch(15, OutfitMultiplier, JunkMultiplier)},
            {item = "RedPen", chance = abch(20, OutfitMultiplier, JunkMultiplier)},
            {item = "WhiskeyFull", chance = abch(5, OutfitMultiplier, OtherFoodMultiplier)}
          }
        },
        Thug = {
          rollEach = {
            {item = "Molotov", chance = abch(10, OutfitMultiplier, ResourceMultiplier)}
          }
        },
        ThunderGas = {
          rollEach = {
            {item = "RippedSheetsDirty", chance = abch(30, OutfitMultiplier, JunkMultiplier)},
            {item = "Screwdriver", chance = abch(10, OutfitMultiplier, MeleeMultiplier)},
            {item = "Wrench", chance = abch(10, OutfitMultiplier, MeleeMultiplier)}
          }
        },
        Varsity = {
          rollEach = {
            {item = "Radio.CDplayer", chance = abch(10, OutfitMultiplier, JunkMultiplier)}
          },
          rollOne = {
            multiplyDistro(itemSets.pornoMags, abch(5, OutfitMultiplier, JunkMultiplier)),
            multiplyDistro({"BeerCan", "WhiskeyFull"}, abch(5, OutfitMultiplier, OtherFoodMultiplier))
          }
        },
        Waiter_Classy = {
          rollEach = {
            {item = "BluePen", chance = abch(10, OutfitMultiplier, JunkMultiplier)},
            {item = "CorkScrew", chance = abch(10, OutfitMultiplier, JunkMultiplier)},
            {item = "Notebook", chance = abch(10, OutfitMultiplier, JunkMultiplier)}
          }
        },
        Waiter_Diner = {
          rollEach = {
            {item = "Dishcloth", chance = abch(10, OutfitMultiplier, JunkMultiplier)},
            {item = "Notebook", chance = abch(10, OutfitMultiplier, JunkMultiplier)},
            {item = "Pencil", chance = abch(10, OutfitMultiplier, JunkMultiplier)}
          },
          rollOne = {
            multiplyDistro(itemSets.cake, abch(5, OutfitMultiplier, OtherFoodMultiplier))
          }
        },
        Waiter_Restaurant = {
          rollEach = {
            {item = "BluePen", chance = abch(10, OutfitMultiplier, JunkMultiplier)},
            {item = "CorkScrew", chance = abch(10, OutfitMultiplier, JunkMultiplier)},
            {item = "Notebook", chance = abch(10, OutfitMultiplier, JunkMultiplier)}
          }
        }
      },
      bullets = {
        rollEach = {},
        rollOne = {
          {
            {
              item = "Bullets9mm",
              chance = abch(0.3, AmmoMultiplier),
              alsoRollEach = {
                {
                  item = "Bullets9mm",
                  chance = abch(50, GunLooseBulletsMultiplier),
                  times = GunLooseBulletsRolls
                }
              }
            },
            {
              item = "Bullets38",
              chance = abch(0.3, AmmoMultiplier),
              alsoRollEach = {
                {
                  item = "Bullets38",
                  chance = abch(50, GunLooseBulletsMultiplier),
                  times = GunLooseBulletsRolls
                }
              }
            },
            {
              item = "Bullets44",
              chance = abch(0.3, AmmoMultiplier),
              alsoRollEach = {
                {
                  item = "Bullets44",
                  chance = abch(50, GunLooseBulletsMultiplier),
                  times = GunLooseBulletsRolls
                }
              }
            },
            {
              item = "Bullets45",
              chance = abch(0.3, AmmoMultiplier),
              alsoRollEach = {
                {
                  item = "Bullets45",
                  chance = abch(50, GunLooseBulletsMultiplier),
                  times = GunLooseBulletsRolls
                }
              }
            },
            {
              item = "ShotgunShells",
              chance = abch(0.3, AmmoMultiplier),
              alsoRollEach = {
                {
                  item = "ShotgunShells",
                  chance = abch(50, GunLooseBulletsMultiplier),
                  times = GunLooseBulletsRolls
                }
              }
            },
            {
              item = "223Bullets",
              chance = abch(0.3, AmmoMultiplier),
              alsoRollEach = {
                {
                  item = "223Bullets",
                  chance = abch(50, GunLooseBulletsMultiplier),
                  times = GunLooseBulletsRolls
                }
              }
            },
            {
              item = "308Bullets",
              chance = abch(0.3, AmmoMultiplier),
              alsoRollEach = {
                {
                  item = "308Bullets",
                  chance = abch(50, GunLooseBulletsMultiplier),
                  times = GunLooseBulletsRolls
                }
              }
            },
            {
              item = "556Bullets",
              chance = abch(0.3, AmmoMultiplier),
              alsoRollEach = {
                {
                  item = "556Bullets",
                  chance = abch(50, GunLooseBulletsMultiplier),
                  times = GunLooseBulletsRolls
                }
              }
            }
          }
        }
      },
      bulletsBoxes = {
        rollEach = {},
        rollOne = {
          {
            {item = "Bullets9mmBox", chance = abch(0.15, AmmoBoxMultiplier)},
            {item = "Bullets38Box", chance = abch(0.15, AmmoBoxMultiplier)},
            {item = "Bullets44Box", chance = abch(0.15, AmmoBoxMultiplier)},
            {item = "Bullets45Box", chance = abch(0.15, AmmoBoxMultiplier)},
            {item = "ShotgunShellsBox", chance = abch(0.15, AmmoBoxMultiplier)},
            {item = "223Box", chance = abch(0.15, AmmoBoxMultiplier)},
            {item = "308Box", chance = abch(0.15, AmmoBoxMultiplier)},
            {item = "556Box", chance = abch(0.15, AmmoBoxMultiplier)}
          }
        }
      },
      melee = {
        rollEach = {},
        rollOne = {
          {
            {item = "WoodenMallet", chance = abch(0.5, MeleeMultiplier)},
            {item = "ClosedUmbrellaRed", chance = abch(0.5, MeleeMultiplier)},
            {item = "RollingPin", chance = abch(0.5, MeleeMultiplier)},
            {item = "MetalBar", chance = abch(0.1, MeleeMultiplier)},
            {item = "LeadPipe", chance = abch(0.1, MeleeMultiplier)},
            {item = "Wrench", chance = abch(0.1, MeleeMultiplier)}
          }
        }
      },
      pistols = {
        rollEach = {},
        rollOne = {
          {
            {
              item = "Pistol",
              chance = abch(0.1, PistolMultiplier),
              -- when Pistol is successfully rolled and added to zombie,
              -- these items will also be rolled to add adjace to the pistol
              alsoRollEach = {
                {
                  item = "[LOOSE_BULLETS]",
                  chance = abch(50, GunLooseBulletsMultiplier),
                  times = GunLooseBulletsRolls
                }
              }
            },
            {
              item = "Pistol2",
              chance = abch(0.1, PistolMultiplier),
              alsoRollEach = {
                {
                  item = "[LOOSE_BULLETS]",
                  chance = abch(50, GunLooseBulletsMultiplier),
                  times = GunLooseBulletsRolls
                }
              }
            },
            {
              item = "Pistol3",
              chance = abch(0.1, PistolMultiplier),
              alsoRollEach = {
                {
                  item = "[LOOSE_BULLETS]",
                  chance = abch(50, GunLooseBulletsMultiplier),
                  times = GunLooseBulletsRolls
                }
              }
            },
            {
              item = "Revolver",
              chance = abch(0.1, PistolMultiplier),
              alsoRollEach = {
                {
                  item = "[LOOSE_BULLETS]",
                  chance = abch(50, GunLooseBulletsMultiplier),
                  times = GunLooseBulletsRolls
                }
              }
            },
            {
              item = "Revolver_Long",
              chance = abch(0.1, PistolMultiplier),
              alsoRollEach = {
                {
                  item = "[LOOSE_BULLETS]",
                  chance = abch(50, GunLooseBulletsMultiplier),
                  times = GunLooseBulletsRolls
                }
              }
            },
            {
              item = "Revolver_Short",
              chance = abch(0.1, PistolMultiplier),
              alsoRollEach = {
                {
                  item = "[LOOSE_BULLETS]",
                  chance = abch(50, GunLooseBulletsMultiplier),
                  times = GunLooseBulletsRolls
                }
              }
            }
          }
        }
      },
      longGuns = {
        rollEach = {},
        rollOne = {
          {
            {
              item = "DoubleBarrelShotgun",
              chance = abch(0.1, LongGunsMultiplier),
              alsoRollEach = {
                {
                  item = "[LOOSE_BULLETS]",
                  chance = abch(50, GunLooseBulletsMultiplier),
                  times = GunLooseBulletsRolls
                }
              }
            },
            {
              item = "DoubleBarrelShotgunSawnoff",
              chance = abch(0.1, LongGunsMultiplier),
              alsoRollEach = {
                {
                  item = "[LOOSE_BULLETS]",
                  chance = abch(50, GunLooseBulletsMultiplier),
                  times = GunLooseBulletsRolls
                }
              }
            },
            {
              item = "Shotgun",
              chance = abch(0.1, LongGunsMultiplier),
              alsoRollEach = {
                {
                  item = "[LOOSE_BULLETS]",
                  chance = abch(50, GunLooseBulletsMultiplier),
                  times = GunLooseBulletsRolls
                }
              }
            },
            {
              item = "ShotgunSawnoff",
              chance = abch(0.1, LongGunsMultiplier),
              alsoRollEach = {
                {
                  item = "[LOOSE_BULLETS]",
                  chance = abch(50, GunLooseBulletsMultiplier),
                  times = GunLooseBulletsRolls
                }
              }
            },
            {
              item = "AssaultRifle",
              chance = abch(0.1, LongGunsMultiplier),
              alsoRollEach = {
                {
                  item = "[LOOSE_BULLETS]",
                  chance = abch(50, GunLooseBulletsMultiplier),
                  times = GunLooseBulletsRolls
                }
              }
            },
            {
              item = "AssaultRifle2",
              chance = abch(0.1, LongGunsMultiplier),
              alsoRollEach = {
                {
                  item = "[LOOSE_BULLETS]",
                  chance = abch(50, GunLooseBulletsMultiplier),
                  times = GunLooseBulletsRolls
                }
              }
            },
            {
              item = "VarmintRifle",
              chance = abch(0.1, LongGunsMultiplier),
              alsoRollEach = {
                {
                  item = "[LOOSE_BULLETS]",
                  chance = abch(50, GunLooseBulletsMultiplier),
                  times = GunLooseBulletsRolls
                }
              }
            },
            {
              item = "HuntingRifle",
              chance = abch(0.1, LongGunsMultiplier),
              alsoRollEach = {
                {
                  item = "[LOOSE_BULLETS]",
                  chance = abch(50, GunLooseBulletsMultiplier),
                  times = GunLooseBulletsRolls
                }
              }
            }
          }
        }
      },
      otherGuns = {
        rollEach = {},
        rollOne = {}
      },
      cannedFood = {
        rollEach = {},
        rollOne = {
          {
            {item = "BeerCan", chance = abch(0.5, CannedFoodMultiplier)},
            {item = "Dogfood", chance = abch(0.5, CannedFoodMultiplier)},
            {item = "TinnedBeans", chance = abch(0.1, CannedFoodMultiplier)},
            {item = "TunaTin", chance = abch(0.1, CannedFoodMultiplier)},
            {item = "CannedChili", chance = abch(0.1, CannedFoodMultiplier)},
            {item = "CannedCornedBeef", chance = abch(0.1, CannedFoodMultiplier)},
            {item = "CannedCorn", chance = abch(0.1, CannedFoodMultiplier)},
            {item = "CannedMushroomSoup", chance = abch(0.1, CannedFoodMultiplier)},
            {item = "CannedPeas", chance = abch(0.1, CannedFoodMultiplier)},
            {item = "CannedSardines", chance = abch(0.1, CannedFoodMultiplier)},
            {item = "CannedCarrots", chance = abch(0.1, CannedFoodMultiplier)},
            {item = "CannedPotato", chance = abch(0.1, CannedFoodMultiplier)},
            {item = "CannedBolognese", chance = abch(0.1, CannedFoodMultiplier)}
          }
        }
      },
      otherFood = {
        rollEach = {
          {item = "MintCandy", chance = abch(0.5, OtherFoodMultiplier)},
          {item = "JuiceBox", chance = abch(0.5, OtherFoodMultiplier)},
          {item = "Lollipop", chance = abch(0.5, OtherFoodMultiplier)},
          {item = "CookieChocolateChip", chance = abch(0.5, OtherFoodMultiplier)},
          {item = "SunflowerSeeds", chance = abch(0.5, OtherFoodMultiplier)},
          {item = "Peanuts", chance = abch(0.5, OtherFoodMultiplier)},
          {item = "Gum", chance = abch(0.5, OtherFoodMultiplier)},
          {item = "Chocolate", chance = abch(0.2, OtherFoodMultiplier)},
          {item = "MRE", chance = abch(0.1, OtherFoodMultiplier)}
        },
        rollOne = {
          multiplyDistro(itemSets.pop, abch(0.5, OtherFoodMultiplier)),
          multiplyDistro(itemSets.chips, abch(0.4, OtherFoodMultiplier))
        }
      },
      resources = {
        rollEach = {},
        rollOne = {
          multiplyDistro(itemSets.flashlightsRegular, abch(0.5, ResourceMultiplier)),
          {
            {item = "Glue", chance = abch(0.8, ResourceMultiplier)},
            {
              item = "Nails",
              chance = abch(1, ResourceMultiplier),
              alsoRollEach = {
                {item = "Nails", chance = abch(50), times = 10}
              }
            },
            {
              item = "Screws",
              chance = abch(1, ResourceMultiplier),
              alsoRollEach = {
                {item = "Screws", chance = abch(50), times = 10}
              }
            },
            {item = "DuctTape", chance = abch(0.3, ResourceMultiplier)},
            {item = "Woodglue", chance = abch(0.3, ResourceMultiplier)},
            {item = "Scotchtape", chance = abch(0.4, ResourceMultiplier)},
            {item = "NailsBox", chance = abch(0.2, ResourceMultiplier)},
            {item = "ScrewsBox", chance = abch(0.2, ResourceMultiplier)},
            {item = "PaperclipBox", chance = abch(0.5, ResourceMultiplier)}
          }
        }
      },
      junk = {
        rollEach = {
          {item = "Tissue", chance = abch(1, JunkMultiplier)},
          {item = "Newspaper", chance = abch(1, JunkMultiplier)},
          {
            item = "Money",
            chance = abch(1, JunkMultiplier),
            alsoRollEach = {{item = "Money", chance = abch(50), times = 4}}
          },
          {item = "Paperclip", chance = abch(1, JunkMultiplier), times = 3},
          {item = "BandageDirty", chance = abch(1, JunkMultiplier)},
          {item = "Razor", chance = abch(0.5, JunkMultiplier)},
          {item = "WaterBottleEmpty", chance = abch(1, JunkMultiplier)},
          {item = "RubberBand", chance = abch(1, JunkMultiplier)},
          {item = "ComicBook", chance = abch(0.5, JunkMultiplier)},
          {item = "Book", chance = abch(0.2, JunkMultiplier)},
          {item = "BeerCanEmpty", chance = abch(1, JunkMultiplier)},
          {item = "Yoyo", chance = abch(0.2, JunkMultiplier)}
        },
        rollOne = {}
      },
      bags = {
        rollEach = {},
        rollOne = {
          {
            {item = "Bag_FannyPackFront", chance = abch(1, BagMultiplier)},
            {item = "Briefcase", chance = abch(1, BagMultiplier)},
            {item = "FirstAidKit", chance = abch(0.5, BagMultiplier)},
            {item = "GroceryBag1", chance = abch(1, BagMultiplier)},
            {item = "GroceryBag2", chance = abch(1, BagMultiplier)},
            {item = "GroceryBag3", chance = abch(1, BagMultiplier)},
            {item = "GroceryBag4", chance = abch(1, BagMultiplier)},
            {item = "Handbag", chance = abch(1, BagMultiplier)},
            {item = "Lunchbox", chance = abch(1, BagMultiplier)},
            {item = "Lunchbox2", chance = abch(1, BagMultiplier)},
            {item = "Paperbag_Jays", chance = abch(1, BagMultiplier)},
            {item = "Paperbag_Spiffos", chance = abch(1, BagMultiplier)},
            {item = "Bag_Satchel", chance = abch(1, BagMultiplier)},
            {item = "Plasticbag", chance = abch(2, BagMultiplier)},
            {item = "Suitcase", chance = abch(1, BagMultiplier)},
            {item = "Toolbox", chance = abch(0.5, BagMultiplier)},
            {item = "Tote", chance = abch(1, BagMultiplier)},
            {item = "SewingKit", chance = abch(0.5, BagMultiplier)}
            -- disable bags in this distro that already appear or are unrealistically large for zombie pockets
            -- { item = "Bag_GolfBag", chance = abch(1,BagMultiplier) },
            -- { item = "Bag_Schoolbag", chance = abch(1,BagMultiplier) },
            -- { item = "Bag_SurvivorBag", chance = abch(0.1,BagMultiplier) }
          }
        }
      },
      gunBags = {
        rollEach = {},
        rollOne = {
          {
            -- isGunCase means guns within bag will be unloaded and in somewhat better condition than otherwise
            {item = "PistolCase1", chance = abch(0.1, GunBagMultiplier), isGunCase = true},
            {item = "PistolCase2", chance = abch(0.1, GunBagMultiplier), isGunCase = true},
            {item = "PistolCase3", chance = abch(0.1, GunBagMultiplier), isGunCase = true},
            {item = "RevolverCase1", chance = abch(0.1, GunBagMultiplier), isGunCase = true},
            {item = "RevolverCase2", chance = abch(0.1, GunBagMultiplier), isGunCase = true},
            {item = "RevolverCase3", chance = abch(0.1, GunBagMultiplier), isGunCase = true}
            -- disable bags that are unlikely to be found in zombie pockets :P
            -- { item = "Bag_ShotgunBag", chance = abch(0.1,GunBagMultiplier) },
            -- { item = "ShotgunCase1", chance = abch(0.1,GunBagMultiplier), isGunCase = true },
            -- { item = "ShotgunCase2", chance = abch(0.1,GunBagMultiplier), isGunCase = true },
            -- { item = "Bag_WeaponBag", chance = abch(0.1,GunBagMultiplier) },
            -- { item = "RifleCase1", chance = abch(0.1,GunBagMultiplier), isGunCase = true },
            -- { item = "RifleCase2", chance = abch(0.1,GunBagMultiplier), isGunCase = true },
            -- { item = "RifleCase3", chance = abch(0.1,GunBagMultiplier), isGunCase = true },
            -- { item = "Bag_ShotgunDblBag", chance = abch(0.1,GunBagMultiplier) },
            -- { item = "Bag_ShotgunDblSawnoffBag", chance = abch(0.1,GunBagMultiplier) },
            -- { item = "Bag_ShotgunSawnoffBag", chance = abch(0.1,GunBagMultiplier) }
          }
        }
      },
      extras = {
        rollEach = unserializePairs(SandboxVars.AirbobbelzLoot.ExtraRollEach),
        rollOne = {
          unserializePairs(SandboxVars.AirbobbelzLoot.ExtraRollOne1),
          unserializePairs(SandboxVars.AirbobbelzLoot.ExtraRollOne2),
          unserializePairs(SandboxVars.AirbobbelzLoot.ExtraRollOne3)
        }
      }
    }

    for _, plugin in pairs(AB_LOOT_PLUGINS) do
      plugin(LootTables)
    end

    -- remove any invalid items from the loot table, so that
    -- we don't end up wasting rolls on items that would never appear.
    -- Also remove anything explicity in the removal map
    LootTables = AB_table_cleanup(LootTables, getItemRemovalMap())

    if DEBUG then
      AB_LOOT_prettyPrint(LootTables)
    end
  end
  return LootTables
end
