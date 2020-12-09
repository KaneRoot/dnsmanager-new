
class DNSManager::Request
	# Periodic actions to perform as an administrator.
	IPC::JSON.message Maintainance, 7 do
		enum Subject
			Verbosity      # Change the verbosity of dnsmanagerd.
		end

		property key : String
		property subject : Subject
		property value : Int32?

		def initialize(@key, @subject)
		end

		def handle(dnsmanagerd : DNSManager::Service, event : IPC::Event::Events)
			# This request means serious business.
			raise AdminAuthorizationException.new if key != dnsmanagerd.authd.key

			case @subject
			when Subject::Verbosity
				if verbosity = @value
					Baguette::Context.verbosity = verbosity
				end
				Response::Success.new
			else
				Response::Error.new "not implemented"
			end
		end
	end
	DNSManager.requests << Maintainance
end
