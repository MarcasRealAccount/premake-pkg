local p   = premake
local pkg = p.extensions.pkg

-- Index in array: major version
-- Element value:  max minor version (nil means not supported)
-- 1.0.0 -> 1.0.*
pkg.supportedRepoVersions = { nil, 0 }

newoption({
	trigger     = "pkg-prune",
	description = "Redownloads used repositories",
	category    = "pkg"
})

newoption({
	trigger     = "pkg-prune-full",
	description = "Deletes all repositories first",
	category    = "pkg"
})

function pkg:isRepoVersionSupported(version)
	if type(version) == "string" then
		version = self:semver(version, false)
	end
	
	if version[1] < 0 then return false end
	
	if version[1] > #self.supportedRepoVersions then return false end
	
	local maxMinor = self.supportedRepoVersions[version[1]]
	if maxMinor == nil then return false end
	if version[2] < 0 then return false end
	return version[2] <= maxMinor
end

function pkg:isVersionInRange(version, range)
	if type(version) == "string" then
		version = self:semver(version, false)
	end
	if type(range) == "string" then
		range = self:semverRange(range, false)
	end
	
	if version[1] < 0 or range[1][1] < 0 or range[2][1] < 0 then return false end
	
	if range[1][4] == 0 then
		-- Inclusive lower
		if version[1] < range[1][1] then return false end
		if version[2] < range[1][2] then return false end
		if version[3] < range[1][3] then return false end
	else
		-- Exclusive lower
		if version[1] <= range[1][1] then return false end
		if version[2] <= range[1][2] then return false end
		if version[3] <= range[1][3] then return false end
	end
	if range[2][4] == 0 then
		-- Inclusive upper
		if version[1] > range[2][1] then return false end
		if version[2] > range[2][2] then return false end
		if version[3] > range[2][3] then return false end
	else
		-- Exclusive upper
		if version[1] >= range[2][1] then return false end
		if version[2] >= range[2][2] then return false end
		if version[3] >= range[2][3] then return false end
	end
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
		
		return { major, minor, patch }
	end
	return { -1, 0, 0 }
end

function pkg:semverRange(range, allowString)
	if type(range) == "string" then
		local found, _, lbrack, lmajor, lminor, lpatch, umajor, uminor, upatch, ubrack = range:find("^([%(%[])(%d+)%.(%d+)%.?(%d*),(%d+)%.(%d+)%.?(%d*)([%)%]])$")
		if not found then
			local ver = self:semver(range, allowString)
			ver[4] = 0
			return { ver, ver }
		end
		return { { lmajor, lminor, lpatch, iif(lbrack == "(", 0, 1) }, { umajor, uminor, upatch, iif(ubrack == "(", 0, 1) } }
	end
	return { { -1, 0, 0, 0 }, { -1, 0, 0, 0 } }
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
	local index   = name:find("@", 1, true)
	if not index then
		return name, ""
	end
	return name:sub(1, index - 1), name:sub(index + 1)
end

function pkg:addRepo(repo)
	table.insert(self.repos, {
		path    = repo,
		updated = false,
		cloned  = false
	}, 1)
	self.updateRepos = true
end

function pkg:updateRepo(repo)
	if not repo then
		error("pkg repo is nil")
	end

	if not repo.path then
		error("pkg repo is missing a path")
	end

	if type(repo.path) ~= "string" then
		error("pkg repo path has to be a string")
	end

	local path     = repo.path
	local index    = path:find("+", 1, true)
	if not index then
		error(string.format("'%s' doesn't use an api, if github repo add 'github+'", path))
	end
	local apiName  = path:sub(1, index - 1)
	local repoPath = path:sub(index + 1)
	local repoapi  = pkg.repoapis[apiName]
	if not repoapi then
		error(string.format("'%s' uses unknown api '%s'", path, apiName))
	end
	repo.api     = repoapi
	repo.updated = true
	repoapi:updateRepo(repo, repoPath)
	repo.data = json.decode(io.readfile(string.format("%s/repo.json", repo.dir)))
	for _, extension in ipairs(repo.data.exts) do
		extension.isExtension = true
	end
	for _, pack in ipairs(repo.data.pkgs) do
		pack.isExtension = false
	end
end

function pkg:updateRepos()
	if not self.reloadRepos then
		return
	end
	self.reloadRepos = false
	if _OPTIONS["pkg-prune-full"] then
		common:rmdir(string.format("%s/repos/", self.dir))
	end
	for _, repo in ipairs(self.repos) do
		if not repo.updated then
			pkg:updateRepo(repo)
		end
	end
end

function pkg:getExtension(ext)
	for _, repo in ipairs(self.repos) do
		for _, extension in ipairs(repo.data.exts) do
			if extension.name == ext then
				return extension, repo
			end
		end
	end
	
	return nil, nil
end

function pkg:getPackage(pack)
	for _, repo in ipairs(self.repos) do
		for _, packa in ipairs(repo.data.pkgs) do
			if packa.name == pack then
				return packa, repo
			end
		end
	end
	
	return nil, nil
end

local function iterr(a, i)
	i = i - 1
	local v = a[i]
	if v then
		return i, v
	end
end

local function ipairsr(a)
	return iter, a, #a
end

function pkg:getPkgVersion(pack, version)
	if not version then
		version = pack.latest_version
	end

	if (type(version) == "string" and version:len() == 0) or (type(version) == "table" and #version == 0) then
		version = pack.latest_version
	end
	
	for _, ver in ipairsr(pack.versions) do
		if self:compatibleVersions(ver.version, version) then
			return ver
		end
	end
	return nil
end

function pkgrepos(repos)
	if type(repos) ~= "table" and type(repos) ~= "string" then
		error("pkgrepos argument #1 has to be either a table of strings or a string")
	end
	
	if type(repos) == "string" then
		pkgrepos({ repos })
		return
	end
	
	for _, repo in ipairs(repos) do
		if type(repo) ~= "string" then
			error("pkgrepos argument #1 has to be either a table of strings or a string")
		end
		
		pkg:addRepo(repo)
	end
end