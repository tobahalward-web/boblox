-- Flattens an Instance tree into a list of part descriptors for tools/render.py
-- returns a Lua array of { sh, mesh, cf = {x,y,z,r11..r33}, sz = {x,y,z}, col = {r,g,b}, t, neon }
return function(root, only)
	local out = {}
	local function describe(d)
		if not (d:IsA("BasePart")) then return end
		local cf = d.CFrame
		local sh = "Block"
		if d.ClassName == "WedgePart" then
			sh = "Wedge"
		elseif d.ClassName == "CornerWedgePart" then
			sh = "CornerWedge"
		else
			local s = d.Shape
			if s and s.Name then sh = s.Name end
		end
		local mesh = nil
		for _, c in ipairs(d:GetChildren()) do
			if c.ClassName == "SpecialMesh" and c.MeshType and c.MeshType.Name == "Sphere" then
				mesh = "Sphere"
			end
		end
		local mat = d.Material and d.Material.Name or "Plastic"
		local col = d.Color
		local size = d.Size
		out[#out + 1] = {
			sh = sh, mesh = mesh, mat = mat,
			cf = { cf.p.X, cf.p.Y, cf.p.Z, table.unpack(cf.r) },
			sz = { size.X, size.Y, size.Z },
			col = { col.R * 255, col.G * 255, col.B * 255 },
			t = d.Transparency or 0,
			neon = mat == "Neon",
			name = d.Name,
		}
	end
	if only then
		for _, d in ipairs(only) do describe(d) end
	else
		describe(root)
		for _, d in ipairs(root:GetDescendants()) do describe(d) end
	end
	return out
end
