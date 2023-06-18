/*
 * The Half-Life version of the python
 */

#include 'utils'

namespace CPython
{

enum python_e
{
  IDLE1 = 0,
  FIDGET,
  FIRE1,
  RELOAD,
  HOLSTER,
  DRAW,
  IDLE2,
  IDLE3
};

// Weapon information
const int MAX_CARRY    = 36;
const int MAX_CLIP     = 6;
const int DEFAULT_GIVE = MAX_CLIP;
const int WEIGHT       = 15;

// Laser sight thing
const CCVar@ g_RevolverLaserSight = CCVar('revolver_laser_sight', 1, '', ConCommandFlag::Cheat); // as_command revolver_laser_sight

bool UseLaserSight()
{
  return g_RevolverLaserSight.GetBool();
}

class weapon_hlpython : ScriptBasePlayerWeaponEntity, WeaponUtils
{
  private CBasePlayer@ m_pPlayer
  {
    get const { return cast<CBasePlayer>(self.m_hPlayer.GetEntity()); }
    set       { self.m_hPlayer = EHandle(@value); }
  }

  void Spawn()
  {
    Precache();
    g_EntityFuncs.SetModel(self, self.GetW_Model('models/hlclassic/w_357.mdl'));
    self.m_iDefaultAmmo = DEFAULT_GIVE;
    self.FallInit();
  }

  void Precache()
  {
    self.PrecacheCustomModels();
    g_Game.PrecacheModel('models/hlclassic/v_357.mdl');
    g_Game.PrecacheModel('models/hlclassic/w_357.mdl');
    g_Game.PrecacheModel('models/hlclassic/p_357.mdl');

    g_SoundSystem.PrecacheSound('hlclassic/weapons/357_reload1.wav'); // default viewmodel; sequence: 3; frame: 70; event 5004
    g_SoundSystem.PrecacheSound('hlclassic/weapons/357_cock1.wav');
    g_SoundSystem.PrecacheSound('hlclassic/weapons/357_shot1.wav');
    g_SoundSystem.PrecacheSound('hlclassic/weapons/357_shot2.wav');

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
    info.iSlot = 1;
    info.iPosition = 6;
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
    if (UseLaserSight())
    {
      pev.body = 1;
    }
    else
    {
      pev.body = 0;
    }

    bool bResult = self.DefaultDeploy(self.GetV_Model('models/hlclassic/v_357.mdl'), self.GetP_Model('models/hlclassic/p_357.mdl'), DRAW, 'python', 0, pev.body);
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

    BaseClass.Holster(skiplocal );
  }

  void PrimaryAttack()
  {
    if (m_pPlayer.pev.waterlevel == WATERLEVEL_HEAD)
    {
      self.PlayEmptySound();
      self.m_flNextPrimaryAttack = WeaponTimeBase() + 0.15;
      return;
    }

    if (self.m_iClip <= 0)
    {
      if (self.m_bFireOnEmpty)
      {
        self.PlayEmptySound();
        self.m_flNextPrimaryAttack = WeaponTimeBase() + 0.15;
      }
      return;
    }

    m_pPlayer.m_iWeaponVolume = LOUD_GUN_VOLUME;
    m_pPlayer.m_iWeaponFlash = BRIGHT_GUN_FLASH;

    --self.m_iClip;

    m_pPlayer.pev.effects |= EF_MUZZLEFLASH;

    m_pPlayer.SetAnimation(PLAYER_ATTACK1);

    Math.MakeVectors(m_pPlayer.pev.v_angle + m_pPlayer.pev.punchangle);

    Vector vecSrc = m_pPlayer.GetGunPosition();
    Vector vecAiming = m_pPlayer.GetAutoaimVector(AUTOAIM_10DEGREES);

    FireBulletsPlayer(1, vecSrc, vecAiming, VECTOR_CONE_1DEGREES, 8192.0, BULLET_PLAYER_357, 0);

    pev.effects |= EF_MUZZLEFLASH;

    self.SendWeaponAnim(FIRE1, 0, pev.body);
    m_pPlayer.pev.punchangle.x = -10.0;

    switch (Math.RandomLong(0, 1))
    {
    case 0:
      g_SoundSystem.EmitSoundDyn(m_pPlayer.edict(), CHAN_WEAPON, 'hlclassic/weapons/357_shot1.wav', Math.RandomFloat(0.8, 0.9), ATTN_NORM, 0, PITCH_NORM);
      break;
    case 1:
      g_SoundSystem.EmitSoundDyn(m_pPlayer.edict(), CHAN_WEAPON, 'hlclassic/weapons/357_shot2.wav', Math.RandomFloat(0.8, 0.9), ATTN_NORM, 0, PITCH_NORM);
      break;
    }

    if (self.m_iClip <= 0 && m_pPlayer.m_rgAmmo(self.m_iPrimaryAmmoType) <= 0)
      m_pPlayer.SetSuitUpdate('!HEV_AMO0', false, 0);

    self.m_flNextPrimaryAttack = WeaponTimeBase() + 0.75;
    self.m_flTimeWeaponIdle = WeaponTimeBase() + g_PlayerFuncs.SharedRandomFloat(m_pPlayer.random_seed, 10.0, 15.0);
  }

