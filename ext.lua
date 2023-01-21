local p   = premake
local pkg = p.extensions.pkg

function pkg:requireExtension(extension)
	self:updateRepos()
	
	local ext, version, args = self:splitPkgName(extension)
	local exts               = self:getExtensions(ext)
	if not exts or #exts == 0 then
		common:fail("Failed to find extension '%s'", ext)
		return
	end
	local range            = self:semverRange(version, true)
	local repo, exte, vers = self:getPkgVersion(exts, range)
	if not vers then
		common:fail("Failed to find version '%s' for extension '%s'", version, ext)
		return
	end
	
	if vers.loaded then
		return
	end
	
	local loaderAPI, filepath = self:getLoaderAPI(vers.path)
	loaderAPI:loadPackage(repo, exte, vers, filepath)
	_PKG_ARGS = args
	pcall(function() dofile(vers.fullPath .. "/init.lua") end)
	_PKG_ARGS = nil
	vers.loaded = true
end

function pkgexts(extensions)
	if type(extensions) ~= "table" and type(extensions) ~= "string" then
		common:fail("pkgexts argument #1 has to be either a table of strings or a string")
		return
	end
	
	if type(extensions) == "string" then
		pkgexts({ extensions })
		return
	end
	
	if #extensions == 0 then
		return
	end
	
	for _, extension in ipairs(extensions) do
		if type(extension) ~= "string" then
			common:fail("pkgexts argument #1 has to be either a table of strings or a string")
			return
		end
		
		pkg:requireExtension(extension)
	end
end