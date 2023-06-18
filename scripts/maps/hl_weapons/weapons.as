#include 'weapon_hlpython'
#include 'weapon_ofeagle'
#include 'weapon_ofm249'
#include 'weapon_ofsniperrifle'
#include 'weapon_ofshockrifle'

void RegisterClassicWeapons()
{
  CPython::Register();
  CEagle::Register();
  CM249::Register();
  CShockRifle::Register();
  CSniperRifle::Register();
}
