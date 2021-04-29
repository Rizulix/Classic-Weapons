# Classic Weapons
> Classic weapons for Sven Co-op

## Installation Guide

1. Download this repository and extract it's contents inside `Steam\steamapps\common\Sven Co-op\svencoop_addon\`
2. In your map_script, add in the header `#include "hl_weapons/weapons"` and in the MapInit function add `RegisterClassicWeapons();`

## Notes

The MaxAmmo and MaxClip of the m249 are the same as the default version, the same goes for the shockrifle, this is to avoid overwriting the values of the default weapons.

I recommend using in conjunction with an ItemMapper such as [Outerbeast's classic_weapons.as](https://github.com/Outerbeast/Entities-and-Gamemodes/blob/master/classic_weapons.as), in this case follow step 2 of the installation guide but add `RegisterClassicWeapons();` in the Enable function and replace the `array<ItemMapping@> CLASSIC_WEAPONS_LIST`
with the following:
```
array<ItemMapping@> CLASSIC_WEAPONS_LIST = 
{
    ItemMapping( "weapon_m16", "weapon_hlmp5" ),
    ItemMapping( "weapon_9mmAR", "weapon_hlmp5" ),
    ItemMapping( "weapon_uzi", "weapon_hlmp5" ),
    ItemMapping( "weapon_uziakimbo", "weapon_hlmp5" ),
    ItemMapping( "weapon_crowbar", "weapon_hlcrowbar" ),
    ItemMapping( "weapon_shotgun", "weapon_hlshotgun" ),
    ItemMapping( "ammo_556clip", "ammo_9mmAR" ),
    ItemMapping( "weapon_357", "weapon_hlpython" ),
    ItemMapping( "weapon_m249", "weapon_ofm249" ),
    ItemMapping( "weapon_shockrifle", "weapon_ofshockrifle" ),
    ItemMapping( "weapon_sniperrifle", "weapon_ofsniperrifle" )
};
```

## Credits

* Code for the python  was based on [Valve Half-Life SDK](https://github.com/ValveSoftware/halflife).
* Code for the Opposing Force weapons was based on [FreeSlave Half-Life SDK](https://github.com/FreeSlave/hlsdk-xash3d).
