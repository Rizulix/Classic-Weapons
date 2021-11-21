/* 
* The Opposing Force version of the sniper
*/

namespace OF_SNIPERRIFLE
{

enum sniperrifle_e
{
	SNIPERRIFLE_DRAW = 0,
	SNIPERRIFLE_SLOWIDLE,
	SNIPERRIFLE_FIRE,
	SNIPERRIFLE_FIRELASTROUND,
	SNIPERRIFLE_RELOAD1,
	SNIPERRIFLE_RELOAD2,
	SNIPERRIFLE_RELOAD3,
	SNIPERRIFLE_SLOWIDLE2,
	SNIPERRIFLE_HOLSTER
};

// Models
string W_MODEL		= "models/hlclassic/w_m40a1.mdl";
string V_MODEL		= "models/hlclassic/v_m40a1.mdl";
string P_MODEL		= "models/hlclassic/p_m40a1.mdl";
string A_MODEL		= "models/hlclassic/w_m40a1clip.mdl";
// Sprites
string SPR_DIR		= "hl_weapons/";
// Sounds
array<string> Sounds = { 
		"hlclassic/weapons/sniper_fire.wav",
		"weapons/sniper_zoom.wav",
		"hlclassic/weapons/sniper_bolt1.wav",
		"hlclassic/weapons/sniper_bolt2.wav",
		"hlclassic/weapons/sniper_reload_first_seq.wav",
		"hlclassic/weapons/sniper_reload_second_seq.wav",
		//"hlclassic/weapons/sniper_reload3.wav", //unused
		"hlclassic/weapons/357_cock1.wav"
};
string AMMO_PICKUP	= "hlclassic/items/9mmclip1.wav";
// Weapon information
int MAX_CARRY		= 15;
int MAX_CLIP		= 5;
int DEFAULT_GIVE	= MAX_CLIP;
int WEIGHT		= 10;
int FLAGS		= 0;
uint DAMAGE		= uint(g_EngineFuncs.CVarGetFloat("sk_plr_762_bullet"));
uint SLOT		= 5;
uint POSITION		= 5;
string AMMO_TYPE 	= "m40a1";

class weapon_ofsniperrifle : ScriptBasePlayerWeaponEntity
{
	private CBasePlayer@ m_pPlayer
	{
		get const	{ return cast<CBasePlayer@>( self.m_hPlayer.GetEntity() ); }
		set		{ self.m_hPlayer = EHandle( @value ); }
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
		g_Game.PrecacheModel( A_MODEL );

		g_Game.PrecacheOther( GetAmmoName() );

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
		bool bResult = self.DefaultDeploy( self.GetV_Model( V_MODEL ), self.GetP_Model( P_MODEL ), SNIPERRIFLE_DRAW, "sniper" );
		self.m_flTimeWeaponIdle = WeaponTimeBase() + 1.0;
		return bResult;
	}

	bool PlayEmptySound()
	{
		if( self.m_bPlayEmptySound )
		{
			self.m_bPlayEmptySound = false;
			g_SoundSystem.EmitSoundDyn( m_pPlayer.edict(), CHAN_WEAPON, Sounds[6], 0.8, ATTN_NORM, 0, PITCH_NORM );
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
			if( m_pPlayer.pev.waterlevel == WATERLEVEL_HEAD )
				self.m_flNextPrimaryAttack = WeaponTimeBase() + 1.0;
			return;
		}

		--self.m_iClip;

		Vector vecSrc	 = m_pPlayer.GetGunPosition();
		Vector vecAiming = m_pPlayer.GetAutoaimVector( AUTOAIM_2DEGREES );

		m_pPlayer.FireBullets( 1, vecSrc, vecAiming, g_vecZero, 8192, BULLET_PLAYER_SNIPER, 0 );
		g_SoundSystem.EmitSoundDyn( m_pPlayer.edict(), CHAN_WEAPON, Sounds[0], Math.RandomFloat(0.9,1.0), ATTN_NORM, 0, 98 + Math.RandomLong(0,3) );

		if( self.m_iClip <= 0 && m_pPlayer.m_rgAmmo( self.m_iPrimaryAmmoType ) <= 0 )
			m_pPlayer.SetSuitUpdate( "!HEV_AMO0", false, 0 );

		m_pPlayer.pev.effects |= EF_MUZZLEFLASH;
		self.pev.effects |= EF_MUZZLEFLASH;

		m_pPlayer.SetAnimation( PLAYER_ATTACK1 );
		self.SendWeaponAnim( self.m_iClip > 0 ? SNIPERRIFLE_FIRE : SNIPERRIFLE_FIRELASTROUND );

		m_pPlayer.m_iWeaponVolume = QUIET_GUN_VOLUME;

		m_pPlayer.pev.punchangle.x = -2.0;

		self.m_flTimeWeaponIdle = self.m_flNextPrimaryAttack = WeaponTimeBase() + 2.0;

		TraceResult tr;
		float x, y;

		g_Utility.GetCircularGaussianSpread( x, y );

		Vector vecDir = vecAiming + x * g_vecZero.x * g_Engine.v_right + y * g_vecZero.y * g_Engine.v_up;
		Vector vecEnd = vecSrc + vecDir * 8192;

		g_Utility.TraceLine( vecSrc, vecEnd, dont_ignore_monsters, m_pPlayer.edict(), tr );

		if( tr.flFraction < 1.0 )
		{
			if( tr.pHit !is null )
			{
				CBaseEntity@ pHit = g_EntityFuncs.Instance( tr.pHit );

				g_SoundSystem.PlayHitSound( tr, vecSrc, vecEnd, BULLET_PLAYER_SNIPER );
				g_Utility.BubbleTrail( vecSrc, tr.vecEndPos, int((8192 * tr.flFraction)/64.0) );

				if( pHit is null || pHit.IsBSPModel() )
					g_WeaponFuncs.DecalGunshot( tr, BULLET_PLAYER_SNIPER );
			}
		}
	}

