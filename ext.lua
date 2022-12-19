local p   = premake
local pkg = p.extensions.pkg

function pkg:requireExtension(extension)
	self:updateRepos()
	
	local ext, version = self:splitPkgName(extension)
	local exte, repo   = self:getExtension(ext)
	if not exte then
		error(string.format("Failed to find extension '%s'", ext))
	end
	local range = self:semverRange(version, true)
	local vers  = self:getPkgVersion(exte, range)
	if not vers then
		error(string.format("Failed to find version '%s' for extension '%s'", version, extension))
	end
	
	if vers.loaded then
		return
	end
	
	local loaderAPI, filepath = self:getLoaderAPI(vers.path)
	loaderAPI:loadPackage(repo, exte, vers, filepath)
	dofile(vers.fullPath .. "/init.lua")
	vers.loaded = true
end

function pkgexts(extensions)
	if type(extensions) ~= "table" and type(extensions) ~= "string" then
		error("pkgexts argument #1 has to be either a table of strings or a string")
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
			error("pkgexts argument #1 has to be either a table of strings or a string")
		end
		
		pkg:requireExtension(extension)
	end
end