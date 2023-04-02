local p    = premake
local pkg  = p.extensions.pkg
pkg.repo   = pkg.repo or {}
local repo = pkg.repo

-- Index in array: major version
-- Element value:  max minor version (nil means not supported)
-- 1.0.0 -> 1.0.*
repo.supportedRepoVersions = { nil, 0 }

function repo:new(api, path)
	local object = {
		api       = api,
		path      = path,
		loaded    = false,
		cleanable = api:isCleanable(),
		pkgs      = {},
		exts      = {}
	}
	setmetatable(object, self)
	self.__index = self
	return object
end

function repo:splitRepoName(name)
	local pindex = name:find("+", 1, true)
	if not pindex then return nil, name end
	
	local repoapi  = name:sub(1, pindex - 1)
	local repopath = name:sub(pindex + 1)
	return repoapi, repopath
end

function repo:isVersionSupported(version)
	if version.major < 0 then return false end
	if version.major > #self.supportedRepoVersions then return false end
	
	local maxMinor = self.supportedRepoVersions[version.major + 1]
	if maxMinor == nil then return false end
	if version.minor < 0 then return false end
	return version.minor <= maxMinor
end