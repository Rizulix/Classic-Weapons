/* 
* The Half-Life version of the python
*/

namespace HL_PYTHON
{

enum python_e
{
	PYTHON_IDLE1 = 0,
	PYTHON_FIDGET,
	PYTHON_FIRE1,
	PYTHON_RELOAD,
	PYTHON_HOLSTER,
	PYTHON_DRAW,
	PYTHON_IDLE2,
	PYTHON_IDLE3
};

// Models
string W_MODEL		= "models/hlclassic/w_357.mdl";
string V_MODEL		= "models/hlclassic/v_357.mdl";
string P_MODEL		= "models/hlclassic/p_357.mdl";
// Sprites
string SPR_DIR		= "hl_weapons/";
// Sounds
array<string> Sounds = { 
		"hlclassic/weapons/357_shot1.wav",
		"hlclassic/weapons/357_shot2.wav",
		"hlclassic/weapons/357_reload1.wav",
		"hlclassic/weapons/357_cock1.wav"
};
// Weapon information
int MAX_CARRY		= 36;
int MAX_CLIP		= 6;
int DEFAULT_GIVE	= MAX_CLIP;
int WEIGHT		= 15;
int FLAGS		= 0;
uint SLOT		= 1;
uint POSITION		= 6;
string AMMO_TYPE 	= "357";

class weapon_hlpython : ScriptBasePlayerWeaponEntity
{
	private CBasePlayer@ m_pPlayer
	{
		get const	{ return cast<CBasePlayer@>( self.m_hPlayer.GetEntity() ); }
		set		{ self.m_hPlayer = EHandle( @value ); }
	}
	private int GetBodygroup()
	{
		return IsMultiplayer ? 1 : 0;
	}

	float WeaponTimeBase()
	{
		return g_Engine.time;
	}

	void ToggleZoom( int fov )
	{
		if( m_pPlayer.pev.fov != 0 )
			m_pPlayer.pev.fov = m_pPlayer.m_iFOV = 0;
		else if( m_pPlayer.pev.fov != fov )
			m_pPlayer.pev.fov = m_pPlayer.m_iFOV = fov;
	}

	void Spawn()
	{
		Precache();
		g_EntityFuncs.SetModel( self, self.GetW_Model( W_MODEL ) );
		self.m_iDefaultAmmo = DEFAULT_GIVE;
		self.FallInit();
	}

	void Precache()
	{
		self.PrecacheCustomModels();
		g_Game.PrecacheModel( V_MODEL );
		g_Game.PrecacheModel( W_MODEL );
		g_Game.PrecacheModel( P_MODEL );

		g_Game.PrecacheOther( GetAmmoName() );

		for( uint i = 0; i < Sounds.length(); i++ )
			g_SoundSystem.PrecacheSound( Sounds[i] );

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
		if ( !BaseClass.AddToPlayer( pPlayer ) )
			return false;

		NetworkMessage message( MSG_ONE, NetworkMessages::WeapPickup, pPlayer.edict() );
			message.WriteLong( g_ItemRegistry.GetIdForName( self.pev.classname ) );
		message.End();

		return true;
	}

	bool Deploy()
	{
		bool bResult = self.DefaultDeploy( self.GetV_Model( V_MODEL ), self.GetP_Model( P_MODEL ), PYTHON_DRAW, "python", 0, GetBodygroup() );
		self.m_flTimeWeaponIdle = WeaponTimeBase() + 1.0;
		return bResult;
	}

	bool PlayEmptySound()
	{
		if( self.m_bPlayEmptySound )
		{
			self.m_bPlayEmptySound = false;
			g_SoundSystem.EmitSoundDyn( m_pPlayer.edict(), CHAN_WEAPON, Sounds[3], 0.8, ATTN_NORM, 0, PITCH_NORM );
		}

		return false;
	}

	void Holster( int skiplocal = 0 )
	{
		self.m_fInReload = false;
		SetThink( null );
		ToggleZoom( 0 );

		BaseClass.Holster( skiplocal );
	}

