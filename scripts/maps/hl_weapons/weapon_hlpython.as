/* 
* The original Half-Life version of the python
*/

const int PYTHON_DEFAULT_GIVE	= 6;
const int PYTHON_MAX_CARRY	= 36;
const int PYTHON_MAX_CLIP	= 6;
const int PYTHON_WEIGHT		= 15;

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

class weapon_hlpython : ScriptBasePlayerWeaponEntity
{
	private CBasePlayer@ m_pPlayer
	{
		get const	{ return cast<CBasePlayer@>( self.m_hPlayer.GetEntity() ); }
		set		{ self.m_hPlayer = EHandle( @value ); }
	}

	bool GetItemInfo( ItemInfo& out info )
	{
		info.iMaxAmmo1 	= PYTHON_MAX_CARRY;
		info.iAmmo1Drop	= PYTHON_MAX_CLIP;
		info.iMaxAmmo2 	= -1;
		info.iAmmo2Drop	= -1;
		info.iMaxClip 	= PYTHON_MAX_CLIP;
		info.iSlot	= 1;
		info.iPosition 	= 6;
		info.iId	= g_ItemRegistry.GetIdForName( self.pev.classname );
		info.iFlags 	= 0;
		info.iWeight 	= PYTHON_WEIGHT;

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

	bool PlayEmptySound()
	{
		if( self.m_bPlayEmptySound )
		{
			self.m_bPlayEmptySound = false;

			g_SoundSystem.EmitSoundDyn( m_pPlayer.edict(), CHAN_WEAPON, "hlclassic/weapons/357_cock1.wav", 0.8, ATTN_NORM, 0, PITCH_NORM );
		}

		return false;
	}

	void Spawn()
	{
		Precache();
		g_EntityFuncs.SetModel( self, self.GetW_Model( "models/hlclassic/w_357.mdl" ) );

		self.m_iDefaultAmmo = PYTHON_DEFAULT_GIVE;

		self.FallInit();// get ready to fall
	}

	void Precache()
	{
		self.PrecacheCustomModels();
		g_Game.PrecacheModel( "models/hlclassic/v_357.mdl" );
		g_Game.PrecacheModel( "models/hlclassic/w_357.mdl" );
		g_Game.PrecacheModel( "models/hlclassic/p_357.mdl" );

		//g_Game.PrecacheModel( "models/hlclassic/w_357ammobox.mdl" );
		g_SoundSystem.PrecacheSound( "hlclassic/items/9mmclip1.wav" );

		g_SoundSystem.PrecacheSound( "hlclassic/weapons/357_reload1.wav" );
		g_SoundSystem.PrecacheSound( "hlclassic/weapons/357_cock1.wav" );
		g_SoundSystem.PrecacheSound( "hlclassic/weapons/357_shot1.wav" );
		g_SoundSystem.PrecacheSound( "hlclassic/weapons/357_shot2.wav" );

		g_Game.PrecacheGeneric( "sprites/hl_weapons/weapon_hlpython.txt" );
	}

	bool Deploy()
	{
		// enable laser sight geometry.
		self.pev.body = 1;

		return self.DefaultDeploy( self.GetV_Model( "models/hlclassic/v_357.mdl" ), self.GetP_Model( "models/hlclassic/p_357.mdl" ), PYTHON_DRAW, "python", 0, self.pev.body );
	}

	void Holster( int skiplocal )
	{
		self.m_fInReload = false;

		if( self.m_fInZoom )
		{
			SecondaryAttack();
		}

		BaseClass.Holster( skiplocal );
	}

	float WeaponTimeBase()
	{
		return g_Engine.time;
	}

	void SecondaryAttack()
	{
		if( m_pPlayer.pev.fov != 0 )
		{
			self.m_fInZoom = false;
			m_pPlayer.pev.fov = m_pPlayer.m_iFOV = 0; // 0 means reset to default fov
		}
		else if( m_pPlayer.pev.fov != 40 )
		{
			self.m_fInZoom = true;
			m_pPlayer.pev.fov = m_pPlayer.m_iFOV = 40;
		}

		self.m_flNextSecondaryAttack = WeaponTimeBase() + 0.5;
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
			if( !self.m_bFireOnEmpty )
				self.Reload();
			else
			{
				g_SoundSystem.EmitSound( m_pPlayer.edict(), CHAN_WEAPON, "hlclassic/weapons/357_cock1.wav", 0.8, ATTN_NORM );
				self.m_flNextPrimaryAttack = WeaponTimeBase() + 0.15;
			}

			return;
		}

		m_pPlayer.m_iWeaponVolume = LOUD_GUN_VOLUME;
		m_pPlayer.m_iWeaponFlash = BRIGHT_GUN_FLASH;

		self.m_iClip--;

		m_pPlayer.pev.effects |= EF_MUZZLEFLASH;
		self.pev.effects |= EF_MUZZLEFLASH;

		self.SendWeaponAnim( PYTHON_FIRE1, 0, self.pev.body );

		switch ( g_PlayerFuncs.SharedRandomLong( m_pPlayer.random_seed, 0, 1 ) )
		{
		case 0:
			g_SoundSystem.EmitSoundDyn( m_pPlayer.edict(), CHAN_WEAPON, "hlclassic/weapons/357_shot1.wav", Math.RandomFloat( 0.8, 0.9 ), ATTN_NORM, 0, PITCH_NORM );
			break;
		case 1:
			g_SoundSystem.EmitSoundDyn( m_pPlayer.edict(), CHAN_WEAPON, "hlclassic/weapons/357_shot2.wav", Math.RandomFloat( 0.8, 0.9 ), ATTN_NORM, 0, PITCH_NORM );
			break;
		}

		// player "shoot" animation
		m_pPlayer.SetAnimation( PLAYER_ATTACK1 );

		Math.MakeVectors( m_pPlayer.pev.v_angle + m_pPlayer.pev.punchangle );

		Vector vecSrc	 = m_pPlayer.GetGunPosition();
		Vector vecAiming = m_pPlayer.GetAutoaimVector( AUTOAIM_10DEGREES );

		m_pPlayer.FireBullets( 1, vecSrc, vecAiming, VECTOR_CONE_1DEGREES, 8192, BULLET_PLAYER_357, 0 );

		if( self.m_iClip == 0 && m_pPlayer.m_rgAmmo( self.m_iPrimaryAmmoType ) <= 0 )
			// HEV suit - indicate out of ammo condition
			m_pPlayer.SetSuitUpdate( "!HEV_AMO0", false, 0 );

		m_pPlayer.pev.punchangle.x = -10.0;

		self.m_flNextPrimaryAttack = WeaponTimeBase() + 0.75;

		self.m_flTimeWeaponIdle = WeaponTimeBase() + g_PlayerFuncs.SharedRandomFloat( m_pPlayer.random_seed, 10, 15 );

		TraceResult tr;

		float x, y;

		g_Utility.GetCircularGaussianSpread( x, y );

		Vector vecDir = vecAiming + x * VECTOR_CONE_1DEGREES.x * g_Engine.v_right + y * VECTOR_CONE_1DEGREES.y * g_Engine.v_up;

		Vector vecEnd	= vecSrc + vecDir * 8192;

		g_Utility.TraceLine( vecSrc, vecEnd, dont_ignore_monsters, m_pPlayer.edict(), tr );

		if( tr.flFraction < 1.0 )
		{
			if( tr.pHit !is null )
			{
				CBaseEntity@ pHit = g_EntityFuncs.Instance( tr.pHit );

				if( pHit is null || pHit.IsBSPModel() )
					g_WeaponFuncs.DecalGunshot( tr, BULLET_PLAYER_357 );
			}
		}
	}

