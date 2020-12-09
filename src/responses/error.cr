
class DNSManager::Response
	IPC::JSON.message Error, 0 do
		property reason : String | Array(String)
		def initialize(@reason)
		end
	end
	DNSManager.responses << Error
end
