/* 
* The original Half-Life version of the eagle
*/

namespace OF_EAGLE
{

enum eagle_e
{
	EAGLE_IDLE1 = 0,
	EAGLE_IDLE2,
	EAGLE_IDLE3,
	EAGLE_IDLE4,
	EAGLE_IDLE5,
	EAGLE_SHOOT,
	EAGLE_SHOOT_EMPTY,
	EAGLE_RELOAD_NOSHOT,
	EAGLE_RELOAD,
	EAGLE_DRAW,
	EAGLE_HOLSTER
};

// Models
string W_MODEL		= "models/hlclassic/w_desert_eagle.mdl";
string V_MODEL		= "models/hlclassic/v_desert_eagle.mdl";
string P_MODEL		= "models/hlclassic/p_desert_eagle.mdl";
string S_MODEL		= "models/hlclassic/shell.mdl"; /*This cannot be changed with .gmr, must be changed beforehand and in the same function where RegisterClassicWeapons(); is found. Ex: 
void MapInit()
{
	OF_EAGLE::S_MODEL = "models/mycustommodel.mdl";
	RegisterClassicWeapons();
}
*/
// Sprites
string SPR_DIR		= "hl_weapons/";
string LSR_SPR		= "sprites/laserdot.spr";
// Sounds
array<string> Sounds = { 
		"weapons/desert_eagle_fire.wav",
		"weapons/desert_eagle_sight.wav",
		"weapons/desert_eagle_sight2.wav",
		"hlclassic/weapons/desert_eagle_reload.wav",
		"hlclassic/weapons/357_cock1.wav"
};
// Weapon information
int MAX_CARRY		= 36;
int MAX_CLIP		= 7;
int DEFAULT_GIVE	= MAX_CLIP;
int WEIGHT		= 15;
int FLAGS		= 0;
uint SLOT		= 1;
uint POSITION		= 7;
string AMMO_TYPE 	= "357";

class weapon_ofeagle : ScriptBasePlayerWeaponEntity
{
	private CBasePlayer@ m_pPlayer
	{
		get const	{ return cast<CBasePlayer@>( self.m_hPlayer.GetEntity() ); }
		set		{ self.m_hPlayer = EHandle( @value ); }
	}
	private CSprite@ m_pLaser;
	private bool m_bLaserActive = false, m_bSpotVisible = false;
	private int m_iShell;

	float WeaponTimeBase()
	{
		return g_Engine.time;
	}

	void GetDefaultShellInfo( CBasePlayer@ pPlayer, Vector& out ShellVelocity, Vector& out ShellOrigin, float forwardScale, float upScale, float rightScale )
	{
		Vector vecForward, vecRight, vecUp;

		g_EngineFuncs.AngleVectors( pPlayer.pev.v_angle, vecForward, vecRight, vecUp );

		const float fR = Math.RandomFloat( 50.0, 70.0 );
		const float fU = Math.RandomFloat( 100.0, 150.0 );

		for( int i = 0; i < 3; ++i )
		{
			ShellVelocity[i] = pPlayer.pev.velocity[i] + vecRight[i] * fR + vecUp[i] * fU + vecForward[i] * 25;
			ShellOrigin[i]   = pPlayer.pev.origin[i] + pPlayer.pev.view_ofs[i] + vecUp[i] * upScale + vecForward[i] * forwardScale + vecRight[i] * rightScale;
		}
	}

	void CreateLaserSpot()
	{
		if( m_pLaser is null )
			@m_pLaser = g_EntityFuncs.CreateSprite( LSR_SPR, g_vecZero, false );

		m_pLaser.pev.movetype = MOVETYPE_NONE;
		m_pLaser.pev.solid = SOLID_NOT;
		m_pLaser.pev.rendermode = kRenderGlow;
		m_pLaser.pev.renderfx = kRenderFxNoDissipation;
		m_pLaser.pev.renderamt = 255;
		m_pLaser.pev.scale = 0.5;
	}

	void RedrawLaser()
	{
		if( m_pLaser !is null )
			m_pLaser.pev.effects &= ~EF_NODRAW;

		SetThink( null );
	}

	void HideLaser( float time )
	{
		if( m_pLaser !is null && m_bLaserActive )
		{
			m_pLaser.pev.effects |= EF_NODRAW;
			SetThink( ThinkFunction( RedrawLaser ) );
			self.pev.nextthink = g_Engine.time + time;
		}
	}

