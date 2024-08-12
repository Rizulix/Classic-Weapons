/*
 * The Opposing Force version of the eagle
 */

namespace COFEagle
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
  RELOAD,
  RELOAD_NOSHOT,
  DRAW,
  HOLSTER
};

// Weapon information
const int MAX_CARRY    = 36;
const int MAX_CLIP     = 7;
const int DEFAULT_GIVE = MAX_CLIP;
const int WEIGHT       = 15;

class weapon_ofeagle : ScriptBasePlayerWeaponEntity
{
  private CBasePlayer@ m_pPlayer
  {
    get const { return cast<CBasePlayer>(self.m_hPlayer.GetEntity()); }
    set       { self.m_hPlayer = EHandle(@value); }
  }
  private EHandle m_hLaser; // Yeah... no custom eagle_laser (laser_spot)
  private bool m_bLaserActive;
  private int m_iShell;

  void Spawn()
  {
    Precache();
    g_EntityFuncs.SetModel(self, self.GetW_Model("models/hlclassic/w_desert_eagle.mdl"));
    self.m_iDefaultAmmo = DEFAULT_GIVE;
    self.FallInit();

    m_bLaserActive = true; // Starts with the laser active as well as the SC version
  }

  void Precache()
  {
    self.PrecacheCustomModels();
    g_Game.PrecacheModel("models/hlclassic/w_desert_eagle.mdl");
    g_Game.PrecacheModel("models/hlclassic/v_desert_eagle.mdl");
    g_Game.PrecacheModel("models/hlclassic/p_desert_eagle.mdl");

    g_Game.PrecacheModel("sprites/laserdot.spr");
    m_iShell = g_Game.PrecacheModel("models/hlclassic/shell.mdl");

    g_SoundSystem.PrecacheSound("weapons/desert_eagle_fire.wav");
    g_SoundSystem.PrecacheSound("weapons/desert_eagle_sight.wav");
    g_SoundSystem.PrecacheSound("weapons/desert_eagle_sight2.wav");
    g_SoundSystem.PrecacheSound("hlclassic/weapons/357_cock1.wav");
    g_SoundSystem.PrecacheSound("hlclassic/weapons/desert_eagle_reload.wav"); // sequence: 7, 8; frame: 1; event 5004
    g_Game.PrecacheGeneric("sound/hlclassic/weapons/desert_eagle_reload.wav");

    g_Game.PrecacheGeneric("sprites/opfor/" + pev.classname + ".txt");
  }

