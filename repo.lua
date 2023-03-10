local p   = premake
local pkg = p.extensions.pkg

-- Index in array: major version
-- Element value:  max minor version (nil means not supported)
-- 1.0.0 -> 1.0.*
pkg.supportedRepoVersions = { nil, 0 }

newoption({
	trigger     = "pkg-purge",
	description = "Redownloads used repositories",
	category    = "pkg"
})

newoption({
	trigger     = "pkg-purge-full",
	description = "Deletes all repositories first",
	category    = "pkg"
})

function pkg:isRepoVersionSupported(version)
	if type(version) == "string" then
		version = self:semver(version, false)
	end
	
	if version[1] < 0 then return false end
	
	if version[1] > #self.supportedRepoVersions then return false end
	
	local maxMinor = self.supportedRepoVersions[version[1] + 1]
	if maxMinor == nil then return false end
	if version[2] < 0 then return false end
	return version[2] <= maxMinor
end

function pkg:isVersionGreater(a, b)
	if a[1] < 0 or b[1] < 0 then return false end
	if a[1] < b[1] then return true end
	if a[2] < b[2] then return true end
	if a[3] < b[3] then return true end
	return false
end

function pkg:isVersionInRange(version, range)
	if type(version) == "string" then
		version = self:semver(version, false)
	end
	if type(range) == "string" then
		range = self:semverRange(range, false)
	end
	
	if version[1] < 0 or range[1][1] < 0 or range[2][1] < 0 then return false end
	
	repeat
		if range[1][4] == 0 then
			-- Inclusive lower
			if version[1] < range[1][1] then
				return false
			elseif version[1] > range[1][1] then
				break
			end
			if version[2] < range[1][2] then
				return false
			elseif version[2] > range[1][2] then
				break
			end
			if range[1][3] >= 0 then
				if version[3] < range[1][3] then
					return false
				elseif version[3] > range[1][3] then
					break
				end
			end
		else
			-- Exclusive lower
			if version[1] < range[1][1] then
				return false
			elseif version[1] > range[1][1] then
				break
			end
			if version[2] < range[1][2] then
				return false
			elseif version[2] > range[1][2] then
				break
			end
			if range[1][3] >= 0 then
				if version[3] < range[1][3] then
					return false
				elseif version[3] > range[1][3] then
					break
				end
				return false
			end
		end
	until true
	repeat
		if range[2][4] == 0 then
			-- Inclusive upper
			if version[1] > range[2][1] then
				return false
			elseif version[1] < range[2][1] then
				break
			end
			if version[2] > range[2][2] then
				return false
			elseif version[2] < range[2][2] then
				break
			end
			if range[2][3] >= 0 then
				if version[3] > range[2][3] then
					return false
				elseif version[3] < range[2][3] then
					break
				end
			end
		else
			-- Exclusive upper
			if version[1] > range[2][1] then
				return false
			elseif version[1] < range[2][1] then
				break
			end
			if version[2] > range[2][2] then
				return false
			elseif version[2] < range[2][2] then
				break
			end
			if range[2][3] >= 0 then
				if version[3] > range[2][3] then
					return false
				elseif version[3] < range[2][3] then
					break
				end
				return false
			end
		end
	until true
	return true
end

function pkg:semver(version, allowString)
	if type(version) == "string" then
		local found, _, major, minor, patch = version:find("^(%d+)%.(%d+)%.(%d+)$")
		if not found then
			if allowString then
				return version
			else
				return { -1, 0, 0 }
			end
		end
		
		return { tonumber(major), tonumber(minor), tonumber(patch) }
	end
	return { -1, 0, 0 }
end

function pkg:semverToString(version)
	if type(version) == "string" then return version end
	return string.format("%d.%d.%d", version[1], version[2], version[3])
end

function pkg:semverRange(range, allowString)
	if type(range) == "string" then
		local found, _, lbrack, lmajor, lminor, lpatch, umajor, uminor, upatch, ubrack = range:find("^([%(%[])(%d+)%.(%d+)%.?(%d*),(%d+)%.(%d+)%.?(%d*)([%)%]])$")
		if not found then
			local ver = self:semver(range, allowString)
			if type(ver) == "string" then return ver end
			ver[4] = 0
			return { ver, ver }
		end
		if lpatch:len() == 0 or upatch:len() == 0 then
			lpatch = -1
			upatch = -1
		end
		return { { tonumber(lmajor), tonumber(lminor), tonumber(lpatch), iif(lbrack == "(", 1, 0) }, { tonumber(umajor), tonumber(uminor), tonumber(upatch), iif(ubrack == ")", 1, 0) } }
	end
	return { { -1, 0, 0, 0 }, { -1, 0, 0, 0 } }
end

function pkg:semverRangeToString(range)
	if range[1][4] == 0 and range[2][4] == 0 then
		if range[1][1] == range[2][1] and range[1][2] == range[2][2] and range[1][3] == range[2][3] then
			return pkg:semverToString(range[1])
		end
	end
	local lbrack = iif(range[1][4] == 0, "[", "(")
	local ubrack = iif(range[2][4] == 0, "]", ")")
	if range[1][3] < 0 or range[2][3] < 0 then
		return string.format("%s%d.%d,%d.%d%s", lbrack, range[1][1], range[1][2], range[2][1], range[2][2], ubrack)
	end
	return string.format("%s%d.%d.%d,%d.%d.%d%s", lbrack, range[1][1], range[1][2], range[1][3], range[2][1], range[2][2], range[2][3], ubrack)
