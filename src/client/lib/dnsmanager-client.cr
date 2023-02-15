require "../../requests/*"

class DNSManager::Client < IPC
	property server_fd : Int32 = -1

	def initialize
		super()
		fd = self.connect "dnsmanager"
		if fd.nil?
			raise "couldn't connect to 'auth' IPC service"
		end
		@server_fd = fd
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

	#
	# Simple users.
	#

	def login(token : String)
		request = DNSManager::Request::Login.new token
		send_now request
		parse_message [ DNSManager::Response::Success ], read
	end

	# Adding a full zone.
	def user_zone_add(zone : DNSManager::Storage::Zone)
		request = DNSManager::Request::AddOrUpdateZone.new zone
		send_now request
		parse_message [ DNSManager::Response::Success, DNSManager::Response::InvalidZone ], read
	end

	#
	# Admin stuff.
	#

	def admin_maintainance(key : String, subject : DNSManager::Request::Maintainance::Subject, value : Int32? = nil)
		request = DNSManager::Request::Maintainance.new(key,subject)
		if value
			request.value = value
		end
		send_now request
		parse_message [ DNSManager::Response::Success ], read
	end

	def send_now(msg : IPC::JSON)
		m = IPCMessage::TypedMessage.new msg.type.to_u8, msg.to_json
		write @server_fd, m
	end

	def send_now(type : Request::Type, payload)
		m = IPCMessage::TypedMessage.new type.value.to_u8, payload
		write @server_fd, m
	end

	def read
		slice = self.read @server_fd
		m = IPCMessage::TypedMessage.deserialize slice
		m.not_nil!
	end
end
