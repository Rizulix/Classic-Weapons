#include "weapon_hlpython"
#include "weapon_ofeagle"
#include "weapon_ofm249"
#include "weapon_ofsniperrifle"
#include "weapon_ofshockrifle"

// Weapon behaviour/mode
// Like the singleplayer/multiplayer differences in vanilla HL/OF
bool IsMultiplayer = false;

void RegisterClassicWeapons()
{
	HL_PYTHON::Register();
	OF_EAGLE::Register();
	OF_M249::Register();
	OF_SHOCKRIFLE::Register();
	OF_SNIPERRIFLE::Register();
}

