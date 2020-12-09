
# Store a DNS zone.
class DNSManager::Storage::Zone
	include JSON::Serializable

	property domain    : String
	property resources = [] of DNSManager::Storage::Zone::ResourceRecord

	def initialize(@domain)
	end


	# Store a Resource Record: A, AAAA, TXT, PTR, CNAME…
	abstract class ResourceRecord
		include JSON::Serializable

		use_json_discriminator "rrtype", {
				a:      A,
				aaaa:   AAAA,
				soa:    SOA,
				txt:    TXT,
				ptr:    PTR,
				ns:     NS,
				cname:  CNAME,
				mx:     MX,
				srv:    SRV
			}

		# Used to discriminate between classes.
		property rrtype   : String = ""

		property name   : String
		property ttl    : UInt32
		property target : String

		# zone class is omited, it always will be IN in our case.
		def initialize(@name, @ttl, @target)
			@rrtype = self.class.name.downcase.gsub /dnsmanager::storage::zone::/, ""
		end
	end

	class SOA < ResourceRecord
		# Start of Authority
		property mname   : String # Master Name Server for the zone.
		property rname   : String # admin email address john.doe@example.com => john\.doe.example.com
		property serial  : UInt64 = 0      # Number for tracking new versions of the zone (master-slaves).
		property refresh : UInt64 = 86400  # #seconds before requesting new zone version (master-slave).
		property retry   : UInt64 = 7200   # #seconds before retry accessing new data from the master.
		property expire  : UInt64 = 3600000# #seconds slaves should consider master dead.

		def initialize(@name, @ttl, @target,
			@mname, @rname,
			@serial = 0, @refresh = 86400, @retry = 7200, @expire = 3600000)
			@rrtype = "soa"
		end
	end

	class A < ResourceRecord
	end
	class AAAA < ResourceRecord
	end
	class TXT < ResourceRecord
	end
	class PTR < ResourceRecord
	end
	class NS < ResourceRecord
	end
	class CNAME < ResourceRecord
	end

	class MX < ResourceRecord
		property priority  : UInt32 = 10
		def initialize(@name, @ttl, @target, @priority = 10)
			@rrtype = "mx"
		end
	end

	class SRV < ResourceRecord
		property port     : UInt16
		property protocol : String = "tcp"
		property priority : UInt32 = 10
		property weight   : UInt32 = 10
		def initialize(@name, @ttl, @target, @port, @protocol = "tcp", @priority = 10, @weight = 10)
			@rrtype = "srv"
		end
	end

	def to_s(io : IO)
		io << "TEST"
	end
end
