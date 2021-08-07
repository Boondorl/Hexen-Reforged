struct Rotate
{
	private Vector3 forward;
	private Vector3 right;
	private Vector3 up;
	
	private static Vector2 GetGaussian()
	{
		double u, v, s;
		do
		{
			u = frandom[Rotate](-1,1);
			v = frandom[Rotate](-1,1);
			s = u*u + v*v;
		} while (s >= 1 || !s);
		
		s = sqrt(-2*log(s) / s);
		
		return (u*s, v*s);
	}
	
	private static double ScaledGaussian(double mean, double standDev)
	{
		return mean + GetGaussian() * standDev;
	}
	
	static double BoxMuller(double min, double max, double deviations = 3)
	{
		double x;
		double mean = (max + min) / 2;
		double standDev = (max - min) / 2;
		double absMin = mean - standDev*deviations;
		double absMax = mean + standDev*deviations;
		
		do
		{
			x = ScaledGaussian(mean, standDev);
		} while (x < absMin || x > absMax);
		
		return x;
	}
	
	void SetAxes(Vector3 angles)
	{
		double ac, as, pc, ps, rc, rs;
		ac = cos(angles.x);
		as = sin(angles.x);
		pc = cos(angles.y);
		ps = sin(angles.y);
		rc = cos(angles.z);
		rs = sin(angles.z);
			
		forward = (ac*pc, as*pc, -ps);
		right = (-1*rs*ps*ac + -1*rc*-as, -1*rs*ps*as + -1*rc*ac, -1*rs*pc);
		up = (rc*ps*ac + -rs*-as, rc*ps*as + -rs*ac, rc*pc);
	}
	
	Vector3, Vector3, Vector3 GetAxes()
	{
		return forward, right, up;
	}
	
	Vector3 Rotate(double angOfs, double pchOfs)
	{
		return forward + right*tan(angOfs) + up*tan(pchOfs);
	}
	
	Vector3 Offset(double angle)
	{
		double theta = frandom[Rotator](0,360);
		double r = abs(angle) * sqrt(frandom[Rotator](0,1));
		
		return Rotate(r*cos(theta), r*sin(theta));
	}
	
	Vector3 GuassianOffset(double angle)
	{
		double theta = frandom[Rotator](0,360);
		double ang = abs(angle) / 3;
		double r = abs(Rotate.BoxMuller(-ang, ang));
		
		return Rotate(r*cos(theta), r*sin(theta));
	}
	
	Vector2 GetAngles(Vector3 dir)
	{
		return (VectorAngle(dir.x, dir.y), -VectorAngle(dir.xy.Length(), dir.z));
	}
}