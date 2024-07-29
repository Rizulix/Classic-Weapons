/*
 * The Opposing Force version of the sporelauncher
 */

namespace COFSporeLauncher
{

enum sporelauncher_e
{
  IDLE = 0,
  FIDGET,
  RELOAD_REACH,
  RELOAD,
  AIM,
  FIRE,
  HOLSTER1,
  DRAW1,
  IDLE2
};

enum reloadstate_e
{
  NOT_RELOADING = 0,
  DO_RELOAD_EFFECTS,
  RELOAD_ONE
};

// Weapon information
const int MAX_CARRY    = 30;
const int MAX_CLIP     = 5;
const int DEFAULT_GIVE = MAX_CLIP;
const int WEIGHT       = 20;

namespace COFSpore
{

ofspore@ ShootContact(const Vector& in vecOrigin, const Vector& in vecAngles, const Vector& in vecVelocity, edict_t@ pOwner)
{
  CBaseEntity@ cbeSpore = g_EntityFuncs.Create(GetName(), vecOrigin, vecAngles, true, pOwner);
  ofspore@ sbeSpore = cast<ofspore>(CastToScriptClass(cbeSpore));
  sbeSpore.pev.velocity = vecVelocity;
  sbeSpore.pev.movetype = MOVETYPE_FLY;
  sbeSpore.pev.speed = 32.0f;
  sbeSpore.SetThink(ThinkFunction(sbeSpore.IgniteThink));
  sbeSpore.pev.nextthink = g_Engine.time;
  sbeSpore.SetTouch(TouchFunction(sbeSpore.ExplodeTouch));
  g_EntityFuncs.DispatchSpawn(sbeSpore.self.edict());
  return sbeSpore;
}

ofspore@ ShootTimed(const Vector& in vecOrigin, const Vector& in vecAngles, const Vector& in vecVelocity, edict_t@ pOwner)
{
  CBaseEntity@ cbeSpore = g_EntityFuncs.Create(GetName(), vecOrigin, vecAngles, true, pOwner);
  ofspore@ sbeSpore = cast<ofspore>(CastToScriptClass(cbeSpore));
  sbeSpore.pev.velocity = vecVelocity;
  sbeSpore.pev.angles.x -= float(Math.RandomLong(-5, 5) + 30);
  sbeSpore.pev.movetype = MOVETYPE_BOUNCE;
  sbeSpore.pev.dmgtime = g_Engine.time + 2.0f;
  sbeSpore.pev.speed = 64.0f;
  sbeSpore.SetThink(ThinkFunction(sbeSpore.IgniteThink));
  sbeSpore.pev.nextthink = g_Engine.time;
  sbeSpore.SetTouch(TouchFunction(sbeSpore.BounceTouch));
  g_EntityFuncs.DispatchSpawn(sbeSpore.self.edict());
  return sbeSpore;
}

class ofspore : ScriptBaseEntity
{
  private float m_flSoundDelay;
  private int m_iSpitSprite;
  private int m_iBlowSmall;
  private int m_iTrail;
  private int m_iBlow;

  void Spawn()
  {
    Precache();

    g_EntityFuncs.SetModel(self, "models/spore.mdl");
    g_EntityFuncs.SetSize(pev, Vector(-4.0f, -4.0f, 0.0f), Vector(4.0f, 4.0f, 4.0f));

    pev.solid = SOLID_BBOX;
    pev.gravity = 1.0f;
    pev.dmg = g_EngineFuncs.CVarGetFloat("sk_plr_spore");

    m_flSoundDelay = g_Engine.time;
  }

  void Precache()
  {
    g_Game.PrecacheModel("models/spore.mdl");
    g_Game.PrecacheModel("sprites/glow01.spr");

    m_iBlow = g_Game.PrecacheModel("sprites/spore_exp_01.spr");
    m_iBlowSmall = g_Game.PrecacheModel("sprites/spore_exp_c_01.spr");
    m_iSpitSprite = m_iTrail = g_Game.PrecacheModel("sprites/tinyspit.spr");

    g_SoundSystem.PrecacheSound("weapons/splauncher_impact.wav");
    g_SoundSystem.PrecacheSound("weapons/splauncher_bounce.wav");
  }

