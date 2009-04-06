require"luv.debug"
require"luv.table"
local string, table, unpack, select, debug, error, loadstring, assert = string, table, unpack, select, debug, error, loadstring, assert
local type, tostring, pairs, io = type, tostring, pairs, io

module(...)

string.slice = string.sub

string.capitalize = function (self)
	if string.len(self) == 0 then return self end
	return string.upper(string.slice(self, 1, 1))..string.slice(self, 2)
end

string.beginsWith = function (str, beg)
	if 1 ~= string.find(str, beg, 1, true) then
		return false
	end
	return true
end

string.endsWith = function (str, search)
	if string.slice(str, -string.len(search)) ~= search then
		return false
	end
	return true
end

string.split = function (str, ...)
	local res, tail, i, len = {}, str, 1, select("#", ...)
	for i = 1, len do
		if not tail then break end
		local begPos, endPos = string.find(tail, select(i, ...), 1, true)
		if begPos then
			table.insert(res, string.slice(tail, 1, begPos-1))
			tail = string.slice(tail, endPos+1)
		end
	end
	table.insert(res, tail)
	return unpack(res)
end

string.findLast = function (self, substr)
	local i, lastPos = 1
	local begPos = string.find(self, substr, i, true)
	while begPos do
		lastPos = begPos
		i = begPos+1
		begPos = string.find(self, substr, i, true)
	end
	return lastPos
end

string.explode = function (self, ex)
	local res, tail, begPos, endPos = {}, self
	begPos, endPos = string.find(tail, ex, 1, true)
	while begPos do
		table.insert(res, string.slice(tail, 1, begPos-1))
		tail = string.slice(tail, endPos+1)
		begPos, endPos = string.find(tail, ex, 1, true)
	end
	table.insert(res, tail)
	return res
end

string.escape = function (self)
	return string.gsub(self, "\"", "\\\"")
end

--[[
local urlEncodeChars = {36=true;38;43;44;47;58;59;61;63;64}

string.urlEncode = function (self)
	local res, _, byte = ""
	for _, byte in ipairs({string.byte(self, 1, string.len(self))}) do
		if byte > 31 and byte < 127
		res = res..
	end
	return res
end]]

string.replace = string.gsub

string.serialize = function (self, seen)
	seen = seen or {}
	local selfType = type(self)
	if "string" == selfType then
		return '"'..string.escape(self)..'"'
	elseif "number" == selfType or "boolean" == selfType or "nil" == selfType  then
		return tostring(self)
	elseif "table" == selfType then
		local res, first, k, v = "{", true
		table.insert(seen, self)
		for k, v in pairs(self) do
			if "table" ~= type(v) or not table.find(seen, v) then
				if first then
					first = false
				else
					res = res..","
				end
				res = res.."["..string.serialize(k).."]="..string.serialize(v, seen)
			end
		end
		table.removeValue(seen, self)
		return res.."}"
	end
	return ""
end

string.unserialize = function (self)
	return assert(loadstring("return "..self))()
end

return string
