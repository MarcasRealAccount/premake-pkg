local p        = premake
local pkg      = p.extensions.pkg
pkg.pack       = pkg.pack or {}
local pack     = pkg.pack
pack.version   = pack.version or {}
local version  = pack.version
pkg.repo       = pkg.repo or {}
local pkgrepo  = pkg.repo
pkg.repoapis   = pkg.repoapis or {}
local repoapis = pkg.repoapis
repoapis.debug = repoapis.debug or { name = "debug" }
local dbg      = repoapis.debug
local semver   = pkg.semver

function dbg:supportsBuilt()
	return false
end

function dbg:isCleanable()
	return false
end

function dbg:normalizePath(repopath)
	return path.getabsolute(path.normalize(repopath))
end

function dbg:getRepoDir(repo)
	return repo.path
end

function dbg:load(repo)
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

function dbg:purgeFull()
end