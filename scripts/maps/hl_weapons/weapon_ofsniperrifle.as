/*
 * The Opposing Force version of the sniper
 */

#include 'utils'

namespace CSniperRifle
{

enum sniperrifle_e
{
  DRAW = 0,
  SLOWIDLE,
  FIRE,
  FIRELASTROUND,
  RELOAD1,
  RELOAD2,
  RELOAD3,
  SLOWIDLE2,
  HOLSTER
};

// Weapon information
const int MAX_CARRY    = 15;
const int MAX_CLIP     = 5;
const int DEFAULT_GIVE = MAX_CLIP;
const int WEIGHT       = 10;

class weapon_ofsniperrifle : ScriptBasePlayerWeaponEntity, WeaponUtils
{
  private CBasePlayer@ m_pPlayer
  {
    get const { return cast<CBasePlayer>(self.m_hPlayer.GetEntity()); }
    set       { self.m_hPlayer = EHandle(@value); }
  }
  private float m_flReloadStart;
  private bool m_bReloading;

  void Spawn()
  {
    Precache();
    g_EntityFuncs.SetModel(self, self.GetW_Model('models/hlclassic/w_m40a1.mdl'));
    self.m_iDefaultAmmo = DEFAULT_GIVE;
    self.FallInit();
  }

  void Precache()
  {
    self.PrecacheCustomModels();
    g_Game.PrecacheModel('models/hlclassic/v_m40a1.mdl');
    g_Game.PrecacheModel('models/hlclassic/w_m40a1.mdl');
    g_Game.PrecacheModel('models/hlclassic/p_m40a1.mdl');

    g_SoundSystem.PrecacheSound('hlclassic/weapons/sniper_fire.wav');
    g_SoundSystem.PrecacheSound('weapons/sniper_zoom.wav');
    g_SoundSystem.PrecacheSound('hlclassic/weapons/sniper_reload_first_seq.wav'); // default viewmodel; sequence: 4, 6; frame: 1; event 5004
    g_SoundSystem.PrecacheSound('hlclassic/weapons/sniper_reload_second_seq.wav'); // default viewmodel; sequence: 5; frame: 1; event 5004
    g_SoundSystem.PrecacheSound('hlclassic/weapons/sniper_bolt1.wav'); // default viewmodel; sequence: 2; frame: 32; event 5004
    g_SoundSystem.PrecacheSound('hlclassic/weapons/sniper_bolt2.wav'); // default viewmodel; sequence: 3; frame: 32; event 5004
    g_SoundSystem.PrecacheSound('hlclassic/weapons/357_cock1.wav');

    g_Game.PrecacheGeneric('sound/hlclassic/weapons/sniper_fire.wav');
    g_Game.PrecacheGeneric('sound/hlclassic/weapons/sniper_reload_first_seq.wav');
    g_Game.PrecacheGeneric('sound/hlclassic/weapons/sniper_reload_second_seq.wav');
    g_Game.PrecacheGeneric('sound/hlclassic/weapons/sniper_bolt1.wav');
    g_Game.PrecacheGeneric('sound/hlclassic/weapons/sniper_bolt2.wav');

    g_Game.PrecacheGeneric('sprites/hl_weapons/' + pev.classname + '.txt');
  }

  bool GetItemInfo(ItemInfo& out info)
  {
    info.iMaxAmmo1 = MAX_CARRY;
    info.iMaxAmmo2 = -1;
    info.iAmmo1Drop = MAX_CLIP;
    info.iAmmo2Drop = -1;
    info.iMaxClip = MAX_CLIP;
    info.iFlags = 0;
    info.iSlot = 5;
    info.iPosition = 5;
    info.iId = g_ItemRegistry.GetIdForName(pev.classname);
    info.iWeight = WEIGHT;

    return true;
  }

  bool AddToPlayer(CBasePlayer@ pPlayer)
  {
    if (!BaseClass.AddToPlayer(pPlayer))
      return false;

    NetworkMessage message(MSG_ONE, NetworkMessages::WeapPickup, pPlayer.edict());
      message.WriteLong(g_ItemRegistry.GetIdForName(pev.classname));
    message.End();

    return true;
  }

  bool PlayEmptySound()
  {
    if (self.m_bPlayEmptySound)
    {
      g_SoundSystem.EmitSoundDyn(m_pPlayer.edict(), CHAN_WEAPON, 'hlclassic/weapons/357_cock1.wav', 0.8, ATTN_NORM, 0, PITCH_NORM);
      self.m_bPlayEmptySound = false;
      return false;
    }
    return false;
  }

  bool Deploy()
  {
    bool bResult = self.DefaultDeploy(self.GetV_Model('models/hlclassic/v_m40a1.mdl'), self.GetP_Model('models/hlclassic/p_m40a1.mdl'), DRAW, 'sniper');
    self.m_flTimeWeaponIdle = WeaponTimeBase() + 1.0;
    return bResult;
  }

