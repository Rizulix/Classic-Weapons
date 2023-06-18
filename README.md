# Classic Weapons

> Classic weapons for Sven Co-op

## Installation Guide

1. [Download this repository](https://github.com/Rizulix/Classic-Weapons/archive/refs/heads/main.zip) and extract its content inside `Steam\steamapps\common\Sven Co-op\svencoop_addon\`.

2. Open your map_script: *`my_map_script.as`*. (this name is only for reference)

3. In the header add `#include 'hl_weapons/weapons'` and in the `MapInit()` function add `RegisterClassicWeapons();` this will **only register the weapons**.

	It should look like this:
	```angelscript
	// Assuming that your map_script is in `../scripts/maps/`
	#include 'hl_weapons/weapons'
	
	void MapInit()
	{
		RegisterClassicWeapons();
	}
	```

4. To replace the default weapons with the classic ones you can add in the header `#include 'hl_weapons/mappings'` and in the `MapInit()` function add `g_ClassicMode.SetItemMappings(@g_ClassicWeapons);`

	It should look like this:
	```angelscript
	// Assuming that your map_script is in `../scripts/maps/`
	#include 'hl_weapons/weapons'
	#include 'hl_weapons/mappings'
	
	void MapInit()
	{
		RegisterClassicWeapons();
		g_ClassicMode.SetItemMappings(@g_ClassicWeapons);
		// Uncomment one of the lines below according to your wishes
		// g_ClassicMode.EnableMapSupport(); // Replace only with Classic Mode enabled
		// g_ClassicMode.ForceItemRemap(true); // Always replace
	}
	```

	OOOORRRR you can use [Outerbeast's info_itemswap](https://github.com/Outerbeast/Entities-and-Gamemodes/blob/master/info_itemswap.as) (instructions on how to use there).

5. To activate this weapon pack you will have to add `map_script my_map_script` in the *.cfg* corresponding to the map and toggle to classic mode.

## Notes

- The max ammo for the M249 and the ShockRifle are the same as those of the Sven Co-op version to avoid overwriting the weapon's default values.

- If you are going to use this weapon pack with another map script like `HLSPClassicMode.as` (default map script for Half-Life campaign) or some edited version you will have to add the following line in your MapInit()`:

	```angelscript
	// This will add the ItemMapping of the weapon pack
	// to the existing one in HLSPClassicMode.as
	g_ItemMappings.insertAt(0, g_ClassicWeapons);
	```

	It should look like this:
	```angelscript
	// Assuming that your map_script is in `../scripts/maps/`
	#include 'hl_weapons/weapons'
	#include 'hl_weapons/mappings'
	#include 'HLSPClassicMode'
	
	void MapInit()
	{
		g_ItemMappings.insertAt(0, g_ClassicWeapons);

		RegisterClassicWeapons();

		// Classic Mode settings and ItemMapping is set here with g_ItemMappings
		ClassicModeMapInit();
	}
	```

## Console Variables

- `revolver_laser_sight`: Enables the python laser sight. (default: 1)

- `m249_wide_spread`: Sets whether m249 uses wide spread. (default: 0)

- `m249_knockback`: Enables m249 knockback on firing. (default: 1)

- `shockrifle_fast`: Enables rapid fire and rapid ammo regeneration. (default: 0)

Change its value with `as_command` e.g.:

`as_command revolver_laser_sight 0`

#### Note: To modify the values you must at least have access to cheats.

## Credits
* Code format based on [KernCore's Custom Weapon Projects](https://github.com/KernCore91#sven-co-op-plugins)
* All weapons code was ported/based from SamVanheer's [Half-Life Unified SDK](https://github.com/SamVanheer/halflife-unified-sdk), [Half-Life Updated](https://github.com/SamVanheer/halflife-updated) and [Half-Life Op4 Updated](https://github.com/SamVanheer/halflife-op4-updated)