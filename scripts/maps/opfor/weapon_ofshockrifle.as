/*
 * The Opposing Force version of the shockrifle
 */

namespace COFShockRifle
{

enum shockrifle_e
{
  IDLE1 = 0,
  FIRE,
  DRAW,
  HOLSTER,
  IDLE3
};

// Weapon information
const int MAX_CARRY    = 100;
const int DEFAULT_GIVE = MAX_CARRY;
const int WEIGHT       = 15;

// Fast shot thing
const CCVar@ g_ShockRifleFast = CCVar("shockrifle_fast", 0, "", ConCommandFlag::AdminOnly); // as_command shockrifle_fast

class weapon_ofshockrifle : ScriptBasePlayerWeaponEntity
{
  private CBasePlayer@ m_pPlayer
  {
    get const { return cast<CBasePlayer>(self.m_hPlayer.GetEntity()); }
    set       { self.m_hPlayer = EHandle(@value); }
  }
  private float m_flRechargeTime;

  void Spawn()
  {
    Precache();
    g_EntityFuncs.SetModel(self, self.GetW_Model("models/w_shock_rifle.mdl"));
    self.m_iDefaultAmmo = DEFAULT_GIVE;
    self.FallInit();

    pev.sequence = 0;
    pev.animtime = g_Engine.time;
    pev.framerate = 1.0f;
    self.ResetSequenceInfo();
  }

  void Precache()
  {
    self.PrecacheCustomModels();
    g_Game.PrecacheModel("models/w_shock_rifle.mdl");
    g_Game.PrecacheModel("models/v_shock.mdl");
    g_Game.PrecacheModel("models/p_shock.mdl");

    g_Game.PrecacheModel("sprites/lgtning.spr");

    g_SoundSystem.PrecacheSound("weapons/shock_fire.wav");
    g_SoundSystem.PrecacheSound("weapons/shock_draw.wav"); // default viewmodel; sequence: 2; frame: 1; event 5004
    g_SoundSystem.PrecacheSound("weapons/shock_recharge.wav");
    g_SoundSystem.PrecacheSound("weapons/shock_discharge.wav");

    g_Game.PrecacheOther("shock_beam");
    g_Game.PrecacheGeneric("sprites/opfor/" + pev.classname + ".txt");
  }

