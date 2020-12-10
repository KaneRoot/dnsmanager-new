
class Baguette::Configuration
	class DNSManager < IPC
		property service_name      : String  = "dnsmanager"
		property recreate_indexes  : Bool    = false
		property storage_directory : String  = "storage"

		def initialize
		end
	end
end
