local type, ipairs, tostring, tonumber = type, ipairs, tostring, tonumber
local require, loadstring, assert = require, loadstring, assert
local string = require"luv.string"
local Object = require"luv.oop".Object
local fs = require"luv.fs"
local models = require"luv.db.models"
local fields = require"luv.fields"
local Exception = require"luv.exceptions".Exception

module(...)

local abstract = Object.abstractMethod
local property = Object.property

local MigrationLog = models.Model:extend{
	__tag = .....".MigrationLog";
	Meta = {labels={("migration log"):tr();("migration logs"):tr()}};
	from = fields.Int{required=true};
	to = fields.Int{required=true};
	datetime = fields.Datetime{autonow=true};
}

local Migration = Object:extend{
	__tag = .....".Migration";
	db = property;
	up = abstract;
	down = abstract;
}

local MigrationManager = Object:extend{
	__tag = .....".MigrationManager";
	db = property;
	scriptsDir = property;
	migrations = property"table"
	lastMigration = property"number";
	currentMigration = property("number", function (self)
		if not self._currentMigration then
			-- FIXME: key-value DB support
			self._currentMigration = self:db():SelectCell"to":from(MigrationLog:tableName()):order"-datetime"() or 0
		end
		return self._currentMigration
	end);
	init = function (self, db, scriptsDir)
		self:db(db)
		self:scriptsDir("table" == type(scriptsDir) and scriptsDir or fs.Dir(scriptsDir))
		self:lastMigration(0)
		self:migrations{}
		for i, file in ipairs(self:scriptsDir():files()) do
			local name = file:name()
			if name:endsWith".lua" then
				local begPos, _, capture = name:find"^([0-9]+)"
				if begPos then
					local num = tonumber(capture)
					self:migrations()[num] = file
					if self:lastMigration() < num then
						self:lastMigration(num)
					end
				end
			end
		end
	end;
	_log = function (self, from, to)
		-- FIXME: key-value DB support
		self:db():InsertRow():into(MigrationLog:tableName()):set("?# = ?d", "from", from):set("?# = ?d", "to", to)()
	end;
	_loadMigration = function (self, num)
		if self:migrations()[num] then
			return assert(loadstring(self:migrations()[num]:openReadAndClose"*a"))()(self:db())
		end
	end;
	_apply = function (self, from, to)
		local iter = 1
		if from == to then
			Exception"migrations from and to should be different"
		elseif from > to then
			iter = -1
		end
		for i = from+iter, to, iter do
			if not self:migrations()[i] then
				Exception("migration "..i.." not founded")
			end
		end
		for i = from+iter, to, iter do
			local migration = self:_loadMigration(i)
			if iter > 0 then
				if not migration or not migration:up() then
					-- Try to rollback
					for j = i-1, from+iter, -1 do
						migration = self:_loadMigration(j)
						if not migration or not migration:down() then
							Exception("migration fails to apply from "..from.." to "..to.." and fails to rollback from "..j.." to "..(j-1))
						end
					end
					return false, ("fails to apply up from "..(i-1).." to "..i)
				end
			else
				if not migration or not migration:down() then
					-- Try to rollback
					for j = i+1, from+iter do
						migration = self:_loadMigration(j)
						if not migration or not migration:up() then
							Exception("migration fails to apply from "..from.." to "..to.." and fails to rollback from "..j.." to "..(j+1))
						end
					end
					return false, ("fails to apply down from "..i.." to "..(i-1))
				end
			end
		end
		self:currentMigration(to)
		self:_log(from, to)
		return true
	end;
	up = function (self)
		if self:currentMigration() >= self:lastMigration() then
			Exception "last migration already reached up"
		end
		return self:_apply(self:currentMigration(), self:currentMigration()+1)
	end;
	down = function (self)
		if self:currentMigration() <= 0 then
			Exception "migration 0 already reached down"
		end
		return self:_apply(self:currentMigration(), self:currentMigration()-1)
	end;
	upTo = function (self, to)
		if self:currentMigration() >= self:lastMigration() then
			Exception"last migration already reached up"
		elseif self:currentMigration() >= to then
			Exception("migration "..to.." already reached up")
		elseif to > self:lastMigration() then
			Exception("migration "..to.." can't be reached up")
		end
		return self:_apply(self:currentMigration(), to)
	end;
	downTo = function (self, to)
		if self:currentMigration() <= 0 then
			Exception "migration 0 already reached down"
		elseif self:currentMigration() <= to then
			Exception("migration "..to.." already reached down")
		elseif to <= 0 then
			Exception("migration "..to.." can't be reached down")
		end
		return self:_apply(self:currentMigration(), to)
	end;
	allUp = function (self)
		if self:currentMigration() >= self:lastMigration() then
			Exception "last migration already reached up"
		end
		return self:_apply(self:currentMigration(), self:lastMigration())
	end;
	allDown = function (self)
		if self:currentMigration() <= 0 then
			Exception"migration 0 already reached down"
		end
		return self:_apply(self:currentMigration(), 0)
	end;
}

return {
	models={MigrationLog=MigrationLog};
	Migration=Migration;
	MigrationManager=MigrationManager;
}
