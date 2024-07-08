# Classic Weapons

> Classic weapons for Sven Co-op

## Installation Guide

1. [Download](https://github.com/Rizulix/Classic-Weapons/archive/refs/heads/main.zip) this repo and extract its content inside `Sven Co-op\svencoop_(hd|addon|downloads)\`.

2. Register the new weapons in your mapscript:

	1. In your mapscript header add `#include "classic_weapons"` or add `map_script classic_weapons` in your map cfg.
	2. Inside your `MapInit()` function add `CLASSIC_WEAPONS::Register();`.

3. To play with the new weapons place them in the map or give it yourself with `give <weapon_name>` command **OR** consider using Outerbeast's [info_itemswap](https://github.com/Outerbeast/Entities-and-Gamemodes/blob/master/info_itemswap.as) (instructions on how to use there).

* Weapon names:

	- weapon_hlpython
	- weapon_ofeagle
	- weapon_ofknife
	- weapon_ofm249
	- weapon_ofpenguin
	- weapon_ofshockrifle
	- weapon_ofsniperrifle

## Notes

- The max ammo for the M249 and the ShockRifle are the same as those of the Sven Co-op version to avoid overwriting the weapon's default values.

## Console Variables

- `revolver_laser_sight`: Enables the python laser sight. (default: 0)

- `m249_wide_spread`: Sets whether m249 uses wide spread. (default: 0)

- `m249_knockback`: Enables m249 knockback on firing. (default: 1)

- `shockrifle_fast`: Enables rapid fire and rapid ammo regeneration. (default: 0)

- `knife_allow_backstab`: Enables knife backstack (default: 1)

Change its value with `as_command` e.g.:

`as_command revolver_laser_sight 1`

**IMPORTANT:** To modify the values you must at least have access to admin.

## Credits

* Code format based on [KernCore's Custom Weapon Projects](https://github.com/KernCore91#sven-co-op-plugins).

* All weapons code was ported/based from SamVanheer's [Half-Life Unified SDK](https://github.com/SamVanheer/halflife-unified-sdk), [Half-Life Updated](https://github.com/SamVanheer/halflife-updated) and [Half-Life Op4 Updated](https://github.com/SamVanheer/halflife-op4-updated).
