// TODO: Checks for object destroying itself
class Missile : BBHurtBox
{
	static const double windTab[] = { 5/32., 10/32., 25/32. };
	const EPSILON = 1 / 65536.;
	
	deprecated("3.7") private int missileFlags;
	flagdef Continuous : missileFlags, 0;
	
	Default
	{
		Projectile;
		
		+MISSILE.CONTINUOUS
	}
	
	override void Tick()
	{
		if (IsFrozen())
			return;
		
		if (bWindThrust && waterlevel < 2 && !bNoClip)
		{
			int special = CurSector.special;
			switch (special)
			{
				case 40: case 41: case 42: // Wind_East
					Thrust(windTab[special-40], 0);
					break;
					
				case 43: case 44: case 45: // Wind_North
					Thrust(windTab[special-43], 90);
					break;
					
				case 46: case 47: case 48: // Wind_South
					Thrust(windTab[special-46], 270);
					break;
					
				case 49: case 50: case 51: // Wind_West
					Thrust(windTab[special-49], 180);
					break;
			}
		}
		
		double oldz = pos.z;
		if (!(vel ~== (0,0,0)))
			InterpolateMovement();
		if (bDestroyed)
			return;
		
		if (!bNoGravity && pos.z > floorz)
		{
			if (!waterLevel)
				vel.z -= GetGravity();
			else
			{
				double sinkspeed = -0.5 * clamp(mass, 1, 4000) / 100;
				if (vel.z < sinkspeed)
				{
					vel.z -= max(sinkspeed*2, -8);
					if (vel.z > sinkspeed)
						vel.z = sinkspeed;
				}
				else if (vel.z > sinkspeed)
				{
					vel.z += max(sinkspeed/3, -8);
					if (vel.z < sinkspeed)
						vel.z = sinkspeed;
				}
			}
		}
		
		CheckFakeFloorTriggers(oldz);
		UpdateWaterLevel();
		
		if (!CheckNoDelay())
			return;
		
		if (tics > 0)
			--tics;
		while (!tics)
		{
			if (!SetState(CurState.NextState))
				return;
		}
		
		UpdateBoxes();
	}
	
	void InterpolateMovement()
	{
		int steps = 1;
		if (bContinuous)
		{
			int radSteps, heightSteps;
			if (radius > 0)
				radSteps = ceil(vel.xy.Length() / radius);
			if (height > 0)
				heightSteps = ceil(abs(vel.z) / height);
			
			steps = max(radSteps, heightSteps);
		}
		
		FCheckPosition tm;
		tm.DoRipping = bRipper;
		Vector3 frac = vel / steps;
		for (int i = 0; i < steps; ++i)
		{
			BlockingMobj = null;
			BlockingLine = null;
			BlockingCeiling = BlockingFloor = Blocking3DFloor = null;
			Vector2 dest = pos.xy + frac.xy;
			double oldAng = angle;
			
			bool xyGood = XYMovement(frac.xy, tm);
			if (bDestroyed)
				return;
			
			if (xyGood && pos.xy != dest)
			{
				if (vel.xy ~== (0,0))
					xyGood = false;
				else if (angle != oldAng)
					frac.xy = RotateVector(frac.xy, DeltaAngle(oldAng, angle));
			}
			
			if (BlockingFloor && BlockingFloor.SecActTarget)
				BlockingFloor.TriggerSectorActions(self, SectorAction.SECSPAC_HitFloor);
			if (BlockingCeiling && BlockingCeiling.SecActTarget)
				BlockingCeiling.TriggerSectorActions(self, SectorAction.SECSPAC_HitCeiling);
			
			bool zGood = true;
			if (!(vel.z ~== 0) || BlockingMobj || pos.z != floorz)
				zGood = ZMovement(frac.z);
			if (bDestroyed || !xyGood || !zGood)
				return;
		}
	}
	
