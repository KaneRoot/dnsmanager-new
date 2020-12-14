require "ipaddress"

# Store a DNS zone.
class DNSManager::Storage::Zone
	include JSON::Serializable

	property domain    : String
	property resources = [] of DNSManager::Storage::Zone::ResourceRecord

	# We don't want to accept less than 30 seconds TTL.
	class_property ttl_limit_min = 30

	def initialize(@domain)
	end

	alias Error = String

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
		property rrtype : String = ""

		property name   : String
		property ttl    : UInt32
		property target : String

		# zone class is omited, it always will be IN in our case.
		def initialize(@name, @ttl, @target)
			@rrtype = self.class.name.downcase.gsub /dnsmanager::storage::zone::/, ""
		end

		def get_errors : Array(Error)
			[] of Error
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
			@serial = 0.to_u64, @refresh = 86400.to_u64, @retry = 7200.to_u64, @expire = 3600000.to_u64)
			@rrtype = "soa"
		end

		def get_errors : Array(Error)
			errors = [] of Error

			# TODO: name

			if @ttl < Zone.ttl_limit_min
				errors << "SOA invalid ttl: #{@ttl}, shouldn't be less than #{Zone.ttl_limit_min}"
			end

			# TODO: target
			# TODO: mname
			# TODO: rname
			# TODO: serial
			# TODO: refresh
			# TODO: retry
			# TODO: expire

			errors
		end
	end

	class A < ResourceRecord
		def get_errors : Array(Error)
			errors = [] of Error

			unless Zone.is_subdomain_valid? @name
				errors << "A invalid subdomain: #{@name}"
			end

			if @ttl < Zone.ttl_limit_min
				errors << "A invalid ttl: #{@ttl}, shouldn't be less than #{Zone.ttl_limit_min}"
			end

			unless Zone.is_ipv4_address_valid? @target
				errors << "A target not valid ipv4: #{@target}"
			end

			errors
		end
	end

	class AAAA < ResourceRecord
		def get_errors : Array(Error)
			errors = [] of Error

			unless Zone.is_subdomain_valid? @name
				errors << "AAAA invalid subdomain: #{@name}"
			end

			if @ttl < Zone.ttl_limit_min
				errors << "AAAA invalid ttl: #{@ttl}, shouldn't be less than #{Zone.ttl_limit_min}"
			end

			unless Zone.is_ipv6_address_valid? @target
				errors << "AAAA target not valid ipv6: #{@target}"
			end

			errors
		end
	end

	class TXT < ResourceRecord
		def get_errors : Array(Error)
			errors = [] of Error

			unless Zone.is_subdomain_valid? @name
				errors << "TXT invalid subdomain: #{@name}"
			end

			if @ttl < Zone.ttl_limit_min
				errors << "TXT invalid ttl: #{@ttl}, shouldn't be less than #{Zone.ttl_limit_min}"
			end

			errors
		end
	end

	class PTR < ResourceRecord
		def get_errors : Array(Error)
			errors = [] of Error

			# TODO: PTR name verification.
			# PTR name is different from others.
			# Its name contains numerical-only subdomains.
			unless Zone.is_ptr_name_valid? @target
				errors << "PTR invalid subdomain: #{@target}"
			end

			# The PTR name has to end with in-addr.arpa or ip6.arpa.
			unless @name.ends_with?(/in-addr.arpa\.?/) || @name.ends_with?(/ip6.arpa\.?/)
				errors << "PTR invalid name: doesn't end with 'in-addr.arpa' or 'ip6.arpa'"
			end

			if @ttl < Zone.ttl_limit_min
				errors << "PTR invalid ttl: #{@ttl}, shouldn't be less than #{Zone.ttl_limit_min}"
			end

			unless Zone.is_domain_valid? @target
				errors << "PTR invalid subdomain: #{@target}"
			end

			errors
		end
	end

	class NS < ResourceRecord
		def get_errors : Array(Error)
			errors = [] of Error

			unless Zone.is_subdomain_valid? @name
				errors << "NS invalid subdomain: #{@name}"
			end

			if @ttl < Zone.ttl_limit_min
				errors << "NS invalid ttl: #{@ttl}, shouldn't be less than #{Zone.ttl_limit_min}"
			end

			errors
		end
	end

	class CNAME < ResourceRecord
		def get_errors : Array(Error)
			errors = [] of Error

			unless Zone.is_subdomain_valid? @name
				errors << "CNAME invalid subdomain: #{@name}"
			end

			if @ttl < Zone.ttl_limit_min
				errors << "CNAME invalid ttl: #{@ttl}, shouldn't be less than #{Zone.ttl_limit_min}"
			end

			unless Zone.is_subdomain_valid? @target
				errors << "CNAME invalid target: #{@target}"
			end
			errors
		end
	end

	class MX < ResourceRecord
		property priority  : UInt32 = 10
		def initialize(@name, @ttl, @target, @priority = 10)
			@rrtype = "mx"
		end

		def get_errors : Array(Error)
			errors = [] of Error

			unless Zone.is_subdomain_valid? @name
				errors << "MX invalid subdomain: #{@name}"
			end

			if @ttl < Zone.ttl_limit_min
				errors << "MX invalid ttl: #{@ttl}, shouldn't be less than #{Zone.ttl_limit_min}"
			end

			unless Zone.is_domain_valid? @target
				errors << "MX invalid target (domain): #{@target}"
			end

			errors
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

		def get_errors : Array(Error)
			errors = [] of Error

			# SRV name should be created from scratch, client should send an empty name.
			# WON'T FIX: name verification.

			if @ttl < Zone.ttl_limit_min
				errors << "SRV invalid ttl: #{@ttl}, shouldn't be less than #{Zone.ttl_limit_min}"
			end

			unless Zone.is_domain_valid? @target
				errors << "SRV invalid target (domain): #{@target}"
			end

			errors
		end
	end

	def to_s(io : IO)
		io << "TEST"
	end

	def get_errors? : Array(Error)
		errors = [] of Error
		unless Zone.is_domain_valid? @domain
			errors << "invalid domain #{@domain}"
		end

		# Checking each resource.
		@resources.each do |r|
			r.get_errors().each do |error|
				errors << error
			end
		end

		# Minimal resources: SOA and NS.
		unless @resources.any? &.is_a?(Zone::SOA)
			errors << "invalid zone: no SOA record"
		end
		unless @resources.any? &.is_a?(Zone::NS)
			errors << "invalid zone: no NS record"
		end

		errors
	end

	# This regex only is "good enough for now".
	def self.is_domain_valid?(domain) : Bool
		if domain =~ /^(((?!-))(xn--|_{1,1})?[a-z0-9-]{0,61}[a-z0-9]{1,1}\.)*((xn--)?[a-z0-9][a-z0-9\-]{0,60}[a-z0-9]|(xn--)?[a-z0-9]{1,60})\.[a-z]{2,}$/
			true
		else
			false
		end
	rescue e
		Baguette::Log.error "invalid zone domain #{domain}: #{e}"
		false
	end

	# This regex only is "good enough for now".
	def self.is_subdomain_valid?(subdomain) : Bool
		if subdomain =~ /^(((?!-))(xn--|_{1,1})?[a-z0-9-]{0,61}[a-z0-9]{1,1}\.)*(xn--)?[a-z0-9][a-z0-9\-]{0,60}[a-z0-9]*[a-z]+|[a-z]+|[a-z][a-z0-9]+[a-z]+$/
			true
		else
			false
		end
	rescue e
		Baguette::Log.error "invalid zone subdomain #{subdomain}: #{e}"
		false
	end

	# TODO: PTR name verification.
	def self.is_ptr_name_valid?(subdomain) : Bool
		if subdomain =~ /^(((?!-))(xn--|_{1,1})?[a-z0-9-]{0,61}[a-z0-9]{1,1}\.)*(xn--)?[a-z0-9][a-z0-9\-]{0,60}[a-z0-9]*[a-z]+|[a-z]+|[a-z][a-z0-9]+[a-z]+$/
			true
		else
			false
		end
	rescue e
		Baguette::Log.error "invalid zone subdomain #{subdomain}: #{e}"
		false
	end


	# This only is "good enough for now".
	# Regex only matches for invalid characters.
	def self.is_ipv4_address_valid?(address) : Bool
		if ! address =~ /^[0-9\.]+$/
			false
		elsif ip = IPAddress::IPv4.new address
			true
		else
			false
		end
	rescue e
		Baguette::Log.warning "wrong IPv4 address: #{address}"
		false
	end

	# This only is "good enough for now".
	# Regex only matches for invalid characters.
	def self.is_ipv6_address_valid?(address) : Bool
		if ! address =~ /^[0-9a-f:]+$/
			false
		elsif ip = IPAddress::IPv6.new address
			true
		else
			false
		end
	rescue e
		Baguette::Log.warning "wrong IPv4 address: #{address}"
		false
	end

end
