/* 
* The Opposing Force version of the sniper
*/

const int SNIPERRIFLE_DEFAULT_GIVE	= 5;
const int SNIPERRIFLE_MAX_CARRY		= 15;
const int SNIPERRIFLE_MAX_CLIP		= 5;
const int SNIPERRIFLE_WEIGHT		= 10;

enum sniper_e
{
	SNIPER_DRAW = 0,
	SNIPER_SLOWIDLE1,
	SNIPER_FIRE,
	SNIPER_FIRELASTROUND,
	SNIPER_RELOAD1,
	SNIPER_RELOAD2,
	SNIPER_RELOAD3,
	SNIPER_SLOWIDLE2,
	SNIPER_HOLSTER
};

const array<string> SniperSounds =
{
	"hlclassic/weapons/sniper_bolt1.wav",
	"hlclassic/weapons/sniper_bolt2.wav",
	"hlclassic/weapons/sniper_fire.wav",
	"hlclassic/weapons/sniper_reload_first_seq.wav",
	"hlclassic/weapons/sniper_reload_second_seq.wav",
	"hlclassic/weapons/sniper_reload3.wav",
	"hlclassic/weapons/sniper_zoom.wav"
};

class weapon_ofsniperrifle : ScriptBasePlayerWeaponEntity
{
	private CBasePlayer@ m_pPlayer
	{
		get const	{ return cast<CBasePlayer@>( self.m_hPlayer.GetEntity() ); }
		set		{ self.m_hPlayer = EHandle( @value ); }
	}

	bool m_fSniperReload;

	void Spawn()
	{
		Precache();
		g_EntityFuncs.SetModel( self, self.GetW_Model( "models/hlclassic/w_m40a1.mdl" ) );

		self.m_iDefaultAmmo = SNIPERRIFLE_DEFAULT_GIVE;

		m_fSniperReload = false;

		self.FallInit();// get ready to fall
	}

	void Precache()
	{
		self.PrecacheCustomModels();
		g_Game.PrecacheModel( "models/hlclassic/v_m40a1.mdl" );
		g_Game.PrecacheModel( "models/hlclassic/w_m40a1.mdl" );
		g_Game.PrecacheModel( "models/hlclassic/p_m40a1.mdl" );

		//g_Game.PrecacheModel( "models/hlclassic/w_m40a1clip.mdl" );

		for( uint i = 0; i < SniperSounds.length(); i++ )
		{
			g_SoundSystem.PrecacheSound( SniperSounds[i] );
			g_Game.PrecacheGeneric( "sound/" + SniperSounds[i] );
		}

		g_Game.PrecacheGeneric( "sprites/hl_weapons/weapon_ofsniperrifle.txt" );

		g_SoundSystem.PrecacheSound( "hlclassic/weapons/357_cock1.wav" );
	}

	bool GetItemInfo( ItemInfo& out info )
	{
		info.iMaxAmmo1	= SNIPERRIFLE_MAX_CARRY;
		info.iAmmo1Drop	= SNIPERRIFLE_MAX_CLIP;
		info.iMaxAmmo2	= -1;
		info.iAmmo2Drop	= -1;
		info.iMaxClip	= SNIPERRIFLE_MAX_CLIP;
		info.iSlot	= 5;
		info.iPosition	= 5;
		info.iId	= g_ItemRegistry.GetIdForName( self.pev.classname );
		info.iFlags	= 0;
		info.iWeight	= SNIPERRIFLE_WEIGHT;

		return true;
	}

	bool Deploy()
	{
		self.m_fInReload = false;
		m_fSniperReload = false;
		return self.DefaultDeploy( self.GetV_Model( "models/hlclassic/v_m40a1.mdl" ), self.GetP_Model( "models/hlclassic/p_m40a1.mdl" ), SNIPER_DRAW, "sniper", 0 );
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

	void Holster( int skiplocal )
	{
		self.m_fInReload = false;
		m_fSniperReload = false;

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
			m_pPlayer.pev.fov = m_pPlayer.m_iFOV = 0; // 0 means reset to default fov
			self.m_fInZoom = false;
		}
		else if( m_pPlayer.pev.fov != 15 )
		{
			m_pPlayer.pev.fov = m_pPlayer.m_iFOV = 15;
			self.m_fInZoom = true;
		}

		g_SoundSystem.EmitSoundDyn( m_pPlayer.edict(), CHAN_ITEM, "hlclassic/weapons/sniper_zoom.wav", 1.0, ATTN_NORM, 0, PITCH_NORM );

		self.m_flNextSecondaryAttack = WeaponTimeBase() + 0.5;
	}

