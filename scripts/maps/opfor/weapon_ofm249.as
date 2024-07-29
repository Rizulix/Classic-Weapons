/*
 * The Opposing Force version of the m249
 */

namespace COFM249
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
const CCVar@ g_M249WideSpread = CCVar("m249_wide_spread", 0, "", ConCommandFlag::AdminOnly); // as_command m249_wide_spread
// Knockback thing
const CCVar@ g_M249Knockback = CCVar("m249_knockback", 1, "", ConCommandFlag::AdminOnly); // as_command m249_knockback

class weapon_ofm249 : ScriptBasePlayerWeaponEntity
{
  private CBasePlayer@ m_pPlayer
  {
    get const { return cast<CBasePlayer>(self.m_hPlayer.GetEntity()); }
    set       { self.m_hPlayer = EHandle(@value); }
  }
  private bool m_bAlternatingEject;
  private int m_iShell;
  private int m_iLink;

  void Spawn()
  {
    Precache();
    g_EntityFuncs.SetModel(self, self.GetW_Model("models/hlclassic/w_saw.mdl"));
    self.m_iDefaultAmmo = DEFAULT_GIVE;
    self.FallInit();

    m_bAlternatingEject = false;
  }

  void Precache()
  {
    self.PrecacheCustomModels();
    g_Game.PrecacheModel("models/hlclassic/w_saw.mdl");
    g_Game.PrecacheModel("models/hlclassic/v_saw.mdl");
    g_Game.PrecacheModel("models/hlclassic/p_saw.mdl");

    m_iLink = g_Game.PrecacheModel("models/saw_link.mdl");
    m_iShell = g_Game.PrecacheModel("models/hlclassic/saw_shell.mdl");

    g_SoundSystem.PrecacheSound("weapons/saw_fire1.wav");
    g_SoundSystem.PrecacheSound("hlclassic/weapons/357_cock1.wav");
    g_SoundSystem.PrecacheSound("hlclassic/weapons/saw_reload.wav"); // sequence: 2; frame: 1; event 5004
    g_Game.PrecacheGeneric("sound/hlclassic/weapons/saw_reload.wav");
    g_SoundSystem.PrecacheSound("hlclassic/weapons/saw_reload2.wav"); // sequence: 3; frame: 0; event 5004
    g_Game.PrecacheGeneric("sound/hlclassic/weapons/saw_reload2.wav");

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
    info.iSlot = 5;
    info.iPosition = 6;
    info.iId = g_ItemRegistry.GetIdForName(pev.classname);
    info.iWeight = WEIGHT;
    return true;
  }

  bool Deploy()
  {
    self.DefaultDeploy(self.GetV_Model("models/hlclassic/v_saw.mdl"), self.GetP_Model("models/hlclassic/p_saw.mdl"), DRAW, "saw", 0, pev.body);
    self.m_flNextPrimaryAttack = self.m_flTimeWeaponIdle = g_Engine.time + 1.0f;
    return true;
  }

  void Holster(int skiplocal = 0)
  {
    SetThink(null);
    BaseClass.Holster(skiplocal);
  }

  void ItemPostFrame()
  {
    BaseClass.ItemPostFrame();

    // Speed up player reload anim
    // Surely no one will mess with playeranim index rigth?
    if (m_pPlayer.pev.sequence == 172 || m_pPlayer.pev.sequence == 176)
      m_pPlayer.pev.framerate = 2.0f;
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
      if (!self.m_fInReload)
      {
        self.PlayEmptySound();
        self.m_flNextPrimaryAttack = g_Engine.time + 0.15f;
      }
      return;
    }

    m_pPlayer.m_iWeaponVolume = NORMAL_GUN_VOLUME;
    m_pPlayer.m_iWeaponFlash = NORMAL_GUN_FLASH;

    RecalculateBody(--self.m_iClip);

    m_pPlayer.pev.effects |= EF_MUZZLEFLASH;
    pev.effects |= EF_MUZZLEFLASH;

    m_pPlayer.SetAnimation(PLAYER_ATTACK1);

    m_bAlternatingEject = !m_bAlternatingEject;

    Math.MakeVectors(m_pPlayer.pev.v_angle + m_pPlayer.pev.punchangle);
    Vector vecSrc = m_pPlayer.GetGunPosition();
    Vector vecAiming = m_pPlayer.GetAutoaimVector(AUTOAIM_5DEGREES);

    Vector vecSpread;
    if (g_M249WideSpread.GetBool())
      vecSpread = self.BulletAccuracy(VECTOR_CONE_15DEGREES, VECTOR_CONE_6DEGREES, VECTOR_CONE_3DEGREES);
    else
      vecSpread = self.BulletAccuracy(VECTOR_CONE_10DEGREES, VECTOR_CONE_4DEGREES, VECTOR_CONE_2DEGREES);

