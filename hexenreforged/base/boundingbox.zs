// Object so it can be used with dynamic arrays
class BoundingBox : Object play
{
	Actor owner;
	
	private Vector3 size; // AABB
	private Vector3 dimensions; // OBB
	
	private Vector3 center;
	Vector3 offset; // Here because you can't have dynamic Vector3 arrays
	
	private Vector3 angles;
	private Vector3 forward;
	private Vector3 right;
	private Vector3 up;
	
	bool bDisabled;
	bool bOriented;
	
	// Gameplay
	String name;
	double damageMulti;
	bool bCritical;
	
	Vector3 GetSize()
	{
		return size;
	}
	
	Vector3 GetDimensions()
	{
		return dimensions;
	}
	
	Vector3 GetAngles()
	{
		return angles;
	}
	
	Vector3, Vector3, Vector3 GetAxes()
	{
		return forward, right, up;
	}
	
	Vector3 GetCenter()
	{
		return center;
	}
	
	Vector3, Vector3 GetMinMax()
	{
		return center - size, center + size;
	}
	
	Vector3 GetBoundingSize()
	{
		if (dimensions == (0,0,0))
			return (0,0,0);
		
		Vector3 f, r, u;
		f = forward * dimensions.x;
		r = right * dimensions.y;
		u = up * dimensions.z;
		
		Vector3 vertices[8];
		vertices[0] = center + f + r + u;
		vertices[1] = center + f - r + u;
		vertices[2] = center + f + r - u;
		vertices[3] = center + f - r - u;
		vertices[4] = center - f + r + u;
		vertices[5] = center - f - r + u;
		vertices[6] = center - f + r - u;
		vertices[7] = center - f - r - u;
		
		double xmin, xmax, ymin, ymax, zmin, zmax;
		xmax = ymax = zmax = -double.max;
		xmin = ymin = zmin = double.max;
		for (int i = 0; i < 8; ++i)
		{
			if (vertices[i].x > xmax)
				xmax = vertices[i].x;
			if (vertices[i].x < xmin)
				xmin = vertices[i].x;
			
			if (vertices[i].y > ymax)
				ymax = vertices[i].y;
			if (vertices[i].y < ymin)
				ymin = vertices[i].y;
			
			if (vertices[i].z > zmax)
				zmax = vertices[i].z;
			if (vertices[i].z < zmin)
				zmin = vertices[i].z;
		}
		
		return (xmax-xmin, ymax-ymin, zmax-zmin) / 2;
	}
	
	void SetPosition(Vector3 newPos)
	{
		center = newPos + offset;
		center.z += size.z;
	}
	
	void SetDimensions(Vector3 newDim)
	{
		Vector3 prev = dimensions;
		
		if (newDim.x >= 0)
			dimensions.x = newDim.x;
		if (newDim.y >= 0)
			dimensions.y = newDim.y;
		if (newDim.z >= 0)
			dimensions.z = newDim.z;
		
		if (dimensions != prev)
		{
			if (bOriented)
				size = GetBoundingSize();
			else
				size = dimensions;
		}
	}
	