	void Reload()
	{
		if( m_pPlayer.m_rgAmmo( self.m_iPrimaryAmmoType ) <= 0 || self.m_iClip == PYTHON_MAX_CLIP )
			return;

		if( m_pPlayer.pev.fov != 0 )
		{
			SecondaryAttack();
		}

		self.DefaultReload( PYTHON_MAX_CLIP, PYTHON_RELOAD, 3.0, self.pev.body );

		//Set 3rd person reloading animation -Sniper
		BaseClass.Reload();
	}

	void WeaponIdle()
	{
		self.ResetEmptySound();

		m_pPlayer.GetAutoaimVector( AUTOAIM_5DEGREES );

		if( self.m_flTimeWeaponIdle > WeaponTimeBase() )
			return;

		int iAnim;
		float flRand = g_PlayerFuncs.SharedRandomFloat( m_pPlayer.random_seed, 0, 1 );
		if (flRand <= 0.5)
		{
			iAnim = PYTHON_IDLE1;
			self.m_flTimeWeaponIdle = WeaponTimeBase() + (70.0/30.0);
		}
		else if (flRand <= 0.7)
		{
			iAnim = PYTHON_IDLE2;
			self.m_flTimeWeaponIdle = WeaponTimeBase() + (60.0/30.0);
		}
		else if (flRand <= 0.9)
		{
			iAnim = PYTHON_IDLE3;
			self.m_flTimeWeaponIdle = WeaponTimeBase() + (88.0/30.0);
		}
		else
		{
			iAnim = PYTHON_FIDGET;
			self.m_flTimeWeaponIdle = WeaponTimeBase() + (170.0/30.0);
		}
		self.SendWeaponAnim( iAnim, 0, self.pev.body );
	}
}

string GetHLPythonName()
{
	return "weapon_hlpython";
}

void RegisterHLPython()
{
	g_CustomEntityFuncs.RegisterCustomEntity( "weapon_hlpython", GetHLPythonName() );
	g_ItemRegistry.RegisterWeapon( GetHLPythonName(), "hl_weapons", "357", "", "ammo_357" );
}
