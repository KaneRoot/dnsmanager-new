require "../../requests/*"

class DNSManager::Client < IPC::Client
	def initialize
		initialize "dnsmanager"
	end

	# TODO: parse_message should raise exception if response not anticipated
	def parse_message(expected_messages, message)
		em = Array(IPC::JSON.class).new
		expected_messages.each do |e|
			em << e
		end
		em << DNSManager::Response::Error
		em.parse_ipc_json message
	end
end


# Simple users.
class DNSManager::Client < IPC::Client
	def login(token : String)
		request = DNSManager::Request::Login.new token
		send_now @server_fd.not_nil!, request
		parse_message [ DNSManager::Response::Success ], read
	end

	# Adding a full zone.
	def user_zone_add(zone : DNSManager::Storage::Zone)
		request = DNSManager::Request::AddOrUpdateZone.new zone
		send_now @server_fd.not_nil!, request
		parse_message [ DNSManager::Response::Success, DNSManager::Response::InvalidZone ], read
	end
end

# Admin stuff.
class DNSManager::Client < IPC::Client
	def admin_maintainance(key : String, subject : DNSManager::Request::Maintainance::Subject, value : Int32? = nil)
		request = DNSManager::Request::Maintainance.new(key,subject)
		if value
			request.value = value
		end
		send_now @server_fd.not_nil!, request
		parse_message [ DNSManager::Response::Success ], read
	end
end
