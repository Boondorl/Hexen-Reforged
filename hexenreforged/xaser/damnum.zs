/*
 * DamNums: by Xaser Acheron
 */

class DamNum : Actor
{
	string fontPrefix;
	int digitCount;
	int digitPlace;
	uint digitValue;
	
	Default
	{
		FloatBobPhase 0;
		Radius 1;
		Height 2;
		RenderStyle 'Add';
		Gravity 0.4;
		Scale 0.75;
		
		+BRIGHT
		+NOBLOCKMAP
		+NOTONAUTOMAP
		+SYNCHRONIZED
		+DONTBLAST
		+FORCEXYBILLBOARD
	}
	
	States
	{
		Spawn:
			#### ########## 1;
			#### # 1 A_FadeOut(0.05);
			Wait;
	}
	
	override void Tick()
	{
		SetOrigin(Vec3Offset(vel.x, vel.y, vel.z), true);
		
		if (!bNoGravity)
			vel.z -= gravity;
		
		if (tics > 0)
			--tics;
		while (!tics)
		{
			if (!SetState(CurState.NextState))
				return;
		}
	}

	override void PostBeginPlay()
	{
		super.PostBeginPlay();
		
		int digitCount = !digitCount ? 1 : digitCount;
		int digitPlace = !digitPlace ? 1 : digitPlace;
		string fontPrefix = fontPrefix == "" ? "ND" : fontPrefix;

		int spriteindex = GetSpriteIndex(fontPrefix .. digitCount .. digitPlace);
		if(spriteindex != -1)
		{
			sprite = spriteindex;
			frame = digitValue;
		}
		else
		{
			sprite = GetSpriteIndex('UNKN');
			frame = 0;
		}
	}
}
