local table = require "luv.table"
local string = require "luv.string"
local dev = require "luv.dev"
local pairs, require, select, unpack, type, rawget, rawset, math, os, tostring, io, ipairs, dofile = pairs, require, select, unpack, type, rawget, rawset, math, os, tostring, io, ipairs, dofile
local _G, error = _G, error
local oop, exceptions, sessions, fs, ws, sessions, utils = require"luv.oop", require"luv.exceptions", require "luv.sessions", require "luv.fs", require "luv.webservers", require "luv.sessions", require "luv.utils"
local Object, Exception, Version = oop.Object, exceptions.Exception, utils.Version
local crypt, backend = require "luv.crypt", require "luv.cache.backend"
local Memory, NamespaceWrapper, TagEmuWrapper = backend.Memory, backend.NamespaceWrapper, backend.TagEmuWrapper
local Slot = require "luv.cache.frontend".Slot

module(...)

local MODULE = (...)

local function constructTablesList (models)
	local references = require "luv.fields.references"
	local tables = {}
	table.imap(models, function (model)
		local tableName = model:getTableName()
		for _, info in ipairs(tables) do
			if info[1] == tableName then
				return nil
			end
		end
		table.insert(tables, {model:getTableName();model})
		table.imap(model:getReferenceFields(nil, references.ManyToMany), function (field)
			local tableName = field:getTableName()
			for _, info in ipairs(tables) do
				if info[1] == tableName then
					return nil
				end
			end
			table.insert(tables, {field:getTableName();field})
			return nil
		end)
		return nil
	end)
	return tables
end

local function sortTablesList (tables)
	local models = require "luv.db.models"
	local references = require "luv.fields.references"
	local size, i = #tables, 1
	while i < size do
		local iTbl, iObj = unpack(tables[i])
		for j = i+1, size do
			local jTbl, jObj = unpack(tables[j])
			if jObj:isKindOf(models.Model) then
				local o2o = jObj:getReferenceField(iObj, references.OneToOne)
				if jObj:getReferenceField(iObj, references.ManyToOne)
				or (o2o and not jObj:getField(o2o):isBackLink()) then
					tables[i], tables[j] = tables[j], tables[i]
					break
				end
			else
				if jObj:getRefModel():getTableName() == iTbl
				or jObj:getContainer():getTableName() == iTbl then
					tables[i], tables[j] = tables[j], tables[i]
					break
				end
			end
			if j == size then
				i = i+1
			end
		end
	end
	return tables
end

local UrlConf = Object:extend{
	__tag = .....".UrlConf",
	init = function (self, wsApi)
		self._wsApi = wsApi
		self._uri = wsApi:getRequestHeader("REQUEST_URI") or ""
		local queryPos = string.find(self._uri, "?")
		if queryPos then
			self._uri = string.sub(self._uri, 1, queryPos-1)
		end
		self._tailUri = self._uri
		self._baseUri = ""
		self._captures = {}
	end,
	getWsApi = function (self) return self._wsApi end;
	setWsApi = function (self, wsApi) self._wsApi = wsApi return self end;
	getCapture = function (self, pos)
		return self.captures[pos]
	end;
	getUri = function (self) return self._uri end;
	getTailUri = function (self) return self._tailUri end;
	getBaseUri = function (self) return self._baseUri end;
	execute = function (self, action)
		if type(action) == "string" then
			local result = dofile(action)
			return result and self:dispatch(result) or true
		elseif type(action) == "function" then
			return action(self)
		elseif type(action) == "table" then
			return self:dispatch(action)
		else
			Exception "Invalid action!"
		end
	end,
	dispatch = function (self, urls)
		local _, item, action
		if "string" == type(urls) then
			return self:dispatch(dofile(urls))
		end
		for _, item in pairs(urls) do
			if "string" == type(item[1]) then
				local res = {string.find(self._tailUri, item[1])}
				if nil ~= res[1] then
					local oldTailUri, oldBaseUri, oldCaptures = self._tailUri, self._baseUri, self._captures
					local tailUriLen = string.len(self._tailUri)
					self._baseUri = self._baseUri..string.sub(self._uri, 1, -tailUriLen+res[1]-2)
					self._tailUri = string.sub(self._tailUri, res[2]+1)
					self.captures = {}
					local i = 3
					for i = 3, #res do
						table.insert(self._captures, res[i])
					end
					if false ~= self:execute(item[2]) then
						return true
					end
				end
			elseif false == item[1] then
				action = item[2]
			end
		end
		if action then self:execute(action) return true end
		return false
	end
}

