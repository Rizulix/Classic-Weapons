/*
 * The Opposing Force version of the eagle
 */

#include 'utils'

namespace CEagle
{

enum eagle_e
{
  IDLE1 = 0,
  IDLE2,
  IDLE3,
  IDLE4,
  IDLE5,
  SHOOT,
  SHOOT_EMPTY,
  RELOAD_NOSHOT,
  RELOAD,
  DRAW,
  HOLSTER
};

// Weapon information
const int MAX_CARRY    = 36;
const int MAX_CLIP     = 7;
const int DEFAULT_GIVE = MAX_CLIP;
const int WEIGHT       = 15;

string SHELL_MDL = 'models/hlclassic/shell.mdl';

class weapon_ofeagle : ScriptBasePlayerWeaponEntity, WeaponUtils
{
  private CBasePlayer@ m_pPlayer
  {
    get const { return cast<CBasePlayer>(self.m_hPlayer.GetEntity()); }
    set       { self.m_hPlayer = EHandle(@value); }
  }
  // Yeah... no custom eagle_laser (laser_spot)
  private EHandle m_hLaser;
  private CSprite@ m_pLaser
  {
    get const { return cast<CSprite>(m_hLaser.GetEntity()); }
    set       { m_hLaser = EHandle(@value); }
  }
  private CScheduledFunction@ laser_nextthink;
  // Starts with the laser active as well as the SC version
  private bool m_bLaserActive = true;
  private bool m_bSpotVisible;
  private int m_iShell;

  void Spawn()
  {
    Precache();
    g_EntityFuncs.SetModel(self, self.GetW_Model('models/hlclassic/w_desert_eagle.mdl'));
    self.m_iDefaultAmmo = DEFAULT_GIVE;
    self.FallInit();
  }

  void Precache()
  {
    self.PrecacheCustomModels();
    g_Game.PrecacheModel('models/hlclassic/v_desert_eagle.mdl');
    g_Game.PrecacheModel('models/hlclassic/w_desert_eagle.mdl');
    g_Game.PrecacheModel('models/hlclassic/p_desert_eagle.mdl');

    g_Game.PrecacheModel('sprites/laserdot.spr');

    m_iShell = g_Game.PrecacheModel(SHELL_MDL);

    g_SoundSystem.PrecacheSound('weapons/desert_eagle_fire.wav');
    g_SoundSystem.PrecacheSound('hlclassic/weapons/desert_eagle_reload.wav'); // default viewmodel; sequence: 7, 8; frame: 1; event 5004
    g_SoundSystem.PrecacheSound('weapons/desert_eagle_sight.wav');
    g_SoundSystem.PrecacheSound('weapons/desert_eagle_sight2.wav');
    g_SoundSystem.PrecacheSound('hlclassic/weapons/357_cock1.wav');

    g_Game.PrecacheGeneric('sound/hlclassic/weapons/desert_eagle_reload.wav');

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
    info.iPosition = 7;
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
    m_bSpotVisible = true;

    bool bResult = self.DefaultDeploy(self.GetV_Model('models/hlclassic/v_desert_eagle.mdl'), self.GetP_Model('models/hlclassic/p_desert_eagle.mdl'), DRAW, 'onehanded');
    self.m_flTimeWeaponIdle = WeaponTimeBase() + 1.0;
    return bResult;
  }

  void Holster(int skiplocal = 0)
  {
    self.m_fInReload = false;

    if (m_pLaser !is null)
    {
      RemoveLaser();
      m_bSpotVisible = false;
    }

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
        if (self.m_bFireOnEmpty)
        {
          self.PlayEmptySound();
          self.m_flNextPrimaryAttack = WeaponTimeBase() + 0.2;
        }
      }
      return;
    }

    m_pPlayer.m_iWeaponVolume = NORMAL_GUN_VOLUME;
    m_pPlayer.m_iWeaponFlash = NORMAL_GUN_FLASH;

    --self.m_iClip;

