/* 
* The original Half-Life version of the shockrifle
*/

const int SHOCKRIFLE_DEFAULT_GIVE	= 100;
const int SHOCKRIFLE_MAX_CARRY		= 100;
const int SHOCKRIFLE_WEIGHT		= 15;

enum shockrifle_e
{
	SHOCK_IDLE1 = 0,
	SHOCK_FIRE,
	SHOCK_DRAW,
	SHOCK_HOLSTER,
	SHOCK_IDLE3
};

class weapon_ofshockrifle : ScriptBasePlayerWeaponEntity
{
	private CBasePlayer@ m_pPlayer
	{
		get const	{ return cast<CBasePlayer@>( self.m_hPlayer.GetEntity() ); }
		set		{ self.m_hPlayer = EHandle( @value ); }
	}
	private array <CBeam@> m_pBeam( 3 );

	float m_flRechargeTime;

	void Spawn()
	{
		Precache();
		g_EntityFuncs.SetModel( self, self.GetW_Model( "models/w_shock_rifle.mdl" ) );

		self.m_iDefaultAmmo = SHOCKRIFLE_DEFAULT_GIVE;

		self.FallInit();// get ready to fall
	}

	void Precache()
	{
		self.PrecacheCustomModels();
		g_Game.PrecacheModel( "models/v_shock.mdl" );
		g_Game.PrecacheModel( "models/w_shock_rifle.mdl" );
		g_Game.PrecacheModel( "models/p_shock.mdl" );

		g_SoundSystem.PrecacheSound( "weapons/shock_discharge.wav" );
		g_SoundSystem.PrecacheSound( "weapons/shock_draw.wav" );
		g_SoundSystem.PrecacheSound( "weapons/shock_fire.wav" );
		g_SoundSystem.PrecacheSound( "weapons/shock_impact.wav" );
		g_SoundSystem.PrecacheSound( "weapons/shock_recharge.wav" );

		g_Game.PrecacheModel( "sprites/lgtning.spr" );
		g_Game.PrecacheModel( "sprites/flare3.spr" );

		g_Game.PrecacheOther( "shock_beam" );

		g_Game.PrecacheGeneric( "sprites/hl_weapons/weapon_ofshockrifle.txt" );
	}

	bool AddToPlayer( CBasePlayer@ pPlayer )
	{
		if( !BaseClass.AddToPlayer( pPlayer ) )
			return false;

		NetworkMessage message( MSG_ONE, NetworkMessages::WeapPickup, pPlayer.edict() );
			message.WriteLong( g_ItemRegistry.GetIdForName( self.pev.classname ) );
		message.End();

		return true;
	}

	bool GetItemInfo( ItemInfo& out info )
	{
		info.iMaxAmmo1 	= SHOCKRIFLE_MAX_CARRY;
		info.iAmmo1Drop	= -1;
		info.iMaxAmmo2 	= -1;
		info.iAmmo2Drop	= -1;
		info.iMaxClip 	= WEAPON_NOCLIP;
		info.iSlot	= 6;
		info.iPosition 	= 3;
		info.iId	= g_ItemRegistry.GetIdForName( self.pev.classname );
		info.iFlags 	= ITEM_FLAG_NOAUTOSWITCHEMPTY | ITEM_FLAG_NOAUTORELOAD;
		info.iWeight 	= SHOCKRIFLE_WEIGHT;

		return true;
	}

	bool Deploy()
	{
		m_flRechargeTime = g_Engine.time + 0.667;

		return self.DefaultDeploy( self.GetV_Model( "models/v_shock.mdl" ), self.GetP_Model( "models/p_shock.mdl" ), SHOCK_DRAW, "bow" );
	}

	void Holster( int skiplocal )
	{
		ClearBeams();

		if( m_pPlayer.m_rgAmmo( self.m_iPrimaryAmmoType ) <= 0 )
			m_pPlayer.m_rgAmmo( self.m_iPrimaryAmmoType, 1 );

		BaseClass.Holster( skiplocal );
	}

	float WeaponTimeBase()
	{
		return g_Engine.time;
	}

