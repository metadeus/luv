local pairs, tonumber, ipairs, table, os, type, io = pairs, tonumber, ipairs, table, os, type, io
local Object, validators, Widget, widgets, string = require"luv.oop".Object, require"luv.validators", require"luv".Widget, require"luv.fields.widgets", require "luv.string"

module(...)

local MODULE = ...

local Field = Object:extend{
	__tag = .....".Field",
	init = function (self, params)
		if self.parent.parent == Object then
			Exception"Can not instantiate abstract class!":throw()
		end
		self.validators = {}
		self.errors = {}
		self:setParams(params)
	end,
	clone = function (self)
		local new = Object.clone(self)
		-- Clone validators
		new.validators = {}
		if self.validators then
			local k, v
			for k, v in pairs(self.validators) do
				new.validators[k] = v:clone()
			end
		end
		return new
	end,
	setParams = function (self, params)
		params = params or {}
		self.pk = params.pk or false
		self.unique = params.unique or false
		self.required = params.required or false
		self.label = params.label
		self:setWidget(params.widget)
		if self.required then
			self.validators.filled = validators.Filled()
		end
		self:setDefaultValue(params.defaultValue)
		return self
	end,
	isRequired = function (self) return self.required end,
	isUnique = function (self) return self.unique end,
	isPk = function (self) return self.pk end,
	getId = function (self) return self.id end,
	setId = function (self, id) self.id = id return self end,
	getLabel = function (self) return self.label end,
	setLabel = function (self, label) self.label = label return self end;
	getName = function (self) return self.name end;
	setName = function (self, name) self.name = name return self end;
	getValue = function (self) return self.value end,
	setValue = function (self, value) self.value = value return self end,
	getDefaultValue = function (self) return self.defaultValue end,
	setDefaultValue = function (self, val) self.defaultValue = val return self end,
	addError = function (self, error) table.insert(self.errors, error) return self end,
	addErrors = function (self, errors)
		local i, v for i, v in ipairs(errors) do table.insert(self.errors, v) end
		return self
	end,
	setErrors = function (self, errors) self.errors = errors return self end,
	getErrors = function (self) return self.errors end,
	isValid = function (self, value)
		local value = value or self.value
		self:setErrors{}
		if not self.validators then
			return true
		end
		local _, val
		for _, val in pairs(self.validators) do
			if not val:isValid(value) then
				self:addErrors(val:getErrors())
				return false
			end
		end
		return true
	end,
	getWidget = function (self) return self.widget end,
	setWidget = function (self, widget) self.widget = widget return self end,
	asHtml = function (self, form) return self.widget:render(self, form) end
}

local Text = Field:extend{
	__tag = .....".Text",
	setParams = function (self, params)
		params = params or {}
		if false == params.maxLength then params.maxLength = 0 end
		if not params.widget then
			if "number" == type(params.maxLength) and (params.maxLength == 0 or params.maxLength > 65535) then
				params.widget = widgets.TextArea
			else
				params.widget = widgets.TextInput
			end
		end
		Field.setParams(self, params)
		if params.regexp then
			self.validators.regexp = validators.Regexp(params.regexp)
		end
		self.validators.length = validators.Length(params.minLength or 0, params.maxLength or 255)
	end,
	getMinLength = function (self)
		return self.validators.length:getMinLength()
	end,
	getMaxLength = function (self)
		return self.validators.length:getMaxLength()
	end
}

local Int = Field:extend{
	__tag = .....".Int",
	init = function (self, params)
		params = params or {}
		params.widget = params.widget or widgets.TextInput
		Field.init(self, params)
		self.validators.int = validators.Int()
	end,
	setValue = function (self, value)
		self.value = tonumber(value)
	end;
	getMinLength = function (self) return self:isRequired() and 1 or 0 end;
	getMaxLength = function (self) return 12 end;
}

local Boolean = Int:extend{
	__tag = .....".Boolean";
	init = function (self, params)
		params = params or {}
		params.widget = params.widget or widgets.CheckboxInput
		Int.init(self, params)
	end;
	setValue = function (self, value)
		if "number" == type(value) then
			self.value = value
		elseif "nil" == type(value) then
			self.value = nil
		else
			self.value = value and 1 or 0
		end
	end;
	getValue = function (self) if not self.value then return nil end return self.value ~= 0 end;
}

local Login = Text:extend{
	__tag = .....".Login",
	init = function (self, params)
		params = params or {}
		params.minLength = 1
		params.maxLength = 32
		params.required = true
		params.unique = true
		params.regexp = "^[a-zA-Z0-9_%.%-]+$"
		Text.init(self, params)
	end
}

local Id = Int:extend{
	__tag = .....".Id",
	init = function (self, params)
		params = params or {}
		params.widget = params.widget or widgets.HiddenInput
		params.pk = true
		Int.init(self, params)
	end
}

local Button = Text:extend{
	__tag = .....".Button",
	init = function (self, params)
		params = params or {}
		if "table" ~= type(params) then
			params = {defaultValue=params}
		end
		params.widget = params.widget or widgets.Button
		Text.init(self, params)
	end
}

local Submit = Button:extend{
	__tag = .....".Submit",
	init = function (self, params)
		params = params or {}
		if "table" ~= type(params) then
			params = {defaultValue=params}
		end
		params.widget = params.widget or widgets.SubmitButton
		Button.init(self, params)
	end
}

local Datetime = Field:extend{
	__tag = .....".Datetime";
	setParams = function (self, params)
		params = params or {}
		self:setAutoNow(params.autoNow)
	end;
	getAutoNow = function (self) return self.autoNow end;
	setAutoNow = function (self, autoNow) self.autoNow = autoNow return self end;
	getDefaultValue = function (self)
		if self.defaultValue then
			return self.defaultValue
		end
		if self:getAutoNow() then
			return os.date("%Y-%m-%d %H:%M:%S")
		end
		return nil
	end;
	getValue = function (self)
		if not self.value then
			return self:getDefaultValue()
		end
		return self.value
	end;
	setValue =  function (self, value)
		if "string" == type(value) then
			self.value = os.time{
				year=tonumber(string.slice(value, 1, 4));
				month=tonumber(string.slice(value, 6, 7));
				day=tonumber(string.slice(value, 9, 10));
				hour=tonumber(string.slice(value, 12, 13));
				min=tonumber(string.slice(value, 15, 16));
				sec=tonumber(string.slice(value, 18, 19));
			}
		else
			self.value = value
		end
	end;
}

return {
	Field = Field,
	Text = Text,
	Int = Int,
	Boolean=Boolean;
	Login = Login,
	Id = Id,
	Button = Button,
	Submit = Submit;
	Datetime=Datetime;
}