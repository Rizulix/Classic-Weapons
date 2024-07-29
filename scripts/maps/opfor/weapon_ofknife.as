/*
 * The Opposing Force version of the knife
 */

namespace COFKnife
{

enum knife_e
{
  IDLE1 = 0,
  DRAW,
  HOLSTER,
  ATTACK1,
  ATTACK1MISS,
  ATTACK2,
  ATTACK2HIT,
  ATTACK3,
  ATTACK3HIT,
  IDLE2,
  IDLE3,
  CHARGE,
  STAB
};

// Weapon information
const int MAX_CARRY    = -1;
const int MAX_CLIP     = WEAPON_NOCLIP;
const int DEFAULT_GIVE = 0;
const int WEIGHT       = 0;

// Backstab thing
const CCVar@ g_KnifeAllowBackstab = CCVar("knife_allow_backstab", 1, "", ConCommandFlag::AdminOnly); // as_command knife_allow_backstab

class weapon_ofknife : ScriptBasePlayerWeaponEntity
{
  private CBasePlayer@ m_pPlayer
  {
    get const { return cast<CBasePlayer>(self.m_hPlayer.GetEntity()); }
    set       { self.m_hPlayer = EHandle(@value); }
  }
  private TraceResult m_trHit;
  private int m_iSwing;

  void Spawn()
  {
    Precache();
    self.m_flCustomDmg = pev.dmg;
    g_EntityFuncs.SetModel(self, self.GetW_Model("models/opfor/w_knife.mdl"));
    self.m_iDefaultAmmo = DEFAULT_GIVE;
    self.FallInit(); // Get ready to fall down.
  }

  void Precache()
  {
    self.PrecacheCustomModels();
    g_Game.PrecacheModel("models/opfor/w_knife.mdl");
    g_Game.PrecacheModel("models/hlclassic/v_knife.mdl");
    g_Game.PrecacheModel("models/opfor/p_knife.mdl");

    g_SoundSystem.PrecacheSound("weapons/knife1.wav");
    g_SoundSystem.PrecacheSound("weapons/knife2.wav");
    g_SoundSystem.PrecacheSound("weapons/knife3.wav");
    g_SoundSystem.PrecacheSound("weapons/knife_hit_flesh1.wav");
    g_SoundSystem.PrecacheSound("weapons/knife_hit_flesh2.wav");
    g_SoundSystem.PrecacheSound("weapons/knife_hit_wall1.wav");
    g_SoundSystem.PrecacheSound("weapons/knife_hit_wall2.wav");

    g_Game.PrecacheGeneric("sprites/opfor/640hudof03.spr");
    g_Game.PrecacheGeneric("sprites/opfor/640hudof04.spr");
    g_Game.PrecacheGeneric("sprites/opfor/" + pev.classname + ".txt");
  }

  bool AddToPlayer(CBasePlayer@ pPlayer)
  {
    if (!BaseClass.AddToPlayer(pPlayer))
      return false;

    SetThink(null);
    SetTouch(null);

    NetworkMessage weapon(MSG_ONE, NetworkMessages::WeapPickup, pPlayer.edict());
      weapon.WriteLong(g_ItemRegistry.GetIdForName(pev.classname));
    weapon.End();
    return true;
  }

  bool GetItemInfo(ItemInfo& out info)
  {
    info.iMaxAmmo1 = MAX_CARRY;
    info.iAmmo1Drop = -1;
    info.iMaxAmmo2 = -1;
    info.iAmmo2Drop = -1;
    info.iMaxClip = MAX_CLIP;
    info.iSlot = 0;
    info.iPosition = 7;
    info.iId = g_ItemRegistry.GetIdForName(pev.classname);
    info.iFlags = -1;
    info.iWeight = WEIGHT;
    return true;
  }

  bool Deploy()
  {
    self.DefaultDeploy(self.GetV_Model("models/hlclassic/v_knife.mdl"), self.GetP_Model("models/opfor/p_knife.mdl"), DRAW, "crowbar");
    self.m_flNextPrimaryAttack = self.m_flNextTertiaryAttack = self.m_flTimeWeaponIdle = g_Engine.time + 1.0f;
    return true;
  }

  void Holster(int skiplocal = 0)
  {
    SetThink(null);
    BaseClass.Holster(skiplocal);
  }

  void PrimaryAttack()
  {
    if (!Swing(true))
    {
      SetThink(ThinkFunction(SwingAgain));
      pev.nextthink = g_Engine.time + 0.1f;
    }
  }

  void TertiaryAttack()
  {
    if (int(g_EngineFuncs.CVarGetFloat("mp_dropweapons")) == 0)
      return;

    self.SendWeaponAnim(ATTACK1);
    self.m_flNextPrimaryAttack = self.m_flNextTertiaryAttack = g_Engine.time + 1.0f;

    SetThink(ThinkFunction(Throw));
    pev.nextthink = g_Engine.time + 0.3f;
  }

