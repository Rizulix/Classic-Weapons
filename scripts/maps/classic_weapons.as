#include "hl_weapons/weapon_hlpython"
#include "opfor/weapon_ofeagle"
#include "opfor/weapon_ofm249"
#include "opfor/weapon_ofshockrifle"
#include "opfor/weapon_ofsniperrifle"

namespace CLASSIC_WEAPONS
{

void Register()
{
  CHLPython::Register();
  COFEagle::Register();
  COFM249::Register();
  COFShockRifle::Register();
  COFSniperRifle::Register();
}

}
