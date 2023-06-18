/* 
 * The Opposing Force version of the m249
 */

#include 'utils'

namespace CM249
{

enum m249_e
{
  SLOWIDLE = 0,
  IDLE2,
  RELOAD_START,
  RELOAD_END,
  HOLSTER,
  DRAW,
  SHOOT1,
  SHOOT2,
  SHOOT3
};

// Weapon information
const int MAX_CARRY    = 600;
const int MAX_CLIP     = 100;
const int DEFAULT_GIVE = MAX_CLIP;
const int WEIGHT       = 20;

// Spread thing
const CCVar@ g_M249WideSpread = CCVar('m249_wide_spread', 0, '', ConCommandFlag::Cheat); // as_command m249_wide_spread
// Knockback thing
const CCVar@ g_M249Knockback = CCVar('m249_knockback', 1, '', ConCommandFlag::Cheat); // as_command m249_knockback

class weapon_ofm249 : ScriptBasePlayerWeaponEntity, WeaponUtils
{
  private CBasePlayer@ m_pPlayer
  {
    get const { return cast<CBasePlayer>(self.m_hPlayer.GetEntity()); }
    set       { self.m_hPlayer = EHandle(@value); }
  }
  private float m_flNextAnimTime;
  private float m_flReloadStart;
  private bool m_bAlternatingEject = false;
  private bool m_bReloading;
  private int m_iShell;
  private int m_iLink;

  void Spawn()
  {
    Precache();
    g_EntityFuncs.SetModel(self, self.GetW_Model('models/hlclassic/w_saw.mdl'));
    self.m_iDefaultAmmo = DEFAULT_GIVE;
    self.FallInit();
  }

  void Precache()
  {
    self.PrecacheCustomModels();
    g_Game.PrecacheModel('models/hlclassic/v_saw.mdl');
    g_Game.PrecacheModel('models/hlclassic/w_saw.mdl');
    g_Game.PrecacheModel('models/hlclassic/p_saw.mdl');

    m_iShell = g_Game.PrecacheModel('models/hlclassic/saw_shell.mdl');
    m_iLink = g_Game.PrecacheModel('models/saw_link.mdl');

    g_SoundSystem.PrecacheSound('hlclassic/weapons/saw_reload.wav'); // default viewmodel; sequence: 2; frame: 1; event 5004
    g_SoundSystem.PrecacheSound('hlclassic/weapons/saw_reload2.wav'); // default viewmodel; sequence: 3; frame: 0; event 5004
    g_SoundSystem.PrecacheSound('weapons/saw_fire1.wav');
    g_SoundSystem.PrecacheSound('hlclassic/weapons/357_cock1.wav');

    g_Game.PrecacheGeneric('sound/hlclassic/weapons/saw_reload.wav');
    g_Game.PrecacheGeneric('sound/hlclassic/weapons/saw_reload2.wav');

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
    info.iPosition = 6;
    info.iId = g_ItemRegistry.GetIdForName(pev.classname);
    info.iWeight = WEIGHT;

    return true;
  }

  bool AddToPlayer(CBasePlayer@ pPlayer)
  {
    if(!BaseClass.AddToPlayer(pPlayer))
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
    bool bResult = self.DefaultDeploy(self.GetV_Model('models/hlclassic/v_saw.mdl'), self.GetP_Model('models/hlclassic/p_saw.mdl'), DRAW, 'saw', 0, pev.body);
    self.m_flTimeWeaponIdle = WeaponTimeBase() + 1.0;
    return bResult;
  }

  void Holster(int skiplocal = 0)
  {
    SetThink(null);

    m_bReloading = false;
    self.m_fInReload = false;

    BaseClass.Holster(skiplocal);
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
      if (!self.m_fInReload)
      {
        self.PlayEmptySound();
        self.m_flNextPrimaryAttack = WeaponTimeBase() + 0.15;
      }
      return;
    }

    --self.m_iClip;

    pev.body = RecalculateBody(self.m_iClip);

    m_bAlternatingEject = !m_bAlternatingEject;

    m_pPlayer.m_iWeaponVolume = NORMAL_GUN_VOLUME;
    m_pPlayer.m_iWeaponFlash = NORMAL_GUN_FLASH;

    m_pPlayer.pev.effects |= EF_MUZZLEFLASH;

    m_flNextAnimTime = WeaponTimeBase() + 0.2;

    m_pPlayer.SetAnimation(PLAYER_ATTACK1);

    Math.MakeVectors(m_pPlayer.pev.v_angle + m_pPlayer.pev.punchangle);

    Vector vecSrc   = m_pPlayer.GetGunPosition();
    Vector vecAiming = m_pPlayer.GetAutoaimVector(AUTOAIM_5DEGREES);

    Vector vecSpread;

    if (g_M249WideSpread.GetBool())
    {
      if (m_pPlayer.pev.button & IN_DUCK != 0)
      {
        vecSpread = VECTOR_CONE_3DEGREES;
      }
      else if (m_pPlayer.pev.button & (IN_MOVERIGHT | IN_MOVELEFT | IN_FORWARD | IN_BACK) != 0)
      {
        vecSpread = VECTOR_CONE_15DEGREES;
      }
      else
      {
        vecSpread = VECTOR_CONE_6DEGREES;
      }
    }
    else
    {
      if (m_pPlayer.pev.button & IN_DUCK != 0)
      {
        vecSpread = VECTOR_CONE_2DEGREES;
      }
      else if (m_pPlayer.pev.button & (IN_MOVERIGHT | IN_MOVELEFT | IN_FORWARD | IN_BACK) != 0)
      {
        vecSpread = VECTOR_CONE_10DEGREES;
      }
      else
      {
        vecSpread = VECTOR_CONE_4DEGREES;
      }
    }