	void PrimaryAttack()
	{
		if( self.m_iClip <= 0 || m_pPlayer.pev.waterlevel == WATERLEVEL_HEAD )
		{
			self.PlayEmptySound();
			self.m_flNextPrimaryAttack = WeaponTimeBase() + 0.15;
			return;
		}

		--self.m_iClip;

		Vector vecSrc	 = m_pPlayer.GetGunPosition();
		Vector vecAiming = m_pPlayer.GetAutoaimVector( AUTOAIM_10DEGREES );

		m_pPlayer.FireBullets( 1, vecSrc, vecAiming, VECTOR_CONE_1DEGREES, 8192, BULLET_PLAYER_357, 0 );
		g_SoundSystem.EmitSoundDyn( m_pPlayer.edict(), CHAN_WEAPON, Sounds[Math.RandomLong(0,1)], Math.RandomFloat(0.8,0.9), ATTN_NORM, 0, PITCH_NORM );

		if( self.m_iClip <= 0 && m_pPlayer.m_rgAmmo( self.m_iPrimaryAmmoType ) <= 0 )
			m_pPlayer.SetSuitUpdate( "!HEV_AMO0", false, 0 );

		m_pPlayer.pev.effects |= EF_MUZZLEFLASH;
		self.pev.effects |= EF_MUZZLEFLASH;

		m_pPlayer.SetAnimation( PLAYER_ATTACK1 );
		self.SendWeaponAnim( PYTHON_FIRE1, 0, GetBodygroup() );

		m_pPlayer.m_iWeaponVolume = LOUD_GUN_VOLUME;
		m_pPlayer.m_iWeaponFlash = BRIGHT_GUN_FLASH;

		m_pPlayer.pev.punchangle.x = -10.0;

		self.m_flNextPrimaryAttack = WeaponTimeBase() + 0.75;
		self.m_flTimeWeaponIdle = WeaponTimeBase() + g_PlayerFuncs.SharedRandomFloat( m_pPlayer.random_seed, 10.0, 15.0 );

		TraceResult tr;
		float x, y;

		g_Utility.GetCircularGaussianSpread( x, y );

		Vector vecDir = vecAiming + x * VECTOR_CONE_1DEGREES.x * g_Engine.v_right + y * VECTOR_CONE_1DEGREES.y * g_Engine.v_up;
		Vector vecEnd = vecSrc + vecDir * 8192;

		g_Utility.TraceLine( vecSrc, vecEnd, dont_ignore_monsters, m_pPlayer.edict(), tr );

		if( tr.flFraction < 1.0 )
		{
			if( tr.pHit !is null )
			{
				CBaseEntity@ pHit = g_EntityFuncs.Instance( tr.pHit );

				g_SoundSystem.PlayHitSound( tr, vecSrc, vecEnd, BULLET_PLAYER_357 );
				g_Utility.BubbleTrail( vecSrc, tr.vecEndPos, int((8192 * tr.flFraction)/64.0) );

				if( pHit is null || pHit.IsBSPModel() )
					g_WeaponFuncs.DecalGunshot( tr, BULLET_PLAYER_357 );
			}
		}
	}

	void SecondaryAttack()
	{
		if( !IsMultiplayer )
			return;

		ToggleZoom( 40 );
		self.m_flNextSecondaryAttack = WeaponTimeBase() + 0.5;
	}

	void PlayReloadSound()
	{
		g_SoundSystem.EmitSoundDyn( m_pPlayer.edict(), CHAN_WEAPON, Sounds[2], Math.RandomFloat(0.8,0.9), ATTN_NORM, 0, PITCH_NORM );
		SetThink( null );
	}

	void Reload()
	{
		if( self.m_iClip == MAX_CLIP || m_pPlayer.m_rgAmmo( self.m_iPrimaryAmmoType ) <= 0 )
			return;

		ToggleZoom( 0 );
		SetThink( ThinkFunction( this.PlayReloadSound ) );
		self.pev.nextthink = WeaponTimeBase() + 1.5;
		self.DefaultReload( MAX_CLIP, PYTHON_RELOAD, 2.0, GetBodygroup() );
		self.m_flTimeWeaponIdle = WeaponTimeBase() + 3.0;

		BaseClass.Reload();
	}

	void WeaponIdle()
	{
		self.ResetEmptySound();
		m_pPlayer.GetAutoaimVector( AUTOAIM_5DEGREES );

		if( self.m_flTimeWeaponIdle > WeaponTimeBase() )
			return;

		float flRand = g_PlayerFuncs.SharedRandomFloat( m_pPlayer.random_seed, 0.0, 1.0 );
		if( flRand <= 0.5 )
		{
			self.SendWeaponAnim( PYTHON_IDLE1, 0, GetBodygroup() );
			self.m_flTimeWeaponIdle = WeaponTimeBase() + (70.0/30.0);
		}
		else if( flRand <= 0.7 )
		{
			self.SendWeaponAnim( PYTHON_IDLE2, 0, GetBodygroup() );
			self.m_flTimeWeaponIdle = WeaponTimeBase() + (60.0/30.0);
		}
		else if( flRand <= 0.9 )
		{
			self.SendWeaponAnim( PYTHON_IDLE3, 0, GetBodygroup() );
			self.m_flTimeWeaponIdle = WeaponTimeBase() + (88.0/30.0);
		}
		else
		{
			self.SendWeaponAnim( PYTHON_FIDGET, 0, GetBodygroup() );
			self.m_flTimeWeaponIdle = WeaponTimeBase() + (170.0/30.0);
		}
	}
}

string GetAmmoName()
{
	return "ammo_357";
}

string GetName()
{
	return "weapon_hlpython";
}

void Register()
{
	if( !g_CustomEntityFuncs.IsCustomEntity( GetName() ) )
	{
		g_CustomEntityFuncs.RegisterCustomEntity( "HL_PYTHON::weapon_hlpython", GetName() );
		g_ItemRegistry.RegisterWeapon( GetName(), SPR_DIR, AMMO_TYPE, "", GetAmmoName() );
	}
}

}