  void IgniteThink()
  {
    NetworkMessage trail(MSG_PVS, NetworkMessages::SporeTrail, pev.origin);
      trail.WriteShort(self.entindex());
      trail.WriteByte(1);
    trail.End();

    if (pev.dmgtime != 0.0f)
    {
      SetThink(ThinkFunction(Detonate));
      pev.nextthink = pev.dmgtime;
    }
  }

  void BounceTouch(CBaseEntity@ pOther)
  {
    if (pOther.pev.takedamage == DAMAGE_NO)
    {
      if (pOther.edict() is pev.owner)
        return;

      if (g_Engine.time > m_flSoundDelay)
      {
        GetSoundEntInstance().InsertSound(bits_SOUND_DANGER, pev.origin, int(pev.dmg * 2.5f), 0.3f, self);
        m_flSoundDelay = g_Engine.time + 1.0f;
      }

      if ((pev.flags & FL_ONGROUND) != 0)
        pev.velocity = pev.velocity * 0.5f;
      else
        g_SoundSystem.EmitSoundDyn(self.edict(), CHAN_VOICE, "weapons/splauncher_bounce.wav", 0.9f, ATTN_NORM, 0, PITCH_NORM);
    }
    else
    {
      pOther.TakeDamage(pev, pev.owner.vars, g_EngineFuncs.CVarGetFloat("sk_plr_spore"), DMG_GENERIC);
      Detonate();
    }
  }

  void ExplodeTouch(CBaseEntity@ pOther)
  {
    if (pOther.pev.takedamage != DAMAGE_NO)
      pOther.TakeDamage(pev, pev.owner.vars, g_EngineFuncs.CVarGetFloat("sk_plr_spore"), DMG_GENERIC);

    Detonate();
  }