  bool Swing(const bool bFirst)
  {
    bool fDidHit = false;

    TraceResult tr;
    Math.MakeVectors(m_pPlayer.pev.v_angle);
    Vector vecSrc = m_pPlayer.GetGunPosition();
    Vector vecEnd = vecSrc + (g_Engine.v_forward * 32.0f);

    g_Utility.TraceLine(vecSrc, vecEnd, dont_ignore_monsters, m_pPlayer.edict(), tr);

    if (tr.flFraction >= 1.0f)
    {
      g_Utility.TraceHull(vecSrc, vecEnd, dont_ignore_monsters, head_hull, m_pPlayer.edict(), tr);
      if (tr.flFraction < 1.0f)
      {
        // Calculate the point of intersection of the line (or hull) and the object we hit
        // This is and approximation of the "best" intersection
        CBaseEntity@ pHit = g_EntityFuncs.Instance(tr.pHit);
        if (pHit is null || pHit.IsBSPModel())
          g_Utility.FindHullIntersection(vecSrc, tr, tr, VEC_DUCK_HULL_MIN, VEC_DUCK_HULL_MAX, m_pPlayer.edict());
        vecEnd = tr.vecEndPos; // This is the point on the actual surface (the hull could have hit space)
      }
    }

    if (tr.flFraction >= 1.0f)
    {
      if (bFirst)
      {
        // miss
        switch ((m_iSwing++) % 3)
        {
        case 0: self.SendWeaponAnim(ATTACK1MISS); break;
        case 1: self.SendWeaponAnim(ATTACK2); break;
        case 2: self.SendWeaponAnim(ATTACK3); break;
        }

        self.m_flNextPrimaryAttack = self.m_flNextTertiaryAttack = g_Engine.time + 0.5f;
        // Play wiff or swish sound
        switch (Math.RandomLong(0, 2))
        {
        case 0:
          g_SoundSystem.EmitSoundDyn(m_pPlayer.edict(), CHAN_WEAPON, "weapons/knife1.wav", 1.0f, ATTN_NORM, 0, PITCH_NORM);
          break;
        case 1:
          g_SoundSystem.EmitSoundDyn(m_pPlayer.edict(), CHAN_WEAPON, "weapons/knife2.wav", 1.0f, ATTN_NORM, 0, PITCH_NORM);
          break;
        case 2:
          g_SoundSystem.EmitSoundDyn(m_pPlayer.edict(), CHAN_WEAPON, "weapons/knife3.wav", 1.0f, ATTN_NORM, 0, PITCH_NORM);
          break;
        }
        // Player "shoot" animation
        m_pPlayer.SetAnimation(PLAYER_ATTACK1);
      }
    }
    else
    {
      // Hit
      fDidHit = true;

      // Hit
      CBaseEntity@ pEntity = g_EntityFuncs.Instance(tr.pHit);

      switch (((m_iSwing++) % 2) + 1)
      {
      case 0: self.SendWeaponAnim(ATTACK1); break;
      case 1: self.SendWeaponAnim(ATTACK2HIT); break;
      case 2: self.SendWeaponAnim(ATTACK3HIT); break;
      }

      // Player "shoot" animation
      m_pPlayer.SetAnimation(PLAYER_ATTACK1);

      // AdamR: Custom damage option
      float flDamage = g_EngineFuncs.CVarGetFloat("sk_plr_crowbar");
      if (self.m_flCustomDmg > 0.0f)
        flDamage = self.m_flCustomDmg;
      // AdamR: End

      int bitsDamageType = DMG_CLUB;

      if (g_KnifeAllowBackstab.GetBool())
      {
        Vector forward, right;
        g_EngineFuncs.AngleVectors(pEntity.pev.angles, void, right, void); // targetRightDirection
        g_EngineFuncs.AngleVectors(m_pPlayer.pev.v_angle, forward, void, void); // ownerForwardDirection

        // isBehindTarget
        if (CrossProduct(right, forward).z > 0.0f)
        {
          flDamage *= 3.0f; // g_EngineFuncs.CVarGetFloat("sk_monster_head");
          bitsDamageType |= DMG_NEVERGIB;
        }
      }

      g_WeaponFuncs.ClearMultiDamage();
      if (self.m_flNextPrimaryAttack + 1.0f < g_Engine.time)
      {
        // First swing does full damage
        pEntity.TraceAttack(m_pPlayer.pev, flDamage, g_Engine.v_forward, tr, bitsDamageType);
      }
      else
      {
        // Subsequent swings do 50% (Changed -Sniper) (Half)
        pEntity.TraceAttack(m_pPlayer.pev, flDamage * 0.5f, g_Engine.v_forward, tr, bitsDamageType);
      }
      g_WeaponFuncs.ApplyMultiDamage(m_pPlayer.pev, m_pPlayer.pev);

      // Play thwack, smack, or dong sound
      float flVol = 1.0f;
      bool fHitWorld = true;

      self.m_flNextPrimaryAttack = self.m_flNextTertiaryAttack = g_Engine.time + 0.25f;

      if (pEntity !is null)
      {
        if (pEntity.Classify() != CLASS_NONE && pEntity.Classify() != CLASS_MACHINE && pEntity.BloodColor() != DONT_BLEED)
        {
          // aone
          if (pEntity.IsPlayer()) // Lets pull them
            pEntity.pev.velocity = pEntity.pev.velocity + ((pev.origin - pEntity.pev.origin).Normalize() * 120.0f);
          // end aone

          // Play thwack or smack sound
          switch (Math.RandomLong(0, 1))
          {
          case 0:
            g_SoundSystem.EmitSoundDyn(m_pPlayer.edict(), CHAN_ITEM, "weapons/knife_hit_flesh1.wav", 1.0f, ATTN_NORM, 0, PITCH_NORM);
            break;
          case 1:
            g_SoundSystem.EmitSoundDyn(m_pPlayer.edict(), CHAN_ITEM, "weapons/knife_hit_flesh2.wav", 1.0f, ATTN_NORM, 0, PITCH_NORM);
            break;
          }

          m_pPlayer.m_iWeaponVolume = 128;

          if (!pEntity.IsAlive())
            return true;
          else
            flVol = 0.1f;

          fHitWorld = false;
        }
      }

      // Play texture hit sound
      // UNDONE: Calculate the correct point of intersection when we hit with the hull instead of the line
      if (fHitWorld)
      {
        g_SoundSystem.PlayHitSound(tr, vecSrc, vecSrc + ((vecEnd - vecSrc) * 2.0f), BULLET_PLAYER_CROWBAR);

        // Also play crowbar strike
        switch (Math.RandomLong(0, 1))
        {
        case 0:
          g_SoundSystem.EmitSoundDyn(m_pPlayer.edict(), CHAN_ITEM, "weapons/knife_hit_wall1.wav", 1.0f, ATTN_NORM, 0, 98 + Math.RandomLong(0, 3));
          break;
        case 1:
          g_SoundSystem.EmitSoundDyn(m_pPlayer.edict(), CHAN_ITEM, "weapons/knife_hit_wall2.wav", 1.0f, ATTN_NORM, 0, 98 + Math.RandomLong(0, 3));
          break;
        }
      }

      // Delay the decal a bit
      m_trHit = tr;
      SetThink(ThinkFunction(Smack));
      pev.nextthink = g_Engine.time + 0.2f;

      m_pPlayer.m_iWeaponVolume = int(flVol * 512);
    }
    return fDidHit;
  }

