local p   = premake
local api = p.api

p.extensions     = p.extensions or {}
p.extensions.pkg = {
	_VERSION     = "1.0.0",
	dir          = common:scriptDir(),
	reloadRepos  = true,
	repos        = {
		{
			path    = "github+MarcasRealAccount/premake-pkgs",
			updated = false,
			cloned  = false
		}
	}
}

api.register({
	name   = "pkgdeps",
	scope  = "config",
	kind   = "list:mixed",
	tokens = true
})

return true