	void UpdateLaser()
	{
		if( m_bLaserActive && m_bSpotVisible )
		{
			if( m_pLaser is null )
			{
				CreateLaserSpot();
				g_SoundSystem.EmitSoundDyn( m_pPlayer.edict(), CHAN_WEAPON, Sounds[1], VOL_NORM, ATTN_NORM, 0, PITCH_NORM );
			}

			Vector vecSrc = m_pPlayer.GetGunPosition();
			Vector vecEnd = vecSrc + g_Engine.v_forward * 8192;

			TraceResult tr;
			g_Utility.TraceLine( vecSrc, vecEnd, dont_ignore_monsters, m_pPlayer.edict(), tr );
			g_EntityFuncs.SetOrigin( m_pLaser, tr.vecEndPos );
		}
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
		g_Game.PrecacheModel( LSR_SPR );
		m_iShell = g_Game.PrecacheModel( S_MODEL );

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
		bool bResult = self.DefaultDeploy( self.GetV_Model( V_MODEL ), self.GetP_Model( P_MODEL ), EAGLE_DRAW, "onehanded" );
		m_bSpotVisible = true;
		self.m_flTimeWeaponIdle = WeaponTimeBase() + 1.0;
		return bResult;
	}

	bool PlayEmptySound()
	{
		if( self.m_bPlayEmptySound )
		{
			self.m_bPlayEmptySound = false;
			g_SoundSystem.EmitSoundDyn( m_pPlayer.edict(), CHAN_WEAPON, Sounds[4], 0.8, ATTN_NORM, 0, PITCH_NORM );
		}

		return false;
	}

	void Holster( int skiplocal = 0 )
	{
		self.m_fInReload = false;
		SetThink( null );
		if( m_pLaser !is null )
		{
			g_EntityFuncs.Remove( m_pLaser );
			@m_pLaser = @null;
			m_bSpotVisible = false;
		}

		BaseClass.Holster( skiplocal );
	}

	void PrimaryAttack()
	{
		if( self.m_iClip <= 0 || m_pPlayer.pev.waterlevel == WATERLEVEL_HEAD )
		{
			self.PlayEmptySound();
			self.m_flNextPrimaryAttack = WeaponTimeBase() + (self.m_iClip > 0 ? 0.15 : 2.0);
			return;
		}

		--self.m_iClip;

		Vector vecSrc	 = m_pPlayer.GetGunPosition();
		Vector vecAiming = m_pPlayer.GetAutoaimVector( AUTOAIM_10DEGREES );
		Vector vecSpread = m_bLaserActive ? Vector(0.001,0.001,0.001) : Vector(0.1,0.1,0.1);

		m_pPlayer.FireBullets( 1, vecSrc, vecAiming, vecSpread, 8192, BULLET_PLAYER_EAGLE );
		g_SoundSystem.EmitSoundDyn( m_pPlayer.edict(), CHAN_WEAPON, Sounds[0], Math.RandomFloat(0.92,1.0), ATTN_NORM, 0, 98 + Math.RandomLong(0,3) );

		HideLaser( 0.6 );

		Vector vecShellVelocity, vecShellOrigin;
		GetDefaultShellInfo( m_pPlayer, vecShellVelocity, vecShellOrigin, 14.0, -9.0, 9.0 );
		g_EntityFuncs.EjectBrass( vecShellOrigin, vecShellVelocity, m_pPlayer.pev.angles.y, m_iShell, TE_BOUNCE_SHELL );

		if( self.m_iClip <= 0 && m_pPlayer.m_rgAmmo( self.m_iPrimaryAmmoType ) <= 0 )
			m_pPlayer.SetSuitUpdate( "!HEV_AMO0", false, 0 );

		m_pPlayer.pev.effects |= EF_MUZZLEFLASH;
		self.pev.effects |= EF_MUZZLEFLASH;

		m_pPlayer.SetAnimation( PLAYER_ATTACK1 );
		self.SendWeaponAnim( self.m_iClip > 0 ? EAGLE_SHOOT : EAGLE_SHOOT_EMPTY );

		m_pPlayer.m_iWeaponVolume = NORMAL_GUN_VOLUME;
		m_pPlayer.m_iWeaponFlash = NORMAL_GUN_FLASH;

		m_pPlayer.pev.punchangle.x = -4.0;

		self.m_flNextPrimaryAttack = self.m_flNextSecondaryAttack = WeaponTimeBase() + (m_bLaserActive ? 0.5 : 0.22);
		self.m_flTimeWeaponIdle = WeaponTimeBase() + g_PlayerFuncs.SharedRandomFloat( m_pPlayer.random_seed, 10.0, 15.0 );

		UpdateLaser();

		TraceResult tr;
		float x, y;

		g_Utility.GetCircularGaussianSpread( x, y );

		Vector vecDir = vecAiming + x * vecSpread.x * g_Engine.v_right + y * vecSpread.y * g_Engine.v_up;
		Vector vecEnd = vecSrc + vecDir * 8192;

		g_Utility.TraceLine( vecSrc, vecEnd, dont_ignore_monsters, m_pPlayer.edict(), tr );

		if( tr.flFraction < 1.0 )
		{
			if( tr.pHit !is null )
			{
				CBaseEntity@ pHit = g_EntityFuncs.Instance( tr.pHit );

				if( pHit is null || pHit.IsBSPModel() )
					g_WeaponFuncs.DecalGunshot( tr, BULLET_PLAYER_EAGLE );
			}
		}
	}