  void Detonate()
  {
    SetThink(null);
    SetTouch(null);

    g_SoundSystem.EmitSoundDyn(self.edict(), CHAN_WEAPON, "weapons/splauncher_impact.wav", VOL_NORM, ATTN_NORM, 0, PITCH_NORM);

    TraceResult tr;
    g_Utility.TraceLine(pev.origin, pev.origin + (pev.velocity.Normalize() * pev.speed), dont_ignore_monsters, self.edict(), tr);

    g_Utility.DecalTrace(tr, DECAL_SPORESPLAT1 + Math.RandomLong(0, 2));

    // I should use this for the explosion effect but
    // it hides the same effect on other spores for the duration of the explosion.
    // NetworkMessage trail(MSG_PVS, NetworkMessages::SporeTrail, pev.origin);
    //   trail.WriteShort(self.entindex());
    //   trail.WriteByte(0);
    // trail.End();

    NetworkMessage spit(MSG_PVS, NetworkMessages::SVC_TEMPENTITY, pev.origin);
      spit.WriteByte(TE_SPRITE_SPRAY);
      spit.WriteCoord(pev.origin.x);
      spit.WriteCoord(pev.origin.y);
      spit.WriteCoord(pev.origin.z);
      spit.WriteCoord(tr.vecPlaneNormal.x);
      spit.WriteCoord(tr.vecPlaneNormal.y);
      spit.WriteCoord(tr.vecPlaneNormal.z);
      spit.WriteShort(m_iSpitSprite);
      spit.WriteByte(100);
      spit.WriteByte(40);
      spit.WriteByte(180);
    spit.End();

    NetworkMessage light(MSG_PVS, NetworkMessages::SVC_TEMPENTITY, pev.origin);
      light.WriteByte(TE_DLIGHT);
      light.WriteCoord(pev.origin.x);
      light.WriteCoord(pev.origin.y);
      light.WriteCoord(pev.origin.z);
      light.WriteByte(10);
      light.WriteByte(15);
      light.WriteByte(220);
      light.WriteByte(40);
      light.WriteByte(5);
      light.WriteByte(10);
    light.End();

    NetworkMessage blow(MSG_PVS, NetworkMessages::SVC_TEMPENTITY, pev.origin);
      blow.WriteByte(TE_SPRITE);
      blow.WriteCoord(pev.origin.x);
      blow.WriteCoord(pev.origin.y);
      blow.WriteCoord(pev.origin.z);
      blow.WriteShort((Math.RandomLong(0, 1) != 0) ? m_iBlow : m_iBlowSmall);
      blow.WriteByte(20);
      blow.WriteByte(128);
    blow.End();

    NetworkMessage trail(MSG_PVS, NetworkMessages::SVC_TEMPENTITY, pev.origin);
      trail.WriteByte(TE_SPRITE_SPRAY);
      trail.WriteCoord(pev.origin.x);
      trail.WriteCoord(pev.origin.y);
      trail.WriteCoord(pev.origin.z);
      trail.WriteCoord(Math.RandomFloat(-1.0f, 1.0f));
      trail.WriteCoord(1);
      trail.WriteCoord(Math.RandomFloat(-1.0f, 1.0f));
      trail.WriteShort(m_iTrail);
      trail.WriteByte(2);
      trail.WriteByte(20);
      trail.WriteByte(80);
    trail.End();

    g_WeaponFuncs.RadiusDamage(pev.origin, pev, pev.owner.vars, pev.dmg, 200.0f, CLASS_NONE, DMG_ALWAYSGIB | DMG_BLAST);

    SetThink(ThinkFunction(SUB_Remove));
    pev.nextthink = g_Engine.time;
  }

  void SUB_Remove()
  {
    self.SUB_Remove();
  }
}

string GetName()
{
  return "ofspore";
}

void Register()
{
  if (!g_CustomEntityFuncs.IsCustomEntity(GetName()))
  {
    g_CustomEntityFuncs.RegisterCustomEntity("COFSporeLauncher::COFSpore::ofspore", GetName());
    g_Game.PrecacheOther(GetName());
  }
}

}

class weapon_ofsporelauncher : ScriptBasePlayerWeaponEntity
{
  private CBasePlayer@ m_pPlayer
  {
    get const { return cast<CBasePlayer>(self.m_hPlayer.GetEntity()); }
    set       { self.m_hPlayer = EHandle(@value); }
  }
  private int m_kReloadState
  {
    get const { return m_fInReload; }
    // Update CBasePlayerWeapon.m_fInReload as well
    // because it blocks player manual reload (+reload)
    set       { self.m_fInReload = (m_fInReload = value) > NOT_RELOADING; }
  }
  private int m_fInReload;

  void Spawn()
  {
    Precache();
    g_EntityFuncs.SetModel(self, self.GetW_Model("models/w_spore_launcher.mdl"));
    self.m_iDefaultAmmo = DEFAULT_GIVE;
    self.FallInit(); // Get ready to fall down.

    pev.sequence = 0;
    pev.animtime = g_Engine.time;
    pev.framerate = 1.0f;
    self.ResetSequenceInfo();
  }