  bool AddToPlayer(CBasePlayer@ pPlayer)
  {
    if (!BaseClass.AddToPlayer(pPlayer))
      return false;

    NetworkMessage weapon(MSG_ONE, NetworkMessages::WeapPickup, pPlayer.edict());
      weapon.WriteLong(g_ItemRegistry.GetIdForName(pev.classname));
    weapon.End();
    return true;
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

  bool Deploy()
  {
    if (m_bLaserActive)
    {
      SetThink(ThinkFunction(LaserDeploy));
      pev.nextthink = g_Engine.time + 0.5f;
    }

    self.DefaultDeploy(self.GetV_Model("models/hlclassic/v_desert_eagle.mdl"), self.GetP_Model("models/hlclassic/p_desert_eagle.mdl"), DRAW, "onehanded");
    self.m_flNextPrimaryAttack = self.m_flNextSecondaryAttack = self.m_flTimeWeaponIdle = g_Engine.time + 1.0f;
    return true;
  }

  void Holster(int skiplocal = 0)
  {
    SetThink(null);
    GetLaserSpot().pev.effects |= EF_NODRAW;
    BaseClass.Holster(skiplocal);
  }

  void ItemPostFrame()
  {
    BaseClass.ItemPostFrame();
    UpdateLaser();
  }

  bool PlayEmptySound()
  {
    if (self.m_bPlayEmptySound)
    {
      g_SoundSystem.EmitSoundDyn(m_pPlayer.edict(), CHAN_WEAPON, "hlclassic/weapons/357_cock1.wav", 0.8f, ATTN_NORM, 0, PITCH_NORM);
      self.m_bPlayEmptySound = false;
    }
    return false;
  }

  void PrimaryAttack()
  {
    if (m_pPlayer.pev.waterlevel == WATERLEVEL_HEAD)
    {
      self.PlayEmptySound();
      self.m_flNextPrimaryAttack = g_Engine.time + 0.15f;
      return;
    }

    if (self.m_iClip <= 0)
    {
      if (self.m_bFireOnEmpty)
      {
        self.PlayEmptySound();
        self.m_flNextPrimaryAttack = g_Engine.time + 0.2f;
      }
      return;
    }

    m_pPlayer.m_iWeaponVolume = NORMAL_GUN_VOLUME;
    m_pPlayer.m_iWeaponFlash = NORMAL_GUN_FLASH;

    --self.m_iClip;

    m_pPlayer.pev.effects |= EF_MUZZLEFLASH;
    pev.effects |= EF_MUZZLEFLASH;

    m_pPlayer.SetAnimation(PLAYER_ATTACK1);

    if (m_bLaserActive)
    {
      GetLaserSpot().pev.effects |= EF_NODRAW;
      SetThink(ThinkFunction(LaserRevive));
      pev.nextthink = g_Engine.time + 0.6f;
    }

    Math.MakeVectors(m_pPlayer.pev.v_angle + m_pPlayer.pev.punchangle);
    Vector vecSrc = m_pPlayer.GetGunPosition();
    Vector vecAiming = m_pPlayer.GetAutoaimVector(AUTOAIM_10DEGREES);

    float flSpread = m_bLaserActive ? 0.001f : 0.1f;
    self.FireBullets(1, vecSrc, vecAiming, Vector(flSpread, flSpread, flSpread), 8192.0f, BULLET_PLAYER_EAGLE, 0, 0, m_pPlayer.pev);

    self.SendWeaponAnim((self.m_iClip <= 0) ? SHOOT_EMPTY : SHOOT);
    g_SoundSystem.EmitSoundDyn(m_pPlayer.edict(), CHAN_WEAPON, "weapons/desert_eagle_fire.wav", Math.RandomFloat(0.92f, 1.0f), ATTN_NORM, 0, 98 + Math.RandomLong(0, 3));
    m_pPlayer.pev.punchangle.x = -4.0f;

    // GetDefaultShellInfo(origin, velocity, -9.0f, 9.0f, 14.0f);
    Math.MakeVectors(m_pPlayer.pev.v_angle);
    float fR = Math.RandomFloat(50.0f, 70.0f);
    float fU = Math.RandomFloat(100.0f, 150.0f);
    Vector vecOrigin = m_pPlayer.GetGunPosition() + (g_Engine.v_forward * 14.0f) + (g_Engine.v_right * 8.0f) + (g_Engine.v_up * -10.0f);
    Vector vecVelocity = m_pPlayer.pev.velocity + (g_Engine.v_forward * 25.0f) + (g_Engine.v_right * fR) + (g_Engine.v_up * fU);
    g_EntityFuncs.EjectBrass(vecOrigin, vecVelocity, m_pPlayer.pev.angles.y, m_iShell, TE_BOUNCE_SHELL);

    if (self.m_iClip <= 0 && m_pPlayer.m_rgAmmo(self.m_iPrimaryAmmoType) <= 0)
      m_pPlayer.SetSuitUpdate("!HEV_AMO0", false, 0);

    self.m_flNextPrimaryAttack = self.m_flNextSecondaryAttack = g_Engine.time + (m_bLaserActive ? 0.5f : 0.22f);
    self.m_flTimeWeaponIdle = g_Engine.time + g_PlayerFuncs.SharedRandomFloat(m_pPlayer.random_seed, 10.0f, 15.0f);
  }

  void SecondaryAttack()
  {
    m_bLaserActive = !m_bLaserActive;

    if (m_bLaserActive)
    {
      GetLaserSpot().pev.effects &= ~EF_NODRAW;
      g_SoundSystem.EmitSoundDyn(m_pPlayer.edict(), CHAN_WEAPON, "weapons/desert_eagle_sight.wav", VOL_NORM, ATTN_NORM, 0, PITCH_NORM);
    }
    else
    {
      GetLaserSpot().pev.effects |= EF_NODRAW;
      g_SoundSystem.EmitSoundDyn(m_pPlayer.edict(), CHAN_WEAPON, "weapons/desert_eagle_sight2.wav", VOL_NORM, ATTN_NORM, 0, PITCH_NORM);
    }

    self.m_flNextSecondaryAttack = g_Engine.time + 0.5f;
  }

  void Reload()
  {
    if (self.m_iClip == MAX_CLIP || m_pPlayer.m_rgAmmo(self.m_iPrimaryAmmoType) <= 0)
      return;

    // Only turn it off if we're actually reloading
    if (m_bLaserActive)
    {
      GetLaserSpot().pev.effects |= EF_NODRAW;
      self.m_flNextSecondaryAttack = g_Engine.time + 1.5f;
      SetThink(ThinkFunction(LaserRevive));
      pev.nextthink = g_Engine.time + 1.6f;
    }

    self.DefaultReload(MAX_CLIP, (self.m_iClip <= 0) ? RELOAD : RELOAD_NOSHOT, 1.5f);
    self.m_flTimeWeaponIdle = g_Engine.time + g_PlayerFuncs.SharedRandomFloat(m_pPlayer.random_seed, 10.0f, 15.0f);
    BaseClass.Reload();
  }

  void WeaponIdle()
  {
    self.ResetEmptySound();
    m_pPlayer.GetAutoaimVector(AUTOAIM_10DEGREES); // Update autoaim

    if (self.m_flTimeWeaponIdle > g_Engine.time || self.m_iClip <= 0)
      return;

    float flRand = g_PlayerFuncs.SharedRandomFloat(m_pPlayer.random_seed, 0.0f, 1.0f);
    if (m_bLaserActive)
    {
      if (flRand > 0.5f)
      {
        self.SendWeaponAnim(IDLE5);
        self.m_flTimeWeaponIdle = g_Engine.time + 2.0f;
      }
      else
      {
        self.SendWeaponAnim(IDLE4);
        self.m_flTimeWeaponIdle = g_Engine.time + 2.5f;
      }
    }
    else
    {
      if (flRand <= 0.3f)
      {
        self.SendWeaponAnim(IDLE1);
        self.m_flTimeWeaponIdle = g_Engine.time + 2.5f;
      }
      else if (flRand > 0.6f)
      {
        self.SendWeaponAnim(IDLE3);
        self.m_flTimeWeaponIdle = g_Engine.time + 1.633f;
      }
      else
      {
        self.SendWeaponAnim(IDLE2);
        self.m_flTimeWeaponIdle = g_Engine.time + 2.5f;
      }
    }
  }

  private void UpdateLaser()
  {
    if (!m_bLaserActive)
      return;

    Math.MakeVectors(m_pPlayer.pev.v_angle);
    Vector vecSrc = m_pPlayer.GetGunPosition();
    Vector vecEnd = vecSrc + (g_Engine.v_forward * 8192.0f);

    TraceResult tr;
    g_Utility.TraceLine(vecSrc, vecEnd, dont_ignore_monsters, m_pPlayer.edict(), tr);
    g_EntityFuncs.SetOrigin(GetLaserSpot(), tr.vecEndPos);
  }

  // CEagleLaser::Revive()
  private void LaserRevive()
  {
    SetThink(null);
    GetLaserSpot().pev.effects &= ~EF_NODRAW;
  }

  private void LaserDeploy()
  {
    LaserRevive();
    UpdateLaser();
    g_SoundSystem.EmitSoundDyn(m_pPlayer.edict(), CHAN_WEAPON, "weapons/desert_eagle_sight.wav", VOL_NORM, ATTN_NORM, 0, PITCH_NORM);
  }

  // Instead of creating/removing in Holster, Deploy, SecondaryAttack
  // only creates a new one if the previous one was somehow deleted
  private CBaseEntity@ GetLaserSpot()
  {
    if (!m_hLaser)
    {
      m_hLaser = EHandle(g_EntityFuncs.CreateEntity("info_target", null, false));
      g_EntityFuncs.SetModel(m_hLaser.GetEntity(), "sprites/laserdot.spr");
      m_hLaser.GetEntity().pev.movetype = MOVETYPE_NONE;
      m_hLaser.GetEntity().pev.solid = SOLID_NOT;
      m_hLaser.GetEntity().pev.scale = 0.5f;
      m_hLaser.GetEntity().pev.rendermode = kRenderGlow;
      m_hLaser.GetEntity().pev.renderamt = 255.0f;
      m_hLaser.GetEntity().pev.renderfx = kRenderFxNoDissipation;
      g_EntityFuncs.DispatchSpawn(m_hLaser.GetEntity().edict());
    }
    return m_hLaser.GetEntity();
  }
}

string GetName()
{
  return "weapon_ofeagle";
}

void Register()
{
  if (!g_CustomEntityFuncs.IsCustomEntity(GetName()))
  {
    g_CustomEntityFuncs.RegisterCustomEntity("COFEagle::weapon_ofeagle", GetName());
    g_ItemRegistry.RegisterWeapon(GetName(), "opfor", "357", "", "ammo_357", "");
  }
}

}