    m_pPlayer.pev.effects |= EF_MUZZLEFLASH;

    m_pPlayer.SetAnimation(PLAYER_ATTACK1);

    if (m_pLaser !is null && m_bLaserActive)
    {
      SuspendLaser(0.6);
    }

    Math.MakeVectors(m_pPlayer.pev.v_angle + m_pPlayer.pev.punchangle);

    Vector vecSrc = m_pPlayer.GetGunPosition();
    Vector vecAiming = m_pPlayer.GetAutoaimVector(AUTOAIM_10DEGREES);

    const float flSpread = m_bLaserActive ? 0.001 : 0.1;

    FireBulletsPlayer(1, vecSrc, vecAiming, Vector(flSpread, flSpread, flSpread), 8192.0, BULLET_PLAYER_EAGLE, 0);

    self.m_flNextPrimaryAttack = self.m_flNextSecondaryAttack = WeaponTimeBase() + (m_bLaserActive ? 0.5 : 0.22);

    pev.effects |= EF_MUZZLEFLASH;

    self.SendWeaponAnim(self.m_iClip <= 0 ? SHOOT_EMPTY : SHOOT, 0, pev.body);
    m_pPlayer.pev.punchangle.x = -4.0;

    Vector ShellVelocity, ShellOrigin;
    // GetDefaultShellInfo(ShellVelocity, ShellOrigin, -9.0, 14.0, 9.0);
    GetDefaultShellInfo(ShellVelocity, ShellOrigin, 14.0, -10.0, 8.0);
    g_EntityFuncs.EjectBrass(ShellOrigin, ShellVelocity, m_pPlayer.pev.angles[1], m_iShell, TE_BOUNCE_SHELL);

    g_SoundSystem.EmitSoundDyn(m_pPlayer.edict(), CHAN_WEAPON, 'weapons/desert_eagle_fire.wav', Math.RandomFloat(0.92, 1.0), ATTN_NORM, 0, 98 + Math.RandomLong(0, 3));

    if (self.m_iClip <= 0 && m_pPlayer.m_rgAmmo(self.m_iPrimaryAmmoType) <= 0)
      m_pPlayer.SetSuitUpdate('!HEV_AMO0', false, 0);

    self.m_flTimeWeaponIdle = WeaponTimeBase() + g_PlayerFuncs.SharedRandomFloat(m_pPlayer.random_seed, 10.0, 15.0);