	void SecondaryAttack()
	{
		ToggleZoom( 18 );
		g_SoundSystem.EmitSoundDyn( m_pPlayer.edict(), CHAN_ITEM, Sounds[1], VOL_NORM, ATTN_NORM, 0, PITCH_NORM );
		self.m_flNextSecondaryAttack = WeaponTimeBase() + 0.5;
	}

	void FinishAnim()
	{
		self.SendWeaponAnim( SNIPERRIFLE_RELOAD2 );
		SetThink( null );
	}

	void Reload()
	{
		if( self.m_iClip == MAX_CLIP || m_pPlayer.m_rgAmmo( self.m_iPrimaryAmmoType ) <= 0 )
			return;

		ToggleZoom( 0 );
		if( self.m_iClip <= 0 )
		{
			SetThink( ThinkFunction( this.FinishAnim ) );
			self.pev.nextthink = WeaponTimeBase() + 2.324;
		}
		self.DefaultReload( MAX_CLIP, self.m_iClip > 0 ? SNIPERRIFLE_RELOAD3 : SNIPERRIFLE_RELOAD1, 2.324 );
		self.m_flNextPrimaryAttack = WeaponTimeBase() + (self.m_iClip > 0 ? 2.324 : 4.102);
		self.m_flTimeWeaponIdle = WeaponTimeBase() + 4.102;

		BaseClass.Reload();
	}

	void WeaponIdle()
	{
		self.ResetEmptySound();
		m_pPlayer.GetAutoaimVector( AUTOAIM_2DEGREES );

		if( self.m_flTimeWeaponIdle > WeaponTimeBase() )
			return;

		self.SendWeaponAnim( self.m_iClip > 0 ? SNIPERRIFLE_SLOWIDLE : SNIPERRIFLE_SLOWIDLE2 );
		self.m_flTimeWeaponIdle = WeaponTimeBase() + 4.348;
	}
}

class ammo_of762 : ScriptBasePlayerAmmoEntity
{
	void Spawn()
	{
		Precache();
		g_EntityFuncs.SetModel( self, A_MODEL );
		BaseClass.Spawn();
	}

	void Precache()
	{
		g_Game.PrecacheModel( A_MODEL );
		g_SoundSystem.PrecacheSound( AMMO_PICKUP );
	}

	bool AddAmmo( CBaseEntity@ pOther )
	{
		if( pOther.GiveAmmo( MAX_CLIP, AMMO_TYPE, MAX_CARRY ) != -1 )
		{
			g_SoundSystem.EmitSoundDyn( self.edict(), CHAN_ITEM, AMMO_PICKUP, VOL_NORM, ATTN_NORM, 0, PITCH_NORM );
			return true;
		}
		return false;
	}
}

string GetAmmoName()
{
	return "ammo_of762";
}

string GetName()
{
	return "weapon_ofsniperrifle";
}

void Register()
{
	if( !g_CustomEntityFuncs.IsCustomEntity( GetAmmoName() ) )
		g_CustomEntityFuncs.RegisterCustomEntity( "OF_SNIPERRIFLE::ammo_of762", GetAmmoName() );

	if( !g_CustomEntityFuncs.IsCustomEntity( GetName() ) )
	{
		g_CustomEntityFuncs.RegisterCustomEntity( "OF_SNIPERRIFLE::weapon_ofsniperrifle", GetName() );
		g_ItemRegistry.RegisterWeapon( GetName(), SPR_DIR, AMMO_TYPE, "", GetAmmoName() );
	}
}

}

