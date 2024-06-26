/*
 * The Opposing Force version of the sniper
 */

namespace COFSniperRifle
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

class weapon_ofsniperrifle : ScriptBasePlayerWeaponEntity
{
  private CBasePlayer@ m_pPlayer
  {
    get const { return cast<CBasePlayer>(self.m_hPlayer.GetEntity()); }
    set       { self.m_hPlayer = EHandle(@value); }
  }
  private bool m_fInSpecialReload;

  void Spawn()
  {
    Precache();
    g_EntityFuncs.SetModel(self, self.GetW_Model("models/hlclassic/w_m40a1.mdl"));
    self.m_iDefaultAmmo = DEFAULT_GIVE;
    self.FallInit();

    m_fInSpecialReload = false;
  }

  void Precache()
  {
    self.PrecacheCustomModels();
    g_Game.PrecacheModel("models/hlclassic/w_m40a1.mdl");
    g_Game.PrecacheModel("models/hlclassic/v_m40a1.mdl");
    g_Game.PrecacheModel("models/hlclassic/p_m40a1.mdl");

    g_SoundSystem.PrecacheSound("weapons/sniper_zoom.wav");
    g_SoundSystem.PrecacheSound("hlclassic/weapons/357_cock1.wav");
    g_SoundSystem.PrecacheSound("hlclassic/weapons/sniper_fire.wav");
    g_Game.PrecacheGeneric("sound/hlclassic/weapons/sniper_fire.wav");
    g_SoundSystem.PrecacheSound("hlclassic/weapons/sniper_bolt1.wav"); // default viewmodel; sequence: 2; frame: 32; event 5004
    g_Game.PrecacheGeneric("sound/hlclassic/weapons/sniper_bolt1.wav");
    g_SoundSystem.PrecacheSound("hlclassic/weapons/sniper_bolt2.wav"); // default viewmodel; sequence: 3; frame: 32; event 5004
    g_Game.PrecacheGeneric("sound/hlclassic/weapons/sniper_bolt2.wav");
    g_SoundSystem.PrecacheSound("hlclassic/weapons/sniper_reload_first_seq.wav"); // default viewmodel; sequence: 4, 6; frame: 1; event 5004
    g_Game.PrecacheGeneric("sound/hlclassic/weapons/sniper_reload_first_seq.wav");
    g_SoundSystem.PrecacheSound("hlclassic/weapons/sniper_reload_second_seq.wav"); // default viewmodel; sequence: 5; frame: 1; event 5004
    g_Game.PrecacheGeneric("sound/hlclassic/weapons/sniper_reload_second_seq.wav");

    g_Game.PrecacheGeneric("sprites/opfor/" + pev.classname + ".txt");
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
      g_SoundSystem.EmitSoundDyn(m_pPlayer.edict(), CHAN_WEAPON, "hlclassic/weapons/357_cock1.wav", 0.8f, ATTN_NORM, 0, PITCH_NORM);
      self.m_bPlayEmptySound = false;
      return false;
    }
    return false;
  }

  bool Deploy()
  {
    self.DefaultDeploy(self.GetV_Model("models/hlclassic/v_m40a1.mdl"), self.GetP_Model("models/hlclassic/p_m40a1.mdl"), DRAW, "sniper");
    self.m_flTimeWeaponIdle = g_Engine.time + 1.0f;
    return true;
  }

  void Holster(int skiplocal = 0)
  {
    if (m_pPlayer.m_iFOV != 0)
      SecondaryAttack();

    SetThink(null);
    m_fInSpecialReload = false;
    BaseClass.Holster(skiplocal);
  }

  void PrimaryAttack()
  {
    if (m_pPlayer.pev.waterlevel == WATERLEVEL_HEAD)
    {
      self.PlayEmptySound();
      self.m_flNextPrimaryAttack = g_Engine.time + 1.0f;
      return;
    }

    if (self.m_iClip <= 0)
    {
      self.PlayEmptySound();
      return;
    }

    m_pPlayer.m_iWeaponVolume = QUIET_GUN_VOLUME;

    --self.m_iClip;

    m_pPlayer.pev.effects |= EF_MUZZLEFLASH;
    pev.effects |= EF_MUZZLEFLASH;

    m_pPlayer.SetAnimation(PLAYER_ATTACK1);

    Math.MakeVectors(m_pPlayer.pev.v_angle + m_pPlayer.pev.punchangle);
    Vector vecSrc = m_pPlayer.GetGunPosition();
    Vector vecAiming = m_pPlayer.GetAutoaimVector(AUTOAIM_2DEGREES);

    self.FireBullets(1, vecSrc, vecAiming, g_vecZero, 8192.0f, BULLET_PLAYER_SNIPER, 0, 0, m_pPlayer.pev);

    self.SendWeaponAnim((self.m_iClip != 0) ? FIRE : FIRELASTROUND);
    g_SoundSystem.EmitSoundDyn(m_pPlayer.edict(), CHAN_WEAPON, "hlclassic/weapons/sniper_fire.wav", Math.RandomFloat(0.9f, 1.0f), ATTN_NORM, 0, 98 + Math.RandomLong(0, 3));
    m_pPlayer.pev.punchangle.x = -2.0f;

    if (self.m_iClip <= 0 && m_pPlayer.m_rgAmmo(self.m_iPrimaryAmmoType) <= 0)
      m_pPlayer.SetSuitUpdate("!HEV_AMO0", false, 0);

    self.m_flTimeWeaponIdle = self.m_flNextPrimaryAttack = g_Engine.time + 2.0f;
  }

  void SecondaryAttack()
  {
    ToggleZoom();
    self.m_flNextSecondaryAttack = g_Engine.time + 0.5f;
    g_SoundSystem.EmitSoundDyn(m_pPlayer.edict(), CHAN_ITEM, "weapons/sniper_zoom.wav", VOL_NORM, ATTN_NORM, 0, PITCH_NORM);
  }

  void Reload()
  {
    if (self.m_iClip == MAX_CLIP || m_pPlayer.m_rgAmmo(self.m_iPrimaryAmmoType) <= 0)
      return;

    if (m_pPlayer.m_iFOV != 0)
      ToggleZoom();

    if (self.m_iClip != 0)
    {
      self.DefaultReload(MAX_CLIP, RELOAD3, 2.324f);
      self.m_flTimeWeaponIdle = g_Engine.time + 4.102f;
    }
    else
    {
      self.DefaultReload(MAX_CLIP, RELOAD1, 2.324f);
      self.m_flTimeWeaponIdle = self.m_flNextPrimaryAttack = g_Engine.time + 4.102f;
      SetThink(ThinkFunction(FinishAnim));
      pev.nextthink = g_Engine.time + 2.324f;
    }

    BaseClass.Reload();
  }

  void WeaponIdle()
  {
    self.ResetEmptySound();
    m_pPlayer.GetAutoaimVector(AUTOAIM_2DEGREES); // Update autoaim

    if (self.m_flTimeWeaponIdle > g_Engine.time)
      return;

    self.SendWeaponAnim((self.m_iClip != 0) ? SLOWIDLE : SLOWIDLE2);
    self.m_flTimeWeaponIdle = g_Engine.time + 4.348f;
  }

  private void FinishAnim()
  {
    SetThink(null);
    self.SendWeaponAnim(RELOAD2);
  }

  private void ToggleZoom()
  {
    if (m_pPlayer.m_iFOV == 0)
    {
      m_pPlayer.m_iFOV = 18;
      m_pPlayer.m_szAnimExtension = "sniperscope";
    }
    else
    {
      m_pPlayer.m_iFOV = 0;
      m_pPlayer.m_szAnimExtension = "sniper";
    }
  }
}

string GetName()
{
  return "weapon_ofsniperrifle";
}

void Register()
{
  if (!g_CustomEntityFuncs.IsCustomEntity(GetName()))
  {
    g_CustomEntityFuncs.RegisterCustomEntity("COFSniperRifle::weapon_ofsniperrifle", GetName());
    g_ItemRegistry.RegisterWeapon(GetName(), "opfor", "m40a1", "", "ammo_762", "");
  }
}

}
