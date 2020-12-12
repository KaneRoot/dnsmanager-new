require "authd"
require "ipc"
require "../network.cr"
require "../storage.cr"
require "yaml"

require "baguette-crystal-base"

require "../config"

require "./lib/*"

class Context
	class_property command  = "not-implemented"
	class_property args     : Array(String)? = nil
end

require "./parser.cr"

def read_zones
	Array(DNSManager::Storage::Zone).from_json_files Context.args.not_nil!
end

class Actions
	property the_call     = {} of String => Proc(Nil)
	property dnsmanagerd  : DNSManager::Client
	property authd        : AuthD::Client
	property authd_config : Baguette::Configuration::Auth
	property config       : Baguette::Configuration::DNSManager

	def initialize(@dnsmanagerd, @authd, @authd_config, @config)
		#
		# Admin section.
		#

		# Maintainance
		@the_call["admin-maintainance"] = ->admin_maintainance
		@the_call["user-zone-add"]      = ->user_zone_add
	end

	def admin_maintainance
		subjects = Context.args.not_nil!
		past_is_verbosity = false
		subjects.each do |subject|
			begin
				case subject
				when /verbosity/i
					Baguette::Log.info "changing verbosity"
					past_is_verbosity = true
					next
				end

				key = @authd_config.shared_key

				if past_is_verbosity
					sub   = DNSManager::Request::Maintainance::Subject::Verbosity
					value = subject.to_i
					pp! sub, value
					pp! @dnsmanagerd.admin_maintainance key, sub, value
				else
					sub   = DNSManager::Request::Maintainance::Subject.parse(subject)
					pp! sub
					pp! @dnsmanagerd.admin_maintainance key, sub
				end
			rescue e
				puts "error for admin_maintainance #{subject}: #{e.message}"
			end
		end
	end

	def user_zone_add
		zones = read_zones
		zones.each do |zone|
			begin
				pp! zone
				pp! @dnsmanagerd.user_zone_add zone
			rescue e
				puts "error for admin_maintainance #{subject}: #{e.message}"
			end
		end
	end
end

def main

	simulation, no_configuration, configuration_file = Baguette::Configuration.option_parser

	# Authd configuration.
	authd_config = if no_configuration
		Baguette::Log.info "do not load a configuration file."
		Baguette::Configuration::Auth.new
	else
		# Configuration file is for dnsmanagerd.
		Baguette::Configuration::Auth.get || Baguette::Configuration::Auth.new
	end
	if key_file = authd_config.shared_key_file
		authd_config.shared_key = File.read(key_file).chomp
	end

	# Authd configuration.
	config = if no_configuration
		Baguette::Log.info "do not load a configuration file."
		Baguette::Configuration::DNSManager.new
	else
		# Configuration file is for dnsmanagerd.
		Baguette::Configuration::DNSManager.get || Baguette::Configuration::DNSManager.new
	end

	Baguette::Context.verbosity = config.verbosity
	Baguette::Log.info "verbosity: #{config.verbosity}."

	parsing_cli authd_config

	# dnsmanagerd connection and authentication
	dnsmanagerd = DNSManager::Client.new

	if simulation
		pp! authd_config
		pp! Context.command
		pp! Context.args
		exit 0
	end

	# Authd authentication, get the token and quit right away.
	# If login == pass == "undef": do not even try.
	if authd_config.login.nil? || authd_config.pass.nil?
		Baguette::Log.info "no authd login"
	else
		login = authd_config.login.not_nil!
		pass  = authd_config.pass.not_nil!
		token = authd_get_token login: login, pass: pass
		dnsmanagerd.login token
	end

	authd = AuthD::Client.new
	actions = Actions.new dnsmanagerd, authd, authd_config, config

	# Now we did read the intent, we should proceed doing what was asked.
	begin
		actions.the_call[Context.command].call
	rescue e
		Baguette::Log.info "The command is not recognized (or implemented)."
	end

	# dnsmanagerd disconnection
	dnsmanagerd.close
	authd.close
rescue e
	Baguette::Log.info "Exception: #{e}"
end

# Command line:
#   tool [options] command subcommand [options-for-subcommand] [YAML-or-JSON-files]

main