  void Holster(int skiplocal = 0)
  {
    self.m_fInReload = false;

    if (m_pPlayer.m_iFOV != 0)
    {
      SecondaryAttack();
    }

    BaseClass.Holster(skiplocal);
  }

  void PrimaryAttack()
  {
    if (m_pPlayer.pev.waterlevel == WATERLEVEL_HEAD)
    {
      self.PlayEmptySound();
      self.m_flNextPrimaryAttack = WeaponTimeBase() + 1.0;
      return;
    }

    if (self.m_iClip <= 0)
    {
      self.PlayEmptySound();
      return;
    }

    m_pPlayer.m_iWeaponVolume = QUIET_GUN_VOLUME;

    --self.m_iClip;

    m_pPlayer.SetAnimation(PLAYER_ATTACK1);

    Math.MakeVectors(m_pPlayer.pev.v_angle + m_pPlayer.pev.punchangle);

    Vector vecSrc = m_pPlayer.GetGunPosition();
    Vector vecAiming = m_pPlayer.GetAutoaimVector(AUTOAIM_2DEGREES);

    FireBulletsPlayer(1, vecSrc, vecAiming, g_vecZero, 8192.0, BULLET_PLAYER_SNIPER, 0);

    pev.effects |= EF_MUZZLEFLASH;

    self.SendWeaponAnim(self.m_iClip <= 0 ? FIRELASTROUND : FIRE, 0, pev.body);
    m_pPlayer.pev.punchangle.x = -2.0;

    g_SoundSystem.EmitSoundDyn(m_pPlayer.edict(), CHAN_WEAPON, 'weapons/sniper_fire.wav', Math.RandomFloat(0.9, 1.0), ATTN_NORM, 0, 98 + Math.RandomLong(0, 3));

    // Not present in sdk
    if (self.m_iClip <= 0 && m_pPlayer.m_rgAmmo(self.m_iPrimaryAmmoType) <= 0)
      m_pPlayer.SetSuitUpdate('!HEV_AMO0', false, 0);

    self.m_flNextPrimaryAttack = WeaponTimeBase() + 2.0;
    self.m_flTimeWeaponIdle = WeaponTimeBase() + 2.0;
  }

  void SecondaryAttack()
  {
    g_SoundSystem.EmitSoundDyn(m_pPlayer.edict(), CHAN_ITEM, 'weapons/sniper_zoom.wav', VOL_NORM, ATTN_NORM, 0, PITCH_NORM);

    ToggleZoom();

    self.m_flNextSecondaryAttack = WeaponTimeBase() + 0.5;
  }

  void Reload()
  {
    if (self.m_iClip == MAX_CLIP)
      return;

    if (m_pPlayer.m_rgAmmo(self.m_iPrimaryAmmoType) > 0)
    {
      if (m_pPlayer.m_iFOV != 0)
      {
        ToggleZoom();
      }

      if (self.m_iClip > 0)
      {
        if (self.DefaultReload(MAX_CLIP, RELOAD3, 2.324))
        {
          self.m_flNextPrimaryAttack = WeaponTimeBase() + 2.324;
        }
      }
      else if (self.DefaultReload(MAX_CLIP, RELOAD1, 2.324))
      {
        self.m_flNextPrimaryAttack = WeaponTimeBase() + 4.102;
        m_flReloadStart = g_Engine.time;
        m_bReloading = true;
      }
      else
      {
        m_bReloading = false;
      }
    }

    self.m_flTimeWeaponIdle = WeaponTimeBase() + 4.102;

    BaseClass.Reload();
  }

  void WeaponIdle()
  {
    m_pPlayer.GetAutoaimVector(AUTOAIM_2DEGREES);

    self.ResetEmptySound();

    if (m_bReloading && g_Engine.time >= m_flReloadStart + 2.324)
    {
      self.SendWeaponAnim(RELOAD2, 0, pev.body);
      m_bReloading = false;
    }

    if (self.m_flTimeWeaponIdle < WeaponTimeBase())
    {
      if (self.m_iClip > 0)
        self.SendWeaponAnim(SLOWIDLE, 0, pev.body);
      else
        self.SendWeaponAnim(SLOWIDLE2, 0, pev.body);

      self.m_flTimeWeaponIdle = WeaponTimeBase() + 4.348;
    }
  }

  void ToggleZoom()
  {
    if (m_pPlayer.m_iFOV == 0)
    {
      m_pPlayer.m_iFOV = 18;
    }
    else
    {
      m_pPlayer.m_iFOV = 0;
    }
  }
}

string GetName()
{
  return 'weapon_ofsniperrifle';
}

void Register()
{
  if (!g_CustomEntityFuncs.IsCustomEntity(GetName()))
  {
    g_CustomEntityFuncs.RegisterCustomEntity('CSniperRifle::weapon_ofsniperrifle', GetName());
    g_ItemRegistry.RegisterWeapon(GetName(), 'hl_weapons', 'm40a1', '', 'ammo_762', '');
  }
}

}
