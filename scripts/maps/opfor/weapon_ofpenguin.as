/*
 * The Opposing Force version of the penguin
 */

namespace COFPenguin
{

enum penguin_e
{
  IDLE1 = 0,
  FIDGETFIT,
  FIDGETNIP,
  DOWN,
  UP,
  THROW
};

// Weapon information
const int MAX_CARRY    = 9;
const int MAX_CLIP     = WEAPON_NOCLIP;
const int DEFAULT_GIVE = 3;
const int WEIGHT       = 5;

class weapon_ofpenguin : ScriptBasePlayerWeaponEntity
{
  private CBasePlayer@ m_pPlayer
  {
    get const { return cast<CBasePlayer>(self.m_hPlayer.GetEntity()); }
    set       { self.m_hPlayer = EHandle(@value); }
  }
  private bool m_fDropped;

  void Spawn()
  {
    Precache();
    g_EntityFuncs.SetModel(self, self.GetW_Model("models/opfor/w_penguinnest.mdl"));
    self.m_iDefaultAmmo = DEFAULT_GIVE;
    self.FallInit();

    pev.sequence = 1;
    pev.animtime = g_Engine.time;
    pev.framerate = 1.0f;
    self.ResetSequenceInfo();
  }

  void Precache()
  {
    self.PrecacheCustomModels();
    g_Game.PrecacheModel("models/opfor/w_penguinnest.mdl");
    g_Game.PrecacheModel("models/hlclassic/v_penguin.mdl");
    g_Game.PrecacheModel("models/opfor/p_penguin.mdl");

    // Allow for custom monster models
    if (string(pev.noise).IsEmpty())
      pev.noise = "models/opfor/w_penguin.mdl";

    g_Game.PrecacheModel(pev.noise);

    g_SoundSystem.PrecacheSound("squeek/sqk_hunt2.wav");
    g_SoundSystem.PrecacheSound("squeek/sqk_hunt3.wav");
    g_SoundSystem.PrecacheSound("common/null.wav");

    g_Game.PrecacheOther("monster_snark");
    g_Game.PrecacheGeneric("sprites/opfor/640hud7.spr");
    g_Game.PrecacheGeneric("sprites/opfor/640hudof03.spr");
    g_Game.PrecacheGeneric("sprites/opfor/640hudof04.spr");
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

  void DestroyItem()
  {
    SetThink(null);
    self.DestroyItem();
  }

  bool GetItemInfo(ItemInfo& out info)
  {
    info.iMaxAmmo1 = MAX_CARRY;
    info.iMaxAmmo2 = -1;
    info.iAmmo1Drop = 1;
    info.iAmmo2Drop = -1;
    info.iMaxClip = MAX_CLIP;
    info.iFlags = ITEM_FLAG_LIMITINWORLD | ITEM_FLAG_EXHAUSTIBLE;
    info.iSlot = 4;
    info.iPosition = 9;
    info.iId = g_ItemRegistry.GetIdForName(pev.classname);
    info.iWeight = WEIGHT;
    return true;
  }

  bool CanDeploy()
  {
    return m_pPlayer.m_rgAmmo(self.m_iPrimaryAmmoType) > 0;
  }

  bool Deploy()
  {
    m_fDropped = false;

    if (Math.RandomFloat(0.0f, 1.0f) <= 0.5f)
      g_SoundSystem.EmitSoundDyn(self.edict(), CHAN_VOICE, "squeek/sqk_hunt2.wav", VOL_NORM, ATTN_NORM, 0, PITCH_NORM);
    else
      g_SoundSystem.EmitSoundDyn(self.edict(), CHAN_VOICE, "squeek/sqk_hunt3.wav", VOL_NORM, ATTN_NORM, 0, PITCH_NORM);

    m_pPlayer.m_iWeaponVolume = QUIET_GUN_VOLUME;

    self.DefaultDeploy(self.GetV_Model("models/hlclassic/v_penguin.mdl"), self.GetP_Model("models/opfor/p_penguin.mdl"), UP, "squeak");
    self.m_flNextPrimaryAttack = self.m_flTimeWeaponIdle = g_Engine.time + 1.0f;
    return true;
  }

  void Holster(int skiplocal = 0)
  {
    SetThink(null);
    g_SoundSystem.EmitSoundDyn(m_pPlayer.edict(), CHAN_WEAPON, "common/null.wav", VOL_NORM, ATTN_NORM, 0, PITCH_NORM);

    if (m_pPlayer.m_rgAmmo(self.m_iPrimaryAmmoType) <= 0 && !m_fDropped)
    {
      SetThink(ThinkFunction(DestroyItem));
      pev.nextthink = g_Engine.time + 0.1f;
    }

    BaseClass.Holster(skiplocal);
  }

  CBasePlayerItem@ DropItem()
  {
    m_fDropped = true;
    return self;
  }

  bool CanHaveDuplicates()
  {
    return true;
  }

  void PrimaryAttack()
  {
    if (m_pPlayer.m_rgAmmo(self.m_iPrimaryAmmoType) <= 0)
      return;

    Math.MakeVectors(m_pPlayer.pev.v_angle);

    Vector vecSrc = m_pPlayer.pev.origin;
    if ((m_pPlayer.pev.flags & FL_DUCKING) != 0)
      vecSrc.z += 18.0f;

    Vector vecStart = vecSrc + (g_Engine.v_forward * 20.0f);
    Vector vecEnd = vecSrc + (g_Engine.v_forward * 64.0f);

    TraceResult tr;
    g_Utility.TraceLine(vecStart, vecEnd, dont_ignore_monsters, null, tr);

    if (tr.fAllSolid != 0 || tr.fStartSolid != 0 || tr.flFraction <= 0.25f)
      return;

    m_pPlayer.m_iWeaponVolume = QUIET_GUN_VOLUME;

    m_pPlayer.m_rgAmmo(self.m_iPrimaryAmmoType, m_pPlayer.m_rgAmmo(self.m_iPrimaryAmmoType) - 1);

    // Player "shoot" animation
    m_pPlayer.SetAnimation(PLAYER_ATTACK1);

    // Yeah... I don't wanna bother making custom monster that most likely won't work correctly.
    CBaseEntity@ pPenguin = g_EntityFuncs.Create("monster_snark", tr.vecEndPos, m_pPlayer.pev.v_angle, true, m_pPlayer.edict());
    g_EntityFuncs.DispatchKeyValue(pPenguin.edict(), "ondestroyfn", "COFPenguin::Killed");
    g_EntityFuncs.DispatchKeyValue(pPenguin.edict(), "bloodcolor", "1"); // Snark ignores this kv, I hope this will be fixed someday
    pPenguin.SetClassification(m_pPlayer.Classify());
    g_EntityFuncs.SetModel(pPenguin, pev.noise);
    pPenguin.pev.velocity = m_pPlayer.pev.velocity + (g_Engine.v_forward * 200.0f);
    g_EntityFuncs.DispatchSpawn(pPenguin.edict());

    self.SendWeaponAnim(THROW);

    if (Math.RandomFloat(0.0f, 1.0f) <= 0.5f)
      g_SoundSystem.EmitSoundDyn(self.edict(), CHAN_VOICE, "squeek/sqk_hunt2.wav", VOL_NORM, ATTN_NORM, 0, PITCH_NORM);
    else
      g_SoundSystem.EmitSoundDyn(self.edict(), CHAN_VOICE, "squeek/sqk_hunt3.wav", VOL_NORM, ATTN_NORM, 0, PITCH_NORM);

    self.m_flNextPrimaryAttack = g_Engine.time + 0.3f;
    self.m_flTimeWeaponIdle = g_Engine.time + g_PlayerFuncs.SharedRandomFloat(m_pPlayer.random_seed, 10.0f, 15.0f);

    if (m_pPlayer.m_rgAmmo(self.m_iPrimaryAmmoType) > 0)
    {
      SetThink(ThinkFunction(UpAgain));
      pev.nextthink = g_Engine.time + 1.0f;
    }
  }

  void WeaponIdle()
  {
    if (self.m_flTimeWeaponIdle > g_Engine.time)
      return;

    float flRand = g_PlayerFuncs.SharedRandomFloat(m_pPlayer.random_seed, 0.0f, 1.0f);
    if (flRand <= 0.75f)
    {
      self.SendWeaponAnim(IDLE1);
      self.m_flTimeWeaponIdle = g_Engine.time + 3.75f;
    }
    else if (flRand <= 0.875f)
    {
      self.SendWeaponAnim(FIDGETFIT);
      self.m_flTimeWeaponIdle = g_Engine.time + 4.375f;
    }
    else
    {
      self.SendWeaponAnim(FIDGETNIP);
      self.m_flTimeWeaponIdle = g_Engine.time + 5.0f;
    }
  }

  private void UpAgain()
  {
    SetThink(null);
    self.SendWeaponAnim(UP);
  }
}

void Killed(CBaseEntity@ pSqueak)
{
  const int iHitTimes = int(pSqueak.pev.dmg / g_EngineFuncs.CVarGetFloat("sk_snark_dmg_pop"));
  pSqueak.pev.dmg = g_EngineFuncs.CVarGetFloat("sk_plr_hand_grenade") * iHitTimes;

  // CPenguinGrenade::SuperBounceTouch(CBaseEntity* pOther)
  if (pSqueak.pev.dmg > 500.0f)
    pSqueak.pev.dmg = 500.0f;

  // CPenguinGrenade::Killed(CBaseEntity* attacker, int iGib)
  Vector vecSpot = pSqueak.pev.origin + Vector(0.0f, 0.0f, 8.0f);
  cast<CGrenade>(pSqueak).Explode(vecSpot, vecSpot + Vector(0.0f, 0.0f, -40.0f));
}

string GetName()
{
  return "weapon_ofpenguin";
}

void Register()
{
  if (!g_CustomEntityFuncs.IsCustomEntity(GetName()))
  {
    g_CustomEntityFuncs.RegisterCustomEntity("COFPenguin::weapon_ofpenguin", GetName());
    g_ItemRegistry.RegisterWeapon(GetName(), "opfor", GetName(), "", GetName(), "");
  }
}

}