local select = select
local string = require"luv.string"
local io, os, pairs, ipairs, tonumber = io, os, pairs, ipairs, tonumber
local type, table, math, tostring, require = type, table, math, tostring, require
local Object, Exception = require"luv.oop".Object, require"luv.exceptions".Exception
local fs = require"luv.fs"
local crypt = require"luv.crypt"

module(...)
local property = Object.property;

local Exception = Exception:extend{__tag = .....".Exception"}
local Http4xx = Exception:extend{__tag = .....".Http4xx"}
local Http403 = Http4xx:extend{__tag = .....".Http403"}
local Http404 = Http4xx:extend{__tag = .....".Http404"}

local HttpRequest = Object:extend{
	__tag = .....".HttpRequest";
	backend = property;
	init = function (self, backend)
		self:backend(backend)
	end;
	method = function (self) return self:header"REQUEST_METHOD" end;
	headers = function (self) return self:backend():requestHeaders() end;
	header = function (self, header) return self:backend():requestHeader(header) end;
	get = function (self, ...)
		if select("#", ...) > 1 then
			self:backend():get(...)
			return self
		else
			return self:backend():get()
		end
	end;
	getData = function (self) return self:backend():getData() end;
	post = function (self, ...)
		if select("#", ...) > 1 then
			self:backend():post(...)
			return self
		else
			return self:backend():post(...)
		end
	end;
	postData = function (self) return self:backend():postData() end;
	cookie = function (self, name) return self:backend():cookie(name) end;
	cookies = function (self) return self:backend():cookies() end;
	session = function (self) return self:backend():session() end;
}

local HttpResponse = Object:extend{
	__tag = .....".HttpResponse";
	backend = property"table";
	content = property"string";
	init = function (self, backend, content)
		self:backend(backend)
		self:content(content)
	end;
	header = function (self, header, ...)
		if select("#", ...) > 0 then
			self:backend():responseHeader(header, ...)
			return self
		else
			return self:backend():responseHeader(header)
		end
	end;
	code = function (self, code) self:backend():responseCode(code) return self end;
	contentType = function (self, contentType) self:header("Content-Type", contentType) return self end;
	appendContent = function (self, content) self:content(self:content()..content) return self end;
}

local Api = Object:extend{
	__tag = .....".Api";
	parseMultipartFormData = function (self, boundary, stream)
		postData = stream:explode(boundary)
		for i = 2, #postData-1 do
			local headersStr, data = postData[i]:split"\r\n\r\n"
			local headers = {}
			for _, header in ipairs(headersStr:explode"\r\n") do
				local name, value = header:split":"
				headers[name:lower()] = value
			end
			-- Process headers
			local contentDispValues = headers["content-disposition"]:explode";"
			if "form-data" ~= contentDispValues[1]:trim() then
				Exception"invalid Content-Disposition value"
			end
			local key, isFile
			for i = 2, #contentDispValues do
				local n, v = contentDispValues[i]:split"="
				n = n:trim():lower()
				v = v:trim()
				if "name" == n then
					key = v:slice(2, -2)
				elseif "filename" == n then
					isFile = true
				end
			end
			-- Process value
			data = data:slice(1, -3)
			if isFile then
				if "" ~= data then
					self:postData()[key] = {filename=key}
					if self:tmpDir() then
						self:postData()[key].tmpFilePath = tostring(self:tmpDir() / tostring(crypt.Md5(math.random(2000000000))))
						file = fs.File(self:post(key).tmpFilePath):openWriteAndClose(data)
					else
						self:post(key).data = data
					end
				end
			else
				self:postData()[key] = data
			end
		end
	end;
}

local urlDecodeArr = {["+"]=" "}

local urlDecode = function (url)
	return url:gsub("%%(..)", function (s)
		local zero, A = ("0"):byte(), ("A"):byte()
		local i, j = s:byte(1, 2)
		if i >= A then i = i - A + 10 else i = i - zero end
		if j >= A then j = j - A + 10 else j = j - zero end
		return string.char(i*16+j)
	end):gsub("([+])", function (ch)
		return urlDecodeArr[ch]
	end)
end

