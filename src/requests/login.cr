
class DNSManager::Request
	IPC::JSON.message Login, 0 do
		property token : String

		def initialize(@token)
		end

		def handle(dnsmanagerd : DNSManager::Service, event : IPC::Event::Events)
			user, _ = dnsmanagerd.decode_token token
			dnsmanagerd.logged_users[event.fd] = user

			# In case we want to log their last connection.
			#dnsmanagerd.auth.edit_profile_content user.uid, {
			#	"dnsmanager-last-connection" => JSON::Any.new Time.utc.to_s
			#}

			return Response::Success.new 
		rescue e
			# FIXME: Should those be logged?
			return Response::Error.new "unauthorized"
		end
	end
	DNSManager.requests << Login
end