	void SecondaryAttack()
	{
		m_bLaserActive = !m_bLaserActive;

		if( !m_bLaserActive )
		{
			if( m_pLaser !is null )
			{
				g_EntityFuncs.Remove( m_pLaser );
				@m_pLaser = @null;
				g_SoundSystem.EmitSoundDyn( m_pPlayer.edict(), CHAN_WEAPON, Sounds[2], VOL_NORM, ATTN_NORM, 0, PITCH_NORM );
			}
		}

		self.m_flNextSecondaryAttack = WeaponTimeBase() + 0.5;
	}

	void Reload()
	{
		if( self.m_iClip == MAX_CLIP || m_pPlayer.m_rgAmmo( self.m_iPrimaryAmmoType ) <= 0 )
			return;

		if( m_pLaser !is null && m_bLaserActive )
		{
			HideLaser( 1.6 );
			self.m_flNextSecondaryAttack = WeaponTimeBase() + 1.5;
		}
		self.DefaultReload( MAX_CLIP, self.m_iClip > 0 ? EAGLE_RELOAD : EAGLE_RELOAD_NOSHOT, 1.5 );
		self.m_flTimeWeaponIdle = WeaponTimeBase() + g_PlayerFuncs.SharedRandomFloat( m_pPlayer.random_seed, 10.0, 15.0 );

		BaseClass.Reload();
	}

	void WeaponIdle()
	{
		UpdateLaser();
		self.ResetEmptySound();
		m_pPlayer.GetAutoaimVector( AUTOAIM_10DEGREES );

		if( self.m_flTimeWeaponIdle > WeaponTimeBase() || self.m_iClip <= 0 )
			return;

		float flRand = g_PlayerFuncs.SharedRandomFloat( m_pPlayer.random_seed, 0.0, 1.0 );
		if( m_bLaserActive )
		{
			self.SendWeaponAnim( flRand > 0.5 ? EAGLE_IDLE5 : EAGLE_IDLE4 );
			self.m_flTimeWeaponIdle = WeaponTimeBase() + (flRand > 0.5 ? 2.0 : 2.5);
		}
		else
		{
			if( flRand <= 0.3 )
			{
				self.SendWeaponAnim( EAGLE_IDLE1 );
				self.m_flTimeWeaponIdle = WeaponTimeBase() + 2.5;
			}
			else
			{
				self.SendWeaponAnim( flRand > 0.6 ? EAGLE_IDLE3 : EAGLE_IDLE2 );
				self.m_flTimeWeaponIdle = WeaponTimeBase() + (flRand > 0.6 ? 1.633 : 2.5);
			}
		}
	}
}

string GetAmmoName()
{
	return "ammo_357";
}

string GetName()
{
	return "weapon_ofeagle";
}

void Register()
{
	if( !g_CustomEntityFuncs.IsCustomEntity( GetName() ) )
	{
		g_CustomEntityFuncs.RegisterCustomEntity( "OF_EAGLE::weapon_ofeagle", GetName() );
		g_ItemRegistry.RegisterWeapon( GetName(), SPR_DIR, AMMO_TYPE, "", GetAmmoName() );
	}
}

}

