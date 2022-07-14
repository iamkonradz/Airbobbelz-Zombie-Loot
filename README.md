# Airbobbelz Zombie Loot

I found it difficult with default distribution tables to get a combination of large item variety in zombie drops with really low frequency to make those rare drops special. This mod uses a different technique outside of default zombie loot tables to better control randomness and allow really super random item spawns on zombies while being able to retain a large variety of items.

The mod also adds special loot for specific zombie outfits. For example, farmers can drop seeds and firefighters have a chance to drop fire extinguishers or axes.

There are multiple item categories (configurable in sandbox settings) and in many of those, depending on the category, instead of rolling for every item to decide what to add to zombies, a pre-roll is made to decide which single item in the given list to roll for to add to zombie loot. This allows a huge variety of items to be in the table while keeping drops exceptionally rare.

Any category of items can be disabled. For example, remove dropping of gun cases or long guns by setting the multipliers in sandbox to 0.

Additionally, there are settings that affect the condition of dropped items and amount left in drainables (like duct tape, glue, batteries).

Default settings are tuned to rare/super rare loot, but everything is configurable in sandbox. The easiest way to adjust everything is to change the global multiplier and also each category can be adjusted independently. Any category-rolls will be multiplied with the global multiplier -- for example if global multiplier is 50 and ammo multiplier is 25, then the final multiplier in the calculation for ammo will be (0.5x0.25) = 0.125 of the default.

All drops in this mod are ADDITIVE. Nothing is removed from zombie loot tables, and any items added to zombie drops by this mod will be on top of any other mods you have that add zombie loot. This mod also will not affect frequency of weapons lodged in living zombies such a crowbars/knives, or guns on police zombies. I would suggest utilizing the "More Loot Options +" mod, which is compatible with this, to adjust those drops.

EXTRA MOD SUPPORT:

# BRITA's weapons / Gunfighter

When Brita's weapon mod is active, all weapons from the gun store distribution are added to zombie drops. The multiplier for zombie drops is controlled by the "other guns" multiplier in sandbox. The zombie loot distribution should take into account any weapon settings set in gunfighter options, so for example if post-1993 weapons are removed in those settings they should not appear on zombies. Same goes for disabled weapons or ammo types.

My suggestion for Brita's, if you want to fine-tune non-police zombie gun drops, would be to disable the zombie weapon drops entirely within gunfighter settings and adjust drops with the "other guns" multiplier in this mod to fine-tune and make the drops as rare as you need.

# Firearms B41

When Firearms b41 is active, all the new firearms and ammo are added to the table of items dropped from zombies, tuneable by the pistol/long gun sandbox modifiers.

# Extra customization

There are 4 additional sandbox options for adding more items to zombie drops.

Extra Rolls (Each): Add items here in the format of "[item1]:[chance];[item2]:[chance]" to add those items to all zombie drops. For example "Base.Paperclip:0.1;Base.Crowbar:5" will add a 0.1% chance to all zombies to drop a paperclip and also a 5% chance for all zombies to drop a crowbar.

Extra Rolls (One) 1-3: For each of these additional sections, if there are multiple items listed, only one item will be randomly chosen to be rolled to add to the loot of a dead zombie. For example, "Base.BaseballBat:1;Base.Crowbar:5;Base.Axe:5" will result in EITHER a bat, crowbar, or axe being rolled. For 3 items, there is a 33% chance of any of these being selected to roll. Once an item is chosen, the defined percentage will be how likely it is to show up on a zombie. In this case, bat 1%, crowbar 5% and axe 5%. This is useful to prevent two competing items from appearing at the same time or to make sure a large variety of items only have a single % chance of appearing when all sub-items are set to the same drop %.

For adding items to zombie loot where you might want more than 1 item to drop at a time, for example you might want 'Money' to drop between 1 and 5 items, there is an alternate syntax:

item:Money,chance:1,add:5,addChance:50

which can also be chained with additional items and also the 'single item' syntax, for example

item:Money,chance:1,add:5,addChance:50;item:Newspaper,chance:2,add:10,addChance:25;Axe:5

The above string will:

- add "Money" as a 1% zombie drop. If this 1% chance is triggered, there will be 5 additional rolls at 50% per roll to add another "Money" resulting in a maximum of 6 items

- add "Newspaper" as a 2% zombie drop. If this 2% chance is triggered, there will be 10 additional rolls at 25% per roll to add another "Newspaper" resulting in a maximum of 11 "Newspaper"

- add 5% chance to drop an Axe on zombie

# Attributions

Loot Zeta Enhanced Edition https://steamcommunity.com/sharedfiles/filedetails/?id=2581183375 for some ideas on custom outfit loot

Advanced Alternative Zombie Loot https://steamcommunity.com/sharedfiles/filedetails/?id=2557379685 for additional outfit specific loot. I've carried over a number of distributions and modded items from this mod into the default distributions in this mod.

Github: [url=https://github.com/iamkonradz/Airbobbelz-Zombie-Loot]Here[/url]

Full list of default items added can be found in the [url=https://github.com/iamkonradz/Airbobbelz-Zombie-Loot/blob/main/media/lua/server/ABZombieLoot.lua]source file[/url] (just scroll down, item names are in blue)

Workshop ID: 2798636684
Mod ID: ab_zombie_loot
