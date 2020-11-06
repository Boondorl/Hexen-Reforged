class Marker : Actor
{
	Default
	{
		FloatBobPhase 0;
		Radius 1;
		Height 2;
		Scale 0.1;
		
		+SYNCHRONIZED
		+NOBLOCKMAP
		+DONTBLAST
		+NOTONAUTOMAP
		+SPRITEANGLE
		+FORCEXYBILLBOARD
	}
	
	override void Tick()
	{
		if (!tics--)
			Destroy();
	}
	
	States
	{
		Spawn:
			DMFX A 1 Bright;
			Stop;
	}
}