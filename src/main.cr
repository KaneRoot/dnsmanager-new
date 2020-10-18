require "http/server"

require "ipc"
require "ipc/json"
require "authd"
require "baguette-crystal-base"

class Context
	class_property service_name = "dnsmanager"
	class_property recreate_indexes = false
	class_property print_timer      = false
end

module DNSManager
	class Exception < ::Exception
	end
	class AuthorizationException < ::Exception
	end
	class NotLoggedException < ::Exception
	end
	class AdminAuthorizationException < ::Exception
	end
end


require "./cli-parser"
require "./storage.cr"
require "./network.cr"


class DNSManager::Service < IPC::Server
	getter storage_directory  : String
	getter storage            : DNSManager::Storage
	getter logged_users       : Hash(Int32, AuthD::User::Public)
	# getter logged_connections : Hash(Int32, IPC::Connection)

	@authd : AuthD::Client

	def initialize(service_name, @storage_directory : String, @authd : AuthD::Client)
		@storage = DNSManager::Storage.new @storage_directory

		@logged_users       = Hash(Int32, AuthD::User::Public).new
		# @logged_connections = Hash(Int32, IPC::Connection).new

		super service_name
	end

	def get_logged_user(event : IPC::Event::Events)
		fd = event.connection.fd

		@logged_users[fd]?
	end

	def decode_token(token : String)
		@auth.decode_token token
	end

	def get_user_data(uid : Int32)
		@storage.user_data_per_user.get uid.to_s
	rescue e : DODB::MissingEntry
		entry = UserData.new uid
		entry
	end

	def get_user_data(user : ::AuthD::User::Public)
		get_user_data user.uid
	end

	def update_user_data(user_data : UserData)
		@storage.user_data_per_user.update_or_create user_data.uid.to_s, user_data
	end

	def handle_request(event : IPC::Event::MessageReceived)
		request_start = Time.utc

		request = DNSManager.requests.parse_ipc_json event.message

		if request.nil?
			raise "unknown request type"
		end

		reqname = request.class.name.sub /^DNSManager::Request::/, ""
		Baguette::Log.debug "<< #{reqname}"

		response = DNSManager::Response::Error.new "generic error"

		begin
			response = request.handle self, event
		rescue e : AuthorizationException
			Baguette::Log.error "#{reqname} authorization error"
			response = DNSManager::Response::Error.new "authorization error"
		rescue e : AdminAuthorizationException
			Baguette::Log.error "#{reqname} no admin authorization"
			response = DNSManager::Response::Error.new "admin authorization error"
		rescue e : NotLoggedException
			Baguette::Log.error "#{reqname} user not logged"
			response = DNSManager::Response::Error.new "user not logged"
		# Do not handle generic exception case: do not provide a response.
		# rescue e # Generic case
		# 	Baguette::Log.error "#{reqname} generic error #{e}"
		end

		# If clients sent requests with an “id” field, it is copied
		# in the responses. Allows identifying responses easily.
		response.id = request.id

		send event.fd, response

		duration = Time.utc - request_start

		response_str = response.class.name.sub /^DNSManager::Response::/, ""

		if response.is_a? DNSManager::Response::Error
			Baguette::Log.warning ">> #{response_str} (#{response.reason})"
		else
			Baguette::Log.debug ">> #{response_str} (Total duration: #{duration})"
		end
	end

	def run
		Baguette::Log.title "Starting #{Context.service_name}"

		self.loop do |event|
			begin
				case event
				when IPC::Event::Timer
					Baguette::Log.debug "Timer" if Context.print_timer

				when IPC::Event::Connection
					Baguette::Log.debug "connection from #{event.fd}"

				when IPC::Event::Disconnection
					Baguette::Log.debug "disconnection from #{event.fd}"
					fd = event.fd

					# @logged_connections.delete fd
					@logged_users.delete fd

				when IPC::Event::MessageSent
					Baguette::Log.debug "message sent to #{event.fd}"

				when IPC::Event::MessageReceived
					Baguette::Log.debug "message sent to #{event.fd}"

					handle_request event
				else
					Baguette::Log.warning "unhandled IPC event: #{event.class}"
				end
			rescue exception
				Baguette::Log.error "exception: #{typeof(exception)} - #{exception.message}"
			end
		end
	end
end

def dnsmanager_webserver_init
	server = HTTP::Server.new do |context|
		context.response.content_type = "text/plain"
		pp! context.request
		context.response.print "Hello. New version of dnsmanager, soon."
	end

	address = server.bind_tcp Context.webserver_domain, Context.webserver_port
	puts "Listening on http://#{address}"

	server
end

authd = AuthD::Client.new
authd.key = Context.authd_key.not_nil!
server = dnsmanager_webserver_init

spawn server.listen

service = DNSManager::Service.new Context.service_name, Context.storage_directory, authd
service.run
