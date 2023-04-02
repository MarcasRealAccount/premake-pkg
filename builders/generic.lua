local p          = premake
local pkg        = p.extensions.pkg
pkg.builders     = pkg.builders or {}
local builders   = pkg.builders
builders.generic = builders.generic or {}
local generic    = builders.generic

function generic:new()
	local object = {
		configs   = {},
		binDir    = "",
		buildDir  = "",
		cleanable = false
	}
	setmetatable(object, self)
	self.__index = self
	return object
end

function generic:setup(configs, buildDir)
	self.binDir    = string.format("%s/Bin/", pkg.currentPack.version.dir)
	self.buildDir  = path.normalize(buildDir) .. "/"
	self.cleanable = pkg.currentPack.repo.cleanable
	for _, config in ipairs(configs) do
		self.configs[config] = {}
	end
end

function generic:mapConfigs(configMap)
	for config, data in pairs(configMap) do
		local cfg = self.configs[config]
		cfg.data  = data
	end
end

function generic:cleanTemp()
	if not self.buildDir then return end
	if not self.cleanable then return end
	pkg:rmdir(self.buildDir)
end