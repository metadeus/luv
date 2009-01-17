local require, io, select, type, next, getmetatable, setmetatable, pairs, unpack, tostring, select = require, io, select, type, next, getmetatable, setmetatable, pairs, unpack, tostring, select
local Table, String, Object, Exception, Namespace, Debug = from"Luv":import("Table", "String", "Object", "Exception", "Namespace", "Debug")

module(...)

local CLASS = ...

local Exception = Exception:extend{__tag = .....".Exception"}

local Factory = Object:extend{
	__tag = .....".Factory",
	
	connect = function (self, dsn)
		local login, pass, port, params = nil, nil, nil, {}
		local driver, host, database, paramsStr = String.split(dsn, "://", "/", "?")
		login, host = String.split(host, "@")
		login, pass = String.split(login, ":")
		host, port = String.split(host, ":")
		paramsStr = String.split(paramsStr, "&")
		if paramsStr then
			for _, v in ipairs(paramsStr) do
				local key, val = String.split(v, "=")
				params[key] = val
			end
		end
		return require(CLASS.."."..String.capitalize(driver))(host, login, pass, database, port, params)
	end
}

local Select = Object:extend{
	__tag = .....".Select",

	init = function (self, db, ...)
		self.db = db
		self.fieldsVal = {}
		self:fields(...)
		self.tables = {}
		self.conditions = {
			where = {},
			orWhere = {},
			order = {},
			limit = {}
		}
		self.joins = {
			inner = {},
			outer = {},
			left = {},
			right = {},
			natural = {},
			full = {},
			cross = {}
		}
		self.joinsUsing = {
			inner = {},
			outer = {},
			left = {},
			right = {},
			full = {}
		}
	end,
	from = function (self, ...)
		local i, val, k, v
		for i = 1, select("#", ...) do
			val = select(i, ...)
			if type(val) == "table" then
				for k, v in pairs(val) do
					self.tables[k] = v
				end
			else
				Table.insert(self.tables, val)
			end
		end
		return self
	end,
	fields = function (self, ...)
		self.fieldsVal = {}
		local i, val, k, v
		if 0 ~= select("#", ...) then
			for i = 1, select("#", ...) do
				val = select(i, ...)
				if type(val) == "table" then
					for k, v in pairs(val) do
						self.fieldsVal[k] = v
					end
				else
					Table.insert(self.fieldsVal, val)
				end
			end
		end
		return self
	end,
	where = function (self, ...) Table.insert(self.conditions.where, {...}) return self end,
	orWhere = function (self, ...) Table.insert(self.conditions.orWhere, {...}) return self end,
	order = function (self, ...)
		local i, val
		for i = 1, select("#", ...) do
			val = select(i, ...)
			Table.insert(self.conditions.order, val)
		end
		return self
	end,
	limit = function (self, from, to)
		if to then
			self.conditions.limit.from = from
			self.conditions.limit.to = to
		else
			self.conditions.limit.from = 0
			self.conditions.limit.to = from
		end
		return self
	end,
	limitPage = function (self, page, onPage)
		self.conditions.limit.from = (page-1)*onPage
		self.conditions.limit.to = page*onPage
		return self
	end,
	-- TODO: Make it protected
	joinInternalProcess = function (self, joinType, joinTable, condition, fields)
		local table  = joinTable
		if "table" == type(table) then
			table = next(table)
		end
		-- Condition
		if "table" == type(condition) then
			condition = self.db:processPlaceholders (unpack(condition))
		end
		Table.insert(joinType, {joinTable, condition})
		-- Fields
		if fields then
			local k, v
			for k, v in pairs(fields) do
				if "number" ~= type(k) then
					self.fieldsVal[k] = table.."."..v
				else
					Table.insert(self.fieldsVal, table.."."..v)
				end
			end
		else
			Table.insert(self.fieldsVal, table..".*")
		end
	end,
	join = function (self, ...)
		return self:joinInner(...)
	end,
	joinInner = function (self, ...)
		self:joinInternalProcess(self.joins.inner, ...)
		return self
	end,
	joinOuter = function (self, ...) Table.insert(self.joins.outer, {...}) return self end,
	joinLeft = function (self, ...) Table.insert(self.joins.left, {...}) return self end,
	joinRight = function (self, ...) Table.insert(self.joins.right, {...}) return self end,
	joinFull = function (self, ...) Table.insert(self.joins.full, {...}) return self end,
	joinCross = function (self, ...) Table.insert(self.joins.cross, {...}) return self end,
	joinNatural = function (self, ...) Table.insert(self.joins.natural, {...}) return self end,
	joinInnerUsing = function (self, ...) Table.insert(self.joinsUsing.inner, {...}) return self end,
	joinOuterUsing = function (self, ...) Table.insert(self.joinsUsing.outer, {...}) return self end,
	joinLeftUsing = function (self, ...) Table.insert(self.joinsUsing.left, {...}) return self end,
	joinRightUsing = function (self, ...) Table.insert(self.joinsUsing.right, {...}) return self end,
	joinFullUsing = function (self, ...) Table.insert(self.joinsUsing.full, {...}) return self end,
	exec = function (self) return self.db:fetchAll(tostring(self)) end,
	__tostring = Object.abstractMethod
}

