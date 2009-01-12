local type, debug, table, unpack, error, ipairs, select, io = type, debug, table, unpack, error, ipairs, select, io

module(...)

local CheckTypes = {}

CheckTypes.expect = function (value, valType)
	if valType == "nil" then
		return
	end
	if type(value) ~= valType then
		error("Expected "..valType.." not "..type(value).."!"..debug.traceback())
	end
end

CheckTypes.checkTypes = function (...)
	local total, params, func, result, i, resultFlag = select("#", ...), {}, nil, {}, 0, false
	for i = 1, total do
		local param = select(i, ...)
		if not resultFlag then
			if type(param) == "function" then
				resultFlag = true
				func = param
			else
				table.insert(params, param)
			end
		else
			table.insert(result, param)
		end
	end
	return function (...)
		local i, v
		-- Test input
		for i, v in ipairs(params) do
			CheckTypes.expect(select(i, ...), v)
		end
		-- Call
		local realResult = {func(...)}
		-- Test result
		for i, v in ipairs(result) do
			CheckTypes.expect(realResult[i], v)
		end
		return unpack(realResult)
	end
end

return CheckTypes