local responseString = {
	[200]="OK";[201]="Created";[202]="Accepted";[203]="Non-Authoritative Information";[204]="No Content";[205]="Reset Content";[206]="Partial Content";[207]="Multi-Status";
	[300]="Multiple Choices";[301]="Moved permanently";[302]="Found";[303]="See Other";[304]="Not Modified";[305]="Use Proxy";[307]="Temporary Redirect";
	[400]="Bad Request";[401]="Unauthorized";[402]="Payment Required";[403]="Forbidden";[404]="Not Found";[405]="Method Not Allowed";[406]="Not Acceptable";[407]="Proxy Authentication Required";[408]="Request Timeout";[409]="Conflict";[410]="Gone";[411]="Length Required";[412]="Precondition Failed";[413]="Request Entity Too Large";[414]="Request-URI Too Long";[415]="Unsupported Media Type";[416]="Requested Range Not Satisfiable";[417]="Expectation Failed";[418]="I'm a teapot";[422]="Unprocessable Entity";[423]="Locked";[424]="Failed Dependency";[425]="Unordered Collection";[426]="Upgrade Required";[449]="Retry With";[450]="Blocked";
	[500]="Internal Server Error";[501]="Not Implemented";[502]="Bad Gateway";[503]="Service Unavailable";[504]="Gateway Timeout";[505]="HTTP Version Not Supported";[506]="Variant Also Negotiates";[507]="Insufficient Storage";[509]="Bandwidth Limit Exceeded";[510]="Not Extended"
}

local Cgi = Api:extend{
	__tag = .....".Cgi";
	_responseHeaders = {};
	_headersAlreadySent = false;
	_cookies = {};
	_get = {};
	_post = {};
	tmpDir = property;
	session = property;
	new = function (self, tmpDir, session)
		self:tmpDir(tmpDir)
		if session then self:session(session) end
		if not self._write then
			self._write = io.write
			io.write = function (...)
				if not self._headersAlreadySent then self:sendHeaders() end
				self._write(...)
			end
			self:parseCookies()
			self:parseGetData()
			self:parsePostData()
		end
		return self
	end,
	-- Headers
	requestHeader = function (self, header) return os.getenv(header) end;
	requestHeaders = function (self)
		local headers = {}
		setmetatable(headers, {__index=self.requestHeader;__newindex=self.maskedMethod})
		return headers
	end;
	responseHeader = function (self, header, ...)
		if select("#", ...) > 0 then
			if self._headersAlreadySent then
				Exception"can't change response headers, headers already sent"
			end
			self._responseHeaders[header] = (select(1, ...))
			return self
		else
			local lowerHeader = header:lower()
			for k, v in pairs(self._responseHeaders) do
				if k:lower() == lowerHeader then
					return v
				end
			end
			return nil
		end
	end;
	responseCode = function (self, ...)
		if select("#", ...) > 0 then		
			self._responseCode = (select(1, ...))
			return self
		else
			return self._responseCode
		end
	end;
	requestMethod = function (self)
		return self:requestHeader"REQUEST_METHOD"
	end;
	-- Get
	get = function (self, key, ...)
		if select("#", ...) > 0 then
			self._get[key] = (select(1, ...))
			return self
		else
			return self._get[key] 
		end
	end;
	getData = function (self) return self._get end;
	parseGetData = function (self)
		local _, data = (self:requestHeader"REQUEST_URI" or ""):split"?"
		if data then
			data = data:explode"&"
			for _, v in ipairs(data) do
				local key, val = v:split"="
				val = urlDecode(val)
				self._get[key] = urlDecode(val)
			end
		end
	end;
	-- Post
	post = function (self, key, ...)
		if select("#", ...) > 0 then
			self._post[key] = (select(1, ...))
			return self
		else
			return self._post[key]
		end
	end;
	postData = function (self) return self._post end;
	parsePostData = function (self)
		if "POST" ~= self:requestHeader"REQUEST_METHOD" then
			return
		end
		local contentType = self:requestHeader"CONTENT_TYPE"
		if contentType:beginsWith"application/x-www-form-urlencoded" then
			local data = io.read(tonumber(self:requestHeader"CONTENT_LENGTH"))
			if data then
				data = data:explode"&"
				for _, v in ipairs(data) do
					local key, val = v:split"="
					val = urlDecode(val)
					if not self._post[key] then
						self._post[key] = val
					else
						if "table" == type(self._post[key]) then
							table.insert(self._post[key], val)
						else
							self._post[key] = {self._post[key];val}
						end
					end
				end
			end
		elseif contentType:beginsWith"multipart/form-data" then
			local _, boundaryStr = contentType:split";"
			local _, boundary = boundaryStr:split"="
			self:parseMultipartFormData("--"..boundary, io.read "*a")
		else
			Exception("not implemented for content-type: "..contentType)
		end
	end;
	-- Cookies
	parseCookies = function (self)
		local cookieString = self:requestHeader"HTTP_COOKIE"
		if not cookieString then
			return nil
		end
		local cookies
		if cookieString:find("&", 1, true) then
			cookies = cookieString:explode"&"
		elseif cookieString:find(";", 1, true) then
			cookies = cookieString:explode";"
		else
			cookies = {cookieString}
		end
		for _, v in ipairs(cookies) do
			local name, value = v:split"="
			self._cookies[name:trim()] = value:trim()
		end
	end;
	cookie = function (self, name, ...)
		if select("#", ...) > 0 then
			local value, expires, domain, path = ...
			if not name then
				Exception"name required"
			end
			local cookie = name.."="
			self._cookies[name] = value
			if value then cookie = cookie..value end
			if expires then
				cookie = cookie..";expires="..expires
			end
			if domain then
				cookie = cookie..";domain="..domain
			end
			if path then
				cookie = cookie..";path="..path
			end
			self:responseHeader("Set-Cookie", cookie)
			return self
		else
			return self._cookies[name]
		end
	end;
	cookies = function (self) return self._cookies end;
	sendHeaders = function (self)
		io.write = self._write
		if not self._responseCode then self._responseCode = 200 end
		if not self:responseHeader"Location" then
			io.write("HTTP/1.1 ", self._responseCode, " ", responseString[self._responseCode], "\n")
		end
		if not self:responseHeader("Content-type") then
			self:responseHeader("Content-type", "text/html")
		end
		for k, v in pairs(self._responseHeaders) do
			io.write(k, ":", v, "\n")
		end
		io.write"\n"
		self._headersAlreadySent = true
	end;
}