local TemplateSlot = Slot:extend{
	__tag = .....".TemplateSlot";
	init = function (self, luv, template, params)
		self.luv = luv
		self.template = template
		return Slot.init(self, luv:getCacher(), tostring(crypt.Md5(template..string.serialize(params))), 60*60)
	end;
	displayCached = function (self)
		local res = self:get()
		if not res then return false end
		io.write(res)
		return true
	end;
	display = function (self)
		self.luv:info("Template cache date "..os.date(), "Cacher")
		local res = self.luv:fetch(self.template)
		self:set(res)
		io.write(res)
		return self
	end;
}

local Core = Object:extend{
	__tag = .....".Core",
	version = Version(0, 8, 0, "alpha"),
	-- Init
	init = function (self, wsApi)
		self:setProfiler(dev.Profiler())
		self:beginProfiling "Luv"
		--
		self._wsApi = wsApi:setResponseHeader("X-Powered-By", "Luv/"..tostring(self.version))
		self._urlconf = UrlConf(self._wsApi)
		self:setCacher(TagEmuWrapper(Memory()))
	end,
	getWsApi = function (self) return self._wsApi end,
	setWsApi = function (self, wsApi) self._wsApi = wsApi return self end,
	getTemplater = function (self) return self._templater end,
	setTemplater = function (self, templater) self._templater = templater return self end,
	getSession = function (self) return self._session end,
	setSession = function (self, session) self._session = session return self end,
	-- Database
	getDsn = function (self) return self._dsn end,
	setDsn = function (self, dsn)
		self._dsn = dsn
		self._db = require "luv.db".Factory(dsn)
		require "luv.db.models".Model:setDb(self._db)
		self._db:setLogger(function (sql, result)
			--io.write(sql, "<br />")
			self:debug(sql, "Database")
		end)
		return self
	end,
	getDb = function (self) return self._db end,
	beginTransaction = function (self) return self._db:beginTransaction() end;
	commit = function (self) return self._db:commit() end;
	rollback = function (self) return self._db:rollback() end;
	-- Web-server
	getRequestHeader = function (self, ...) return self._wsApi:getRequestHeader(...) end,
	setResponseHeader = function (self, ...) self._wsApi:setResponseHeader(...) return self end,
	setResponseCode = function (self, ...) self._wsApi:setResponseCode(...) return self end;
	sendHeaders = function (self, ...) self._wsApi:sendHeaders(...) return self end;
	getGet = function (self, name) return self._wsApi:getGet(name) end,
	getGetData = function (self) return self._wsApi:getGetData() end,
	getPost = function (self, name) return self._wsApi:getPost(name) end,
	getPostData = function (self) return self._wsApi:getPostData() end,
	getCookie = function (self, name) return self.wsApi:getCookie(name) end,
	setCookie = function (self, ...) self._wsApi:setCookie(...) return self end,
	getCookies = function (self) return self._wsApi:getCookies() end,
	getSession = function (self) return self._session end,
	setSession = function (self, session) self._session = session return self end,
	-- URL conf
	dispatch = function (self, urlconf) return self._urlconf:dispatch(urlconf) end,
	-- Models
	dropModels = function (self, models)
		for _, info in ipairs(sortTablesList(constructTablesList(models))) do
			info[2]:dropTable()
		end
	end,
	createModels = function (self, models)
		local tables = sortTablesList(constructTablesList(models))
		for i = #tables, 1, -1 do
			tables[i][2]:createTable()
		end
	end,
	-- Templater
	addTemplatesDir = function (self, templatesDir)
		self._templater:addTemplatesDir(templatesDir)
		return self
	end,
	assign = function (self, ...)
		self._templater:assign(...)
		return self
	end;
	fetchString = function (self, template)
		self:flush()
		return self._templater:fetchString(template)
	end;
	fetch = function (self, template)
		self:flush()
		return self._templater:fetch(template)
	end;
	displayString = function (self, template)
		self:flush()
		return self._templater:displayString(template)
	end;
	display = function (self, template)
		self:flush()
		return self._templater:display(template)
	end;
	flush = function (self)
		self:endProfiling("Luv")
		for section, info in pairs(self:getProfiler():getStat()) do
			self:info(section.." was executed "..tostring(info.count).." times and takes "..tostring(info.total).." secs", "Profiler")
		end
		self:assign{debugger=self._debugger or ""}
	end;
	-- Profiler
	getProfiler = function (self) return self._profiler end;
	setProfiler = function (self, profiler) self._profiler = profiler return self end;
	beginProfiling = function (self, section) self._profiler:beginSection(section) return self end;
	endProfiling = function (self, section) self._profiler:endSection(section) return self end;
	-- Debugger
	getDebugger = function (self) return self._debugger end;
	setDebugger = function (self, debugger)
		self._debugger = debugger
		return self
	end;
	debug = function (self, ...)
		if self._debugger then
			self._debugger:debug(...)
		end
		return self
	end;
	info = function (self, ...)
		if self._debugger then
			self._debugger:info(...)
		end
		return self
	end;
	warn = function (self, ...)
		if self._debugger then
			self._debugger:warn(...)
		end
		return self
	end;
	error = function (self, ...)
		if self._debugger then
			self._debugger:error(...)
		end
		return self
	end;
	-- Caching
	getCacher = function (self) return self._cacher end;
	setCacher = function (self, cacher)
		self._cacher = cacher
		require "luv.db.models".Model:setCacher(cacher)
		return self
	end;
	createTemplateSlot = function (self, template, params)
		return TemplateSlot(self, template, params)
	end;
	--[[createModelSlot = function (self, model)
		return require "luv.db.models".ModelSlot(self:getCacher(), model)
	end;]]
	createModelTag = function (self, model)
		return require "luv.db.models".ModelTag(self:getCacher(), model)
	end;
	-- I18n
	getI18n = function (self) return self._i18n end;
	setI18n = function (self, i18n) self._i18n = i18n return self end;
	tr = function (self, str) return self._i18n:tr(str) or str end;
}

