/* 
* The Opposing Force version of the m249
*/

const int M249_DEFAULT_GIVE	= 200;
const int M249_MAX_CARRY	= 600;
const int M249_MAX_CLIP		= 200;
const int M249_WEIGHT		= 15;

enum m249_e
{
	M249_SLOWIDLE = 0,
	M249_IDLE2,
	M249_LAUNCH,
	M249_RELOAD1,
	M249_HOLSTER,
	M249_DEPLOY,
	M249_SHOOT1,
	M249_SHOOT2,
	M249_SHOOT3,
};

const array<string> M249Sounds =
{
	"hlclassic/weapons/saw_fire1.wav",
	"hlclassic/weapons/saw_fire2.wav",
	"hlclassic/weapons/saw_fire3.wav",
	"hlclassic/weapons/saw_reload.wav",
	"hlclassic/weapons/saw_reload2.wav"
};

class weapon_ofm249 : ScriptBasePlayerWeaponEntity
{
	private CBasePlayer@ m_pPlayer
	{
		get const	{ return cast<CBasePlayer@>( self.m_hPlayer.GetEntity() ); }
		set		{ self.m_hPlayer = EHandle( @value ); }
	}

	int m_iVisibleClip;
	int m_iShell;
	bool m_fM249Reload;

	void Spawn()
	{
		Precache();
		g_EntityFuncs.SetModel( self, self.GetW_Model( "models/hlclassic/w_saw.mdl" ) );

		self.m_iDefaultAmmo = M249_DEFAULT_GIVE;

		m_fM249Reload = false;

		self.FallInit();// get ready to fall
	}

	void Precache()
	{
		self.PrecacheCustomModels();
		g_Game.PrecacheModel( "models/hlclassic/v_saw.mdl" );
		g_Game.PrecacheModel( "models/hlclassic/w_saw.mdl" );
		g_Game.PrecacheModel( "models/hlclassic/p_saw.mdl" );

		m_iShell = g_Game.PrecacheModel( "models/hlclassic/saw_shell.mdl" );// brass shellTE_MODEL

		//g_Game.PrecacheModel( "models/hlclassic/w_saw_clip.mdl" );
		g_SoundSystem.PrecacheSound( "hlclassic/items/9mmclip1.wav" );

		for( uint i = 0; i < M249Sounds.length(); i++ )
		{
			g_SoundSystem.PrecacheSound( M249Sounds[i] );
			g_Game.PrecacheGeneric( "sound/" + M249Sounds[i] );
		}

		g_Game.PrecacheGeneric( "sprites/hl_weapons/weapon_ofm249.txt" );

		g_SoundSystem.PrecacheSound( "hlclassic/weapons/357_cock1.wav" );
	}

