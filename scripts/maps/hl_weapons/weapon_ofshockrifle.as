/* 
* The Opposing Force version of the shockrifle
*/

namespace OF_SHOCKRIFLE
{

enum shockrifle_e
{
	SHOCKRIFLE_IDLE1 = 0,
	SHOCKRIFLE_FIRE,
	SHOCKRIFLE_DRAW,
	SHOCKRIFLE_HOLSTER,
	SHOCKRIFLE_IDLE3
};

// Models
string W_MODEL		= "models/w_shock_rifle.mdl";
string V_MODEL		= "models/v_shock.mdl";
string P_MODEL		= "models/p_shock.mdl";
// Sprites
string SPR_DIR		= "hl_weapons/";
string BEAM_SPR		= "sprites/lgtning.spr";
// Sounds
array<string> Sounds = { 
		"weapons/shock_fire.wav",
		"weapons/shock_draw.wav",
		"weapons/shock_recharge.wav",
		"weapons/shock_discharge.wav"
};
// Weapon information
int MAX_CARRY		= 100; //10; Swap values if you want the default OF values
int MAX_CLIP		= WEAPON_NOCLIP;
int DEFAULT_GIVE	= MAX_CARRY;
int WEIGHT		= 15;
int FLAGS		= ITEM_FLAG_NOAUTORELOAD | ITEM_FLAG_NOAUTOSWITCHEMPTY;
uint DAMAGE		= uint(g_EngineFuncs.CVarGetFloat("sk_plr_shockrifle"));
uint SLOT		= 6;
uint POSITION		= 3;
string AMMO_TYPE 	= "shock charges";

class weapon_ofshockrifle : ScriptBasePlayerWeaponEntity
{
	private CBasePlayer@ m_pPlayer
	{
		get const	{ return cast<CBasePlayer@>( self.m_hPlayer.GetEntity() ); }
		set		{ self.m_hPlayer = EHandle( @value ); }
	}
	private array<CBeam@> m_pBeam( 3 );
	private float m_flRechargeTime;

	float WeaponTimeBase()
	{
		return g_Engine.time;
	}

	void CreateChargeEffect()
	{
		if( IsMultiplayer )
			return;

		for( uint i = 0; i < m_pBeam.length(); i++ )
		{
			if( m_pBeam[i] is null )
				@m_pBeam[i] = g_EntityFuncs.CreateBeam( BEAM_SPR, 16 );

			m_pBeam[i].EntsInit( m_pPlayer.entindex(), m_pPlayer.entindex() );
			m_pBeam[i].SetStartAttachment( 1 );
			m_pBeam[i].SetEndAttachment( 2+i );
			m_pBeam[i].SetNoise( 75 );
			m_pBeam[i].pev.scale = 10.0;
			m_pBeam[i].SetColor( 0, 253, 253 );
			m_pBeam[i].SetScrollRate( 30 );
			m_pBeam[i].SetBrightness( 190 );
		}
		SetThink( ThinkFunction( ClearBeams ) );
		self.pev.nextthink = WeaponTimeBase() + 0.08;
	}

	void ClearBeams()
	{
		if( IsMultiplayer )
			return;

		for( uint i = 0; i < m_pBeam.length(); i++ )
		{
			if( m_pBeam[i] !is null )
			{
				g_EntityFuncs.Remove( m_pBeam[i] );
				@m_pBeam[i] = @null;
			}
		}
		SetThink( null );
	}

	void Spawn()
	{
		Precache();
		g_EntityFuncs.SetModel( self, self.GetW_Model( W_MODEL ) );
		self.m_iDefaultAmmo = DEFAULT_GIVE;
		self.FallInit();

		self.pev.sequence = 0;
		self.pev.animtime = g_Engine.time;
		self.pev.framerate = 1;
	}

	void Precache()
	{
		self.PrecacheCustomModels();
		g_Game.PrecacheModel( V_MODEL );
		g_Game.PrecacheModel( W_MODEL );
		g_Game.PrecacheModel( P_MODEL );
		g_Game.PrecacheModel( BEAM_SPR );

		g_Game.PrecacheOther( "shock_beam" );

		for( uint i = 0; i < Sounds.length(); i++ )
		{
			g_SoundSystem.PrecacheSound( Sounds[i] );
			g_Game.PrecacheGeneric( "sound/" + Sounds[i] );
		}

		g_Game.PrecacheGeneric( "sprites/" + SPR_DIR + self.pev.classname + ".txt" );
	}

