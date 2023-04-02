local p           = premake
local pkg         = p.extensions.pkg
pkg.pack          = pkg.pack or {}
local pack        = pkg.pack
pack.version      = pack.version or {}
local version     = pack.version
pack.dep          = pack.dep or {}
local dep         = pack.dep
local semver      = pkg.semver
local semverRange = semver.range

function pack:new(isExt, name, description, latestVersion)
	local object = {
		isExtension   = isExt,
		name          = name,
		description   = description,
		latestVersion = latestVersion,
		versions      = {}
	}
	setmetatable(object, self)
	self.__index = self
	return object
end

function pack:addVersion(version)
	table.insert(self.versions, version)
end

function version:new(ver, path, script, buildscript, data)
	local packapi, packpath = self:splitPackPath(path)
	if not packapi then
		pkg:error("Pack path '%s' needs to specify a packapi like 'git+path'", name)
		return nil
	end
	local api = pkg.packapis[packapi]
	if not api then
		pkg:error("Packapi '%s' does not exist for '%s'", packapi, path)
		return nil
	end

	local object = {
		api         = api,
		path        = packpath,
		version     = ver,
		script      = script,
		buildscript = buildscript,
		data        = data,
		loaded      = false,
		built       = false
	}
	setmetatable(object, self)
	self.__index = self
	return object
end

function version:splitPackPath(path)
	local pindex = path:find("+", 1, true)
	if not pindex then return nil, path end
	
	local packapi  = path:sub(1, pindex - 1)
	local packpath = path:sub(pindex + 1)
	return packapi, packpath
end

function dep:splitPackName(name)
	local vindex  = name:find("@", 1, true)
	local aindex  = name:find(":", vindex or 1, true)
	vindex        = vindex or aindex or name:len() + 1
	aindex        = aindex or name:len() + 1
	
	local packName = name:sub(1, vindex - 1)
	local verStr   = name:sub(vindex + 1, aindex - 1)
	local argsStr  = name:sub(aindex + 1)
	
	local verRange = nil
	if verStr:len() == 0 then
		verRange = semverRange:inf()
	else
		verRange = semverRange:parse(verStr)
	end
	
	local args = {}
	if argsStr:len() > 0 then
		for lhs, rhs in a:gmatch("([^ =]+)=([^,]+)") do
			args[lhs] = rhs
		end
	end
	return packName, verRange, args
end