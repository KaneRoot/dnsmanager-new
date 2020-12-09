require "json"
require "uuid"
require "uuid/json"

class DNSManager::Storage::UserData
	include JSON::Serializable

	property uid     : Int32

	# Users may have many domains, and a domain can have many owners.
	property domains = [] of String

	def initialize(@uid)
	end
end
