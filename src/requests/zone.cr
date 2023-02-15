require "grok"

class DNSManager::Request

	IPC::JSON.message AddOrUpdateZone, 10 do
		property zone : DNSManager::Storage::Zone

		def initialize(@zone)
		end

		def handle(dnsmanagerd : DNSManager::Service, event : IPC::Event)
			user = dnsmanagerd.get_logged_user event
			raise NotLoggedException.new if user.nil?

			# TODO: test for zone validity.
			if errors = zone.get_errors?
				return DNSManager::Response::InvalidZone.new errors
			end

			# In case there is no error, retrieve the zone in the DB.
			#z = dnsmanagerd.storage.zones_by_domain.get? zone.domain
			#if z
			#else
			#	dnsmanagerd.storage.zones << @zone
			#end

			Response::Success.new
		end
	end
	DNSManager.requests << AddOrUpdateZone
end
