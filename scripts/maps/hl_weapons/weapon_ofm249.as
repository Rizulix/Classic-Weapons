/* 
* The Opposing Force version of the m249
*/

namespace OF_M249
{

enum m249_e
{
	M249_SLOWIDLE = 0,
	M249_IDLE2,
	M249_RELOAD_START,
	M249_RELOAD_END,
	M249_HOLSTER,
	M249_DRAW,
	M249_SHOOT1,
	M249_SHOOT2,
	M249_SHOOT3,
};

// Models
string W_MODEL		= "models/hlclassic/w_saw.mdl";
string V_MODEL		= "models/hlclassic/v_saw.mdl";
string P_MODEL		= "models/hlclassic/p_saw.mdl";
string A_MODEL		= "models/hlclassic/w_saw_clip.mdl";
string S_MODEL		= "models/hlclassic/saw_shell.mdl"; // Change this manually in MapInit function, ex: OF_M249::S_MODEL = "models/mymodel.mdl";
// Sprites
string SPR_DIR		= "hl_weapons/";
// Sounds
array<string> Sounds = { 
		"weapons/saw_fire1.wav",
		//"hlclassic/weapons/saw_fire2.wav", //unused
		//"hlclassic/weapons/saw_fire3.wav", //unused
		"hlclassic/weapons/saw_reload.wav",
		"hlclassic/weapons/saw_reload2.wav",
		"hlclassic/weapons/357_cock1.wav"
};
string AMMO_PICKUP	= "hlclassic/items/9mmclip1.wav";
// Weapon information
int MAX_CARRY		= 600; //200; Swap values if you want the default OF values
int MAX_CLIP		= 200; //50; Swap values if you want the default OF values
int DEFAULT_GIVE	= MAX_CLIP;
int WEIGHT		= 20;
int FLAGS		= 0;
uint SLOT		= 5;
uint POSITION		= 6;
string AMMO_TYPE 	= "556";

class weapon_ofm249 : ScriptBasePlayerWeaponEntity
{
	private CBasePlayer@ m_pPlayer
	{
		get const	{ return cast<CBasePlayer@>( self.m_hPlayer.GetEntity() ); }
		set		{ self.m_hPlayer = EHandle( @value ); }
	}
	private int m_iShell;
	private int GetBodygroup()
	{
		if( self.m_iClip == 0 )
			return 8;
		else if( self.m_iClip <= 7 )
			return 9 - self.m_iClip;
		else
			return 0;
	}

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
		m_iShell = g_Game.PrecacheModel( S_MODEL );

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
		bool bResult = self.DefaultDeploy( self.GetV_Model( V_MODEL ), self.GetP_Model( P_MODEL ), M249_DRAW, "saw", 0, GetBodygroup() );
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
		Vector vecAiming = m_pPlayer.GetAutoaimVector( AUTOAIM_5DEGREES );
		Vector vecSpread;

		if( m_pPlayer.pev.button & IN_DUCK != 0 )
			vecSpread = IsMultiplayer ? VECTOR_CONE_3DEGREES : VECTOR_CONE_4DEGREES;
		else if( m_pPlayer.pev.button & ( IN_MOVERIGHT | IN_MOVELEFT | IN_FORWARD | IN_BACK ) != 0 )
			vecSpread = IsMultiplayer ? VECTOR_CONE_15DEGREES : VECTOR_CONE_10DEGREES;
		else
			vecSpread = IsMultiplayer ? VECTOR_CONE_6DEGREES : VECTOR_CONE_2DEGREES;

		m_pPlayer.FireBullets( 1, vecSrc, vecAiming, vecSpread, 8192, BULLET_PLAYER_SAW, 2 );
		g_SoundSystem.EmitSoundDyn( m_pPlayer.edict(), CHAN_WEAPON, Sounds[0], VOL_NORM, ATTN_NORM, 0, 94 + Math.RandomLong(0,15) );

		Vector vecShellVelocity, vecShellOrigin;
		GetDefaultShellInfo( m_pPlayer, vecShellVelocity, vecShellOrigin, 24.0, -28.0, 4.0 );
		g_EntityFuncs.EjectBrass( vecShellOrigin, vecShellVelocity, m_pPlayer.pev.angles.y, m_iShell, TE_BOUNCE_SHELL );

		if( self.m_iClip <= 0 && m_pPlayer.m_rgAmmo( self.m_iPrimaryAmmoType ) <= 0 )
			m_pPlayer.SetSuitUpdate( "!HEV_AMO0", false, 0 );

		m_pPlayer.pev.effects |= EF_MUZZLEFLASH;
		self.pev.effects |= EF_MUZZLEFLASH;

