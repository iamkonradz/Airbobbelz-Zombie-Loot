-- chances out of 100000 enables fractional chances. Chances passed to abch/AB_get_chance are still out of 100
ABLoot_DIVISOR = 100000

-- provided `chance`, a double representing the chance out of 100 (which can be a decimal between 0 and 1),
-- return an integer chance out of 100,000 (ABLoot_DIVISOR) with mod multipliers applied.
-- sandboxMultiplier is a percentage integer to apply where 100 is 100% or 1x, 200 is 200% or 2x, etc
local function abch(chance, sandboxMultiplier, extraMultiplier)
  local globalMultiplier = SandboxVars.AirbobbelzLoot.GlobalMultiplier or 100
  local baseChance = chance * (ABLoot_DIVISOR / 100)
  if sandboxMultiplier ~= nil then
    baseChance = baseChance * (sandboxMultiplier / 100)
  end
  if extraMultiplier ~= nil then
    baseChance = baseChance * (extraMultiplier / 100)
  end
  return baseChance * (globalMultiplier / 100)
end

AB_get_chance = abch

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

-- build a table of items and chances from a serialized string representing that table
-- ie
-- Base.Axe:0.1;Crowbar:2;Paper:0.001
-- becomes
-- { {item="Base.Axe", chance=abch(0.1,ExtraMultiplier)}, {item="Crowbar", chance=abch(2,ExtraMultiplier)}, {item="Paper", chance=abch(0.001,ExtraMultiplier)} }
local function unserializePairs(str)
  if string.len(str) == 0 then
    return {}
  end

  local splitString = split(str, ";")
  local mytable = {}
  for _, v in pairs(splitString) do
    if string.find(v, ":") then
      local kv = split(v, ":")
      table.insert(mytable, {item = kv[1], chance = abch(tonumber(kv[2]), SandboxVars.AirbobbelzLoot.ExtraMultiplier)})
    end
  end
  return mytable
end

-- dump a table to a string
local function debug_dump(o)
  if type(o) == "table" then
    local s = "{ "
    for k, v in pairs(o) do
      if type(k) ~= "number" then
        k = '"' .. k .. '"'
      end
      s = s .. "[" .. k .. "] = " .. debug_dump(v) .. ","
    end
    return s .. "} "
  else
    return tostring(o)
  end
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