	bool XYMovement(Vector2 move, FCheckPosition tm)
	{
		if (!TryMove(pos.xy + move, 0, true, tm))
		{
			if (!BlockingLine && !BlockingMobj)
			{
				if (tm.ceilingSector && pos.z+height > tm.ceilingSector.ceilingPlane.ZAtPoint(tm.pos.xy))
					BlockingCeiling = tm.ceilingSector;
				if (tm.floorSector && pos.z < tm.floorSector.floorPlane.ZAtPoint(tm.pos.xy))
					BlockingFloor = tm.floorSector;
				
				CheckFor3DFloorHit(floorz, false);
				CheckFor3DCeilingHit(ceilingz, false);
			}
			
			if (bMissile)
			{
				if (BlockingMobj)
				{
					if (bAllowBounceOnActors)
					{
						if (!BounceActor(BlockingMobj))
							ExplodeMissile(null, BlockingMobj);
						
						return false;
					}
				}
				else if (BlockingLine)
				{
					if (BounceWall(BlockingLine))
					{
						PlayBounceSound(false);
						return false;
					}
				}
					
				if (BlockingMobj && BlockingMobj.bReflective)
				{
					if (ReflectActor(BlockingMobj))
						return false;
				}
				
				bool onsky;
				if (BlockingLine && BlockingLine.special == Line_Horizon)
				{
					if (!bSkyExplode)
					{
						Destroy();
						return false;
					}
					else
						onsky = true;
				}
				
				let l = tm.ceilingline;
				if (l && l.backsector && l.backsector.GetTexture(sector.ceiling) == skyflatnum)
				{
					let posr = PosRelative(l.backsector);
					if (pos.z >= l.backsector.ceilingplane.ZatPoint(posr.xy))
					{
						if (!bSkyExplode)
						{
							Destroy();
							return false;
						}
						else
							onsky = true;
					}
				}
				
				if (BlockingCeiling)
					Destructible.ProjectileHitPlane(self, SECPART_Ceiling);
				if (BlockingFloor)
					Destructible.ProjectileHitPlane(self, SECPART_Floor);
					
				ExplodeMissile(BlockingLine, BlockingMobj, onsky);
				return false;
			}
			else
			{
				vel.xy = (0,0);
				return false;
			}
		}
		
		return true;
	}
	
	bool ZMovement(double move)
	{
		AddZ(move);
				
		// Did we hit the floor?
		if (pos.z <= floorz)
		{
			if (CurSector.SecActTarget && CurSector.floorPlane.ZAtPoint(pos.xy) == floorz)
				CurSector.TriggerSectorActions(self, SectorAction.SECSPAC_HitFloor);
			
			CheckFor3DFloorHit(floorz, true);
			if (pos.z <= floorz)
			{
				BlockingFloor = CurSector;
				if (bMissile && !bNoClip)
				{
					SetZ(floorz);
					if (bBounceOnFloors)
					{
						BouncePlane(CurSector.floorPlane);
						return false;
					}
					else if (bNoExplodeFloor)
					{
						HitFloor();
						vel.z = 0;
						return false;
					}
					else if (bFloorHugger && !bNoDropOff)
						return false;
					else
					{
						bool onsky = false;
						if (floorpic == skyflatnum)
						{
							if (!bSkyExplode)
							{
								Destroy();
								return false;
							}
							else
								onsky = true;
						}
							
						HitFloor();
						Destructible.ProjectileHitPlane(self, SECPART_Floor);
						ExplodeMissile(null, null, onsky);
						return false;
					}
				}
				
				SetZ(floorz);
				if (vel.z < 0)
				{
					HitFloor();
					vel.z = 0;
				}
			}
		}
				
		// Did we hit the ceiling?
		if (pos.z + height > ceilingz)
		{
			if (CurSector.SecActTarget && CurSector.ceilingPlane.ZAtPoint(pos.xy) == ceilingz)
				CurSector.TriggerSectorActions(self, SectorAction.SECSPAC_HitCeiling);
			
			CheckFor3DCeilingHit(ceilingz, true);
			if (pos.z + height > ceilingz)
			{
				BlockingCeiling = CurSector;
				SetZ(ceilingz - height);
					
				if (bBounceOnCeilings)
				{
					BouncePlane(CurSector.ceilingPlane);
					return false;
				}
					
				if (vel.z > 0)
					vel.z = 0;
					
				if (bMissile && !bNoClip)
				{
					if (bCeilingHugger)
						return false;
						
					bool onsky = false;
					if (ceilingpic == skyflatnum)
					{
						if (!bSkyExplode)
						{
							Destroy();
							return false;
						}
						else
							onsky = true;
					}
						
					Destructible.ProjectileHitPlane(self, SECPART_Ceiling);
					ExplodeMissile(null, null, onsky);
					return false;
				}
			}
		}
				
		CheckPortalTransition();
		
		return true;
	}
	
