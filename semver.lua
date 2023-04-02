local p      = premake
local pkg    = p.extensions.pkg
pkg.semver   = pkg.semver or {}
local semver = pkg.semver
semver.range = semver.range or {}
local range  = semver.range

function semver:new(major, minor, patch)
	local object = {
		major = major,
		minor = minor,
		patch = patch
	}
	setmetatable(object, self)
	self.__index = self
	return object
end

function semver:fromArray(arr)
	if type(arr) ~= "table" then return nil end
	if #arr < 2 then return nil end
	if #arr == 2 then return self:new(tonumber(arr[1]), tonumber(arr[2]), -1) end
	return self:new(tonumber(arr[1]), tonumber(arr[2]), tonumber(arr[3]))
end

function semver:parse(str)
	if type(str) ~= "string" then return nil end
	local found, _, major, minor, patch = str:find("^(%d+)%.(%d+)%.?(%d*)$")
	if not found then return nil end
	if patch:len() == 0 then patch = -1 end
	return self:new(tonumber(major), tonumber(minor), tonumber(patch))
end

function semver:__tostring()
	if self.patch < 0 then
		return string.format("%d.%d", self.major, self.minor)
	else
		return string.format("%d.%d.%d", self.major, self.minor, self.patch)
	end
end

function semver.__eq(lhs, rhs)
	return lhs.major == rhs.major and lhs.minor == rhs.minor and lhs.patch == rhs.patch
end

function semver.__lt(lhs, rhs)
	if lhs.major > rhs.major then return false elseif lhs.major < rhs.major then return true end
	if lhs.minor > rhs.minor then return false elseif lhs.minor < rhs.minor then return true end
	return lhs.patch < rhs.patch
end

function semver.__le(lhs, rhs)
	if lhs.major > rhs.major then return false elseif lhs.major < rhs.major then return true end
	if lhs.minor > rhs.minor then return false elseif lhs.minor < rhs.minor then return true end
	return lhs.patch <= rhs.patch
end

function range:new(minver, maxver, minbound, maxbound)
	local object = {
		minver   = minver,
		maxver   = maxver,
		minbound = minbound,
		maxbound = maxbound
	}
	setmetatable(object, self)
	self.__index = self
	return object
end

function range:inf()
	return self:new(nil, nil, true, true)
end

function range:parse(str)
	if type(str) ~= "string" then return nil end

	if str == "inf" then return self:inf() end

	local found, _, lbrack, lver, uver, ubrack = str:find("^([%(%[])([0-9%.]+),([0-9%.]+)([%)%]])$")
	if not found then return nil end
	local minver = semver:parse(lver)
	local maxver = semver:parse(uver)
	if not minver or not maxver then return nil end
	local minbound = iif(lbrack == "[", true, false)
	local maxbound = iif(ubrack == "]", true, false)
	return self:new(minver, maxver, minbound, maxbound)
end

function range:inRange(ver)
	if not self.minver or not self.maxver then return true end

	if self.minbound then
		if ver < self.minver then return false end
	else
		if ver <= self.minver then return false end
	end
	if self.maxbound then
		if ver > self.maxver then return false end
	else
		if ver >= self.maxver then return false end
	end
	return true
end

function range:__tostring()
	if not self.minver or not self.maxver then return "inf" end

	if self.minbound and self.maxbound then
		if self.minver == self.maxver then
			return self.minver:tostring()
		end
	end
	local lbrack = iif(self.minbound, "[", "(")
	local rbrack = iif(self.maxbound, "]", ")")
	return string.format("%s%s,%s%s", lbrack, tostring(self.minver), tostring(self.maxver), rbrack)
end