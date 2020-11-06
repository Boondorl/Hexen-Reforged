/*
 * DamNums: by Xaser Acheron
 */

class DamNumHandler : EventHandler
{
	override void WorldThingDamaged(WorldEvent e)
	{
		if (!e.thing || !hr_dam_enabled || !hr_dam_spray)
			return;
		
		let dm = DamNumTracker(e.thing.FindInventory("DamNumTracker"));
		if (dm && dm.CanSpawn(e.thing))
		{
			Name damageType = e.DamageType;
			if (e.DamageFlags & (1<<20))
				damageType = 'Crit';
				
			dm.SpawnNumbers(e.Damage, damageType, e.thing.pos+(0,0,e.thing.height-e.thing.floorclip-16));
		}
	}

	override void WorldThingSpawned(WorldEvent e)
	{
		if (e.thing && e.thing.bShootable)
			e.thing.GiveInventory("DamNumTracker", 1);
	}
}

class DamNumTracker : Inventory
{
	private int prevHealth;
	
	Default
	{
		FloatBobPhase 0;
		Radius 1;
		Height 2;
		
		+INVENTORY.UNDROPPABLE
		+NOBLOCKMAP
		+NOSECTOR
		+SYNCHRONIZED
		+NOTONAUTOMAP
	}
	
	override void BeginPlay()
	{
		super.BeginPlay();
		
		ChangeStatNum(MAX_STATNUM);
	}

	override void AttachToOwner(Actor other)
	{
		super.AttachToOwner(other);
		
		if (owner)
			prevHealth = max(owner.health, 0);
	}
	
	override void Tick()
	{
		if (!owner)
		{
			Destroy();
			return;
		}
		
		int curHealth = max(owner.health, 0);
		if (hr_dam_enabled && !hr_dam_spray && CanSpawn(owner) && curHealth != prevHealth)
			SpawnNumbers(prevHealth-curHealth, owner.DamageTypeReceived, owner.pos+(0,0,owner.height-owner.floorclip-16));
		
		prevHealth = curHealth;
	}
	
	bool CanSpawn(Actor mo)
	{
		return mo && (mo.bIsMonster || mo.player || (hr_dam_shootable && mo.bShootable));
	}

	void SpawnNumbers(int dmg, Name dmgType, Vector3 position)
	{
		if (!dmg || dmgType == 'Massacre' || dmgType == 'Telefrag')
			return;
		
		if (dmg < 0)
			dmgType = "Heal";
		dmg = min(abs(dmg), DAMAGE_CAP);
		
		PlayerInfo curPlayer = players[consoleplayer];
		Vector3 dir;
		if (curPlayer.mo)
			dir = level.Vec3Diff(position, curPlayer.mo.pos);
		
		double ang = VectorAngle(dir.x, dir.y) + frandom[DamNum](-20,20);

		Cvar cv = CVar.GetCvar("hr_dam_physics", curPlayer);
		int physics = cv ? cv.GetInt() : 0;
		Vector3 nvel;
		bool noGravity;
		switch(physics)
		{
			case PHYSICS_TOSS:
				nvel = (cos(ang), sin(ang), frandom[DamNum](3,4));
				break;

			case PHYSICS_FLOAT:
				nvel = (0,0,1);
				noGravity = true;
				break;
		}

		cv = CVar.GetCvar("hr_dam_fontclass", curPlayer);
		string fontname = cv ? cv.GetString() : DEFAULT_NAME;

		class<DamNumFont> fontclass = fontname;
		let font = DamNumFont(GetDefaultByType(fontclass));

		cv = CVar.GetCvar("hr_dam_translation", curPlayer);
		string userTranslation = cv ? cv.GetString() : DEFAULT_PLACEHOLDER;
		string fontTrans = font ? font.fontTranslation : DEFAULT_TRANSLATION;
		if(userTranslation != DEFAULT_PLACEHOLDER)
			fontTrans = userTranslation;

		cv = CVar.GetCvar("hr_dam_usetypes", curPlayer);
		bool usedamagetype = cv ? cv.GetBool() : 0;
		if(usedamagetype && dmgType != 'None')
		{
			string typecolorname = COLOR_PREFIX..dmgType;
			string typecolor = Stringtable.Localize("$" .. typecolorname);
			if(typecolor != typecolorname)
				fontTrans = typecolor;
		}

		int place = 1;
		int length = log10(dmg) + 1;
		while(dmg > 0)
		{
			let damnum = DamNum(Spawn("DamNum", position, ALLOW_REPLACE));
			if(damnum)
			{
				damnum.vel = nvel;
				damnum.angle = ang;
				damnum.bNoGravity = noGravity;
				damnum.scale = font.scale;
				damnum.A_SetRenderStyle(font.alpha, font.GetRenderStyle());
				damnum.A_SetTranslation(fontTrans);
				damnum.fontPrefix = font.fontPrefix;
				damnum.digitCount = length;
				damnum.digitPlace = place;
				damnum.digitValue = dmg % 10;
				damnum.damageType = dmgType;
			}

			dmg /= 10;
			++place;
		}
	}
}