	bool ReflectActor(Actor mo)
	{
		if (!mo || mo.bThruReflect)
			return false;
		
		if (!CheckReflect(mo))
			return false;
			
		Actor targ  = target ? target : mo.target;
		if (mo.bAimReflect && targ)
		{
			Vector3 dir = Vec3To(targ) + (0,0,targ.height/2 - height/2);
			vel = dir.Unit() * vel.Length();
		}
		else if (mo.bMirrorReflect)
		{
			vel *= -1;
		}
		else
		{
			Vector3 norm = (mo.Vec3To(self) + (0,0,height/2 - mo.height/2)).Unit();
			Vector3 u = (vel dot norm)*norm;
			vel = (vel - u) - u;
			
			if (mo.bShieldReflect || mo.bDeflect)
			{
				double ang = mo.angle;
				if (DeltaAngle(mo.angle, mo.AngleTo(self)) < 0)
					ang -= 45;
				else
					ang += 45;
					
				vel.xy = AngleToVector(ang, vel.xy.Length());
			}
		}
			
		angle = VectorAngle(vel.x, vel.y);
		
		if (bSeekerMissile)
			tracer = target;
		target = mo;
		
		return true;
	}
	
	bool CheckReflect(Actor mo)
	{
		if (bDontReflect)
			return false;
		if (!mo || mo.bThruReflect)
			return true;
		
		if (mo.bShieldReflect && (bNoShieldReflect || AbsAngle(mo.AngleTo(self), mo.angle) > 45))
			return false;
		
		return true;
	}
	
	bool BounceActor(Actor mo)
	{
		if (!mo)
			return false;
		
		if (mo.bReflective && mo.bThruReflect)
			return true;
		
		if (bBounceOnActors
			|| ((!bRipper || mo.bDontRip || (bNoBossRip && mo.bBoss)) && mo.bReflective)
			|| (!mo.player && !mo.bIsMonster))
		{
			if (bRipper && mo.bShootable && !bBounceOnUnrippables && mo.bDontRip)
				return true;
			
			if (mo.bShootable && bDontBounceOnShootables)
				bounceCount = 1;
			
			if (bounceCount > 0 && !--bounceCount)
			{
				ExplodeMissile(null, mo);
				return true;
			}
			
			if (bHitTarget)
				target = mo;
			if (bHitMaster)
				master = mo;
			if (bHitTracer)
				tracer = mo;
			
			Vector3 norm = (mo.Vec3To(self) + (0,0,height/2 - mo.height/2)).Unit();
			Vector3 u = (vel dot norm)*norm;
			vel = (vel - u) - u;
			vel *= BounceFactor;
			PlayBounceSound(true);
			
			angle = VectorAngle(vel.x, vel.y);
			
			if (bUseBounceState)
			{
				State bounce = FindState("Bounce");
				if (bounce)
					SetState(bounce);
			}
			
			return true;
		}
		
		return false;
	}
	
