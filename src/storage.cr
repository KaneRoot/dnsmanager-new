require "json"
require "uuid"
require "uuid/json"

require "dodb"

# require "./storage/*"

class DNSManager::Storage
	def initialize(@root : String)
	end
end
