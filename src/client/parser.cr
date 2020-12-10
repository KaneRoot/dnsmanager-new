require "option_parser"


class OptionParser
	def to_s(io : IO)
		if banner = @banner
			io << banner
			io << "\n\n"
		end
		@flags.join io, "\n"
	end
end


def parsing_cli(authd_config : Baguette::Configuration::Auth)

	opt_authd_admin = -> (parser : OptionParser, authd_config : Baguette::Configuration::Auth) {
		parser.on "-k file", "--key-file file", "Read the authd shared key from a file." do |file|
			authd_config.shared_key  = File.read(file).chomp
			Baguette::Log.info "Key for admin operations: #{authd_config.shared_key}."
		end
	}

	# frequently used functions
	opt_authd_login = -> (parser : OptionParser, authd_config : Baguette::Configuration::Auth) {
		parser.on "-l LOGIN", "--login LOGIN", "Authd user login." do |login|
			authd_config.login = login
			Baguette::Log.info "User login for authd: #{authd_config.login}."
		end
		parser.on "-p PASSWORD", "--password PASSWORD", "Authd user password." do |password|
			authd_config.pass = password
			Baguette::Log.info "User password for authd: #{authd_config.pass}."
		end
	}

	opt_help = -> (parser : OptionParser) {
		parser.on "-h", "--help", "Prints command usage." do
			puts "usage: #{PROGRAM_NAME} command -h"
			puts
			puts parser

			case Context.command
			when /admin-maintainance/
				Baguette::Log.warning "should provide subjects to request"
				Baguette::Log.warning "as in:"
				DNSManager::Request::Maintainance::Subject.names.each do |n|
					Baguette::Log.warning "- #{n}"
				end
			end

			exit 0
		end
	}

	# Unrecognized parameters are used to create commands with multiple arguments.
	# Example: user add _login email phone_
	# Here, login, email and phone are unrecognized arguments.
	# Still, the "user add" command expect them.
	unrecognized_args_to_context_args = -> (parser : OptionParser,
		nexact   : Int32?,
		at_least : Int32?) {

		# With the right args, these will be interpreted as serialized data.
		parser.unknown_args do |args|

			# either we test with the exact expected number of arguments or the least.
			if exact = nexact
				if args.size != exact
					Baguette::Log.error "#{parser}"
					exit 1
				end
			elsif least = at_least
				if args.size < least
					Baguette::Log.error "#{parser}"
					exit 1
				end
			else
				Baguette::Log.error "Number of parameters not even provided!"
				Baguette::Log.error "#{parser}"
				exit 1
			end

			args.each do |arg|
				Baguette::Log.debug "Unrecognized argument: #{arg} (adding to Context.args)"
				if Context.args.nil?
					Context.args = Array(String).new
				end
				Context.args.not_nil! << arg
			end
		end
	}

	parser = OptionParser.new do |parser|
		parser.banner = "Welcome on the DNSManager CLI administration."

		# Admin section.
		parser.on "admin", "Admin operations." do
			# All admin operations require the shared key.
			opt_authd_admin.call parser, authd_config

			# Maintenance.
			parser.on("maintainance", "Maintainance operation of the website.") do
				Baguette::Log.info "Maintainance operation of the website."
				Context.command = "admin-maintainance"
				parser.banner = "COMMAND: admin maintainance subject [value]"
				unrecognized_args_to_context_args.call parser, nil, 1
			end

		end

		opt_help.call parser
	end

	parser.parse
end
