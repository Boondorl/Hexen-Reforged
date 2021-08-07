class HurtBox : OBBActor abstract
{
	private BoundingBox tempBox; // In case something without a bounding box was hit
	
	protected Array<Actor> alreadyHit;
	protected BoundingBox hit;
	
	double ailmentPower;
	class<Ailment> ailmentType;
	int ailmentDamage;
	
	property Roll : roll;
	property AilmentPower : ailmentPower;
	property AilmentType : ailmentType;
	property AilmentDamage : ailmentDamage;
	
	deprecated("3.7") private int hurtBoxFlags;
	flagdef GuardBreaker : hurtBoxFlags, 0; // Force parry state when hitting shields
	flagdef ThruBlock : hurtBoxFlags, 1; // Ignore shields entirely
	flagdef AilmentThruBlock : hurtBoxFlags, 2; // Apply ailment when hitting shields
	flagdef Unparryable : hurtBoxFlags, 3; // Can't parry this, casual
	flagdef NoHitLimit : hurtBoxFlags, 4; // Hit things as many times as you want
	flagdef NoCrit : hurtBoxFlags, 5; // Don't apply bonus damage on crit
	flagdef NoBlockOnHit : hurtBoxFlags, 6; // Don't block when damaged by this
	
	Default
	{
		+ICESHATTER
		+NOICEDEATH
	}
	
	void ClearHit()
	{
		hit = null;
		if (tempBox)
			tempBox.Destroy();
	}
	
	override void Tick()
	{
		ClearHit();
		
		super.Tick();
	}
	
	override void OnDestroy()
	{
		if (tempBox)
			tempBox.Destroy();
		
		super.OnDestroy();
	}
	
	// Check if any of the OBBs colliding with other OBBs
	override bool CanCollideWith(Actor other, bool passive)
	{
		if ((!bNoHitLimit && alreadyHit.Find(other) != alreadyHit.Size())
			|| (bThruBlock && other is "BlockBox"))
		{
			return false;
		}
		
		// Ignore friendlies
		if (target && (target.IsFriend(other) || (other.master && target.IsFriend(other.master))))
			return false;
		
		bool collided;
		let oa = OBBActor(other);
		if (oa)
		{
			Array<BoundingBox> nonCrit, crit;
			oa.GetBoxes(nonCrit, crit);
			
			// Look for a critical hit first
			for (uint i = 0; !collided && i < boxes.Size(); ++i)
			{
				let b = boxes[i];
				if (!b)
					continue;
				
				for (uint j = 0; j < crit.Size(); ++j)
				{
					let box = crit[j];
					if (!box)
						continue;
					
					if (b.bOriented || box.bOriented)
					{
						if (!BoundingBox.OBBNotColliding(b, box));
						{
							collided = true;
							hit = box;
						}
					}
					else if (BoundingBox.AABBColliding(b, box))
					{
						collided = true;
						hit = box;
					}
				}
			}
			
			// Now search the regular hits
			for (uint i = 0; !collided && i < boxes.Size(); ++i)
			{
				let b = boxes[i];
				if (!b)
					continue;
				
				for (uint j = 0; j < nonCrit.Size(); ++j)
				{
					let box = nonCrit[j];
					if (!box)
						continue;
					
					if (b.bOriented || box.bOriented)
					{
						if (!BoundingBox.OBBNotColliding(b, box));
						{
							collided = true;
							hit = box;
						}
					}
					else if (BoundingBox.AABBColliding(b, box))
					{
						collided = true;
						hit = box;
					}
				}
			}
		}
		else
		{
			if (tempBox)
				tempBox.Destroy();
			
			tempBox = new("BoundingBox");
			tempBox.owner = other;
			tempBox.SetAngles((0,0,0), true);
			tempBox.SetDimensions((other.radius, other.radius, other.height/2));
			tempBox.SetPosition(other.pos - (0,0,other.floorclip));
			
			for (uint i = 0; !collided && i < boxes.Size(); ++i)
			{
				let b = boxes[i];
				if (!b)
					continue;
				
				if (b.bOriented)
				{
					if (!BoundingBox.OBBNotColliding(b, tempBox));
					{
						collided = true;
						hit = tempBox;
					}
				}
				else if (BoundingBox.AABBColliding(b, tempBox))
				{
					collided = true;
					hit = tempBox;
				}
			}
			
			if (!collided)
				tempBox.Destroy();
		}
		
		return collided;
	}
	
	// Apply ailments to the right target and track who was already hit
	override int DoSpecialDamage(Actor victim, int damage, name damagetype)
	{
		// Only apply ailments on direct hits
		if (!hit || hit.owner != victim)
			return super.DoSpecialDamage(victim, damage, damagetype);
		
		Actor targ = victim;
		if (victim.master && victim is "BlockBox")
		{
			if (alreadyHit.Find(victim.master) == alreadyHit.Size())
				alreadyHit.Push(victim.master);
			else
				return -1;
			
			if (bAilmentThruBlock)
				targ = victim.master;
		}
		
		if (alreadyHit.Find(victim) == alreadyHit.Size())
			alreadyHit.Push(victim);
		else
			return -1;
		
		ApplyAilment(targ, damage, damagetype);
		
		return super.DoSpecialDamage(victim, damage, damagetype);
	}
	
	virtual void ApplyAilment(Actor victim, int dmg, Name dmgType)
	{
		let ail = Ailment(victim.FindInventory(ailmentType));
		if (ail)
			ail.AddAilment(target, ailmentPower, ailmentDamage);
	}
}