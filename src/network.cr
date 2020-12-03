require "ipc"
require "json"

class IPC::JSON
	def handle(service : IPC::Server, event : IPC::Event::Events)
		raise "unimplemented"
	end
end

module DNSManager
	class_getter requests  = [] of IPC::JSON.class
	class_getter responses = [] of IPC::JSON.class
end

class DNSManager::Response
	IPC::JSON.message Error, 0 do
		property reason : String | Array(String)
		def initialize(@reason)
		end
	end
	IPC::JSON.message Success, 1 do
		def initialize
		end
	end
end

class DNSManager::Request
	IPC::JSON.message Login, 0 do
	end
	IPC::JSON.message Logout, 1 do
	end
	DNSManager.requests << Logout
end

# require "./requests/*"
