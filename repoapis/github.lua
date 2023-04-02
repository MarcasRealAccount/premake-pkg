local p         = premake
local pkg       = p.extensions.pkg
pkg.pack        = pkg.pack or {}
local pack      = pkg.pack
pack.version    = pack.version or {}
local version   = pack.version
pkg.repo        = pkg.repo or {}
local pkgrepo   = pkg.repo
pkg.repoapis    = pkg.repoapis or {}
local repoapis  = pkg.repoapis
repoapis.github = repoapis.github or { name = "github" }
local github    = repoapis.github
local semver    = pkg.semver

function github:supportsBuilt()
	return true
end

function github:isCleanable()
	return false --true
end

function github:normalizePath(repopath)
	return repopath
end

function github:getRepoDir(repo)
	return string.format("%s/github/%s/", pkg.reposDir, repo.path:gsub("/", "-"))
end

function github:load(repo)
	local cloned = false
	if os.isdir(repo.dir) then cloned = true end
	
	if not cloned then
		local repoLink = string.format("https://github.com/%s.git", repo.path)
		if not os.executef("git clone \"%s\" \"%s\"", repoLink, repo.dir) then
			pkg:error("Failed to clone repo '%s'", repoLink)
			return false
		end
	elseif not os.executef("git -C \"%s\" pull -q", repo.dir) then
		pkg:error("Failed to update repo '%s'", repo.dir)
		return false
	end
	
	local data, err = json.decode(io.readfile(string.format("%s/repo.json", repo.dir)))
	if not data then
		pkg:error("Failed to load repo '%s'", repo.path)
		return false
	end
	if not pkgrepo:isVersionSupported(semver:fromArray(data.version)) then
		pkg:error("'%s' uses version '%s' which is not supported", repo.path, tostring(semver:fromArray(data.version)))
		return false
	end
	for _, ext in ipairs(data.exts) do
		local extension = pack:new(true, ext.name, ext.description, semver:fromArray(ext.latest_version))
		for _, ver in ipairs(ext.versions) do
			local res = version:new(semver:fromArray(ver.version), ver.path, ver.depscript or "init.lua", ver.buildscript, ver)
			if res then extension:addVersion(res) end
		end
		table.insert(repo.exts, extension)
	end
	for _, pkg in ipairs(data.pkgs) do
		local package_ = pack:new(false, pkg.name, pkg.description, semver:fromArray(pkg.latest_version))
		for _, ver in ipairs(pkg.versions) do
			local res = version:new(semver:fromArray(ver.version), ver.path, ver.depscript or "init.lua", ver.buildscript, ver)
			if res then package_:addVersion(res) end
		end
		table.insert(repo.pkgs, package_)
	end
	return true
end

function github:purgeFull()
	pkg:rmdir(string.format("%s/github/", pkg.reposDir))
end