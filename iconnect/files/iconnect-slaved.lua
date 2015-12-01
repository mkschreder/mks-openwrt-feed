#!/usr/bin/lua
-- Author: Martin K. Schröder, Copyright 2015

-- iconnect ubus rpc service 
-- allows exposing ubus api to another host through access controlled interface 
-- TODO: right now only a proof of concept. Do not use in production! 

require("ubus");
require("uloop");
local juci = require("juci/core");

uloop.init();

local conn = ubus.connect();
if conn == nil then
        print("could not connect to ubus socket!");
        return;
end

local iconnect_hub_socket = "/var/run/iconnect.hub.sock"; 
local hub = ubus.connect(iconnect_hub_socket);
if hub == nil then
        print("could not connect to "..iconnect_hub_socket);
        return;
end

local clid = juci.shell("openssl x509 -noout -in /etc/stunnel/stunnel.pem -fingerprint | sed 's/://g' | cut -f 2 -d '='");
clid = clid:match("%S+");

local function iconnect_access(sid)
	return true; 
end

local function iconnect_login(req, msg)

end

local function iconnect_logout(req, msg)

end

local function iconnect_call(req, msg)
	local res = {}; 
	if(not iconnect_access(msg.sid)) then return 1; end; 
	if(not msg.object or msg.object == "") then res.error = "No object specified!"; 
	elseif(not msg.method or msg.method == "") then res.error = "No method specified!"; 
	end
	
	if(not res.error) then 
		local data = conn:call(msg.object, msg.method, msg.data); 
		if(not data) then res.error = "Call Failed!";
		else res = data; end
	end
	hub:reply(req, res); 
end

local function iconnect_list(req, msg)
	local res = {}; 
	if(not iconnect_access(msg.sid)) then return 1; end 
	if(not res.error) then
		local namespaces = conn:objects()
		for i, n in ipairs(namespaces) do
			local signatures = conn:signatures(n)
			res[n] = signatures; 
		end
	end
	hub:reply(req, res); 
	return 0; 
end

hub:add({
	[clid] = {
		login = { iconnect_login, { username = ubus.STRING, password = ubus.STRING } }, 
		logout = { iconnect_logout, { sid = ubus.STRING } }, 
		call = { iconnect_call, { sid = ubus.STRING, object = ubus.STRING, method = ubus.STRING } }, 
		list = { iconnect_list, { sid = ubus.STRING, object = ubus.STRING } }
	}
});

uloop.run();