local SelectRow = Select:extend{
	__tag = .....".Driver.SelectRow",
	
	exec = function (self) return self.db:fetchRow(tostring(self)) end,
	__tostring = Object.abstractMethod
}

local SelectCell = SelectRow:extend{
	__tag = .....".Driver.SelectCell",
	
	exec = function (self) return self.db:fetchCell(tostring(self)) end,
	__tostring = Object.abstractMethod
}

local Insert = Object:extend{
	__tag = .....".Driver.Insert",
	
	init = function (self, db, fields, ...)
		self.db = db
		self.valuesData = {}
		self.fields = fields
		self.fieldNames = {...}
	end,
	into = function (self, ...) self.table = {...} return self end,
	values = function (self, ...) Table.insert(self.valuesData, {...}) return self end,
	exec = function (self) return self.db:query(tostring(self)) end,
	__tostring = Object.abstractMethod
}

local InsertRow = Object:extend{
	__tag = .....".Driver.InsertRow",
	
	init = function (self, db)
		self.db = db
		self.sets = {}
	end,
	into = function (self, table) self.table = table return self end,
	set = function (self, ...) Table.insert(self.sets, {...}) return self end,
	exec = function (self) return self.db:query(tostring(self)) end,
	__tostring = Object.abstractMethod
}

local Update = Object:extend{
	__tag = .....".Driver.Update",
	
	init = function (self, db, table)
		self.db = db
		self.table = table
		self.sets = {}
		self.conditions = {
			where = {},
			orWhere = {},
			order = {},
			limit = {}
		}
	end,
	set = function (self, ...) Table.insert(self.sets, {...}) return self end,
	where = function (self, ...) Table.insert(self.conditions.where, {...}) return self end,
	orWhere = function (self, ...) Table.insert(self.conditions.orWhere, {...}) return self end,
	order = function (self, ...)
		local i, val
		for i = 1, select("#", ...) do
			val = select(i, ...)
			Table.insert(self.conditions.order, val)
		end
		return self
	end,
	limit = function (self, from, to)
		if to then
			self.conditions.limit.from = from
			self.conditions.limit.to = to
		else
			self.conditions.limit.from = 0
			self.conditions.limit.to = from
		end
		return self
	end,
	limitPage = function (self, page, onPage)
		self.conditions.limit.from = (page-1)*onPage
		self.conditions.limit.to = (page-1)*onPage+1
		return self
	end,
	exec = function (self) return self.db:query(tostring(self)) end,
	__tostring = Object.abstractMethod
}

local UpdateRow = Update:extend{
	__tag = .....".Driver.UpdateRow",
	
	limit = function (self, from, to)
		if to then
			self.conditions.limit.from = from
			self.conditions.limit.to = from+1
		else
			self.conditions.limit.from = 0
			self.conditions.limit.to = 1
		end
		return self
	end,
	limitPage = Update.maskedMethod,
	__tostring = Object.abstractMethod
}

local Delete = Object:extend{
	__tag = .....".Driver.Delete",

	init = function (self, db, table)
		self.db = db
		self.conditions = {
			where = {},
			orWhere = {},
			order = {},
			limit = {}
		}
	end,
	from = function (self, table) self.table = table return self end,
	where = function (self, ...) Table.insert(self.conditions.where, {...}) return self end,
	orWhere = function (self, ...) Table.insert(self.conditions.orWhere, {...}) return self end,
	order = function (self, ...)
		local i, val
		for i = 1, select("#", ...) do
			val = select(i, ...)
			Table.insert(self.conditions.order, val)
		end
		return self
	end,
	limit = function (self, from, to)
		if to then
			self.conditions.limit.from = from
			self.conditions.limit.to = to
		else
			self.conditions.limit.from = 0
			self.conditions.limit.to = from
		end
		return self
	end,
	limitPage = function (self, page, onPage)
		self.conditions.limit.from = (page-1)*onPage
		self.conditions.limit.to = page*onPage
		return self
	end,
	exec = function (self) return self.db:query(tostring(self)) end,
	__tostring = Object.abstractMethod
}