	void SetAxes(Vector3 newAngles, bool force = false)
	{
		if (!bOriented)
			newAngles = (0,0,0);
		
		if (!force && newAngles == angles)
			return;
		
		angles = newAngles;
		
		if (bOriented)
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
			
			size = GetBoundingSize();
		}
		else
		{
			forward = (0,1,0);
			right = (1,0,0);
			up = (0,0,1);
		}
	}
	
	// For quickly checking Actor bounding boxes
	static bool CheckColliding(Actor origin, Actor mo)
	{
		if (!origin || !mo)
			return false;
		
		Vector3 orMin = origin.pos - (origin.radius, origin.radius, origin.floorclip);
		Vector3 orMax= origin.pos + (origin.radius, origin.radius, origin.height-origin.floorclip);
		
		Vector3 rel = mo.PosRelative(origin.CurSector);
		Vector3 moMin = rel - (mo.radius, mo.radius, mo.floorclip);
		Vector3 moMax = rel + (mo.radius, mo.radius, mo.height-mo.floorclip);
		
		return (orMin.x <= moMax.x && orMax.x >= moMin.x) &&
				(orMin.y <= moMax.y && orMax.y >= moMin.y) &&
				(orMin.z <= moMax.z && orMax.z >= moMin.z);
	}
	
	// TODO: Portal support
	static bool AABBColliding(BoundingBox origin, BoundingBox mo)
	{
		if (!origin || !mo)
			return false;
		
		Vector3 orMin, orMax;
		[orMin, orMax] = origin.GetMinMax();
		
		Vector3 moMin, moMax;
		[moMin, moMax] = mo.GetMinMax();
		
		return (orMin.x <= moMax.x && orMax.x >= moMin.x) &&
				(orMin.y <= moMax.y && orMax.y >= moMin.y) &&
				(orMin.z <= moMax.z && orMax.z >= moMin.z);
	}
	
	static bool OBBNotColliding(BoundingBox origin, BoundingBox mo)
	{
		if (!origin || !mo)
			return true;
		
		Vector3 t = mo.GetCenter() - origin.GetCenter();
		
		Vector3 d, f, r, u;
		d = origin.GetDimensions();
		[f, r, u] = origin.GetAxes();
		
		Vector3 md, mf, mr, mu;
		md = mo.GetDimensions();
		[mf, mr, mu] = mo.GetAxes();
		
		if (ProjectEdge(t, f, d.x, md.x, md.y, md.z, mf, mr, mu) ||
			ProjectEdge(t, r, d.y, md.x, md.y, md.z, mf, mr, mu) ||
			ProjectEdge(t, u, d.z, md.x, md.y, md.z, mf, mr, mu) ||
			ProjectEdge(t, mf, md.x, d.x, d.y, d.z, f, r, u) ||
			ProjectEdge(t, mr, md.y, d.x, d.y, d.z, f, r, u) ||
			ProjectEdge(t, mu, md.z, d.x, d.y, d.z, f, r, u))
		{
			return true;
		}
		
		if (ProjectPlane(t, f, d.y, d.z, mf, md.y, md.z, u, r, mu, mr) ||
			ProjectPlane(t, f, d.y, d.z, mr, md.x, md.z, u, r, mu, mf) ||
			ProjectPlane(t, f, d.y, d.z, mu, md.x, md.y, u, r, mr, mf) ||
			ProjectPlane(t, r, d.x, d.z, mf, md.y, md.z, u, f, mu, mr) ||
			ProjectPlane(t, r, d.x, d.z, mr, md.x, md.z, u, f, mu, mf) ||
			ProjectPlane(t, r, d.x, d.z, mu, md.x, md.y, u, f, mr, mf) ||
			ProjectPlane(t, u, d.x, d.y, mf, md.y, md.z, r, f, mu, mr) ||
			ProjectPlane(t, u, d.x, d.y, mr, md.x, md.z, r, f, mu, mf) ||
			ProjectPlane(t, u, d.x, d.y, mu, md.x, md.y, r, f, mr, mf))
		{
			return true;
		}
		
		return false;
	}
	
	private static bool ProjectEdge(Vector3 t, Vector3 axis, double aR, double bL, double bR, double bD, Vector3 forward, Vector3 right, Vector3 up)
	{
		return abs(t dot axis) > (aR + abs(axis dot (bL*forward)) + abs(axis dot (bR*right)) + abs(axis dot (bD*up)));
	}
	
	private static bool ProjectPlane(Vector3 t, Vector3 a1, double aR, double aD, Vector3 b1, double bR, double bD, Vector3 a2, Vector3 a3, Vector3 b2, Vector3 b3)
	{
		return abs(((t dot a2)*(a3 dot b1)) - ((t dot a3)*(a2 dot b1))) > (abs((aR*a2) dot b1) + abs((aD*a3) dot b1) + abs(a1 dot (bR*b2)) + abs(a1 dot (bD*b3)));
	}
}

class OBBActor : Actor
{
	private double shiftZ;
	
	Array<BoundingBox> boxes;
	
	deprecated("3.7") private int obbFlags;
	flagdef UseAngle : obbFlags, 0;
	flagdef UsePitch : obbFlags, 1;
	flagdef UseRoll : obbFlags, 2;
	flagdef DisableOnDeath : obbFlags, 3;
	flagdef AutoAdjustSize : obbFlags, 4;
	
	virtual void InitializeBoxes() {}
	
