class BBHurtBox : OBBActor
{
	protected Array<Actor> alreadyHit;
	protected bool bCriticalHit;
	
	double ailmentPower;
	class<Ailment> ailmentType;
	int ailmentDamage;
	
	property AilmentPower : ailmentPower;
	property AilmentType : ailmentType;
	property AilmentDamage : ailmentDamage;
	
	deprecated("3.7") private int hurtBoxFlags;
	flagdef GuardBreaker : hurtBoxFlags, 0; // Force parry state against shields
	flagdef ThruBlock : hurtBoxFlags, 1; // Go through shields
	flagdef AilmentThruBlock : hurtBoxFlags, 2; // Apply ailment when hitting shields
	flagdef Unparryable : hurtBoxFlags, 3; // Can't parry this
}