	void PrimaryAttack()
	{
		if( m_pPlayer.m_rgAmmo( self.m_iPrimaryAmmoType ) <= 0 )
			return;

		if( m_pPlayer.pev.waterlevel == WATERLEVEL_HEAD )
		{
			int attenuation = 150 * m_pPlayer.m_rgAmmo( self.m_iPrimaryAmmoType );
			int dmg = 100 * m_pPlayer.m_rgAmmo( self.m_iPrimaryAmmoType );
			g_SoundSystem.EmitSound( m_pPlayer.edict(), CHAN_WEAPON, "weapons/shock_discharge.wav", VOL_NORM, ATTN_NORM );
			m_pPlayer.m_rgAmmo( self.m_iPrimaryAmmoType, 0 );
			g_WeaponFuncs.RadiusDamage( m_pPlayer.pev.origin, m_pPlayer.pev, m_pPlayer.pev, dmg, attenuation, CLASS_NONE, DMG_SHOCK | DMG_ALWAYSGIB );

			return;
		}

		self.SendWeaponAnim( SHOCK_FIRE );

		// Play fire sound.
		g_SoundSystem.EmitSoundDyn( m_pPlayer.edict(), CHAN_WEAPON, "weapons/shock_fire.wav", 1, ATTN_NORM, 0, 100 );

		CreateChargeEffect();

		Vector anglesAim = m_pPlayer.pev.v_angle + m_pPlayer.pev.punchangle;
		anglesAim.x = -anglesAim.x;
		Math.MakeVectors( m_pPlayer.pev.v_angle );

		Vector vecSrc = m_pPlayer.GetGunPosition() + g_Engine.v_forward * 8 + g_Engine.v_right * 12 + g_Engine.v_up * -12;

		CBaseEntity@ pShock = g_EntityFuncs.Create( "shock_beam", vecSrc, anglesAim , false, m_pPlayer.edict() );
		if( pShock !is null )
			pShock.pev.velocity	= g_Engine.v_forward * 2000;

		m_flRechargeTime = g_Engine.time + 1;

		m_pPlayer.m_rgAmmo( self.m_iPrimaryAmmoType, m_pPlayer.m_rgAmmo( self.m_iPrimaryAmmoType ) - 1 );

		m_pPlayer.m_iWeaponVolume = QUIET_GUN_VOLUME;
		m_pPlayer.m_iWeaponFlash = DIM_GUN_FLASH;

		// player "shoot" animation
		m_pPlayer.SetAnimation( PLAYER_ATTACK1 );
		self.m_flNextPrimaryAttack = WeaponTimeBase() + 0.2;

		SetThink( ThinkFunction( ClearBeams ) );
		self.pev.nextthink = WeaponTimeBase() + 0.08;

		self.m_flTimeWeaponIdle = WeaponTimeBase() + 0.33;
	}

	void Reload()
	{
		if( m_pPlayer.m_rgAmmo( self.m_iPrimaryAmmoType ) >= SHOCKRIFLE_MAX_CARRY )
			return;

		while( m_pPlayer.m_rgAmmo( self.m_iPrimaryAmmoType ) < SHOCKRIFLE_MAX_CARRY && m_flRechargeTime < g_Engine.time )
		{
			g_SoundSystem.EmitSound( m_pPlayer.edict(), CHAN_ITEM, "weapons/shock_recharge.wav", 1, ATTN_NORM );

			m_pPlayer.m_rgAmmo( self.m_iPrimaryAmmoType, m_pPlayer.m_rgAmmo( self.m_iPrimaryAmmoType ) + 1 );

			m_flRechargeTime += 0.667;
		}
	}

	void WeaponIdle()
	{
		self.Reload();

		if( self.m_flTimeWeaponIdle > WeaponTimeBase() )
			return;

		float flRand = g_PlayerFuncs.SharedRandomFloat( m_pPlayer.random_seed, 0, 1 );
		if( flRand <= 0.8 )
		{
			self.SendWeaponAnim( SHOCK_IDLE3 );
		} else {
			self.SendWeaponAnim( SHOCK_IDLE1 );	
		}
		self.m_flTimeWeaponIdle = WeaponTimeBase() + 3.3f;
	}

	void CreateChargeEffect()
	{
		int iBeam = 0;

		for( int i = 2; i < 5; i++ )
		{
			if( m_pBeam[iBeam] is null )
				@m_pBeam[iBeam] = g_EntityFuncs.CreateBeam( "sprites/lgtning.spr", 16 );
			m_pBeam[iBeam].EntsInit( m_pPlayer.entindex(), m_pPlayer.entindex() );
			m_pBeam[iBeam].SetStartAttachment( 1 );
			m_pBeam[iBeam].SetEndAttachment( i );
			m_pBeam[iBeam].SetNoise( 75 );
			m_pBeam[iBeam].pev.scale = 10;
			m_pBeam[iBeam].SetColor( 0, 253, 253 );
			m_pBeam[iBeam].SetScrollRate( 30 );
			m_pBeam[iBeam].SetBrightness( 190 );
			iBeam++;
		}
	}

	void ClearBeams()
	{
		for( int i = 0; i < 3; i++ )
		{
			if( m_pBeam[i] !is null )
			{
				g_EntityFuncs.Remove( m_pBeam[i] );
				@m_pBeam[i] = @null;
			}
		}
		SetThink( null );
	}
}

string GetOFShockName()
{
	return "weapon_ofshockrifle";
}

void RegisterOFShock()
{
	g_CustomEntityFuncs.RegisterCustomEntity( "weapon_ofshockrifle", GetOFShockName() );
	g_ItemRegistry.RegisterWeapon( GetOFShockName(), "hl_weapons", "shock charges" );
}