  void Precache()
  {
    self.PrecacheCustomModels();
    g_Game.PrecacheModel("models/w_spore_launcher.mdl");
    g_Game.PrecacheModel("models/hlclassic/v_spore_launcher.mdl");
    g_Game.PrecacheModel("models/p_spore_launcher.mdl");

    g_SoundSystem.PrecacheSound("weapons/splauncher_fire.wav");
    g_SoundSystem.PrecacheSound("weapons/splauncher_altfire.wav");
    g_SoundSystem.PrecacheSound("weapons/splauncher_bounce.wav");
    g_SoundSystem.PrecacheSound("weapons/splauncher_reload.wav");
    g_SoundSystem.PrecacheSound("weapons/splauncher_pet.wav");

    g_Game.PrecacheOther(COFSpore::GetName());
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
    info.iAmmo1Drop = 1;
    info.iMaxAmmo2 = -1;
    info.iAmmo2Drop = -1;
    info.iMaxClip = MAX_CLIP;
    info.iSlot = 6;
    info.iPosition = 5;
    info.iId = g_ItemRegistry.GetIdForName(pev.classname);
    info.iFlags = 0;
    info.iWeight = WEIGHT;
    return true;
  }

  bool Deploy()
  {
    self.DefaultDeploy(self.GetV_Model("models/hlclassic/v_spore_launcher.mdl"), self.GetP_Model("models/p_spore_launcher.mdl"), DRAW1, "rpg");
    self.m_flNextPrimaryAttack = self.m_flNextSecondaryAttack = self.m_flTimeWeaponIdle = g_Engine.time + 1.0f;
    return true;
  }

  void Holster(int skiplocal = 0)
  {
    SetThink(null);
    m_kReloadState = NOT_RELOADING;
    BaseClass.Holster(skiplocal);
  }

  void PrimaryAttack()
  {
    SporeLauncherFire(1200.0f, true);
  }

  void SecondaryAttack()
  {
    SporeLauncherFire(800.0f, false);
  }

  void Reload()
  {
    if (self.m_iClip == MAX_CLIP || m_pPlayer.m_rgAmmo(self.m_iPrimaryAmmoType) <= 0)
    {
      ReloadEnd();
      return;
    }

    switch (m_kReloadState)
    {
    case NOT_RELOADING:
      // Don't reload until recoil is done
      if (self.m_flNextPrimaryAttack > g_Engine.time || self.m_flNextSecondaryAttack > g_Engine.time)
        break;

      // Prepare to reload
      self.SendWeaponAnim(RELOAD_REACH);
      self.m_flTimeWeaponIdle = g_Engine.time + g_PlayerFuncs.SharedRandomFloat(m_pPlayer.random_seed, 10.0f, 15.0f);
      m_kReloadState = DO_RELOAD_EFFECTS;

      SetThink(ThinkFunction(Reload));
      self.m_flNextPrimaryAttack = self.m_flNextSecondaryAttack = pev.nextthink = g_Engine.time + 0.66f;
      break;
    case DO_RELOAD_EFFECTS:
      // Send reload anim
      self.SendWeaponAnim(RELOAD);
      g_SoundSystem.EmitSoundDyn(m_pPlayer.edict(), CHAN_ITEM, "weapons/splauncher_reload.wav", 0.7f, ATTN_NORM, 0, PITCH_NORM);
      m_kReloadState = RELOAD_ONE;
      BaseClass.Reload();

      SetThink(ThinkFunction(Reload));
      pev.nextthink = g_Engine.time + 1.0f;
      break;
    case RELOAD_ONE:
      // Add them to the clip
      self.m_iClip++;
      m_pPlayer.m_rgAmmo(self.m_iPrimaryAmmoType, m_pPlayer.m_rgAmmo(self.m_iPrimaryAmmoType) - 1);
      m_kReloadState = DO_RELOAD_EFFECTS;

      SetThink(ThinkFunction(Reload));
      pev.nextthink = g_Engine.time;
      break;
    }
  }

  void FinishReload()
  {
    // Don't use BaseClass method
    // otherwise it will do the regular reload
  }