	virtual void UpdateBox(BoundingBox box) {}
	
	void UpdateBoxes()
	{
		AddZ(-shiftZ);
		shiftZ = 0;
		
		for (uint i = 0; i < boxes.Size(); ++i)
		{
			if (!boxes[i])
			{
				boxes.Delete(i--);
				continue;
			}
			
			boxes[i].bDisabled = (bDisableOnDeath && health <= 0 && !bIceCorpse);
			
			UpdateBox(boxes[i]);
			
			if (!boxes[i] || boxes[i].bDisabled)
				continue;
			
			Vector3 angles = boxes[i].GetAngles();
			if (bUseAngle)
				angles.x = angle;
			if (bUsePitch)
				angles.y = pitch;
			if (bUseRoll)
				angles.z = roll;
			boxes[i].SetAxes(angles);
			
			Vector3 newPos = pos;
			newPos.z -= floorclip;
			boxes[i].SetPosition(newPos);
		}
		
		if (bAutoAdjustSize)
		{
			Vector2 size;
			double newz;
			[size, newz] = GetBoundingArea();
			
			if (newz != pos.z)
			{
				shiftZ = newz - pos.z;
				AddZ(shiftZ);
			}
				
			height = size.y;
			if (size.x != radius) // This function is more expensive and as such should be avoided when possible
				A_SetSize(size.x);
		}
	}
	
	override void Tick()
	{
		super.Tick();
		if (bDestroyed)
			return;
		
		UpdateBoxes();
	}
	
	override void PostBeginPlay()
	{
		super.PostBeginPlay();
		
		InitializeBoxes();
	}
	
	override void OnDestroy()
	{
		for (uint i = 0; i < boxes.Size(); ++i)
		{
			if (boxes[i])
				boxes[i].Destroy();
		}
		
		super.OnDestroy();
	}
	
	Vector2, double GetBoundingArea()
	{
		uint size = boxes.Size();
		if (!size)
			return (radius, height), pos.z;
		
		double xmin, xmax, ymin, ymax, zmin, zmax;
		xmax = ymax = zmax = -double.max;
		xmin = ymin = zmin = double.max;
		
		Vector3 mini, maxi;
		for (uint i = 0; i < size; ++i)
		{
			[mini, maxi] = boxes[i].GetMinMax();
			if (maxi.x > xmax)
				xmax = maxi.x;
			if (mini.x < xmin)
				xmin = mini.x;
			
			if (maxi.y > ymax)
				ymax = maxi.y;
			if (mini.y < ymin)
				ymin = mini.y;
			
			if (maxi.z > zmax)
				zmax = maxi.z;
			if (mini.z < zmin)
				zmin = mini.z;
		}
		
		double realx = max(abs(xmax-pos.x), abs(pos.x-xmin));
		double realy = max(abs(ymax-pos.y), abs(pos.y-ymin));
		
		return (max(realx, realy), zmax-zmin), zmin;
	}
	
	void GetBoxes(out Array<BoundingBox> nonCrit, out Array<BoundingBox> crit)
	{
		for (uint i = 0; i < boxes.Size(); ++i)
		{
			if (!boxes[i] || boxes[i].bDisabled)
				continue;
			
			if (boxes[i].bCritical)
				crit.Push(boxes[i]);
			else
				nonCrit.Push(boxes[i]);
		}
	}
	
	BoundingBox FindBox(String name)
	{
		for (uint i = 0; i < boxes.Size(); ++i)
		{
			if (boxes[i] && boxes[i].name ~== name)
				return boxes[i];
		}
		
		return null;
	}
	
	BoundingBox PushBox(Vector3 size, Vector3 offset, bool oriented = false, String name = "", double multi = 1, bool crit = false)
	{
		let box = new("BoundingBox");
		if (!box)
			return null;
		
		box.owner = self;
		
		box.bOriented = oriented;
		box.SetAxes((bUseAngle ? angle : 0, bUsePitch ? pitch : 0, bUseRoll ? roll : 0), true);
		
		box.SetDimensions(size);
		
		box.offset = offset;
		box.SetPosition(pos);
		
		box.name = name;
		box.damageMulti = multi;
		box.bCritical = crit;
		
		boxes.Push(box);
		
		return box;
	}
}