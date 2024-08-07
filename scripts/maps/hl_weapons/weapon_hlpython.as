/*
 * The Half-Life version of the python
 */

namespace CHLPython
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
const CCVar@ g_RevolverLaserSight = CCVar("revolver_laser_sight", 0, "", ConCommandFlag::AdminOnly, @OnCVarChange); // as_command revolver_laser_sight

// Instead of checking every ItemPostFrame only listen to cvar change
void OnCVarChange(CCVar@, const string& in, float)
{
  const int iCurrentBody = g_RevolverLaserSight.GetBool() ? 1 : 0;

  CBasePlayerWeapon@ pPython = null;
  while ((@pPython = cast<CBasePlayerWeapon>(g_EntityFuncs.FindEntityByClassname(pPython, GetName()))) !is null)
  {
    // Check if we need to reset the laser sight.
    if (pPython.pev.body != iCurrentBody)
    {
      pPython.pev.body = iCurrentBody;
      pPython.m_flTimeWeaponIdle = 0.0f;

      if (pPython.m_hPlayer && iCurrentBody == 0)
        pPython.SetFOV(0); // 0 means reset to default fov
    }
  }
}

class weapon_hlpython : ScriptBasePlayerWeaponEntity
{
  private CBasePlayer@ m_pPlayer
  {
    get const { return cast<CBasePlayer>(self.m_hPlayer.GetEntity()); }
    set       { self.m_hPlayer = EHandle(@value); }
  }

  void Spawn()
  {
    Precache();
    g_EntityFuncs.SetModel(self, self.GetW_Model("models/hlclassic/w_357.mdl"));
    self.m_iDefaultAmmo = DEFAULT_GIVE;
    self.FallInit();

    pev.body = g_RevolverLaserSight.GetBool() ? 1 : 0; // Enable laser sight geometry?
  }

  void Precache()
  {
    self.PrecacheCustomModels();
    g_Game.PrecacheModel("models/hlclassic/w_357.mdl");
    g_Game.PrecacheModel("models/hlclassic/v_357.mdl");
    g_Game.PrecacheModel("models/hlclassic/p_357.mdl");

    g_SoundSystem.PrecacheSound("hlclassic/weapons/357_shot1.wav");
    g_SoundSystem.PrecacheSound("hlclassic/weapons/357_shot2.wav");
    g_SoundSystem.PrecacheSound("hlclassic/weapons/357_cock1.wav");
    g_SoundSystem.PrecacheSound("hlclassic/weapons/357_reload1.wav"); // sequence: 3; frame: 70; event 5004

    g_Game.PrecacheGeneric("sprites/hl_weapons/" + pev.classname + ".txt");
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
    info.iPosition = 6;
    info.iId = g_ItemRegistry.GetIdForName(pev.classname);
    info.iWeight = WEIGHT;
    return true;
  }

  bool Deploy()
  {
    self.DefaultDeploy(self.GetV_Model("models/hlclassic/v_357.mdl"), self.GetP_Model("models/hlclassic/p_357.mdl"), DRAW, "python", 0, pev.body);
    self.m_flNextPrimaryAttack = self.m_flNextSecondaryAttack = self.m_flTimeWeaponIdle = g_Engine.time + 1.0f;
    return true;
  }

