local p                 = premake
local pkg               = p.extensions.pkg
pkg.loaderapis          = pkg.loaderapis or {}
pkg.loaderapis.fallback = pkg.loaderapis.fallback or {}
local fallback          = pkg.loaderapis.fallback

function fallback:loadPackage(repo, pack, version, filepath)
	version.fullPath = path.getabsolute(filepath, repo.dir)
	return true
end