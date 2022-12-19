local p   = premake
local api = p.api

p.extensions     = p.extensions or {}
p.extensions.pkg = {
	_VERSION     = "1.1.1",
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

return true