	bool BounceWall(Line l)
	{
		if (!l || !bBounceOnWalls)
			return false;
		
		bool onsky;
		if (l.special == Line_Horizon)
			onsky = true;
		
		if (!onsky && bDontBounceOnSky && l.backsector
			&& l.backsector.GetTexture(Sector.ceiling) == skyflatnum)
		{
			let posr = PosRelative(l.backsector);
			if (pos.z >= l.backsector.ceilingplane.ZatPoint(posr.xy))
				onsky = true;
		}
		
		if (onsky)
		{
			SeeSound = BounceSound = "";
			Destroy();
			return true;
		}
		
		if (Destructible.ProjectileHitLinedef(self, l) && bouncecount > 0)
		{
			ExplodeMissile(l);
			return true;
		}
		
		if (bounceCount > 0 && !--bounceCount)
		{
			ExplodeMissile(l);
			return true;
		}
		
		Vector2 normal;
		if (PointOnLineSide(pos.x, pos.y, l))
			normal = (l.delta.y, -l.delta.x);
		else
			normal = (-l.delta.y, l.delta.x);
			
		Vector2 u = ((vel.xy dot normal) / (normal dot normal))*normal;
		vel.xy = (vel.xy - u) - u;
		vel *= WallBounceFactor;
		
		angle = VectorAngle(vel.x, vel.y);
		
		if (BoxOnLineSide(pos.x+radius, pos.x-radius, pos.y+radius, pos.y-radius, l) == -1)
		{
			Vector2 ofs = AngleToVector(angle, radius);
			SetOrigin(Vec3Offset(ofs.x, ofs.y, 0), true);
		}
		
		if (bUseBounceState)
		{
			State bounce = FindState("Bounce");
			if (bounce)
				SetState(bounce);
		}
		
		return true;
	}
	
	bool BouncePlane(SecPlane plane)
	{
		if (!plane)
			return false;
		
		if (Destructible.ProjectileHitPlane(self, -1) && bounceCount > 0)
		{
			ExplodeMissile();
			return true;
		}
		
		if (pos.z <= floorz && HitFloor())
		{
			if (bExplodeOnWater)
			{
				ExplodeMissile();
				return true;
			}
			if (!bCanBounceWater)
			{
				Destroy();
				return true;
			}
		}
		
		bool onsky;
		if (plane.negiC < 0)
		{
			if (!bBounceOnCeilings)
				return true;
			
			onsky = ceilingpic == skyflatnum;
		}
		else
		{
			if (!bBounceOnFloors)
				return true;
			
			onsky = floorpic == skyflatnum;
		}
		
		if (onsky && !bDontBounceOnSky)
		{
			Destroy();
			return true;
		}
		
		if (bounceCount > 0 && !--bounceCount)
		{
			ExplodeMissile();
			return true;
		}
		
		Vector3 u = (vel dot plane.normal)*plane.normal;
		
		vel = (vel - u) - u;
		vel *= BounceFactor;
		
		angle = VectorAngle(vel.x, vel.y);
		
		PlayBounceSound(true);
		
		if (bUseBounceState)
		{
			State bounce = FindState("Bounce");
			if (bounce)
				SetState(bounce);
		}
		
		if (bBounceAutoOff || (bBounceAutoOffFloorOnly && plane.negiC > 0))
		{
			if (!bNoGravity && vel.z < 3)
				ClearBounce();
		}
		
		return false;
	}
	
	void PlayBounceSound(bool onfloor)
	{
		if (!onfloor && !bNoWallBounceSnd)
			return;
		
		if (!bNoBounceSound)
		{
			if (onfloor || !WallBounceSound)
				A_StartSound(BounceSound, CHAN_VOICE);
			else
				A_StartSound(WallBounceSound, CHAN_VOICE);
		}
	}
	
	private int PointOnLineSide(double x, double y, Line l)
	{
        return (y - l.v1.p.y)*l.delta.x + (l.v1.p.x - x)*l.delta.y > EPSILON;
    }
	
	private int BoxOnLineSide(double r, double l, double t, double b, Line ld)
	{
		int p1, p2;

		if (ld.delta.x == 0)
		{
			p1 = r < ld.v1.p.x;
			p2 = l < ld.v1.p.x;
			if (ld.delta.y < 0)
			{
				p1 ^= 1;
				p2 ^= 1;
			}
		}
		else if (ld.delta.y == 0)
		{
			p1 = t > ld.v1.p.y;
			p2 = b > ld.v1.p.y;
			if (ld.delta.x < 0)
			{
				p1 ^= 1;
				p2 ^= 1;
			}
		}
		else if ((ld.delta.x * ld.delta.y) >= 0)
		{
			p1 = PointOnLineSide(l, t, ld);
			p2 = PointOnLineSide(r, b, ld);
		}
		else
		{
			p1 = PointOnLineSide(r, t, ld);
			p2 = PointOnLineSide(l, b, ld);
		}

		return (p1 == p2) ? p1 : -1;
	}
}