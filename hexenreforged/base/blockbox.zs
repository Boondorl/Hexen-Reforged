class BlockBox : OBBActor
{
	private bool bPlayerParry;
	private BoundingBox masterBox;
	
	protected Array<Actor> alreadyBlocked;
	
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
		+SHOOTABLE
		+REFLECTIVE
		+NORADIUSDMG
		+NODAMAGETHRUST
		+NEVERTARGET
		+OBBACTOR.AUTOADJUSTSIZE
	}
	
	override void MarkPrecacheSounds()
	{
		super.MarkPrecacheSounds();
		
		MarkSound(blockSound);
	}
	
	override void UpdateBox(BoundingBox box)
	{
		if (master)
			box.SetAxes(master.angle, master.pitch, master.roll);
	}
	
	override void Tick()
	{
		if (!master)
		{
			masterBox.Destroy();
			Destroy();
			return;
		}
		
		if (bPlayerParry)
		{
			State unblock = master.FindState("Unblock");
			if (unblock && master.health > 0)
			{
				rpgm.SetState(unblock);
				return;
			}
			else
				bPlayerParry = false;
		}
		
		if (!masterBox)
		{
			masterBox = new("BoundingBox");
			masterBox.bOriented = true;
		}
		
		if (master.player)
			masterBox.SetAxes((master.angle,master.pitch,master.roll));
		else if (master.bIsMonster && master.target)
		{
			Vector3 diff = master.Vec3To(master.target) + (0,0,master.target.height/2 - master.height/2);
			masterBox.SetAxes((VectorAngle(diff.x, diff.y), -VectorAngle(diff.xy.Length(), diff.z), 0));
		}
		
		Vector3 f, r, u;
		[f, r, u] = masterBox.GetAxes();
		
		Vector3 ofs = r*sideOffset + (0,0,upOffset);
		if (master.player)
			ofs.z *= master.player.crouchFactor;
		
		Vector3 origin = master.Vec3Offset(ofs.y, ofs.y, ofs.z);
		let tracer = new("ShieldTracer");
		if (tracer)
		{
			tracer.master = master;
			tracer.maxDistance = forwardOffset;
			tracer.Trace(origin, level.PointInSector(origin.xy), f, forwardOffset, TRACE_ReportPortals);
				origin += f*(tracer.results.distance);
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
		if ((flags & DMG_EXPLOSION) || alreadyBlocked.Find(inflictor) != alreadyBlocked.Size())
			return -1;
		
		double reduction = 1 - (parryWindow > 0 ? parryReduction : blockReduction);
		A_StartSound(blockSound, CHAN_AUTO);
		damage = round(damage * reduction);
			
		if (parryWindow > 0)
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
		
		Actor inflict = self;
		if ((inflictor is 'RPGMissile' && RPGMissile(inflictor).bShieldBuster) ||
			(inflictor is 'HurtBox' && HurtBox(inflictor).bShieldBuster))
		{
			inflict = inflictor;
		}
			
		master.DamageMobj(inflict, source, damage, mod, flags, angle);
		
		return -1;
	}
}