AB_LOOT_PLUGINS = {}

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

    LootTables = {
      byOutfit = {
        AirCrew = {
          rollEach = {
            {item = "Radio.WalkieTalkie5", chance = abch(10, OutfitMultiplier, JunkMultiplier)},
            {item = "HandTorch", chance = abch(15, OutfitMultiplier, ResourceMultiplier)}
          }
        },
        AmbulanceDriver = {
          rollEach = {
            {item = "FirstAidKit", chance = abch(10, OutfitMultiplier, BagMultiplier)},
            {item = "Gloves_Surgical", chance = abch(15, OutfitMultiplier, JunkMultiplier)},
            {item = "HandTorch", chance = abch(10, OutfitMultiplier, JunkMultiplier)},
            {item = "Hat_SurgicalMask_Blue", chance = abch(20, OutfitMultiplier, JunkMultiplier)},
            {item = "SutureNeedleHolder", chance = abch(10, OutfitMultiplier, JunkMultiplier)}
          }
        },
        ArmyCamoDesert = {
          rollEach = {
            {item = "P38", chance = abch(10, OutfitMultiplier, JunkMultiplier)},
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
            }
          }
        },
        ArmyCamoGreen = {
          rollEach = {
            {item = "P38", chance = abch(20, OutfitMultiplier, JunkMultiplier)},
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
            }
          }
        },
        ArmyServiceUniform = {
          rollEach = {
            {item = "LabKeycard", chance = abch(5, OutfitMultiplier, JunkMultiplier)},
            {item = "IntelFolder", chance = abch(5, OutfitMultiplier, JunkMultiplier)},
            {item = "Radio.WalkieTalkie5", chance = abch(10, OutfitMultiplier, JunkMultiplier)}
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
            {item = "CheapSpeed", chance = abch(20, OutfitMultiplier, JunkMultiplier)},
            {item = "Cigarettes", chance = abch(20, OutfitMultiplier, JunkMultiplier)},
            {item = "CokeBaggie", chance = abch(20, OutfitMultiplier, JunkMultiplier)},
            {item = "Knuckleduster", chance = abch(10, OutfitMultiplier, MeleeMultiplier)},
            {item = "PornoMag6", chance = abch(5, OutfitMultiplier, JunkMultiplier)},
            {item = "WhiskeyFull", chance = abch(10, OutfitMultiplier, JunkMultiplier)}
          }
        },
        BaseballPlayer_KY = {
          rollEach = {
            {item = "Baseball", chance = abch(15, OutfitMultiplier, JunkMultiplier)}
          }
        },
        BaseballPlayer_Rangers = {
          rollEach = {
            {item = "Baseball", chance = abch(15, OutfitMultiplier, JunkMultiplier)}
          }
        },
        BaseballPlayer_Z = {
          rollEach = {
            {item = "Baseball", chance = abch(15, OutfitMultiplier, JunkMultiplier)}
          }
        },
        Bathrobe = {
          rollEach = {
            {item = "HottieZ", chance = abch(5, OutfitMultiplier, JunkMultiplier)},
            {item = "Rubberducky", chance = abch(16, OutfitMultiplier, JunkMultiplier)},
            {item = "Soap2", chance = abch(16, OutfitMultiplier, JunkMultiplier)},
            {item = "Toothbrush", chance = abch(20, OutfitMultiplier, JunkMultiplier)}
          },
          rollOne = {
            {
              {item = "PornoMag1", chance = abch(8, OutfitMultiplier, JunkMultiplier)},
              {item = "PornoMag2", chance = abch(5, OutfitMultiplier, JunkMultiplier)},
              {item = "PornoMag3", chance = abch(8, OutfitMultiplier, JunkMultiplier)},
              {item = "PornoMag4", chance = abch(5, OutfitMultiplier, JunkMultiplier)},
              {item = "PornoMag5", chance = abch(8, OutfitMultiplier, JunkMultiplier)}
            }
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
            {item = "CheapSpeed", chance = abch(33, OutfitMultiplier, JunkMultiplier)},
            {item = "Cigarettes", chance = abch(33, OutfitMultiplier, JunkMultiplier)},
            {item = "CokeBaggie", chance = abch(33, OutfitMultiplier, JunkMultiplier)},
            {item = "Knuckleduster", chance = abch(20, OutfitMultiplier, MeleeMultiplier)},
            {item = "Revolver_Short", chance = abch(5, OutfitMultiplier, PistolMultiplier)},
            {item = "WhiskeyFull", chance = abch(10, OutfitMultiplier, JunkMultiplier)},
            {item = "Molotov", chance = abch(5, OutfitMultiplier, JunkMultiplier)}
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
            {
              {item = "BerryBlack", chance = abch(10, OutfitMultiplier, OtherFoodMultiplier)},
              {item = "BerryBlue", chance = abch(10, OutfitMultiplier, OtherFoodMultiplier)},
              {item = "BerryGeneric1", chance = abch(10, OutfitMultiplier, OtherFoodMultiplier)},
              {item = "BerryGeneric2", chance = abch(10, OutfitMultiplier, OtherFoodMultiplier)},
              {item = "BerryGeneric3", chance = abch(10, OutfitMultiplier, OtherFoodMultiplier)},
              {item = "BerryGeneric4", chance = abch(10, OutfitMultiplier, OtherFoodMultiplier)},
              {item = "BerryGeneric5", chance = abch(10, OutfitMultiplier, OtherFoodMultiplier)}
            },
            {
              {item = "PlantainCataplasm", chance = abch(10, OutfitMultiplier, JunkMultiplier)},
              {item = "ComfreyCataplasm", chance = abch(10, OutfitMultiplier, JunkMultiplier)},
              {item = "WildGarlicCataplasm", chance = abch(10, OutfitMultiplier, JunkMultiplier)}
            },
            {
              {item = "CliponCompass", chance = abch(10, OutfitMultiplier, JunkMultiplier)},
              {item = "Compass", chance = abch(10, OutfitMultiplier, JunkMultiplier)},
              {item = "Compass2", chance = abch(10, OutfitMultiplier, JunkMultiplier)}
            }
          }
        },
        Classy = {
          rollEach = {
            {item = "Wine", chance = abch(10, OutfitMultiplier, OtherFoodMultiplier)}
          }
        },
        Cook_Generic = {
          rollEach = {
            {item = "Cigarettes", chance = abch(30, OutfitMultiplier, JunkMultiplier)},
            {item = "Dishcloth", chance = abch(30, OutfitMultiplier, JunkMultiplier)},
            {item = "Notebook", chance = abch(20, OutfitMultiplier, JunkMultiplier)},
            {item = "Pencil", chance = abch(30, OutfitMultiplier, JunkMultiplier)}
          }
        },
        ConstructionWorker = {
          rollEach = {
            {item = "Cigarettes", chance = abch(10, OutfitMultiplier, JunkMultiplier)},
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
            {
              {item = "spraypaint.SpraycanOrange", chance = abch(10, OutfitMultiplier, ResourceMultiplier)},
              {item = "spraypaint.SpraycanRed", chance = abch(10, OutfitMultiplier, ResourceMultiplier)}
            },
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
            {
              {item = "SyringeEmpty", chance = abch(10, OutfitMultiplier, JunkMultiplier)},
              {item = "SyringeZombieBlood", chance = abch(10, OutfitMultiplier, JunkMultiplier)},
              {item = "SyringeBlood", chance = abch(10, OutfitMultiplier, JunkMultiplier)}
            }
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
            {
              {item = "HairDyeBlack", chance = abch(5, OutfitMultiplier, JunkMultiplier)},
              {item = "HairDyeBlonde", chance = abch(5, OutfitMultiplier, JunkMultiplier)}
            }
          }
        },
        DressShort = {
          rollEach = {},
          rollOne = {
            {
              {item = "HairDyePink", chance = abch(5, OutfitMultiplier, JunkMultiplier)},
              {item = "HairDyeBlonde", chance = abch(5, OutfitMultiplier, JunkMultiplier)}
            }
          }
        },
        Farmer = {
          rollEach = {
            {item = "FarmingMag1", chance = abch(5, OutfitMultiplier, JunkMultiplier)},
            {item = "SeedBag", chance = abch(5, OutfitMultiplier, BagMultiplier)}
          },
          rollOne = {
            {
              {item = "farming.BroccoliBagSeed", chance = abch(20, OutfitMultiplier, ResourceMultiplier)},
              {item = "farming.CabbageBagSeed", chance = abch(20, OutfitMultiplier, ResourceMultiplier)},
              {item = "farming.CarrotBagSeed", chance = abch(20, OutfitMultiplier, ResourceMultiplier)},
              {item = "farming.RedRadishBagSeed", chance = abch(20, OutfitMultiplier, ResourceMultiplier)},
              {item = "farming.StrewberrieBagSeed", chance = abch(20, OutfitMultiplier, ResourceMultiplier)},
              {item = "farming.TomatoBagSeed", chance = abch(20, OutfitMultiplier, ResourceMultiplier)}
            }
          }
        },
        Fireman = {
          rollEach = {
            {item = "Axe", chance = abch(5, OutfitMultiplier, MeleeMultiplier)},
            {item = "Extinguisher", chance = abch(5, OutfitMultiplier, JunkMultiplier)},
            {item = "WalkieTalkie4", chance = abch(10, OutfitMultiplier, JunkMultiplier)}
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
            {item = "BluePen", chance = abch(25, OutfitMultiplier, JunkMultiplier)},
            {item = "Measuring_Tape", chance = abch(20, OutfitMultiplier, JunkMultiplier)},
            {item = "Notebook", chance = abch(25, OutfitMultiplier, JunkMultiplier)}
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
            {item = "FishingTackle", chance = abch(25, OutfitMultiplier, ResourceMultiplier)},
            {item = "FishingTackle2", chance = abch(25, OutfitMultiplier, ResourceMultiplier)}
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
            {item = "GolfBall", chance = abch(33, OutfitMultiplier, JunkMultiplier)},
            {item = "Notebook", chance = abch(25, OutfitMultiplier, JunkMultiplier)},
            {item = "Pencil", chance = abch(33, OutfitMultiplier, JunkMultiplier)}
          }
        },
        HazardSuit = {
          rollEach = {
            {item = "LabKeycard", chance = abch(10, OutfitMultiplier, JunkMultiplier)},
            {item = "Scalpel", chance = abch(30, OutfitMultiplier, MeleeMultiplier)}
          },
          rollOne = {
            {
              {item = "SyringeEmpty", chance = abch(33, OutfitMultiplier, JunkMultiplier)},
              {item = "SyringeZombieBlood", chance = abch(33, OutfitMultiplier, JunkMultiplier)},
              {item = "SyringeBlood", chance = abch(33, OutfitMultiplier, JunkMultiplier)}
            }
          }
        },
        HospitalPatient = {
          rollEach = {
            {item = "BandageDirty", chance = abch(40, OutfitMultiplier, JunkMultiplier)},
            {item = "BandageDirty", chance = abch(40, OutfitMultiplier, JunkMultiplier)}
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
            {
              {item = "CliponCompass", chance = abch(5, OutfitMultiplier, JunkMultiplier)},
              {item = "Compass", chance = abch(5, OutfitMultiplier, JunkMultiplier)},
              {item = "Compass2", chance = abch(5, OutfitMultiplier, JunkMultiplier)}
            },
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
            {item = "EngineParts", chance = abch(5, OutfitMultiplier, ResourceMultiplier)},
            {item = "CarBatteryCharger", chance = abch(1, OutfitMultiplier, ResourceMultiplier)},
            {item = "spraypaint.SpraycanRed", chance = abch(15, OutfitMultiplier, ResourceMultiplier)}
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
            {item = "BluePen", chance = abch(15, OutfitMultiplier, JunkMultiplier)},
            {item = "Notebook", chance = abch(15, OutfitMultiplier, JunkMultiplier)},
            {item = "Paperclip", chance = abch(15, OutfitMultiplier, JunkMultiplier)}
          }
        },
        Party = {
          rollOne = {
            {
              {item = "Crisps", chance = abch(15, OutfitMultiplier, OtherFoodMultiplier)},
              {item = "Crisps2", chance = abch(15, OutfitMultiplier, OtherFoodMultiplier)},
              {item = "Crisps3", chance = abch(15, OutfitMultiplier, OtherFoodMultiplier)},
              {item = "Crisps4", chance = abch(15, OutfitMultiplier, OtherFoodMultiplier)}
            }
          }
        },
        PokerDealer = {
          rollEach = {
            {item = "CardDeck", chance = abch(50, OutfitMultiplier, JunkMultiplier)}
          }
        },
        Priest = {
          rollEach = {
            {item = "Necklace_Crucifix", chance = abch(80, OutfitMultiplier, JunkMultiplier)},
            {item = "Lollipop", chance = abch(10, OutfitMultiplier, OtherFoodMultiplier)}
          }
        },
        Police = {
          rollEach = {
            {item = "HandTorch", chance = abch(10, OutfitMultiplier, ResourceMultiplier)}
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
            {item = "CheapSpeed", chance = abch(20, OutfitMultiplier, JunkMultiplier)},
            {item = "Cigarettes", chance = abch(20, OutfitMultiplier, JunkMultiplier)},
            {item = "CokeBaggie", chance = abch(10, OutfitMultiplier, JunkMultiplier)},
            {item = "Knuckleduster", chance = abch(20, OutfitMultiplier, MeleeMultiplier)},
            {item = "PornoMag6", chance = abch(5, OutfitMultiplier, JunkMultiplier)},
            {item = "WhiskeyFull", chance = abch(5, OutfitMultiplier, OtherFoodMultiplier)},
            {item = "Molotov", chance = abch(5, OutfitMultiplier, ResourceMultiplier)}
          }
        },
        Ranger = {
          rollEach = {
            {item = "Torch", chance = abch(5, OutfitMultiplier, ResourceMultiplier)}
          }
        },
        Redneck = {
          rollEach = {
            {item = "BeerCan", chance = abch(10, OutfitMultiplier, CannedFoodMultiplier)},
            {item = "BeefJerky", chance = abch(5, OutfitMultiplier, OtherFoodMultiplier)},
            {item = "CheapSpeed", chance = abch(10, OutfitMultiplier, JunkMultiplier)},
            {item = "Cigarettes", chance = abch(20, OutfitMultiplier, JunkMultiplier)},
            {item = "CokeBaggie", chance = abch(5, OutfitMultiplier, JunkMultiplier)},
            {item = "WhiskeyFull", chance = abch(10, OutfitMultiplier, OtherFoodMultiplier)}
          }
        },
        Rocker = {
          rollEach = {
            {item = "CheapSpeed", chance = abch(10, OutfitMultiplier, JunkMultiplier)},
            {item = "Cigarettes", chance = abch(20, OutfitMultiplier, JunkMultiplier)},
            {item = "CokeBaggie", chance = abch(5, OutfitMultiplier, JunkMultiplier)},
            {item = "Molotov", chance = abch(2, OutfitMultiplier, ResourceMultiplier)}
          },
          rollOne = {
            {
              {
                item = "BeerCan",
                chance = abch(20, OutfitMultiplier, CannedFoodMultiplier)
              },
              {
                item = "WhiskeyFull",
                chance = abch(20, OutfitMultiplier, OtherFoodMultiplier)
              }
            }
          }
        },
        Santa = {
          rollEach = {
            {item = "Candycane", chance = abch(50, OutfitMultiplier, OtherFoodMultiplier)}
          }
        },
        SantaGreen = {
          rollEach = {
            {item = "Candycane", chance = abch(50, OutfitMultiplier, OtherFoodMultiplier)}
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
            {item = "Book", chance = abch(5, OutfitMultiplier, JunkMultiplier)},
            {item = "BeerCan", chance = abch(5, OutfitMultiplier, CannedFoodMultiplier)},
            {item = "CDplayer", chance = abch(5, OutfitMultiplier, JunkMultiplier)},
            {item = "ComicBook", chance = abch(5, OutfitMultiplier, JunkMultiplier)},
            {item = "Cube", chance = abch(10, OutfitMultiplier, JunkMultiplier)},
            {item = "Notebook", chance = abch(25, OutfitMultiplier, JunkMultiplier)},
            {item = "Firecracker", chance = abch(5, OutfitMultiplier, JunkMultiplier)},
            {item = "Pencil", chance = abch(25, OutfitMultiplier, JunkMultiplier)},
            {item = "Videogame", chance = abch(5, OutfitMultiplier, JunkMultiplier)}
          },
          rollOne = {
            {
              {item = "PornoMag1", chance = abch(1, OutfitMultiplier, JunkMultiplier)},
              {item = "PornoMag2", chance = abch(1, OutfitMultiplier, JunkMultiplier)},
              {item = "PornoMag3", chance = abch(1, OutfitMultiplier, JunkMultiplier)},
              {item = "PornoMag4", chance = abch(1, OutfitMultiplier, JunkMultiplier)},
              {item = "PornoMag5", chance = abch(1, OutfitMultiplier, JunkMultiplier)}
            }
          }
        },
        Survivalist = {
          rollEach = {
            {item = "FlareGun", chance = abch(5, OutfitMultiplier, PistolMultiplier)},
            {item = "Leatherdad", chance = abch(5, OutfitMultiplier, JunkMultiplier)},
            {item = "MRE", chance = abch(10, OutfitMultiplier, OtherFoodMultiplier)},
            {item = "PLGR", chance = abch(1, OutfitMultiplier, JunkMultiplier)},
            {item = "TitaniumSpork", chance = abch(5, OutfitMultiplier, JunkMultiplier)},
            {item = "HerbalistMag", chance = abch(5, OutfitMultiplier, JunkMultiplier)}
          },
          rollOne = {
            {
              {item = "CliponCompass", chance = abch(5, OutfitMultiplier, JunkMultiplier)},
              {item = "Compass", chance = abch(5, OutfitMultiplier, JunkMultiplier)},
              {item = "Compass2", chance = abch(5, OutfitMultiplier, JunkMultiplier)}
            }
          }
        },
        Survivalist02 = {
          rollEach = {
            {item = "FlareGun", chance = abch(5, OutfitMultiplier, PistolMultiplier)},
            {item = "Leatherdad", chance = abch(5, OutfitMultiplier, JunkMultiplier)},
            {item = "MRE", chance = abch(10, OutfitMultiplier, OtherFoodMultiplier)},
            {item = "PLGR", chance = abch(1, OutfitMultiplier, JunkMultiplier)},
            {item = "TitaniumSpork", chance = abch(5, OutfitMultiplier, JunkMultiplier)},
            {item = "HerbalistMag", chance = abch(5, OutfitMultiplier, JunkMultiplier)}
          },
          rollOne = {
            {
              {item = "CliponCompass", chance = abch(5, OutfitMultiplier, JunkMultiplier)},
              {item = "Compass", chance = abch(5, OutfitMultiplier, JunkMultiplier)},
              {item = "Compass2", chance = abch(5, OutfitMultiplier, JunkMultiplier)}
            }
          }
        },
        Survivalist03 = {
          rollEach = {
            {item = "FlareGun", chance = abch(5, OutfitMultiplier, PistolMultiplier)},
            {item = "Leatherdad", chance = abch(5, OutfitMultiplier, JunkMultiplier)},
            {item = "MRE", chance = abch(5, OutfitMultiplier, OtherFoodMultiplier)},
            {item = "PLGR", chance = abch(1, OutfitMultiplier, JunkMultiplier)},
            {item = "HerbalistMag", chance = abch(5, OutfitMultiplier, JunkMultiplier)}
          },
          rollOne = {
            {
              {item = "CliponCompass", chance = abch(5, OutfitMultiplier, JunkMultiplier)},
              {item = "Compass", chance = abch(5, OutfitMultiplier, JunkMultiplier)},
              {item = "Compass2", chance = abch(5, OutfitMultiplier, JunkMultiplier)}
            }
          }
        },
        Teacher = {
          rollEach = {
            {item = "Book", chance = abch(10, OutfitMultiplier, JunkMultiplier)},
            {item = "BluePen", chance = abch(25, OutfitMultiplier, JunkMultiplier)},
            {item = "Notebook", chance = abch(25, OutfitMultiplier, JunkMultiplier)},
            {item = "Pencil", chance = abch(25, OutfitMultiplier, JunkMultiplier)},
            {item = "RedPen", chance = abch(50, OutfitMultiplier, JunkMultiplier)},
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
            {item = "CDplayer", chance = abch(10, OutfitMultiplier, JunkMultiplier)},
            {item = "HottieZ", chance = abch(1, OutfitMultiplier, JunkMultiplier)},
            {item = "BeerCan", chance = abch(10, OutfitMultiplier, CannedFoodMultiplier)},
            {item = "WhiskeyFull", chance = abch(10, OutfitMultiplier, OtherFoodMultiplier)}
          },
          rollOne = {
            {
              {item = "PornoMag1", chance = abch(5, OutfitMultiplier, JunkMultiplier)},
              {item = "PornoMag2", chance = abch(5, OutfitMultiplier, JunkMultiplier)},
              {item = "PornoMag3", chance = abch(5, OutfitMultiplier, JunkMultiplier)},
              {item = "PornoMag4", chance = abch(5, OutfitMultiplier, JunkMultiplier)},
              {item = "PornoMag5", chance = abch(5, OutfitMultiplier, JunkMultiplier)}
            }
          }
        },
        Waiter_Classy = {
          rollEach = {
            {item = "BluePen", chance = abch(33, OutfitMultiplier, JunkMultiplier)},
            {item = "CorkScrew", chance = abch(33, OutfitMultiplier, JunkMultiplier)},
            {item = "Notebook", chance = abch(33, OutfitMultiplier, JunkMultiplier)}
          }
        },
        Waiter_Diner = {
          rollEach = {
            {item = "Cigarettes", chance = abch(30, OutfitMultiplier, JunkMultiplier)},
            {item = "Dishcloth", chance = abch(30, OutfitMultiplier, JunkMultiplier)},
            {item = "Notebook", chance = abch(33, OutfitMultiplier, JunkMultiplier)},
            {item = "Pencil", chance = abch(33, OutfitMultiplier, JunkMultiplier)}
          }
        },
        Waiter_Restaurant = {
          rollEach = {
            {item = "BluePen", chance = abch(33, OutfitMultiplier, JunkMultiplier)},
            {item = "CorkScrew", chance = abch(20, OutfitMultiplier, JunkMultiplier)},
            {item = "Notebook", chance = abch(33, OutfitMultiplier, JunkMultiplier)}
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
          {item = "MintCandy", chance = abch(0.8, OtherFoodMultiplier)},
          {item = "JuiceBox", chance = abch(0.5, OtherFoodMultiplier)},
          {item = "Lollipop", chance = abch(0.8, OtherFoodMultiplier)},
          {item = "CookieChocolateChip", chance = abch(0.8, OtherFoodMultiplier)},
          {item = "SunflowerSeeds", chance = abch(0.8, OtherFoodMultiplier)},
          {item = "Peanuts", chance = abch(0.8, OtherFoodMultiplier)},
          {item = "Gum", chance = abch(0.8, OtherFoodMultiplier)},
          {item = "Chocolate", chance = abch(0.1, OtherFoodMultiplier)}
        },
        rollOne = {
          {
            {item = "Pop", chance = abch(0.8, OtherFoodMultiplier)},
            {item = "Pop2", chance = abch(0.8, OtherFoodMultiplier)},
            {item = "Pop3", chance = abch(0.8, OtherFoodMultiplier)}
          },
          {
            {item = "Crisps", chance = abch(0.4, OtherFoodMultiplier)},
            {item = "Crisps2", chance = abch(0.4, OtherFoodMultiplier)},
            {item = "Crisps3", chance = abch(0.4, OtherFoodMultiplier)},
            {item = "Crisps4", chance = abch(0.4, OtherFoodMultiplier)}
          }
        }
      },
      resources = {
        rollEach = {},
        rollOne = {
          {
            {item = "Glue", chance = abch(0.8, ResourceMultiplier)},
            {item = "Torch", chance = abch(1, ResourceMultiplier)},
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
          {item = "Money", chance = abch(1, JunkMultiplier), times = 5},
          {item = "Paperclip", chance = abch(1, JunkMultiplier), times = 3},
          {item = "BandageDirty", chance = abch(1, JunkMultiplier)},
          {item = "WaterBottleEmpty", chance = abch(1, JunkMultiplier)},
          {item = "RubberBand", chance = abch(1, JunkMultiplier)},
          {item = "ComicBook", chance = abch(0.5, JunkMultiplier)},
          {item = "Book", chance = abch(0.2, JunkMultiplier)},
          {item = "BeerCanEmpty", chance = abch(1, JunkMultiplier)}
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
  end
  return LootTables
end