  void WeaponIdle()
  {
    self.ResetEmptySound();
    m_pPlayer.GetAutoaimVector(AUTOAIM_10DEGREES);

    if (self.m_flTimeWeaponIdle > g_Engine.time)
      return;

    float flRand = g_PlayerFuncs.SharedRandomFloat(m_pPlayer.random_seed, 0.0f, 1.0f);
    if (flRand <= 0.75f)
    {
      self.SendWeaponAnim(IDLE);
      self.m_flTimeWeaponIdle = g_Engine.time + 2.0f;
    }
    else if (flRand <= 0.95f)
    {
      self.SendWeaponAnim(IDLE2);
      self.m_flTimeWeaponIdle = g_Engine.time + 4.0f;
    }
    else
    {
      self.SendWeaponAnim(FIDGET);
      self.m_flTimeWeaponIdle = g_Engine.time + 4.0f;

      g_SoundSystem.EmitSoundDyn(m_pPlayer.edict(), CHAN_ITEM, "weapons/splauncher_pet.wav", 0.7f, ATTN_NORM, 0, PITCH_NORM);
    }
  }

  private void SporeLauncherFire(float flSpeed, bool fContactType)
  {
    if (self.m_iClip <= 0)
      return;

    if (ReloadEnd())
    {
      self.m_flNextPrimaryAttack = self.m_flNextSecondaryAttack = g_Engine.time + 0.5f;
      return;
    }

    m_pPlayer.m_iWeaponVolume = LOUD_GUN_VOLUME;
    m_pPlayer.m_iWeaponFlash = BRIGHT_GUN_FLASH;

    --self.m_iClip;

    m_pPlayer.SetAnimation(PLAYER_ATTACK1);

    Vector vecAnglesAim = m_pPlayer.pev.v_angle + m_pPlayer.pev.punchangle;
    Math.MakeVectors(m_pPlayer.pev.v_angle);
    Vector vecSrc = m_pPlayer.GetGunPosition() + (g_Engine.v_forward * 16.0f) + (g_Engine.v_right * 8.0f) + (g_Engine.v_up * -8.0f);
    // vecAngles = vecAngles + m_pPlayer.GetAutoaimVectorFromPoint(vecSrc, AUTOAIM_10DEGREES);

    // Math.MakeVectors(vecAnglesAim);
    vecAnglesAim.x = -vecAnglesAim.x;
    if (fContactType)
      COFSpore::ShootContact(vecSrc, vecAnglesAim, g_Engine.v_forward * flSpeed, m_pPlayer.edict());
    else
      COFSpore::ShootTimed(vecSrc, vecAnglesAim, m_pPlayer.pev.velocity + (g_Engine.v_forward * flSpeed), m_pPlayer.edict());

    self.SendWeaponAnim(FIRE);
    g_SoundSystem.EmitSoundDyn(m_pPlayer.edict(), CHAN_WEAPON, "weapons/splauncher_fire.wav", 0.9f, ATTN_NORM, 0, PITCH_NORM);
    m_pPlayer.pev.punchangle.x = -3.0f;

    if (self.m_iClip <= 0 && m_pPlayer.m_rgAmmo(self.m_iPrimaryAmmoType) <= 0)
      m_pPlayer.SetSuitUpdate("!HEV_AMO0", false, 0);

    self.m_flNextPrimaryAttack = self.m_flNextSecondaryAttack = self.m_flTimeWeaponIdle = g_Engine.time + 0.5f;
  }

  private bool ReloadEnd()
  {
    if (m_kReloadState == NOT_RELOADING)
      return false;

    SetThink(null);
    self.SendWeaponAnim(AIM);
    self.m_flTimeWeaponIdle = g_Engine.time + 0.83f;
    m_kReloadState = NOT_RELOADING;
    return true;
  }
}

string GetName()
{
  return "weapon_ofsporelauncher";
}

void Register()
{
  if (!g_CustomEntityFuncs.IsCustomEntity(GetName()))
  {
    COFSpore::Register();
    g_CustomEntityFuncs.RegisterCustomEntity("COFSporeLauncher::weapon_ofsporelauncher", GetName());
    g_ItemRegistry.RegisterWeapon(GetName(), "opfor", "sporeclip", "", "ammo_sporeclip", "");
  }
}

}