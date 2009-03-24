require "luv.debug"
local os, table, pairs, ipairs, io, debug, tostring = os, table, pairs, ipairs, io, debug, tostring
local Object = require "luv.oop".Object

module(...)

local Debugger = Object:extend{
	__tag = .....".Debugger";
	debug = Object.abstractMethod;
	info = Object.abstractMethod;
	warn = Object.abstractMethod;
	error = Object.abstractMethod;
	flush = Object.abstractMethod;
}

local Fire = Debugger:extend{
	__tag = .....".Fire";
	defaultSectionName = "Default section";
	init = function (self)
		self.msgs = {}
	end;
	debug = function (self, msg, section)
		io.write("[", msg, section, "]")
		section = section or self.defaultSectionName
		self.msgs[section] = self.msgs[section] or {}
		table.insert(self.msgs[section], {level="log";msg=msg;time=os.clock()})
	end;
	info = function (self, msg, section)
		section = section or self.defaultSectionName
		self.msgs[section] = self.msgs[section] or {}
		table.insert(self.msgs[section], {level="info";msg=msg;time=os.clock()})
	end;
	warn = function (self, msg, section)
		section = section or self.defaultSectionName
		self.msgs[section] = self.msgs[section] or {}
		table.insert(self.msgs[section], {level="warn";msg=msg;time=os.clock()})
	end;
	error = function (self, msg, section)
		section = section or self.defaultSectionName
		self.msgs[section] = self.msgs[section] or {}
		table.insert(self.msgs[section], {level="error";msg=msg;time=os.clock()})
	end;
	__tostring = function (self)
		io.write("FLUSH!")
		debug.dump(self.msgs, 3)
		local res, section, msgs = "<script type=\"text/javascript\">//<![CDATA[\n"
		for section, msgs in pairs(self.msgs) do
			local _, info
			for _, info in ipairs(msgs) do
				res = res.."console."..info.level.."(\""..section..": "..info.msg.."\");\n"
			end
		end
		return res.."//]]></script>"
	end;
}

return {Debugger=Debugger;Fire=Fire}