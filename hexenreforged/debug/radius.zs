class RadiusDebugHandler : EventHandler
{
	override void WorldThingSpawned(WorldEvent e)
	{
		if (e.thing && e.thing is "OBBActor")
		{
			let rad = Actor.Spawn("RadiusDebug");
			if (rad)
				rad.master = e.thing;
		}
	}
}

class RadiusDebug : Actor
{
	private Vector2 prevSize;
	private Vector3 prevPos;
	
	Default
	{
		FloatBobPhase 0;
		Radius 1;
		Height 2;
		
		+SYNCHRONIZED
		+NOBLOCKMAP
		+DONTBLAST
		+NOTONAUTOMAP
	}
	
	override void PostBeginPlay()
	{
		super.PostBeginPlay();
		
		prevSize = (radius, height);
		prevPos = pos;
	}

	override void Tick()
	{
		if (!master)
		{
			Destroy();
			return;
		}
		
		Vector2 newSize = (master.radius, master.height);
		if (newSize != prevSize)
		{
			A_SetSize(newSize.x, newSize.y);
			scale.x = newSize.x * 2;
			scale.y = newSize.y * level.pixelStretch;
		}
		
		Vector3 newPos = master.pos;
		if (newPos != prevPos)
			SetOrigin(newPos, true);
		
		prevSize = newSize;
		prevPos = newPos;
	}

	States
	{
		Spawn:
			0000 A -1 Bright;
			Stop;
	}
}