end

function pkg:compatibleVersions(a, b)
	if type(a) == "string" and type(b) == "string" then
		return a == b
	elseif type(a) == "table" and type(b) == "table" then
		return self:isVersionInRange(a, b)
	else
		return false
	end
end

function pkg:splitPkgName(name)
	local vindex = name:find("@", 1, true)
	local aindex = name:find(":", vindex or 1, true)
	vindex       = vindex or aindex or name:len() + 1
	aindex       = aindex or name:len() + 1
	local n,v,a = name:sub(1, vindex - 1), name:sub(vindex + 1, aindex - 1), name:sub(aindex + 1)
	if v:len() == 0 then v = "" end
	if a:len() == 0 then
		a = {}
	else
		local t = {}
		for lhs, rhs in a:gmatch("([^ =]+)=([^ ]+)") do
			t[lhs] = rhs
		end
		a = t
	end
	return n,v,a
end

function pkg:addRepo(repo)
	table.insert(self.repos, 1, {
		path    = repo,
		updated = false,
		cloned  = false
	})
	self.updateRepos = true
end

function pkg:updateRepo(repo)
	repo.updated = true
	if not repo then
		common:fail("pkg repo is nil")
		return false
	end

	if not repo.path then
		common:fail("pkg repo is missing a path")
		return false
	end

	if type(repo.path) ~= "string" then
		common:fail("pkg repo path has to be a string")
		return false
	end

	local path     = repo.path
	local index    = path:find("+", 1, true)
	if not index then
		common:fail("'%s' doesn't use an api, if githug repo add the 'github+' prefix", path)
		return false
	end
	local apiName  = path:sub(1, index - 1)
	local repoPath = path:sub(index + 1)
	local repoapi  = pkg.repoapis[apiName]
	if not repoapi then
		common:fail("'%s' uses unknown api '%s'", path, apiName)
		return false
	end
	repo.api     = repoapi
	repoapi:updateRepo(repo, repoPath)
	repo.data = json.decode(io.readfile(string.format("%s/repo.json", repo.dir)))
	if not self:isRepoVersionSupported(repo.data.version) then
		common:fail("'%s' uses version '%s' which is not supported", path, self:semverToString(repo.data.version))
		return false
	end
	for _, extension in ipairs(repo.data.exts) do
		extension.isExtension = true
	end
	for _, pack in ipairs(repo.data.pkgs) do
		pack.isExtension = false
	end
	return true
end

function pkg:updateRepos()
	if not self.reloadRepos then
		return
	end
	self.reloadRepos = false
	if _OPTIONS["pkg-purge-full"] then
		common:rmdir(string.format("%s/repos/", self.dir))
	end
	for _, repo in ipairs(self.repos) do
		if not repo.updated then
			pkg:updateRepo(repo)
		end
	end
end

function pkg:getExtensions(ext)
	local exts = {}

	for _, repo in ipairs(self.repos) do
		for _, extension in ipairs(repo.data.exts) do
			if extension.name == ext then
				table.insert(exts, { extension, repo })
			end
		end
	end

	return exts
end

function pkg:getPackages(pack)
	local pkgs = {}

	for _, repo in ipairs(self.repos) do
		for _, packa in ipairs(repo.data.pkgs) do
			if packa.name == pack then
				table.insert(pkgs, { packa, repo })
			end
		end
	end

	return pkgs
end

function pkg:getPkgVersion(packs, version)
	if not packs or #packs == 0 then
		return nil, nil, nil
	end

	if not version then
		if type(packs[1][1].latest_version) == "string" then
			version = packs[1][1].latest_version
		else
			version = { packs[1][1].latest_version, packs[1][1].latest_version }
			version[1][4] = 0
			version[2][4] = 0
		end
	elseif type(version) == "string" then
		if version:len() == 0 then
			if type(packs[1][1].latest_version) == "string" then
				version = packs[1][1].latest_version
			else
				version = { packs[1][1].latest_version, packs[1][1].latest_version }
				version[1][4] = 0
				version[2][4] = 0
			end
		end
	elseif type(version) == "table" then
		if #version == 0 then
			if type(packs[1][1].latest_version) == "string" then
				version = packs[1][1].latest_version
			else
				version = { packs[1][1].latest_version, packs[1][1].latest_version }
				version[1][4] = 0
				version[2][4] = 0
			end
		end
	end
	
	local newestVersion = nil
	local bestPack      = nil
	local bestRepo      = nil
	for _, pack in ipairs(packs) do
		for _, ver in ipairs(pack[1].versions) do
			if self:compatibleVersions(ver.version, version) then
				if not newestVersion then
					newestVersion = ver
					bestPack      = pack[1]
					bestRepo      = pack[2]
				elseif self:isVersionGreater(newestVersion, self:semver(ver.version, false)) then
					newestVersion = ver
					bestPack      = pack[1]
					bestRepo      = pack[2]
				end
			end
		end
	end
	return bestRepo, bestPack, newestVersion
end

function pkgrepos(repos)
	if type(repos) ~= "table" and type(repos) ~= "string" then
		common:fail("pkgrepos argument #1 has to be either a table of strings or a string")
		return
	end
	
	if type(repos) == "string" then
		pkgrepos({ repos })
		return
	end
	
	for _, repo in ipairs(repos) do
		if type(repo) ~= "string" then
			common:fail("pkgrepos argument #1 has to be either a table of strings or a string")
			return
		end
		
		pkg:addRepo(repo)
	end
end