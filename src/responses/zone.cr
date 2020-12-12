
class DNSManager::Response
	IPC::JSON.message InvalidZone, 10 do
		# For now, Error is just an alias on String.
		property errors : Array(DNSManager::Storage::Zone::Error)
		def initialize(@errors)
		end
	end
	DNSManager.responses << InvalidZone
end