	bool GetItemInfo( ItemInfo& out info )
	{
		info.iMaxAmmo1	= MAX_CARRY;
		info.iAmmo1Drop	= MAX_CLIP;
		info.iMaxAmmo2	= -1;
		info.iAmmo2Drop	= -1;
		info.iMaxClip	= MAX_CLIP;
		info.iSlot	= SLOT;
		info.iPosition	= POSITION;
		info.iId	= g_ItemRegistry.GetIdForName( self.pev.classname );
		info.iFlags	= FLAGS;
		info.iWeight	= WEIGHT;

		return true;
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

	bool Deploy()
	{
		bool bResult = self.DefaultDeploy( self.GetV_Model( V_MODEL ), self.GetP_Model( P_MODEL ), SHOCKRIFLE_DRAW, "bow" );
		m_flRechargeTime = WeaponTimeBase() + (IsMultiplayer ? 0.25 : 0.5);
		self.m_flTimeWeaponIdle = WeaponTimeBase() + 1.0;
		return bResult;
	}

	bool CanDeploy()
	{
		return true;
	}

	void Holster( int skiplocal = 0 )
	{
		if( m_pPlayer.m_rgAmmo( self.m_iPrimaryAmmoType ) <= 0 )
			m_pPlayer.m_rgAmmo( self.m_iPrimaryAmmoType, 1 );

		ClearBeams();

		BaseClass.Holster( skiplocal );
	}

	void PrimaryAttack()
	{
		if( m_pPlayer.pev.waterlevel == WATERLEVEL_HEAD )
		{
			g_SoundSystem.EmitSoundDyn( m_pPlayer.edict(), CHAN_ITEM, Sounds[3], Math.RandomFloat(0.8,0.9), ATTN_NORM, 0, PITCH_NORM );
			g_WeaponFuncs.RadiusDamage( m_pPlayer.pev.origin, m_pPlayer.pev, m_pPlayer.pev, 
				m_pPlayer.m_rgAmmo( self.m_iPrimaryAmmoType ) * 100.0, m_pPlayer.m_rgAmmo( self.m_iPrimaryAmmoType ) * 150.0, CLASS_NONE, DMG_ALWAYSGIB | DMG_BLAST );
			m_pPlayer.m_rgAmmo( self.m_iPrimaryAmmoType, 0 );
			return;
		}

		if( m_pPlayer.m_rgAmmo( self.m_iPrimaryAmmoType ) <= 0 )
			return;

		m_pPlayer.m_rgAmmo( self.m_iPrimaryAmmoType, m_pPlayer.m_rgAmmo( self.m_iPrimaryAmmoType ) - 1 );

		Vector vecSrc	 = m_pPlayer.GetGunPosition() + g_Engine.v_forward * 16 + g_Engine.v_right * 9 + g_Engine.v_up * -7;
		Vector vecAngles = m_pPlayer.pev.v_angle + m_pPlayer.pev.punchangle; vecAngles.x = -vecAngles.x;

		CBaseEntity@ pBeam = g_EntityFuncs.Create( "shock_beam", vecSrc, vecAngles , false, m_pPlayer.edict() );
		if( pBeam !is null ) { pBeam.pev.velocity = g_Engine.v_forward * 2000; pBeam.pev.dmg = DAMAGE; }
		g_SoundSystem.EmitSoundDyn( m_pPlayer.edict(), CHAN_WEAPON, Sounds[0], 1, ATTN_NORM, 0, PITCH_NORM );

		CreateChargeEffect();

		m_pPlayer.pev.effects |= EF_MUZZLEFLASH;
		self.pev.effects |= EF_MUZZLEFLASH;

		m_pPlayer.SetAnimation( PLAYER_ATTACK1 );
		self.SendWeaponAnim( SHOCKRIFLE_FIRE );

		m_pPlayer.m_iWeaponVolume = LOUD_GUN_VOLUME;
		m_pPlayer.m_iWeaponFlash = BRIGHT_GUN_FLASH;

		m_flRechargeTime = g_Engine.time + 1.0;

		self.m_flNextPrimaryAttack = WeaponTimeBase() + (IsMultiplayer ? 0.1 : 0.2);
		self.m_flTimeWeaponIdle = WeaponTimeBase() + 0.33;
	}

	void Reload()
	{
		while( m_pPlayer.m_rgAmmo( self.m_iPrimaryAmmoType ) < MAX_CARRY && m_flRechargeTime < g_Engine.time )
		{
			m_pPlayer.m_rgAmmo( self.m_iPrimaryAmmoType, m_pPlayer.m_rgAmmo( self.m_iPrimaryAmmoType ) + 1 );
			g_SoundSystem.EmitSoundDyn( m_pPlayer.edict(), CHAN_WEAPON, Sounds[2], VOL_NORM, ATTN_NORM, 0, PITCH_NORM );
			m_flRechargeTime += (IsMultiplayer ? 0.25 : 0.5);
		}
	}

	void WeaponIdle()
	{
		self.Reload();

		if( self.m_flTimeWeaponIdle > WeaponTimeBase() )
			return;

		float flRand = g_PlayerFuncs.SharedRandomFloat( m_pPlayer.random_seed, 0.0, 1.0 );
		if( flRand <= 0.75 )
		{
			self.SendWeaponAnim( SHOCKRIFLE_IDLE3 );
			self.m_flTimeWeaponIdle = WeaponTimeBase() + (51.0/15.0);
		}
		else
		{
			self.SendWeaponAnim( SHOCKRIFLE_IDLE1 );	
			self.m_flTimeWeaponIdle = WeaponTimeBase() + (101.0/30.0);
		}
	}
}

string GetName()
{
	return "weapon_ofshockrifle";
}

void Register()
{
	if( !g_CustomEntityFuncs.IsCustomEntity( GetName() ) )
	{
		g_CustomEntityFuncs.RegisterCustomEntity( "OF_SHOCKRIFLE::weapon_ofshockrifle", GetName() );
		g_ItemRegistry.RegisterWeapon( GetName(), SPR_DIR, AMMO_TYPE );
	}
}

}