    self.FireBullets(1, vecSrc, vecAiming, vecSpread, 8192.0f, BULLET_PLAYER_CUSTOMDAMAGE, 2, int(g_EngineFuncs.CVarGetFloat("sk_556_bullet")), m_pPlayer.pev);

    self.SendWeaponAnim(SHOOT1 + Math.RandomLong(0, 2), 0, pev.body);
    g_SoundSystem.EmitSoundDyn(m_pPlayer.edict(), CHAN_WEAPON, "weapons/saw_fire1.wav", VOL_NORM, ATTN_NORM, 0, 94 + Math.RandomLong(0, 15));
    m_pPlayer.pev.punchangle.x = Math.RandomFloat(-2.0f, 2.0f);
    m_pPlayer.pev.punchangle.y = Math.RandomFloat(-1.0f, 1.0f);

    // GetDefaultShellInfo(origin, velocity, -28.0f, 4.0f, 24.0f);
    Math.MakeVectors(m_pPlayer.pev.v_angle);
    float fR = Math.RandomFloat(50.0f, 70.0f);
    float fU = Math.RandomFloat(100.0f, 150.0f);
    Vector vecOrigin = m_pPlayer.GetGunPosition() + (g_Engine.v_forward * 14.0f) + (g_Engine.v_right * 8.0f) + (g_Engine.v_up * -10.0f);
    Vector vecVelocity = m_pPlayer.pev.velocity + (g_Engine.v_forward * 25.0f) + (g_Engine.v_right * fR) + (g_Engine.v_up * fU);
    g_EntityFuncs.EjectBrass(vecOrigin, vecVelocity, m_pPlayer.pev.angles.y, m_bAlternatingEject ? m_iLink : m_iShell, TE_BOUNCE_SHELL);

    if (self.m_iClip <= 0 && m_pPlayer.m_rgAmmo(self.m_iPrimaryAmmoType) <= 0)
      m_pPlayer.SetSuitUpdate("!HEV_AMO0", false, 0);

    self.m_flNextPrimaryAttack = g_Engine.time + 0.067f;
    self.m_flTimeWeaponIdle = g_Engine.time + 0.2f;

    if (g_M249Knockback.GetBool())
    {
      Math.MakeVectors(m_pPlayer.pev.v_angle + m_pPlayer.pev.punchangle);
      float flZVel = m_pPlayer.pev.velocity.z;

      m_pPlayer.pev.velocity = m_pPlayer.pev.velocity + (g_Engine.v_forward * -35.0f);
      // Restore Z velocity to make deathmatch easier.
      m_pPlayer.pev.velocity.z = flZVel;
    }
  }

  void Reload()
  {
    if (self.m_iClip == MAX_CLIP || m_pPlayer.m_rgAmmo(self.m_iPrimaryAmmoType) <= 0)
      return;

    self.DefaultReload(MAX_CLIP, RELOAD_START, 1.0f, pev.body);
    self.m_flNextPrimaryAttack = self.m_flTimeWeaponIdle = g_Engine.time + 3.78f;
    SetThink(ThinkFunction(FinishAnim));
    pev.nextthink = g_Engine.time + 1.33f;
    BaseClass.Reload();
  }

  void WeaponIdle()
  {
    self.ResetEmptySound();
    m_pPlayer.GetAutoaimVector(AUTOAIM_5DEGREES); // Update auto-aim

    if (self.m_flTimeWeaponIdle > g_Engine.time)
      return;

    float flRand = g_PlayerFuncs.SharedRandomFloat(m_pPlayer.random_seed, 0.0f, 1.0f);
    if (flRand <= 0.95f)
    {
      self.SendWeaponAnim(SLOWIDLE, 0, pev.body);
      self.m_flTimeWeaponIdle = g_Engine.time + 5.0f;
    }
    else
    {
      self.SendWeaponAnim(IDLE2, 0, pev.body);
      self.m_flTimeWeaponIdle = g_Engine.time + 6.16f;
    }
  }

  private void RecalculateBody(int iClip)
  {
    if (iClip <= 0)
      pev.body = 8;
    else if (iClip > 0 && iClip < 8)
      pev.body = 9 - iClip;
    else
      pev.body = 0;
  }

  private void FinishAnim()
  {
    SetThink(null);
    RecalculateBody(self.m_iClip);
    self.SendWeaponAnim(RELOAD_END, 0, pev.body);
  }
}

string GetName()
{
  return "weapon_ofm249";
}

void Register()
{
  if (!g_CustomEntityFuncs.IsCustomEntity(GetName()))
  {
    g_CustomEntityFuncs.RegisterCustomEntity("COFM249::weapon_ofm249", GetName());
    g_ItemRegistry.RegisterWeapon(GetName(), "opfor", "556", "", "ammo_556", "");
  }
}

}