local DeleteRow = Delete:extend{
	__tag = .....".Driver.DeleteRow",
	
	limit = function (self, from, to)
		if to then
			self.conditions.limit.from = from
			self.conditions.limit.to = from+1
		else
			self.conditions.limit.from = 0
			self.conditions.limit.to = 1
		end
		return self
	end,
	limitPage = Delete.maskedMethod,
	__tostring = Object.abstractMethod
}

local DropTable = Object:extend{
	__tag = .....".Driver.DropTable",
	
	init = function (self, db, table)
		self.db = db
		self.table = table
	end,
	exec = function (self) return self.db:query(tostring(self)) end,
	__tostring = function (self) return self.db:processPlaceholders("DROP TABLE ?#;", self.table) end
}

local CreateTable = Object:extend{
	__tag = .....".Driver.CreateTable",
	
	init = function (self, db, table)
		self.db = db
		self.table = table
		self.fields = {}
		self.unique = {}
		self.options = {}
		self.constraints = {}
	end,
	field = function (self, ...) Table.insert(self.fields, {...}) return self end,
	uniqueTogether = function (self, ...) Table.insert(self.unique, {...}) return self end,
	option = function (self, key, value)
		self.options[key] = value
		return self
	end,
	constraint = function (self, ...) Table.insert(self.constraints, {...}) return self end,
	primaryKey = function (self, ...) self.primaryKeyValue = {...} return self end,
	exec = function (self) return self.db:query(tostring(self)) end,
	__tostring = Object.abstractMethod
}

local Driver = Object:extend{
	__tag = .....".Driver",

	Exception = Exception:extend{__tag = .....".Driver.Exception"},
	Select = Select,
	SelectRow = SelectRow,
	SelectCell = SelectCell,
	Insert = Insert,
	InsertRow = InsertRow,
	Update = Update,
	UpdateRow = UpdateRow,
	Delete = Delete,
	DeleteRow = DeleteRow,
	CreateTable = CreateTable,
	DropTable = DropTable,

	logger = function (sql, result)
		io.write(sql, "<br />")
	end,
	processPlaceholder = Object.abstractMethod,
	processPlaceholders = function (self, sql, ...)
		local begPos, endPos, res, match, i, lastEnd = 0, 0, {}, nil, 1, 0
		begPos, endPos = String.find(sql, "?[%#davn]?", lastEnd+1)
		while begPos do
			local val = select(i, ...)
			if begPos then
				Table.insert(res, String.slice(sql, lastEnd+1, begPos-1))
				Table.insert(res, self:processPlaceholder(String.slice(sql, begPos, endPos), val))
				lastEnd = endPos
			end
			begPos, endPos = String.find(sql, "?[%#davn]?", lastEnd+1)
			i = i+1
		end
		Table.insert(res, String.slice(sql, lastEnd+1))
		return Table.join(res)
	end,
	fetchAll = function (self, ...)
		local rawSql = self:processPlaceholders(...)
		local cur, error = self.connection:execute(rawSql)
		self.logger(rawSql)
		if not cur then
			self.error = error
			return nil
		end
		local res, row = {}, {}
		while cur:fetch(row, "a") do
			Table.insert(res, Table.copy(row))
		end
		return res
	end,
	fetchRow = function (self, ...)
		local rawSql = self:processPlaceholders(...)
		local cur, error = self.connection:execute(rawSql)
		self.logger(rawSql)
		if not cur then
			self.error = error
		end
		return cur:fetch({}, "a")
	end,
	fetchCell = function (self, ...)
		local rawSql = self:processPlaceholders(...)
		local cur, error = self.connection:execute(rawSql)
		self.logger(rawSql)
		if not cur then
			self.error = error
			return nil
		end
		local res = cur:fetch({}, "a")
		if not res then
			return nil
		end
		local _, v = next(res)
		return v
	end,
	query = function (self, ...)
		local rawSql = self:processPlaceholders(...)
		local cur, error = self.connection:execute(rawSql)
		self.logger(rawSql)
		if not cur then
			self.error = error
			return nil
		end
		if type(cur) == "userdata" then
			return cur:fetch({}, "a")
		end
		return cur
	end,
	getLastInsertId = Object.abstractMethod,
	getError = function (self) return self.error end
}

return Namespace:extend{
	__tag = ...,

	ns = ...,
	Exception = Exception,
	Factory = Factory,
	Driver = Driver
}