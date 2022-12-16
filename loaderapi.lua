local p   = premake
local pkg = p.extensions.pkg

function pkg:getLoaderAPI(path)
	local index = path:find("+", 1, true)
	if not index then
		return pkg.loaderapis.fallback, path
	end
	
	local apiName   = path:sub(1, index - 1)
	local filepath  = path:sub(index + 1)
	local loaderapi = pkg.loaderapis[apiName]
	if not loaderapi then
		error(string.format("Invalid loader api '%s' used in path '%s'", apiName, path))
	end
	return loaderapi, filepath
end