  void SwingAgain()
  {
    Swing(false);
  }

  void Smack()
  {
    g_WeaponFuncs.DecalGunshot(m_trHit, BULLET_PLAYER_CROWBAR);
  }

  // THROW LOGIC STARTS HERE!!!
  private void Throw()
  {
    Math.MakeVectors(m_pPlayer.pev.v_angle);
    CBaseEntity@ pOwner = self.m_hPlayer.GetEntity();
    Vector vecSrc = m_pPlayer.GetGunPosition() + (g_Engine.v_right * 8.0f) + (g_Engine.v_up * -8.0f);

    // This will be null when dropweapons is disabled
    if (m_pPlayer.DropItem(GetName()) is null)
      return;

    SetThink(ThinkFunction(DummyThink));
    pev.nextthink = g_Engine.time + 0.15f;
    SetTouch(TouchFunction(ThrowTouch));

    g_EntityFuncs.SetOrigin(self, vecSrc);
    pev.velocity = (g_Engine.v_forward * 1200.0f) + (g_Engine.v_up * 2.53f);
    pev.angles = Math.VecToAngles(pev.velocity.Normalize());
    pev.angles.z -= 90.0f;
    pev.avelocity = Vector(-800.0f, 0.0f, 0.0f);
    pev.movetype = MOVETYPE_BOUNCE;
    pev.solid = SOLID_BBOX;
    pev.effects &= ~EF_NODRAW;
    pev.friction = 0.3f;
    @pev.owner = pOwner.edict();
    pev.spawnflags |= SF_DODAMAGE;
  }

  private void ThrowThink()
  {
    pev.nextthink = g_Engine.time + 0.1f;

    if ((pev.flags & FL_ONGROUND) != 0)
    {
      Math.MakeVectors(pev.angles);
      pev.angles.y = Math.VecToAngles(g_Engine.v_forward).y;

      // Lie flat
      pev.angles.x = 0.0f;
      pev.angles.z = 0.0f;

      // This is equivalent to
      // SetThink( &CBasePlayerItem::FallThink );
      // Why? No idea... but it seems that the same applies for Touch
      SetThink(null);
    }
  }

