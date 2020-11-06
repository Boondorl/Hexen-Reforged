/*
 * DamNums: by Xaser Acheron
 *
 * Base Font class -- this is an Actor since it not only defines some properties,
 * but also serves to load the font's sprites into memory. Without this step,
 * GetSpriteIndex will return junk when trying to access any of the sprites.
 */

class DamNumFont : Actor
{
	string fontPrefix;
	string fontTranslation;

	property FontPrefix : fontPrefix;
	property FontTranslation : fontTranslation;

	Default
	{
		FloatBobPhase 0;
		Radius 1;
		Height 2;
		DamNumFont.FontPrefix DEFAULT_PREFIX;
		DamNumFont.FontTranslation DEFAULT_TRANSLATION;
		
		+NOBLOCKMAP
		+NOSECTOR
		+SYNCHRONIZED
		+DONTBLAST
		+NOTONAUTOMAP
	}
	
	override void Tick() {}
}