local Scgi = Object:extend{
	__tag = .....".Scgi",
	init = function (self, client)
		local ch = client:receive(1)
		local request = ""
		while ch ~= ":" do
			if not ch then Exception"invalid SCGI request" end
			request = request..ch
			ch = client:receive(1)
		end
		local len = tonumber(request)
		if not len then Exception"invalid SCGI request" end
		request = request..ch..client:receive(len+1)
		io.write = function (...)
			if not self._headersAlreadySent then self:sendHeaders() end
			local params = {select(1, ...)}
			for i = 1, select("#", ...) do
				client:send(tostring(params[i]))
			end
		end
		local keysAndValues = request:slice(request:find(":", 1, true)+1, -3):explode"\0"
		local i
		self._requestHeaders = {}
		for i = 1, #keysAndValues/2 do
			self._requestHeaders[keysAndValues[i*2-1]] = keysAndValues[i*2]
		end
		self._request = request
		self._client = client
		self._responseHeaders = {}
		self._headersAlreadySent = false
	end;
	requestHeader = function (self, header)
		return self._requestHeaders[header]
	end;
	responseHeader = function (self, header, ...)
		if select("#", ...) > 0 then
			self._responseHeaders[header] = (select(1, ...))
			return self
		else
			local lowerHeader = header:lower()
			for k, v in pairs(self._responseHeaders) do
				if k:lower() == lowerHeader then
					return v
				end
			end
			return nil
		end
	end;
	sendHeaders = function (self)
		if self._headersAlreadySent then return end
		self._headersAlreadySent = true
		if not self._responseCode then
			self._responseCode = 200
		end
		io.write("HTTP/1.1 ", self._responseCode, " ", responseString[self._responseCode], "\n")
		if not self:getResponseHeader("Content-type") then
			self:setResponseHeader("Content-type", "text/html")
		end
		for k, v in pairs(self._responseHeaders) do
			io.write(k, ":", v, "\n")
		end
		io.write"\n"
	end,
	close = function (self)
		self._client:close()
	end
}

local SocketAppServer = Object:extend{
	__tag = .....".SocketAppSever",
	init = function (self, wsApi, host, port)
		self._wsApi = wsApi
		self._host, self._port = host, port
		if not self._host then
			Exception"invalid host"
		end
		if not self._port then
			Exception"invalid port number"
		end
		self._server = Socket.tcp()
		if not self._server:bind(self._host, self._port) then
			Exception("can't bind "..self._host..":"..self._port.." to server")
		end
		if not self._server:listen(10) then
			Exception"can't listen"
		end
	end,
	run = function (self, application)
		local client
		while true do
			client = self._server:accept()
			if not client then
				Exception"can't accept connection"
			end
			local co = coroutine.create(setfenv(function ()
				local wsApi = self._wsApi(client)
				application(wsApi)
				wsApi:close()
			end, table.deepCopy(_G)))
			local res, fail = coroutine.resume(co)
			if not res then
				io.write(fail)
			end
		end
	end
}

return {
	HttpRequest=HttpRequest;HttpResponse=HttpResponse;
	Exception=Exception;Api=Api;Cgi=Cgi;Scgi=Scgi;
	SocketAppServer=SocketAppServer;Http403=Http403;Http404=Http404;
}