  private void ThrowTouch(CBaseEntity@ pOther)
  {
    if (pOther.pev.ClassNameIs(pev.classname))
      return;

    // Don't set Touch to DefaultTouch because later
    // when the surface is a lift we will not clank on bounce
    if (pev.velocity.Length() < 10.0f)
      self.DefaultTouch(pOther); // This do the weapon drop sound

    if (pOther.edict() is pev.owner)
      return;

    // Add a bit of static friction
    pev.velocity = pev.velocity * 0.5f;
    pev.avelocity = pev.avelocity * 0.5f;
    pev.angles.z = 0.0f;

    if ((pev.spawnflags & SF_DODAMAGE) != 0)
    {
      pev.angles.z = 320.0f;
      pev.spawnflags &= ~SF_DODAMAGE;

      TraceResult tr = g_Utility.GetGlobalTrace();
      if (pev.owner !is null)
      {
        // AdamR: Custom damage option
        float flDamage = g_EngineFuncs.CVarGetFloat("sk_plr_crowbar");
        if (self.m_flCustomDmg > 0.0f)
          flDamage = self.m_flCustomDmg;
        // AdamR: End

        g_WeaponFuncs.ClearMultiDamage();
        pOther.TraceAttack(pev.owner.vars, flDamage * 2.0f, g_Engine.v_forward, tr, DMG_CLUB);
        g_WeaponFuncs.ApplyMultiDamage(pev, pev.owner.vars);
      }

      if (pOther.IsBSPModel())
      {
        g_Utility.Sparks(tr.vecEndPos);
        g_SoundSystem.EmitSoundDyn(self.edict(), CHAN_VOICE, "debris/metal2.wav", 1.0f, ATTN_NORM, 0, 95 + Math.RandomLong(0, 29));
      }
      else
      {
        switch (Math.RandomLong(0, 1))
        {
        case 0:
          g_SoundSystem.EmitSoundDyn(self.edict(), CHAN_ITEM, "weapons/knife_hit_flesh1.wav", 1.0f, ATTN_NORM, 0, PITCH_NORM);
          break;
        case 1:
          g_SoundSystem.EmitSoundDyn(self.edict(), CHAN_ITEM, "weapons/knife_hit_flesh2.wav", 1.0f, ATTN_NORM, 0, PITCH_NORM);
          break;
        }
      }

      g_Utility.TraceLine(pev.origin, pev.origin - Vector(0.0f, 0.0f, 5.0f), ignore_monsters, self.edict(), tr);
      if (pOther.pev.ClassNameIs("worldspawn") && tr.flFraction >= 1.0f)
      {
        SetThink(ThinkFunction(UnstuckThrow));
        pev.nextthink = g_Engine.time + 0.3f;
        SetTouch(TouchFunction(DummyTouch));

        // If what we hit is static architecture, can stay around for a while.
        pev.movedir = pev.velocity.Normalize();
        g_EntityFuncs.SetOrigin(self, pev.origin + (pev.movedir * -5.0f));

        pev.velocity = g_vecZero;
        pev.avelocity = g_vecZero;
        pev.angles = Math.VecToAngles(pev.movedir);
        pev.angles.z -= 90.0f;
        pev.movetype = MOVETYPE_FLY;
      }
      else
      {
        SetThink(ThinkFunction(ThrowThink));
        pev.nextthink = g_Engine.time + 0.1f;
      }
      return;
    }

    if (pOther.IsBSPModel())
      g_SoundSystem.EmitSoundDyn(self.edict(), CHAN_VOICE, "debris/metal2.wav", 1.0f, ATTN_NORM, 0, 95 + Math.RandomLong(0, 29));
  }

  private void UnstuckThrow()
  {
    SetThink(ThinkFunction(ThrowThink));
    pev.nextthink = g_Engine.time + 0.1f;
    SetTouch(TouchFunction(ThrowTouch));

    pev.velocity = pev.movedir * -64.0f;
    pev.avelocity = Vector(200.0f, 0.0f, 0.0f);
    pev.movetype = MOVETYPE_BOUNCE;
  }

  // Guess why these exists? :D
  private void DummyThink() { }

  private void DummyTouch(CBaseEntity@ pOther) { }
  // THROW LOGIC ENDS HERE!!!
}

string GetName()
{
  return "weapon_ofknife";
}

void Register()
{
  if (!g_CustomEntityFuncs.IsCustomEntity(GetName()))
  {
    g_CustomEntityFuncs.RegisterCustomEntity("COFKnife::weapon_ofknife", GetName());
    g_ItemRegistry.RegisterWeapon(GetName(), "opfor", "", "", "", "");
  }
}

}