		m_pPlayer.SetAnimation( PLAYER_ATTACK1 );
		self.SendWeaponAnim( m249_e(Math.RandomLong(6,8)), 0, GetBodygroup() );

		m_pPlayer.m_iWeaponVolume = NORMAL_GUN_VOLUME;
		m_pPlayer.m_iWeaponFlash = NORMAL_GUN_FLASH;

		m_pPlayer.pev.punchangle.x = Math.RandomFloat( -2.0, 2.0 );
		m_pPlayer.pev.punchangle.y = Math.RandomFloat( -1.0, 1.0 );

		self.m_flNextPrimaryAttack = WeaponTimeBase() + 0.067;
		self.m_flTimeWeaponIdle = WeaponTimeBase() + 0.2;

		const Vector vecVelocity = m_pPlayer.pev.velocity;
		const float flZVel = m_pPlayer.pev.velocity.z;
		Vector vecInvPushDir = g_Engine.v_forward * 35.0;
		float flNewZVel = g_EngineFuncs.CVarGetFloat( "sv_maxspeed" );

		if( vecInvPushDir.z >= 10.0 )
			flNewZVel = vecInvPushDir.z;

		if( !IsMultiplayer )
		{
			m_pPlayer.pev.velocity = m_pPlayer.pev.velocity - vecInvPushDir;
			m_pPlayer.pev.velocity.z = flZVel;
		}
		else
		{
			const float flZTreshold = -( flNewZVel + 100.0 );

			if( vecVelocity.x > flZTreshold )
				m_pPlayer.pev.velocity.x -= vecInvPushDir.x;

			if( vecVelocity.y > flZTreshold )
				m_pPlayer.pev.velocity.y -= vecInvPushDir.y;

			m_pPlayer.pev.velocity.z -= vecInvPushDir.z;
		}

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

				g_SoundSystem.PlayHitSound( tr, vecSrc, vecEnd, BULLET_PLAYER_SAW );
				g_Utility.BubbleTrail( vecSrc, tr.vecEndPos, int((8192 * tr.flFraction)/64.0) );

				if( pHit is null || pHit.IsBSPModel() )
					g_WeaponFuncs.DecalGunshot( tr, BULLET_PLAYER_SAW );
			}
		}
	}

	void FinishAnim()
	{
		self.SendWeaponAnim( M249_RELOAD_END, 0, GetBodygroup() );
		SetThink( null );
	}

	void Reload()
	{
		if( self.m_iClip == MAX_CLIP || m_pPlayer.m_rgAmmo( self.m_iPrimaryAmmoType ) <= 0 )
			return;

		SetThink( ThinkFunction( this.FinishAnim ) );
		self.pev.nextthink = WeaponTimeBase() + 1.5;
		self.DefaultReload( MAX_CLIP, M249_RELOAD_START, 1.0, GetBodygroup() );
		self.m_flNextPrimaryAttack = WeaponTimeBase() + 3.78;
		self.m_flTimeWeaponIdle = WeaponTimeBase() + 3.78;

		m_pPlayer.SetAnimation( PLAYER_RELOAD );
		m_pPlayer.pev.framerate = 1.75;
	}

	void WeaponIdle()
	{
		self.ResetEmptySound();
		m_pPlayer.GetAutoaimVector( AUTOAIM_5DEGREES );

		if( self.m_flTimeWeaponIdle > WeaponTimeBase() )
			return;

		float flRand = g_PlayerFuncs.SharedRandomFloat( m_pPlayer.random_seed, 0.0, 1.0 );
		if( flRand <= 0.95 )
		{
			self.SendWeaponAnim( M249_SLOWIDLE, 0, GetBodygroup() );
			self.m_flTimeWeaponIdle = WeaponTimeBase() + 5.0;
		}
		else
		{
			self.SendWeaponAnim( M249_IDLE2, 0, GetBodygroup() );
			self.m_flTimeWeaponIdle = WeaponTimeBase() + 6.16;	
		}
	}
}

class ammo_of556 : ScriptBasePlayerAmmoEntity
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
	return "ammo_of556";
} 

string GetName()
{
	return "weapon_ofm249";
}

void Register()
{
	if( !g_CustomEntityFuncs.IsCustomEntity( GetAmmoName() ) )
		g_CustomEntityFuncs.RegisterCustomEntity( "OF_M249::ammo_of556", GetAmmoName() );

	if( !g_CustomEntityFuncs.IsCustomEntity( GetName() ) )
	{
		g_CustomEntityFuncs.RegisterCustomEntity( "OF_M249::weapon_ofm249", GetName() );
		g_ItemRegistry.RegisterWeapon( GetName(), SPR_DIR, AMMO_TYPE, "", GetAmmoName() );
	}
}

}