  bool GetItemInfo(ItemInfo& out info)
  {
    info.iMaxAmmo1 = MAX_CARRY;
    info.iMaxAmmo2 = -1;
    info.iAmmo1Drop = -1;
    info.iAmmo2Drop = -1;
    info.iMaxClip = WEAPON_NOCLIP;
    info.iFlags = ITEM_FLAG_NOAUTORELOAD | ITEM_FLAG_NOAUTOSWITCHEMPTY;
    info.iSlot = 6;
    info.iPosition = 3;
    info.iId = g_ItemRegistry.GetIdForName(pev.classname);
    info.iWeight = 15;
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

  void AttachToPlayer(CBasePlayer@ pPlayer)
  {
    if (self.m_iDefaultAmmo == 0)
      self.m_iDefaultAmmo = 1;
    
    BaseClass.AttachToPlayer(pPlayer);
  }

  bool CanDeploy()
  {
    return true;
  }

  bool Deploy()
  {
    m_flRechargeTime = g_Engine.time + (g_ShockRifleFast.GetBool() ? 0.25f : 0.5f);
    self.DefaultDeploy(self.GetV_Model("models/v_shock.mdl"), self.GetP_Model("models/p_shock.mdl"), DRAW, "bow");
    self.m_flTimeWeaponIdle = g_Engine.time + 1.0f;
    return true;
  }

  void Holster(int skiplocal = 0)
  {
    if (m_pPlayer.m_rgAmmo(self.m_iPrimaryAmmoType) <= 0)
      m_pPlayer.m_rgAmmo(self.m_iPrimaryAmmoType, 1);

    BaseClass.Holster(skiplocal);
  }

  void PrimaryAttack()
  {
    if (m_pPlayer.pev.waterlevel == WATERLEVEL_HEAD)
    {
      // Water goes zap.
      const float flVolume = Math.RandomFloat(0.8f, 0.9f);
      g_SoundSystem.EmitSound(m_pPlayer.edict(), CHAN_ITEM, "weapons/shock_discharge.wav", flVolume, ATTN_NONE);

      const int ammoCount = m_pPlayer.m_rgAmmo(self.m_iPrimaryAmmoType);
      g_WeaponFuncs.RadiusDamage(pev.origin, m_pPlayer.pev, m_pPlayer.pev, ammoCount * 100.0f, ammoCount * 150.0f, CLASS_NONE, DMG_ALWAYSGIB | DMG_BLAST);
      m_pPlayer.m_rgAmmo(self.m_iPrimaryAmmoType, 0);
      return;
    }

    RechargeAmmo(true);

    if (m_pPlayer.m_rgAmmo(self.m_iPrimaryAmmoType) <= 0)
      return;

    m_pPlayer.m_iWeaponVolume = LOUD_GUN_VOLUME;
    m_pPlayer.m_iWeaponFlash = BRIGHT_GUN_FLASH;

    m_pPlayer.m_rgAmmo(self.m_iPrimaryAmmoType, m_pPlayer.m_rgAmmo(self.m_iPrimaryAmmoType) - 1);

    m_pPlayer.pev.effects |= EF_MUZZLEFLASH;
    pev.effects |= EF_MUZZLEFLASH;

    m_pPlayer.SetAnimation(PLAYER_ATTACK1);

    m_flRechargeTime = g_Engine.time + 1.0f;

    Vector vecAnglesAim = m_pPlayer.pev.v_angle + m_pPlayer.pev.punchangle;
    Math.MakeVectors(vecAnglesAim);
    Vector vecSrc = m_pPlayer.GetGunPosition() + g_Engine.v_forward * 16.0f + g_Engine.v_right * 9.0f + g_Engine.v_up * -7.0f;
    // m_pPlayer.GetAutoaimVectorFromPoint(vecSrc, AUTOAIM_10DEGREES); // Update auto-aim

    CreateShockBeam(vecSrc, vecAnglesAim, m_pPlayer);

    self.SendWeaponAnim(FIRE);
    g_SoundSystem.EmitSoundDyn(m_pPlayer.edict(), CHAN_WEAPON, "weapons/shock_fire.wav", 0.9f, ATTN_NORM, 0, PITCH_NORM);

    self.m_flNextPrimaryAttack = g_Engine.time + (g_ShockRifleFast.GetBool() ? 0.1f : 0.2f);
    self.m_flTimeWeaponIdle = g_Engine.time + 0.33f;
  }

  void WeaponIdle()
  {
    RechargeAmmo(true);

    self.ResetEmptySound();
    m_pPlayer.GetAutoaimVector(AUTOAIM_10DEGREES);

    if (self.m_flTimeWeaponIdle > g_Engine.time)
      return;

    float flRand = g_PlayerFuncs.SharedRandomFloat(m_pPlayer.random_seed, 0.0f, 1.0f);
    if (flRand <= 0.75f)
    {
      self.SendWeaponAnim(IDLE3);
      self.m_flTimeWeaponIdle = g_Engine.time + 51.0f / 15.0f;
    }
    else
    {
      self.SendWeaponAnim(IDLE1);
      self.m_flTimeWeaponIdle = g_Engine.time + 101.0f / 30.0f;
    }
  }

  void InactiveItemPostFrame()
  {
    RechargeAmmo(false);
    BaseClass.InactiveItemPostFrame();
  }

  private void RechargeAmmo(bool bLoud)
  {
    int ammoCount = m_pPlayer.m_rgAmmo(self.m_iPrimaryAmmoType);

    while (ammoCount < DEFAULT_GIVE && m_flRechargeTime < g_Engine.time)
    {
      ++ammoCount;

      if (bLoud)
        g_SoundSystem.EmitSound(m_pPlayer.edict(), CHAN_WEAPON, "weapons/shock_recharge.wav", VOL_NORM, ATTN_NORM);

      m_flRechargeTime += (g_ShockRifleFast.GetBool() ? 0.25f : 0.5f);
    }

    m_pPlayer.m_rgAmmo(self.m_iPrimaryAmmoType, ammoCount);
  }

  // CShockBeam::CreateShockBeam(const Vector& vecOrigin, const Vector& vecAngles, CBaseEntity* pOwner)
  private void CreateShockBeam(const Vector& in vecOrigin, const Vector& in vecAngles, CBaseEntity@ pOwner)
  {
    CBaseEntity@ pBeam = g_EntityFuncs.CreateEntity("shock_beam", null, false);
    pBeam.pev.angles = vecAngles;
    pBeam.pev.angles.x = -pBeam.pev.angles.x;
    g_EntityFuncs.SetOrigin(pBeam, vecOrigin);

    Math.MakeVectors(pBeam.pev.angles);
    pBeam.pev.velocity = g_Engine.v_forward * 2000.0f;
    pBeam.pev.velocity.z = -pBeam.pev.velocity.z;

    g_EntityFuncs.DispatchSpawn(pBeam.edict());
    @pBeam.pev.owner = @pOwner.edict();

    for (uint uiIndex = 0; uiIndex < 3; ++uiIndex)
    {
      NetworkMessage message(MSG_ALL, NetworkMessages::SVC_TEMPENTITY);
        message.WriteByte(TE_BEAMENTS);
        message.WriteShort(m_pPlayer.entindex() | 0x1000);
        message.WriteShort(m_pPlayer.entindex() | ((uiIndex + 2) << 12));
        message.WriteShort(g_EngineFuncs.ModelIndex("sprites/lgtning.spr"));
        message.WriteByte(0);
        message.WriteByte(10);
        message.WriteByte(1); // 0.8f
        message.WriteByte(10);
        message.WriteByte(75);
        message.WriteByte(0);
        message.WriteByte(253);
        message.WriteByte(253);
        message.WriteByte(190);
        message.WriteByte(30);
      message.End();
    }
  }
}

string GetName()
{
  return "weapon_ofshockrifle";
}

void Register()
{
  if (!g_CustomEntityFuncs.IsCustomEntity(GetName()))
  {
    g_CustomEntityFuncs.RegisterCustomEntity("COFShockRifle::weapon_ofshockrifle", GetName());
    g_ItemRegistry.RegisterWeapon(GetName(), "opfor", "shock charges", "", "", "");
  }
}

}