  void Holster(int skiplocal = 0)
  {
    self.SetFOV(0);
    BaseClass.Holster(skiplocal);
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
    // Don't fire underwater
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
        self.m_flNextPrimaryAttack = g_Engine.time + 0.15f;
      }
      return;
    }

    m_pPlayer.m_iWeaponVolume = LOUD_GUN_VOLUME;
    m_pPlayer.m_iWeaponFlash = BRIGHT_GUN_FLASH;

    --self.m_iClip;

    m_pPlayer.pev.effects |= EF_MUZZLEFLASH;
    pev.effects |= EF_MUZZLEFLASH;

    // Player "shoot" animation
    m_pPlayer.SetAnimation(PLAYER_ATTACK1);

    Math.MakeVectors(m_pPlayer.pev.v_angle + m_pPlayer.pev.punchangle);
    Vector vecSrc = m_pPlayer.GetGunPosition();
    Vector vecAiming = m_pPlayer.GetAutoaimVector(AUTOAIM_10DEGREES);

    self.FireBullets(1, vecSrc, vecAiming, VECTOR_CONE_1DEGREES, 8192.0f, BULLET_PLAYER_357, 0, 0, m_pPlayer.pev);

    self.SendWeaponAnim(FIRE1, 0, pev.body);
    switch (Math.RandomLong(0, 1))
    {
    case 0:
      g_SoundSystem.EmitSoundDyn(m_pPlayer.edict(), CHAN_WEAPON, "hlclassic/weapons/357_shot1.wav", Math.RandomFloat(0.8f, 0.9f), ATTN_NORM, 0, PITCH_NORM);
      break;
    case 1:
      g_SoundSystem.EmitSoundDyn(m_pPlayer.edict(), CHAN_WEAPON, "hlclassic/weapons/357_shot2.wav", Math.RandomFloat(0.8f, 0.9f), ATTN_NORM, 0, PITCH_NORM);
      break;
    }
    m_pPlayer.pev.punchangle.x = -10.0f;

    if (self.m_iClip <= 0 && m_pPlayer.m_rgAmmo(self.m_iPrimaryAmmoType) <= 0)
      // HEV suit - Indicate out of ammo condition
      m_pPlayer.SetSuitUpdate("!HEV_AMO0", false, 0);

    self.m_flNextPrimaryAttack = g_Engine.time + 0.75f;
    self.m_flTimeWeaponIdle = g_Engine.time + g_PlayerFuncs.SharedRandomFloat(m_pPlayer.random_seed, 10.0f, 15.0f);
  }

  void SecondaryAttack()
  {
    if (!g_RevolverLaserSight.GetBool())
      return;

    self.SetFOV((m_pPlayer.m_iFOV != 0) ? 0 : 40); // 0 means reset to default fov
    self.m_flNextSecondaryAttack = g_Engine.time + 0.5f;
  }

  void Reload()
  {
    if (self.m_iClip == MAX_CLIP || m_pPlayer.m_rgAmmo(self.m_iPrimaryAmmoType) <= 0)
      return;

    self.SetFOV(0);

    self.DefaultReload(MAX_CLIP, RELOAD, 2.0f, pev.body);
    self.m_flTimeWeaponIdle = g_Engine.time + 3.0f;
    BaseClass.Reload();
  }

  void WeaponIdle()
  {
    self.ResetEmptySound();
    m_pPlayer.GetAutoaimVector(AUTOAIM_10DEGREES);

    if (self.m_flTimeWeaponIdle > g_Engine.time)
      return;

    float flRand = g_PlayerFuncs.SharedRandomFloat(m_pPlayer.random_seed, 0.0f, 1.0f);
    if (flRand <= 0.5f)
    {
      self.SendWeaponAnim(IDLE1, 0, pev.body);
      self.m_flTimeWeaponIdle = g_Engine.time + 2.33f;
    }
    else if (flRand <= 0.7f)
    {
      self.SendWeaponAnim(IDLE2, 0, pev.body);
      self.m_flTimeWeaponIdle = g_Engine.time + 2.0f;
    }
    else if (flRand <= 0.9f)
    {
      self.SendWeaponAnim(IDLE3, 0, pev.body);
      self.m_flTimeWeaponIdle = g_Engine.time + 2.933f;
    }
    else
    {
      self.SendWeaponAnim(FIDGET, 0, pev.body);
      self.m_flTimeWeaponIdle = g_Engine.time + 5.667f;
    }
  }
}

string GetName()
{
  return "weapon_hlpython";
}

void Register()
{
  if (!g_CustomEntityFuncs.IsCustomEntity(GetName()))
  {
    g_CustomEntityFuncs.RegisterCustomEntity("CHLPython::weapon_hlpython", GetName());
    g_ItemRegistry.RegisterWeapon(GetName(), "hl_weapons", "357", "", "ammo_357", "");
  }
}

}
