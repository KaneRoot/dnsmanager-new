require "ipc"
require "json"

class IPC::JSON
	def handle(service : IPC, event : IPC::Event)
		raise "unimplemented"
	end
end

module DNSManager
	class_getter requests  = [] of IPC::JSON.class
	class_getter responses = [] of IPC::JSON.class
end

require "./requests/*"
require "./responses/*"