	void PrimaryAttack()
	{
		if( self.m_iClip <= 0 )
		{
			if( self.m_bFireOnEmpty )
			{
				self.PlayEmptySound();
				self.m_flNextPrimaryAttack = WeaponTimeBase() + 0.2f;
			}

			return;
		}

		// don't fire underwater
		if( m_pPlayer.pev.waterlevel == WATERLEVEL_HEAD )
		{
			self.PlayEmptySound();
			self.m_flNextPrimaryAttack = WeaponTimeBase() + 0.15f;
			return;
		}

		float flSpread = 0.001f;

		self.m_iClip--;

		m_pPlayer.pev.effects |= EF_MUZZLEFLASH;
		self.pev.effects |= EF_MUZZLEFLASH;

		if( self.m_iClip == 1 )
		{
			self.SendWeaponAnim( SNIPER_FIRELASTROUND );
		}
		else
		{
			self.SendWeaponAnim( SNIPER_FIRE );
		}

		g_SoundSystem.EmitSoundDyn( m_pPlayer.edict(), CHAN_WEAPON, "hlclassic/weapons/sniper_fire.wav", 1.0f, ATTN_NORM, 0, PITCH_NORM );

		// player "shoot" animation
		m_pPlayer.SetAnimation( PLAYER_ATTACK1 );

		m_pPlayer.m_iWeaponVolume = LOUD_GUN_VOLUME;
		m_pPlayer.m_iWeaponFlash = BRIGHT_GUN_FLASH;

		Vector vecSrc		= m_pPlayer.GetGunPosition();
		Vector vecAiming	= g_Engine.v_forward;

		m_pPlayer.FireBullets( 1, vecSrc, vecAiming, Vector( flSpread, flSpread, flSpread ), 8192, BULLET_PLAYER_SNIPER, 0 );

		self.m_flNextPrimaryAttack = WeaponTimeBase() + 1.75f;

		if( self.m_iClip == 0 && m_pPlayer.m_rgAmmo( self.m_iPrimaryAmmoType ) <= 0 )
			// HEV suit - indicate out of ammo condition
			m_pPlayer.SetSuitUpdate( "!HEV_AMO0", false, 0 );

		m_pPlayer.pev.punchangle.x = -5.0;

		self.m_flTimeWeaponIdle = WeaponTimeBase() + 68.0 / 38.0;

		TraceResult tr;

		float x, y;

		g_Utility.GetCircularGaussianSpread( x, y );

		Vector vecDir = vecAiming + x * flSpread * g_Engine.v_right + y * flSpread * g_Engine.v_up;

		Vector vecEnd = vecSrc + vecDir * 8192;

		g_Utility.TraceLine( vecSrc, vecEnd, dont_ignore_monsters, m_pPlayer.edict(), tr );

		if( tr.flFraction < 1.0 )
		{
			if( tr.pHit !is null )
			{
				CBaseEntity@ pHit = g_EntityFuncs.Instance( tr.pHit );

				if( pHit is null || pHit.IsBSPModel() )
					g_WeaponFuncs.DecalGunshot( tr, BULLET_PLAYER_SNIPER );
			}
		}
	}

	void Reload()
	{
		if( m_pPlayer.m_rgAmmo( self.m_iPrimaryAmmoType ) <= 0 || self.m_iClip == SNIPERRIFLE_MAX_CLIP )
			return;

		if( m_pPlayer.pev.fov != 0 )
		{
			SecondaryAttack();
		}

		if( self.m_iClip == 0 )
		{
			self.DefaultReload( SNIPERRIFLE_MAX_CLIP, SNIPER_RELOAD1, 80.0f / 34.0f );
			m_fSniperReload = true;
			self.m_flNextPrimaryAttack = WeaponTimeBase() + (80.0f / 34.0f + 49.0f / 27.0f);
			self.m_flTimeWeaponIdle = WeaponTimeBase() + (80.0f / 34.0f + 49.0f / 27.0f);
		}
		else
		{
			self.DefaultReload( SNIPERRIFLE_MAX_CLIP, SNIPER_RELOAD3, 2.25f );
			self.m_flNextPrimaryAttack = WeaponTimeBase() + 2.25;
			self.m_flTimeWeaponIdle = WeaponTimeBase() + 2.25;
		}

		//Set 3rd person reloading animation -Sniper
		BaseClass.Reload();
	}

	void ItemPostFrame()
	{
		if( m_fSniperReload )
		{
			if( m_pPlayer.m_flNextAttack <= WeaponTimeBase() )
			{
				m_fSniperReload = false;
				self.SendWeaponAnim( SNIPER_RELOAD2 );
				//m_pPlayer.m_flNextAttack = WeaponTimeBase() + 1.8;
			}

			return;
		}

		BaseClass.ItemPostFrame();
	}

	void WeaponIdle()
	{
		self.ResetEmptySound();

		m_pPlayer.GetAutoaimVector( AUTOAIM_10DEGREES );

		if( self.m_flTimeWeaponIdle > WeaponTimeBase() )
			return;

		int iAnim;
		if( self.m_iClip <= 0 )
		{
			iAnim = SNIPER_SLOWIDLE2;
			self.m_flTimeWeaponIdle = WeaponTimeBase() + 80.0f / 16.0f;
		}
		else
		{
			iAnim = SNIPER_SLOWIDLE1;
			self.m_flTimeWeaponIdle = WeaponTimeBase() + 67.5f / 16.0f;
		}
		self.SendWeaponAnim( iAnim );
	}
}

string GetOFSniperName()
{
	return "weapon_ofsniperrifle";
}

void RegisterOFSniper()
{
	g_CustomEntityFuncs.RegisterCustomEntity( "weapon_ofsniperrifle", GetOFSniperName() );
	g_ItemRegistry.RegisterWeapon( GetOFSniperName(), "hl_weapons", "m40a1", "", "ammo_762" );
}
