# Classic Weapons
> Classic weapons for Sven Co-op

## Installation Guide
1. [Download this repository](https://github.com/Rizulix/Classic-Weapons/archive/refs/heads/main.zip) and extract it's contents inside `Steam\steamapps\common\Sven Co-op\svencoop_addon\`
2. Open your map_script: *`my_map_script.as`* (this name is for **reference** only)
3. Add in the header `#include "hl_weapons/weapons"` and in the `MapInit()` function add `RegisterClassicWeapons();` this will only register the weapons
4. To replace the default weapons add in the header `#include "hl_weapons/mappings"` and in the `MapInit()` function add `g_ClassicMode.SetItemMappings( @g_ClassicWeapons );`

	It should look like this:
	```angelscript
	#include "hl_weapons/weapons"
	#include "hl_weapons/mappings"
	
	void MapInit()
	{
		RegisterClassicWeapons();
		g_ClassicMode.SetItemMappings( @g_ClassicWeapons );
		//Uncomment one of the lines below according to your wishes
		//g_ClassicMode.EnableMapSupport(); //Replace only with Classic Mode enabled
		//g_ClassicMode.ForceItemRemap( true ); //Always replace
	}
	```
5. To activate this weapon pack you will have to add `map_script my_map_script` in the *.cfg* corresponding to the map

## Notes
- The `iMaxAmmo1` and `iMaxClip` of the M249 and ShockRifle are the same as those of the Sven Co-op version to avoid overwriting the default weapon values.
- If you are going to use this weapon pack with another map script like `HLSPClassicMode.as` (default map script for Half-Life campaign) or some edited version or another map script like [Outerbeast's classic_weapons.as](https://github.com/Outerbeast/Entities-and-Gamemodes/blob/master/classic_weapons.as) make sure to follow steps 1, 2 and 3, for the first case `RegisterClassicWeapons();` must be added in `ClassicModeMapInit()` while in the last case it would be in `Enable()` and you will have to add the following to their respective `array<ItemMapping@>`:
	```angelscript
	{
		//Some code upsite...
		ItemMapping( "weapon_357", HL_PYTHON::GetName() ),
		ItemMapping( "weapon_python", HL_PYTHON::GetName() ),
		ItemMapping( "weapon_eagle", OF_EAGLE::GetName() ),
		ItemMapping( "weapon_sniperrifle", OF_SNIPERRIFLE::GetName() ),
		ItemMapping( "weapon_m249", OF_M249::GetName() ),
		ItemMapping( "weapon_saw", OF_M249::GetName() ),
		ItemMapping( "weapon_shockrifle", OF_SHOCKRIFLE::GetName() ),
		ItemMapping( "weapon_minigun", OF_M249::GetName() ),
		ItemMapping( "ammo_762", OF_SNIPERRIFLE::GetAmmoName() ),
		ItemMapping( "ammo_556", OF_M249::GetAmmoName() )
	};
	```

## Credits
* Code format based on [KernCore's Custom Weapon Projects](https://github.com/KernCore91#sven-co-op-plugins)
* The Python (aka .357 Magnum) code was based on [Valve's Half-Life SDK](https://github.com/ValveSoftware/halflife)
* The Opposing Force weapons code was based on [Solokiller's Half-Life: Opposing Force SDK](https://github.com/SamVanheer/halflife-op4-updated) and [FreeSlave's Half-Life SDK](https://github.com/FreeSlave/hlsdk-xash3d)