    FireBulletsPlayer(1, vecSrc, vecAiming, vecSpread, 8192.0, BULLET_PLAYER_SAW, 2);

    pev.effects |= EF_MUZZLEFLASH;

    self.SendWeaponAnim(Math.RandomLong(0, 2) + SHOOT1, 0, pev.body);
    m_pPlayer.pev.punchangle.x = Math.RandomFloat(-2.0, 2.0);
    m_pPlayer.pev.punchangle.y = Math.RandomFloat(-1.0, 1.0);

    Vector ShellVelocity, ShellOrigin;
    // GetDefaultShellInfo(ShellVelocity, ShellOrigin, -28.0, 24.0, 4.0);
    GetDefaultShellInfo(ShellVelocity, ShellOrigin, 14.0, -10.0, 8.0);
    g_EntityFuncs.EjectBrass(ShellOrigin, ShellVelocity, m_pPlayer.pev.angles.y, m_bAlternatingEject ? m_iLink : m_iShell, TE_BOUNCE_SHELL);

    g_SoundSystem.EmitSoundDyn(m_pPlayer.edict(), CHAN_WEAPON, 'weapons/saw_fire1.wav', VOL_NORM, ATTN_NORM, 0, 94 + Math.RandomLong(0, 15));

    if (self.m_iClip <= 0 && m_pPlayer.m_rgAmmo(self.m_iPrimaryAmmoType) <= 0)
      m_pPlayer.SetSuitUpdate('!HEV_AMO0', false, 0);

    self.m_flNextPrimaryAttack = WeaponTimeBase() + 0.067;
    self.m_flTimeWeaponIdle = WeaponTimeBase() + 0.2;

    if (g_M249Knockback.GetBool())
    {
      Math.MakeVectors(m_pPlayer.pev.v_angle + m_pPlayer.pev.punchangle);

      const Vector vecVelocity = m_pPlayer.pev.velocity;
      const float flZVel = m_pPlayer.pev.velocity.z;

      Vector vecInvPushDir = g_Engine.v_forward * 35.0;
      float flNewZVel = g_EngineFuncs.CVarGetFloat('sv_maxspeed');

      if (vecInvPushDir.z >= 10.0)
        flNewZVel = vecInvPushDir.z;

      // Yeah... no deathmatch knockback
      m_pPlayer.pev.velocity = m_pPlayer.pev.velocity - vecInvPushDir;
      m_pPlayer.pev.velocity.z = flZVel;
    }
  }

  void Reload()
  {
    if (self.m_iClip == MAX_CLIP || m_pPlayer.m_rgAmmo(self.m_iPrimaryAmmoType) <= 0)
      return;

    if (self.DefaultReload(MAX_CLIP, RELOAD_START, 1.0, pev.body))
    {
      m_bReloading = true;

      self.m_flNextPrimaryAttack = WeaponTimeBase() + 3.78;
      self.m_flTimeWeaponIdle = WeaponTimeBase() + 3.78;

      m_flReloadStart = g_Engine.time;
    }

    BaseClass.Reload();
  }

  void ItemPostFrame()
  {
    // Speed up player reload anim
    if (m_bReloading && g_Engine.time < m_flReloadStart + 3.78)
      m_pPlayer.pev.framerate = 2.15;

    BaseClass.ItemPostFrame();
  }

  void WeaponIdle()
  {
    self.ResetEmptySound();

    m_pPlayer.GetAutoaimVector(AUTOAIM_5DEGREES);

    if (m_bReloading && g_Engine.time >= m_flReloadStart + 1.33)
    {
      m_bReloading = false;

      pev.body = 0;
      self.SendWeaponAnim(RELOAD_END, 0, pev.body);
    }

    if (self.m_flTimeWeaponIdle <= WeaponTimeBase())
    {
      int iAnim;
      const float flNextIdle = g_PlayerFuncs.SharedRandomFloat(m_pPlayer.random_seed, 0.0, 1.0);
      if (flNextIdle <= 0.95)
      {
        iAnim = SLOWIDLE;
        self.m_flTimeWeaponIdle = WeaponTimeBase() + 5.0;
      }
      else
      {
        iAnim = IDLE2;
        self.m_flTimeWeaponIdle = WeaponTimeBase() + 6.16;
      }

      self.SendWeaponAnim(iAnim, 0, pev.body);
    }
  }

  private int RecalculateBody(int iClip)
  {
    if (iClip == 0)
    {
      return 8;
    }
    else if (iClip >= 0 && iClip <= 7)
    {
      return 9 - iClip;
    }
    else
    {
      return 0;
    }
  }
}

string GetName()
{
  return 'weapon_ofm249';
}

void Register()
{
  if (!g_CustomEntityFuncs.IsCustomEntity(GetName()))
  {
    g_CustomEntityFuncs.RegisterCustomEntity('CM249::weapon_ofm249', GetName());
    g_ItemRegistry.RegisterWeapon(GetName(), 'hl_weapons', '556', '', 'ammo_556', '');
  }
}

}
