#include "hl_weapons/weapon_hlpython"
#include "opfor/weapon_ofeagle"
#include "opfor/weapon_ofknife"
#include "opfor/weapon_ofm249"
#include "opfor/weapon_ofpenguin"
#include "opfor/weapon_ofshockrifle"
#include "opfor/weapon_ofsniperrifle"

namespace CLASSIC_WEAPONS
{

void Register()
{
  CHLPython::Register();
  COFEagle::Register();
  COFKnife::Register();
  COFM249::Register();
  COFPenguin::Register();
  COFShockRifle::Register();
  COFSniperRifle::Register();
}

}