  void SecondaryAttack()
  {
    if (!UseLaserSight())
    {
      return;
    }

    if (m_pPlayer.m_iFOV != 0)
    {
      m_pPlayer.m_iFOV = 0;
    }
    else if (m_pPlayer.m_iFOV != 40)
    {
      m_pPlayer.m_iFOV = 40;
    }

    self.m_flNextSecondaryAttack = WeaponTimeBase() + 0.5;
  }

  void ItemPostFrame()
  {
    const int currentBody = UseLaserSight() ? 1 : 0;

    if (currentBody != pev.body)
    {
      pev.body = currentBody;

      self.m_flTimeWeaponIdle = 0;

      if (!UseLaserSight() && m_pPlayer.m_iFOV != 0)
      {
        m_pPlayer.m_iFOV = 0;
      }
    }

    BaseClass.ItemPostFrame();
  }

  void Reload()
  {
    if (self.m_iClip == MAX_CLIP || m_pPlayer.m_rgAmmo(self.m_iPrimaryAmmoType) <= 0)
      return;

    if (m_pPlayer.m_iFOV != 0)
    {
      m_pPlayer.m_iFOV = 0;
    }

    self.DefaultReload(MAX_CLIP, RELOAD, 2.0, pev.body);
    self.m_flTimeWeaponIdle = WeaponTimeBase() + 3.0;

    BaseClass.Reload();
  }

  void WeaponIdle()
  {
    self.ResetEmptySound();

    m_pPlayer.GetAutoaimVector(AUTOAIM_10DEGREES);

    if (self.m_flTimeWeaponIdle > WeaponTimeBase())
      return;

    int iAnim;
    float flRand = g_PlayerFuncs.SharedRandomFloat(m_pPlayer.random_seed, 0.0, 1.0);
    if (flRand <= 0.5)
    {
      iAnim = IDLE1;
      self.m_flTimeWeaponIdle = WeaponTimeBase() + (70.0 / 30.0);
    }
    else if (flRand <= 0.7)
    {
      iAnim = IDLE2;
      self.m_flTimeWeaponIdle = WeaponTimeBase() + (60.0 / 30.0);
    }
    else if (flRand <= 0.9)
    {
      iAnim = IDLE3;
      self.m_flTimeWeaponIdle = WeaponTimeBase() + (88.0 / 30.0);
    }
    else
    {
      iAnim = FIDGET;
      self.m_flTimeWeaponIdle = WeaponTimeBase() + (170.0 / 30.0);
    }

    self.SendWeaponAnim(iAnim, 0, pev.body);
  }
}

string GetName()
{
  return 'weapon_hlpython';
}

void Register()
{
  if (!g_CustomEntityFuncs.IsCustomEntity(GetName()))
  {
    g_CustomEntityFuncs.RegisterCustomEntity('CPython::weapon_hlpython', GetName());
    g_ItemRegistry.RegisterWeapon(GetName(), 'hl_weapons', '357', '', 'ammo_357', '');
  }
}

}