local Struct = Object:extend{
	__tag = .....".Struct",
	init = function (self)
		self.errors = {}
	end,
	__index = function (self, field)
		if field == "pk" then return self:getPk():getValue() end
		local res = rawget(self, "fieldsByName")
		if res then
			res = res[field]
			if res then
				if res:isKindOf(require "luv.fields.references".ManyToMany) or res:isKindOf(require "luv.fields.references".OneToMany)then
					return res
				else
					return res:getValue()
				end
			end
		end
		return rawget(self, "parent")[field]
	end,
	__newindex = function (self, field, value)
		local res = self:getField(field)
		if res then
			res:setValue(value)
		else
			rawset(self, field, value)
		end
		return value
	end,
	-- Fields
	getField = function (self, field) return self.fieldsByName and self.fieldsByName[field] or nil end;
	getFields = function (self) return self.fields end;
	getFieldsByName = function (self) return self.fieldsByName end;
	getValues = function (self)
		local res = {}
		local k, v
		for k, v in pairs(self:getFieldsByName()) do
			local value = v:getValue()
			if "table" == type(value) and value.isKindOf and value:isKindOf(require "luv.fields.references".OneToMany) then
				res[k] = value:all():getValue()
			else
				res[k] = v:getValue()
			end
		end
		return res
	end,
	setValues = function (self, values)
		local k, v
		for k, v in pairs(self:getFieldsByName()) do
			v:setValue(values[k])
		end
		return self
	end;
	addField = function (self, name, field)
		if not field:isKindOf(require "luv.fields".Field) then
			Exception "instance of Field expected!"
		end
		field:setContainer(self)
		field:setName(name)
		table.insert(self.fields, field)
		self.fieldsByName[name] = field
		return self
	end;
	-- Validation & errors collect
	isValid = function (self)
		local _, v
		self:setErrors{}
		for _, v in ipairs(self:getFields()) do
			if not v:isValid() then
				local _, e for _, e in ipairs(v:getErrors()) do
					local label = v:getLabel()
					self:addError(string.gsub(_G.tr(e), "%%s", label and string.capitalize(_G.tr(label)) or string.capitalize(_G.tr(v:getName()))))
				end
			end
		end
		return table.isEmpty(self:getErrors())
	end,
	addError = function (self, error) table.insert(self.errors, error) return self end,
	setErrors = function (self, errors) self.errors = errors return self end,
	addErrors = function (self, errors)
		local i, v for i, v in ipairs(errors) do
			table.insert(self.errors, v)
		end
	end,
	getErrors = function (self) return self.errors end,
	getErrorsCount = function (self) return table.maxn(self.errors) end,
}

local Widget = Object:extend{
	__tag = .....".Widget",
	render = Object.abstractMethod
}

local init = function (params)
	local core = Core(params.wsApi or ws.Cgi(params.tmpDir))
	core:setTemplater(require "luv.templaters.tamplier" (params.templatesDirs))
	core:setSession(sessions.Session(core:getWsApi(), sessions.SessionFile(params.sessionDir)))
	core:setDsn(params.dsn)
	core:setDebugger(params.debugger)
	if params.cacher then core:setCacher(params.cacher) end
	if params.i18n then core:setI18n(params.i18n) end
	return core
end

initRandom = function ()
	-- Init random seed
	local seed, i, str = os.time(), nil, tostring(tostring(MODULE))
	for i = 1, string.len(str) do
		seed = seed + string.byte(str, i)
	end
	math.randomseed(seed)
end

initRandom()

return {
	oop = oop,
	exceptions = exceptions,
	util = util,
	Core = Core,
	UrlConf = UrlConf,
	Struct = Struct,
	Widget = Widget,
	init = init;
}
	
