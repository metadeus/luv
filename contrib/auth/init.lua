require "luv.debug"
local io, type, require, math, tostring, string, debug = io, type, require, math, tostring, string, debug
local models, fields, references, forms, managers, crypt, widgets = require "luv.db.models", require "luv.fields", require "luv.fields.references", require "luv.forms", require "luv.managers", require "luv.crypt", require "luv.fields.widgets"

module(...)

local MODULE = ...

local GroupRight = models.Model:extend{
	__tag = .....".GroupRight",
	Meta = {label="group right", labelMany="group rights"},
	model = fields.Char(),
	action = fields.Char(),
	description = fields.Char{maxLength = 0}
}

local UserGroup = models.Model:extend{
	__tag = .....".UserGroup",
	Meta = {label="user group", labelMany="user groups"},
	title = fields.Char{required=true, unique=true},
	description = fields.Char{maxLength=0},
	rights = references.ManyToMany{references=GroupRight, relatedName="groups"},
}

local User = models.Model:extend{
	__tag = .....".User",
	Meta = {label="user", labelMany="users"},
	sessId = "LUV_AUTH",
	secretSalt = "",
	-- Fields
	login = fields.Login{label="login"},
	name = fields.Char(),
	passwordHash = fields.Char{required = true},
	group = references.ManyToOne{references=UserGroup, relatedName="users"},
	-- Methods
	getSecretSalt = function (self) return self.secretSalt end,
	setSecretSalt = function (self, secretSalt) self.secretSalt = secretSalt return self end,
	encodePassword = function (self, password, method, salt)
		if not password then Exception "Empty password is restricted!":throw() end
		method = method or "sha1"
		if not salt then
			salt = tostring(crypt.hash(method, math.random(2000000000)))
			salt = string.slice(salt, math.random(10), math.random(5, string.len(salt)-10))
		end
		return method.."$"..salt.."$"..tostring(crypt.hash(method, password..salt..self.secretSalt))
	end,
	comparePassword = function (self, password)
		local method, salt, hash = string.split(self.passwordHash, "$", "$")
		return self:encodePassword(password, method, salt) == self.passwordHash
	end,
	getAuthUser = function (self, session, loginForm)
		if self.authUser then return self.authUser end
		if not loginForm or "table" ~= type(loginForm) or not loginForm.isObject
			or not loginForm:isKindOf(require(MODULE).forms.LoginForm) or not loginForm:isSubmitted() or not loginForm:isValid() then
			if not session[self.sessId] then
				session[self.sessId] = nil
				session:save()
				self.authUser = nil
				return nil
			end
			local user = self:find(session[self.sessId].user)
			self.authUser = user
			return user
		end
		local user = self:find{login=loginForm.login}
		if not user or not user:comparePassword(loginForm.password) then
			session[self.sessId] = nil
			session:save()
			loginForm:addError "Invalid authorisation data."
			return nil
		end
		session[self.sessId] = {user=user.pk}
		session:save()
		self.authUser = user
		return user
	end,
	logout = function (self, session)
		session[self.sessId] = nil
		session:save()
	end
}

local LoginForm = forms.Form:extend{
	__tag = .....".LoginForm",
	Meta = {
		fields = {"login", "password", "authorise"}
	},
	login = User:getField "login",
	password = fields.Char{label="password", maxLength=32, minLength=6, widget=widgets.PasswordInput},
	authorise = fields.Submit{defaultValue="Authorise"}
}

local UserManager = managers.Model:extend{
	__tag = .....".UserManager",
	model = User
}

return {
	models = {
		GroupRight = GroupRight,
		UserGroup = UserGroup,
		User = User
	},
	forms = {
		LoginForm = LoginForm
	}
}
