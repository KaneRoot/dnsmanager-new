# require "http/server"
require "option_parser"

require "ipc"
require "ipc/json"
require "authd"
require "baguette-crystal-base"

require "./config"

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


require "./storage.cr"
require "./network.cr"


class DNSManager::Service < IPC
	property configuration    : Baguette::Configuration::DNSManager
	getter storage            : DNSManager::Storage
	getter logged_users       : Hash(Int32, AuthD::User::Public)

	property authd            : AuthD::Client

	def initialize(@configuration, @authd_key : String)
		super()
		@storage = DNSManager::Storage.new @configuration.storage_directory, @configuration.recreate_indexes

		@logged_users       = Hash(Int32, AuthD::User::Public).new

		# TODO: auth service isn't in the FDs pool.
		# If the service crashes, dnsmanagerd won't know it.
		@authd = AuthD::Client.new
		authd.key = @authd_key

		self.timer @configuration.ipc_timer
		self.service_init @configuration.service_name
	end

	def get_logged_user(event : IPC::Event)
		@logged_users[event.fd]?
	end

	def decode_token(token : String)
		@authd.decode_token token
	end

	def handle_request(event : IPC::Event)
		request_start = Time.utc

		array = event.message.not_nil!
		slice = Slice.new array.to_unsafe, array.size
		message = IPCMessage::TypedMessage.deserialize slice
		request = DNSManager.requests.parse_ipc_json message.not_nil!

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

		schedule event.fd, response

		duration = Time.utc - request_start

		response_name = response.class.name.sub /^DNSManager::Response::/, ""

		if response.is_a? DNSManager::Response::Error
			Baguette::Log.warning ">> #{response_name} (#{response.reason})"
		else
			Baguette::Log.debug ">> #{response_name} (Total duration: #{duration})"
		end
	end

	def run
		Baguette::Log.title "Starting #{@configuration.service_name}"

		self.loop do |event|
			begin
				case event.type
				when LibIPC::EventType::Timer
					Baguette::Log.debug "Timer" if @configuration.print_ipc_timer

				when LibIPC::EventType::Connection
					Baguette::Log.debug "connection from #{event.fd}"

				when LibIPC::EventType::Disconnection
					Baguette::Log.debug "disconnection from #{event.fd}"
					@logged_users.delete event.fd

				when LibIPC::EventType::MessageTx
					Baguette::Log.debug "message sent to #{event.fd}"

				when LibIPC::EventType::MessageRx
					Baguette::Log.debug "message received from #{event.fd}"
					handle_request event

				else
					Baguette::Log.warning "unhandled IPC event: #{event.class}"
					if event.responds_to?(:fd)
						fd = event.fd
						Baguette::Log.warning "closing #{fd}"
						close fd
						@logged_users.delete fd
					end

				end

			rescue exception
				Baguette::Log.error "exception: #{typeof(exception)} - #{exception.message}"
			end
		end
	end
end


def main

	# First option parsing, same with all Baguette (service) applications.
	simulation, no_configuration, configuration_file = Baguette::Configuration.option_parser

	# Authd configuration.
	authd_configuration = if no_configuration
		Baguette::Log.info "do not load a configuration file."
		Baguette::Configuration::Auth.new
	else
		# Configuration file is for dnsmanagerd.
		Baguette::Configuration::Auth.get || Baguette::Configuration::Auth.new
	end
	if key_file = authd_configuration.shared_key_file
		authd_configuration.shared_key = File.read(key_file).chomp
	end

	# DNSManagerd configuration.
	configuration = if no_configuration
		Baguette::Log.info "do not load a configuration file."
		Baguette::Configuration::DNSManager.new
	else
		# In case there is a configuration file helping with the parameters.
		Baguette::Configuration::DNSManager.get(configuration_file) ||
			Baguette::Configuration::DNSManager.new
	end


	OptionParser.parse do |parser|
		parser.on "-v verbosity-level", "--verbosity level", "Verbosity." do |opt|
			Baguette::Log.info "Verbosity level: #{opt}"
			configuration.verbosity = opt.to_i
		end

		parser.on "-k key-file", "--key-file file", "Key file." do |opt|
			authd_configuration.shared_key = File.read(opt).chomp
			Baguette::Log.debug "Authd key: #{authd_configuration.shared_key.not_nil!}"
		end

		# IPC Service options
		parser.on "-s service_name", "--service_name service_name", "Service name (IPC)." do |service_name|
			Baguette::Log.info "Service name: #{service_name}"
			configuration.service_name = service_name
		end

		parser.on "-r storage_directory", "--root storage_directory", "Storage directory." do |storage_directory|
			Baguette::Log.info "Storage directory: #{storage_directory}"
			configuration.storage_directory = storage_directory
		end


		parser.on "-h", "--help", "Show this help" do
			puts parser
			exit 0
		end
	end

	if authd_configuration.shared_key.nil?
		Baguette::Log.error "No authd key file: cannot continue"
		exit 1
	end

	if simulation
		pp! authd_configuration, configuration
		exit 0
	end

	authd_key = authd_configuration.shared_key.not_nil!

	service = DNSManager::Service.new configuration, authd_key
	service.run
end

main
