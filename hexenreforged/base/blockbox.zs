class BlockTracer : LineTracer
{
	Actor master;
	
	void Reset()
	{
		results.hitType = TRACE_HitNone;
		results.ffloor = null;
	}
	
	override ETraceStatus TraceCallback()
    {
		switch (results.HitType)
		{
			case TRACE_CrossingPortal:
				results.hitType = TRACE_HitNone;
				break;
				
			case TRACE_HitWall:
				if (results.tier == TIER_Middle
					&& (results.hitLine.flags & Line.ML_TWOSIDED)
					&& !(results.hitLine.flags & (Line.ML_BLOCKING|Line.ML_BLOCKEVERYTHING)))
				{
					break;
				}
			case TRACE_HitFloor:
			case TRACE_HitCeiling:
				if (results.ffloor
					&& (!(results.ffloor.flags & F3DFloor.FF_EXISTS)
					|| !(results.ffloor.flags & F3DFloor.FF_SOLID)))
				{
					results.ffloor = null;
					break;
				}
				return TRACE_Stop;
				break;
			
			case TRACE_HitActor:
				if (results.hitActor != master && results.hitActor.bSolid)
					return TRACE_Stop;
				break;
		}
		
		results.distance = 0;
        return TRACE_Skip;
    }
}

class BlockBox : OBBActor abstract
{
	private Vector3 angles;
	
	double forwardOffset;
	double sideOffset;
	double upOffset;
	sound blockSound;
	double blockReduction;
	double parryReduction;
	int parryWindow;
	
	property Roll : roll;
	property ForwardOffset : forwardOffset;
	property SideOffset : sideOffset;
	property UpOffset : upOffset;
	property BlockSound : blockSound;
	property BlockReduction : blockReduction;
	property ParryReduction : parryReduction;
	property ParryWindow : parryWindow;
	
	Default
	{
		+NOBLOOD
		+SHOOTABLE
		+REFLECTIVE
		+NORADIUSDMG
		+NODAMAGETHRUST
		+NEVERTARGET
		+OBBACTOR.AUTOADJUSTSIZE
	}
	
	void Unblock()
	{
		State unblock = master.FindState("Unblock");
		if (unblock)
			master.SetState(unblock);
	}
	
	void Parry()
	{
		State parry = master.FindState("Parry");
		if (parry)
			master.SetState(parry);
	}
	
	override void MarkPrecacheSounds()
	{
		super.MarkPrecacheSounds();
		
		MarkSound(blockSound);
	}
	
	override void UpdateBox(BoundingBox box)
	{
		Vector3 a = box.GetAngles();
		box.SetAxes(a + angles);
	}
	
	override void Tick()
	{
		if (!master || master.health <= 0)
		{
			Destroy();
			return;
		}
		
		angles = (master.angle, 0, master.roll);
		if (master.player)
			angles.y = master.pitch;
		else if (master.target)
		{
			Vector3 diff = master.Vec3To(master.target) + (0,0,master.target.height/2 - master.height/2);
			angles.y = -VectorAngle(diff.xy.Length(), diff.z);
		}
		
		Rotate r;
		r.SetAxes(angles);
		Vector3 f, r, u;
		[f, r, u] = r.GetAxes();
		
		Vector3 ofs = r*sideOffset + (0,0,upOffset);
		if (master.player)
			ofs.z *= master.player.crouchFactor;
		
		Vector3 origin = master.Vec3Offset(ofs.x, ofs.y, ofs.z);
		let tracer = new("BlockTracer");
		if (tracer)
		{
			tracer.master = master;
			tracer.Trace(origin, level.PointInSector(origin.xy), f, forwardOffset, TRACE_ReportPortals);
			origin = level.Vec3Offset(origin, f*tracer.results.distance);
		}
			
		SetOrigin(origin, true);
		
		if (parryWindow > 0)
		{
			if (--parryWindow <= 0)
				bReflective = false;
		}
		
		UpdateBoxes();
	}
	
	override int DamageMobj(Actor inflictor, Actor source, int damage, Name mod, int flags, double angle)
	{
		if ((flags & DMG_EXPLOSION) || (!source && !inflictor))
			return -1;
		
		double reduction = 1 - (parryWindow > 0 ? parryReduction : blockReduction);
		A_StartSound(blockSound, CHAN_BODY);
		damage = round(damage * reduction);
		
		bool noParry;
		let hb = HurtBox(inflictor);
		if (hb)
		{
			if (hb.bGuardBreaker)
			{
				Parry();
				master.DamageMobj(inflictor, source, damage, mod, flags, angle);
				return -1;
			}
			
			noParry = hb.bUnparryable;
		}
			
		if (!noParry && parryWindow > 0)
		{
			if (inflictor && inflictor.bMissile && inflictor.target != master)
			{
				double realPch = master.pitch;
				if (!master.player && master.target)
				{
					Vector3 forw = master.Vec3To(master.target) + (0,0,(master.target.height/2-master.target.floorclip) - (master.height/2-master.floorclip));
					realPch = -VectorAngle(forw.xy.Length(), forw.z);
				}
				
				Vector3 dir = (AngleToVector(master.angle, cos(realPch)), -sin(realPch));
				let missile = Spawn(inflictor.GetClass(), inflictor.pos);
				if (missile)
				{
					missile.vel = dir * GetDefaultSpeed(inflictor.GetClass());
					missile.target = master;
					missile.tracer = source;
					missile.angle = master.angle;
					missile.SetState(inflictor.CurState);
					missile.tics = inflictor.tics;
					alreadyHit.Push(inflictor);
					inflictor.Destroy();
				}
			}
			else if (source && inflictor && (inflictor.bIsMonster || inflictor is 'HurtBox'))
			{
				if (source is 'RPGMonster')
				{
					let rpgm = RPGMonster(source);
					rpgm.bCancelled = true;
								
					State parry = source.FindState("Parry");
					if (parry)
						source.SetState(parry);
				}
				else if (source is 'RPGPlayer')
				{
					let weap = RPGMelee(source.player.ReadyWeapon);
					if (weap)
					{
						State parry = weap.FindState("Parry");
						if (parry)
						{
							weap.bCancelled = true;
							bPlayerParry = true;
							source.player.SetPsprite(PSP_WEAPON, parry);
						}
					}
				}
				else
				{
					State pain = source.FindState("Pain");
					if (pain)
						source.SetState(pain);
				}
			}
		}
			
		master.DamageMobj(inflictor, source, damage, mod, flags, angle);
		
		return -1;
	}
}