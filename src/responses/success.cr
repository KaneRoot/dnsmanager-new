
class DNSManager::Response
	IPC::JSON.message Success, 1 do
		def initialize
		end
	end
	DNSManager.responses << Success
end