	bool GetItemInfo( ItemInfo& out info )
	{
		info.iMaxAmmo1	= M249_MAX_CARRY;
		info.iAmmo1Drop	= M249_MAX_CLIP;
		info.iMaxAmmo2	= -1;
		info.iAmmo2Drop	= -1;
		info.iMaxClip	= M249_MAX_CLIP;
		info.iSlot	= 5;
		info.iPosition	= 6;
		info.iId	= g_ItemRegistry.GetIdForName( self.pev.classname );
		info.iFlags	= 0;
		info.iWeight	= M249_WEIGHT;

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

	bool PlayEmptySound()
	{
		if( self.m_bPlayEmptySound )
		{
			self.m_bPlayEmptySound = false;

			g_SoundSystem.EmitSoundDyn( m_pPlayer.edict(), CHAN_WEAPON, "hlclassic/weapons/357_cock1.wav", 0.8, ATTN_NORM, 0, PITCH_NORM );
		}

		return false;
	}

	bool Deploy()
	{
		self.m_fInReload = false;
		m_fM249Reload = false;
		UpdateTape();
		return self.DefaultDeploy( self.GetV_Model( "models/hlclassic/v_saw.mdl" ), self.GetP_Model( "models/hlclassic/p_saw.mdl" ), M249_DEPLOY, "saw", 0, self.pev.body );
	}

	void Holster( int skiplocal )
	{
		self.m_fInReload = false;
		m_fM249Reload = false;
		BaseClass.Holster( skiplocal );
	}

	float WeaponTimeBase()
	{
		return g_Engine.time;
	}

	void GetDefaultShellInfo( CBasePlayer@ pPlayer, Vector& out ShellVelocity, Vector& out ShellOrigin, float forwardScale, float upScale, float rightScale )
	{
		Vector vecForward, vecRight, vecUp;

		g_EngineFuncs.AngleVectors( pPlayer.pev.v_angle, vecForward, vecRight, vecUp );

		const float fR = Math.RandomFloat( 50, 70 );
		const float fU = Math.RandomFloat( 100, 150 );

		for( int i = 0; i < 3; ++i )
		{
			ShellVelocity[i] = pPlayer.pev.velocity[i] + vecRight[i] * fR + vecUp[i] * fU + vecForward[i] * 25;
			ShellOrigin[i]   = pPlayer.pev.origin[i] + pPlayer.pev.view_ofs[i] + vecUp[i] * upScale + vecForward[i] * forwardScale + vecRight[i] * rightScale;
		}
	}

	void PrimaryAttack()
	{
		// don't fire underwater
		if( m_pPlayer.pev.waterlevel == WATERLEVEL_HEAD )
		{
			self.PlayEmptySound();
			self.m_flNextPrimaryAttack = WeaponTimeBase() + 0.15;
			return;
		}

		if( self.m_iClip <= 0 )
		{
			self.PlayEmptySound();
			self.m_flNextPrimaryAttack = WeaponTimeBase() + 0.15;
			return;
		}

		m_pPlayer.pev.punchangle.x = Math.RandomFloat( 1.0f, 1.5f );
		m_pPlayer.pev.punchangle.y = Math.RandomFloat( -0.5f, -0.2f );

		m_pPlayer.m_iWeaponVolume = NORMAL_GUN_VOLUME;
		m_pPlayer.m_iWeaponFlash = NORMAL_GUN_FLASH;

		self.m_iClip--;
		UpdateTape();

		m_pPlayer.pev.effects |= EF_MUZZLEFLASH;
		self.pev.effects |= EF_MUZZLEFLASH;

		self.SendWeaponAnim( M249_SHOOT1 + Math.RandomLong( 0, 2 ), 0, self.pev.body );

		Vector vecShellVelocity, vecShellOrigin;

		GetDefaultShellInfo( m_pPlayer, vecShellVelocity, vecShellOrigin, 24.0, -28.0, 4.0 );

		vecShellVelocity.y *= 1;

		g_EntityFuncs.EjectBrass( vecShellOrigin, vecShellVelocity, m_pPlayer.pev.angles.y, m_iShell, TE_BOUNCE_SHELL );

		switch( g_PlayerFuncs.SharedRandomLong( m_pPlayer.random_seed, 0, 2 ) )
		{
		case 0:
			g_SoundSystem.EmitSoundDyn( m_pPlayer.edict(), CHAN_WEAPON, "hlclassic/weapons/saw_fire1.wav", 1, ATTN_NORM, 0, PITCH_NORM );
			break;
		case 1:
			g_SoundSystem.EmitSoundDyn( m_pPlayer.edict(), CHAN_WEAPON, "hlclassic/weapons/saw_fire2.wav", 1, ATTN_NORM, 0, PITCH_NORM );
			break;
		case 2:
			g_SoundSystem.EmitSoundDyn( m_pPlayer.edict(), CHAN_WEAPON, "hlclassic/weapons/saw_fire3.wav", 1, ATTN_NORM, 0, PITCH_NORM );
			break;
		}

		// player "shoot" animation
		m_pPlayer.SetAnimation( PLAYER_ATTACK1 );

		Vector vecSrc	 = m_pPlayer.GetGunPosition();
		Vector vecAiming = m_pPlayer.GetAutoaimVector( AUTOAIM_5DEGREES );

		// optimized multiplayer. Widened to make it easier to hit a moving player
		m_pPlayer.FireBullets( 1, vecSrc, vecAiming, VECTOR_CONE_6DEGREES, 8192, BULLET_PLAYER_SAW, 2 );

		Math.MakeVectors( m_pPlayer.pev.v_angle + m_pPlayer.pev.punchangle );
		Vector vecVelocity = m_pPlayer.pev.velocity;
		Vector vecInvPushDir = g_Engine.v_forward * 35.0;

		float flNewZVel;

		if( vecInvPushDir.z >= 10.0 )
			flNewZVel = vecInvPushDir.z;
		else
			flNewZVel = g_EngineFuncs.CVarGetFloat( "sv_maxspeed" );

		Vector vecNewVel;

		vecNewVel = vecVelocity;

		float flZTreshold = -( flNewZVel + 100.0 );

		if( vecVelocity.x > flZTreshold )
		{
			vecNewVel.x -= vecInvPushDir.x;
		}

		if( vecVelocity.y > flZTreshold )
		{
			vecNewVel.y -= vecInvPushDir.y;
		}

		m_pPlayer.pev.velocity = vecNewVel;

		if( self.m_iClip == 0 && m_pPlayer.m_rgAmmo( self.m_iPrimaryAmmoType ) <= 0 )
			// HEV suit - indicate out of ammo condition
			m_pPlayer.SetSuitUpdate( "!HEV_AMO0", false, 0 );

		m_pPlayer.pev.punchangle.x = Math.RandomFloat( -2, 2 );

		self.m_flNextPrimaryAttack = self.m_flNextPrimaryAttack + 0.067;

		if( self.m_flNextPrimaryAttack < WeaponTimeBase() )
			self.m_flNextPrimaryAttack = WeaponTimeBase() + 0.1;

		self.m_flTimeWeaponIdle = WeaponTimeBase() + g_PlayerFuncs.SharedRandomFloat( m_pPlayer.random_seed,  10, 15 );

		TraceResult tr;

		float x, y;

		g_Utility.GetCircularGaussianSpread( x, y );

		Vector vecDir = vecAiming + x * VECTOR_CONE_6DEGREES.x * g_Engine.v_right + y * VECTOR_CONE_6DEGREES.y * g_Engine.v_up;

		Vector vecEnd = vecSrc + vecDir * 8192;

		g_Utility.TraceLine( vecSrc, vecEnd, dont_ignore_monsters, m_pPlayer.edict(), tr );

		if( tr.flFraction < 1.0 )
		{
			if( tr.pHit !is null )
			{
				CBaseEntity@ pHit = g_EntityFuncs.Instance( tr.pHit );

				if( pHit is null || pHit.IsBSPModel() )
					g_WeaponFuncs.DecalGunshot( tr, BULLET_PLAYER_SAW );
			}
		}
	}

	void Reload()
	{
		if( m_pPlayer.m_rgAmmo( self.m_iPrimaryAmmoType ) <= 0 || self.m_iClip == M249_MAX_CLIP )
			return;

		self.DefaultReload( M249_MAX_CLIP, M249_LAUNCH, 1.33, self.pev.body );
		m_fM249Reload = true;
		self.m_flNextPrimaryAttack = WeaponTimeBase() + 3.78;
		self.m_flTimeWeaponIdle = WeaponTimeBase() + 3.78;

		m_pPlayer.ResetSequenceInfo();
		m_pPlayer.pev.framerate = 2.25;

		//Set 3rd person reloading animation -Sniper
		BaseClass.Reload();
	}

	void ItemPostFrame()
	{
		if( !self.m_fInReload )
		{
			m_iVisibleClip = self.m_iClip;
		}
		if( m_fM249Reload )
		{
			m_iVisibleClip = self.m_iClip + Math.min( self.iMaxClip() - self.m_iClip, m_pPlayer.m_rgAmmo( self.m_iPrimaryAmmoType ) );
			if( m_pPlayer.m_flNextAttack <= WeaponTimeBase() )
			{
				UpdateTape( m_iVisibleClip );
				m_fM249Reload = false;
				self.SendWeaponAnim( M249_RELOAD1, 0, self.pev.body );
				m_pPlayer.m_flNextAttack = 2.4;
				m_pPlayer.ResetSequenceInfo();
				m_pPlayer.pev.framerate = 2.25;
			}
		}
		//UpdateTape( m_iVisibleClip );

		BaseClass.ItemPostFrame();
	}

	void WeaponIdle()
	{
		self.ResetEmptySound();

		m_pPlayer.GetAutoaimVector( AUTOAIM_5DEGREES );

		UpdateTape( m_iVisibleClip );

		if( self.m_flTimeWeaponIdle > WeaponTimeBase() )
			return;

		float flRand = g_PlayerFuncs.SharedRandomFloat( m_pPlayer.random_seed, 0, 1 );
		int iAnim;
		if( flRand <= 0.8 )
		{
			iAnim = M249_SLOWIDLE;
			self.m_flTimeWeaponIdle = WeaponTimeBase() + 5;
		} else {
			iAnim = M249_IDLE2;
			self.m_flTimeWeaponIdle = WeaponTimeBase() + 155.0/25.0;	
		}

		self.SendWeaponAnim( iAnim, 0, self.pev.body );
	}

	void UpdateTape()
	{
		UpdateTape( self.m_iClip );
		m_iVisibleClip = self.m_iClip;
	}

	void UpdateTape( int clip )
	{
		if( clip == 0 ) {
			self.pev.body = 8;
		} else if( clip > 0 && clip < 8 ) {
			self.pev.body = 9 - clip;
		} else {
			self.pev.body = 0;
		}
	}
}

string GetOFM249Name()
{
	return "weapon_ofm249";
}

void RegisterOFM249()
{
	g_CustomEntityFuncs.RegisterCustomEntity( "weapon_ofm249", GetOFM249Name() );
	g_ItemRegistry.RegisterWeapon( GetOFM249Name(), "hl_weapons", "556", "", "ammo_556" );
}
