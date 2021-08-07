class Melee : HurtBox abstract
{
	private bool bHitObstacle;
	private Vector3 ofs;
	private Vector3 angOfs;
	private Rotate r;
	
	// Animation
	private int shiftDuration; // Move the physical location of the melee weapon
	private Vector3 shiftOfs;
	private int swingDuration; // Swing the melee weapon
	private Vector3 swingAngles;
	
	int bonusDamage;
	Name bonusDamageType;
	class<Ammo> bonusType1;
	class<Ammo> bonusType2;
	int bonusUse;
	
	double bonusAilmentPower;
	class<Ailment> bonusAilmentType;
	int bonusAilmentDamage;
	
	property BonusDamage : bonusDamage;
	property BonusDamageType : bonusDamageType;
	property BonusType : bonusType1;
	property BonusType1 : bonusType1;
	property BonusType2 : bonusType2;
	property BonusUse : bonusUse;
	property BonusAilmentPower : bonusAilmentPower;
	property BonusAilmentType : bonusAilmentType;
	property BonusAilmentDamage : bonusAilmentDamage;
	
	deprecated("3.7") private int meleeFlags;
	flagdef Continuous : meleeFlags, 0; // Sweep area
	flagdef NoBonusCrit : meleeFlags, 1; // Bonus damage won't crit
	
	Default
	{
		Radius 1;
		Height 2;
		
		+NOBLOCKMAP
		+NOSECTOR
		+NODAMAGETHRUST
		+NOTONAUTOMAP
		+OBBACTOR.AUTOADJUSTSIZE
		+OBBACTOR.USEANGLE
		+OBBACTOR.USEPITCH
		+OBBACTOR.USEROLL
		+MELEE.CONTINUOUS
	}
	
	void SetOffset(Vector3 newOfs)
	{
		ofs = newOfs;
	}
	
	void SetAngles(Vector3 angs)
	{
		angOfs = angs;
	}
	
	void A_Swing(Vector3 angs, int dur = 0)
	{
		swingAngles = angs;
		swingDuration = 0;
		if (dur > 0)
			swingDuration = dur;
	}
	
	void A_Reposition(Vector3 angs, int dur = 0)
	{
		shiftOfs = angs;
		shiftDuration = 0;
		if (dur > 0)
			shiftDuration = dur;
	}
	
	void A_WarnBlock(double range, double ang)
	{
		ang = clamp(ang, 0, 180);
		if (!target || range <= 0 || ang <= 0)
			return;
		
		BlockThingsIterator it = BlockThingsIterator.Create(target, range);
		double rangeSq = range * range;
		RPGMonster mo;
		while (it.Next())
		{
			mo = RPGMonster(it.thing);
			if (!mo || mo == target || mo.health <= 0 || (target && !target.IsHostile(mo)))
				continue;
			
			if (AbsAngle(target.angle, target.AngleTo(mo)) <= ang && target.Distance3DSquared(mo) <= rangeSq)
				mo.Block(self);
		}
	}
	
	override void Tick()
	{
		if (!target || target.health <= 0)
		{
			Destroy();
			return;
		}
		
		hit = null;
		
		if (target.IsFrozen())
			return;
		
		if (!CheckNoDelay())
			return;
		
		if (tics > 0)
			--tics;
		while (!tics)
		{
			if (!SetState(CurState.NextState))
				return;
		}
		
		// Reorient based off holder's angles
		double pch = target.pitch;
		if (!target.player)
		{
			pch = 0;
			if (target.target)
			{
				Actor targ = target.target;
				Vector3 vecTo = target.Vec3To(targ) + (0,0,targ.height/2-targ.floorclip - (target.height/2-target.floorclip));
				pch = -VectorAngle(vecTo.xy.Length(), vecTo.z);
			}
		}
		
		r.SetAxes((target.angle, pch, target.roll));
		
		// Update offset
		if (shiftDuration > 0 && shiftDuration-- <= 0)
			shiftOfs = (0,0,0);
		
		ofs += shiftOfs;
		
		Vector3 f, r, u;
		[f, r, u] = r.GetAxes();
		Vector3 ofsDir = f*ofs.x + r*ofs.y + u*ofs.z;
		
		// Update position
		Vector3 origin = target.pos + (0,0,target.height/2-target.floorclip);
		if (target.player)
			origin.z += target.player.mo.AttackZOffset*target.player.crouchFactor;
		else
			origin.z += 8;
		
		SetXYZ(origin + ofsDir);
		
		// Swing
		if (swingDuration > 0 && swingDuration-- <= 0)
			swingAngles = (0,0,0);
		
		int steps = 1;
		if (bContinuous)
		{
			steps = ceil(max(swingAngles.x, swingAngles.y, swingAngles.z) / 3);
			if (!steps)
				steps = 1;
		}
		
		Vector3 stepAngs = swingAngles / steps;
		for (int i = 0; i < steps; ++i)
		{
			InterpolateSwing(stepAngs);
			if (bDestroyed)
				return;
		}
	}
	
	void InterpolateSwing(Vector3 step)
	{
		angOfs += step;
		Vector3 newDir = r.Rotate(angOfs.x, angOfs.y);
		angle = VectorAngle(newDir.x, newDir.y);
		pitch = -VectorAngle(newDir.xy.Length(), newDir.z);
		roll = target.roll + angOfs.z;
		
		UpdateBoxes();
		
		// TODO: Use block tracer to check for hitting obstacles
		
		BlockThingsIterator it = BlockThingsIterator.Create(target, radius);
		Actor mo;
		while (it.Next())
		{
			mo = it.thing;
			if (!mo || mo == target || !mo.bShootable || mo.bNonshootable || (mo.health <= 0 && !mo.bIceCorpse)
				|| (target && target.IsFriend(mo)))
			{
				continue;
			}
			
			if (!BoundingBox.CheckColliding(self, mo) || !CheckSight(mo, 15))
				continue;
			
			if (!CanCollideWith(mo) || !mo.CanCollideWith(self))
				continue;
			
			bool isBlock = mo is "BlockBox"; // TODO: More precise block box checking (order is important)
			mo.A_StartSound(AttackSound, CHAN_BODY, CHANF_OVERLAP);
					
			int flags = (!bNoCrit && hit.bCritical) ? DMG_CRIT : 0;
			
			bool doBonus = true;
			bool useNormal, useReserve;
			Ammo normal, reserve;
			if (bonusUse > 0 && !sv_infiniteammo && !target.FindInventory("PowerInfiniteAmmo"))
			{
				normal = Ammo(target.FindInventory(bonusType1));
				reserve = Ammo(target.FindInventory(bonusType2));
							
				if (normal)
				{
					if (normal.amount < bonusUse)
					{
						if (!reserve || (reserve.amount+normal.amount) < bonusUse)
							doBonus = false;
						else
						{
							if (normal.amount > 0)
								useNormal = true;
										
							useReserve = true;
						}
					}
					else
						useNormal = true;
				}
			}
						
			if (doBonus)
			{
				int modDmg = bonusDamage;
				if ((flags & DMG_CRIT) && !bNoBonusCrit)
					modDmg = round(modDmg * hit.damageMultiplier);
							
				int dmg = mo.DamageMobj(self, target, modDmg, bonusDamageType, bNoBonusCrit ? 0 : flags);
				if (dmg > 0 && (mo.bIsMonster || mo.player))
				{
					if (useNormal || useReserve)
					{
						int cost = bonusUse;	
						if (normal && useNormal)
						{
							int take = min(normal.amount, bonusCost);
							cost -= take;
							normal.amount -= take;
						}
									
						if (reserve && useReserve)
							reserve.amount -= cost;
					}
						
					BonusAttack(mo);
				}
			}
			
			int dmg = round(damage * hit.damageMultiplier);
			int newdam = mo.DamageMobj(self, target, dmg, damageType, flags);
			
			if (!bBloodlessImpact)
				SpawnBlood(mo, dmg, newdam);
		}
	}
	
	void SpawnBlood(Actor mo, int intialDamage, int realDamage)
	{
		if (!mo || mo.bNoBlood)
			return;
		
		if (!mo.bNoBloodDecals)
			mo.TraceBleed(realDamage > 0 ? realDamage : intialDamage, target);
		
		double srcAng = AngleTo(mo);
		Vector3 spot = mo.pos + (0,0, pos.z - mo.pos.z-mo.floorclip);
		spot.xy = mo.Vec2Offset(mo.radius*cos(srcAng+180), mo.radius*sin(srcAng+180));
		
		mo.SpawnLineAttackBlood(target, spot, srcAng, intialDamage, realDamage);
	}
	
	override void ApplyAilment(Actor victim, int dmg, Name dmgType)
	{
		if (dmgType == bonusDamageType)
		{
			let ail = Ailment(victim.FindInventory(bonusAilmentType));
			if (ail)
				ail.AddAilment(target, bonusAilmentPower, bonusAilmentDamage);
		}
		else
			super.ApplyAilment(victim, dmg, dmgType);
	}
	
	virtual void BonusAttack(Actor mo) {}
}