    UpdateLaser();
  }

  void SecondaryAttack()
  {
    m_bLaserActive = !m_bLaserActive;

    if (!m_bLaserActive)
    {
      if (m_pLaser !is null)
      {
        RemoveLaser();

        g_SoundSystem.EmitSound(m_pPlayer.edict(), CHAN_WEAPON, 'weapons/desert_eagle_sight2.wav', VOL_NORM, ATTN_NORM);
      }
    }

    self.m_flNextSecondaryAttack = WeaponTimeBase() + 0.5;
  }

  void Reload()
  {
    if (self.m_iClip == MAX_CLIP || m_pPlayer.m_rgAmmo(self.m_iPrimaryAmmoType) <= 0)
      return;

    const bool bResult = self.DefaultReload(MAX_CLIP, self.m_iClip > 0 ? RELOAD : RELOAD_NOSHOT, 1.5);

    if (bResult && m_pLaser !is null && m_bLaserActive)
    {
      SuspendLaser(1.6);

      self.m_flNextSecondaryAttack = WeaponTimeBase() + 1.5;
    }

    if (bResult)
    {
      self.m_flTimeWeaponIdle = WeaponTimeBase() + g_PlayerFuncs.SharedRandomFloat(m_pPlayer.random_seed, 10.0, 15.0);
    }

    BaseClass.Reload();
  }

  bool ShouldWeaponIdle()
  {
    return true;
  }

  void WeaponIdle()
  {
    UpdateLaser();

    // Because ShouldWeaponIdle() returns true this is always called making 
    // m_bPlayEmptySound always true allowing spamming of empty sound
    if (!self.m_bFireOnEmpty)
      self.ResetEmptySound();

    m_pPlayer.GetAutoaimVector(AUTOAIM_10DEGREES);

    if (self.m_flTimeWeaponIdle <= WeaponTimeBase() && self.m_iClip > 0)
    {
      int iAnim;
      const float flNextIdle = g_PlayerFuncs.SharedRandomFloat(m_pPlayer.random_seed, 0.0, 1.0);
      if (m_bLaserActive)
      {
        if (flNextIdle > 0.5)
        {
          iAnim = IDLE5;
          self.m_flTimeWeaponIdle = WeaponTimeBase() + 2.0;
        }
        else
        {
          iAnim = IDLE4;
          self.m_flTimeWeaponIdle = WeaponTimeBase() + 2.5;
        }
      }
      else
      {
        if (flNextIdle <= 0.3)
        {
          iAnim = IDLE1;
          self.m_flTimeWeaponIdle = WeaponTimeBase() + 2.5;
        }
        else
        {
          if (flNextIdle > 0.6)
          {
            iAnim = IDLE3;
            self.m_flTimeWeaponIdle = WeaponTimeBase() + 1.633;
          }
          else
          {
            iAnim = IDLE2;
            self.m_flTimeWeaponIdle = WeaponTimeBase() + 2.5;
          }
        }
      }

      self.SendWeaponAnim(iAnim, 0, pev.body);
    }
  }

  private void UpdateLaser()
  {
    if (m_bLaserActive && m_bSpotVisible)
    {
      if (m_pLaser is null)
      {
        @m_pLaser = CreateLaserSpot();
        g_SoundSystem.EmitSoundDyn(m_pPlayer.edict(), CHAN_WEAPON, 'weapons/desert_eagle_sight.wav', VOL_NORM, ATTN_NORM, 0, PITCH_NORM);
      }

      Math.MakeVectors(m_pPlayer.pev.v_angle);

      Vector vecSrc = m_pPlayer.GetGunPosition();
      Vector vecEnd = vecSrc + g_Engine.v_forward * 8192.0;

      TraceResult tr;
      g_Utility.TraceLine(vecSrc, vecEnd, dont_ignore_monsters, m_pPlayer.edict(), tr);

      g_EntityFuncs.SetOrigin(m_pLaser, tr.vecEndPos);
    }
  }

  // CEagleLaser::CreateSpot()
  private CSprite@ CreateLaserSpot()
  {
    CBaseEntity@ pEntity = g_EntityFuncs.CreateEntity('env_sprite', {
      {'model', 'sprites/laserdot.spr'}, 
      {'scale', '0.5'}, 
      {'framerate', '0.0'}}
    );

    pEntity.pev.rendermode = kRenderGlow;
    pEntity.pev.renderfx = kRenderFxNoDissipation;
    pEntity.pev.renderamt = 255.0;

    return cast<CSprite>(pEntity);
  }

  // CEagleLaser::Suspend(float flSuspendTime)
  private void SuspendLaser(float flSuspendTime)
  {
    m_pLaser.TurnOff();

    @laser_nextthink = @g_Scheduler.SetTimeout(@m_pLaser, 'TurnOn', flSuspendTime);
  }

  private void RemoveLaser()
  {
    g_EntityFuncs.Remove(@m_pLaser);
    @m_pLaser = @null;

    g_Scheduler.RemoveTimer(laser_nextthink);
    @laser_nextthink = @null;
  }
}

string GetName()
{
  return 'weapon_ofeagle';
}

void Register()
{
  if (!g_CustomEntityFuncs.IsCustomEntity(GetName()))
  {
    g_CustomEntityFuncs.RegisterCustomEntity('CEagle::weapon_ofeagle', GetName());
    g_ItemRegistry.RegisterWeapon(GetName(), 'hl_weapons', '357', '', 'ammo_357', '');
  }
}

}
