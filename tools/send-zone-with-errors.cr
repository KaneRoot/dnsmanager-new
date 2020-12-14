require "authd"
require "yaml"

require "baguette-crystal-base"
require "ipc"

require "../src/network.cr"
require "../src/storage.cr"
require "../src/config"
require "../src/client/lib/*"

#
# Create a zone with errors then try to add it to dnsmanager.
# This also shows how to use IPC connections and the dnsmanager client library.
# Real dnsmanager client is in `src/client/`.
#

alias DSZ = DNSManager::Storage::Zone

if ARGV.size < 2
	puts "usage: username pass"
	exit 0
end

# Authentication
login = ARGV[0]
pass  = ARGV[1]

begin
	puts "authd: connection"
	authd = AuthD::Client.new
rescue e
	puts "cannot contact authd:"
	puts e.to_s
	exit 1
end

puts "authd: sending login"
token = authd.get_token? login, pass
puts "authd: after receiving token, disconnection"
authd.close

unless token
	puts "cannot obtain a token from authd"
	exit 1
end

begin
	puts "dnsmanager: connection"
	dnsmanagerd = DNSManager::Client.new
rescue e
	puts "cannot contact dnsmanagerd:"
	puts e.to_s
	exit 1
end

puts "dnsmanager: sending login"
dnsmanagerd.login token.not_nil!
puts "dnsmanager: receiving login response"

zone = DSZ.new "test.my-domain.com!!!"

#
# Invalid records
#

zone.resources << DSZ::A.new    "13931891",  600.to_u32, "127.0.0.1"
zone.resources << DSZ::AAAA.new "www",  600.to_u32, "::10000"
zone.resources << DSZ::MX.new   "mail", 600.to_u32, "!!", 5.to_u32
zone.resources << DSZ::MX.new   "mail", 1.to_u32, "::1", 5.to_u32

# PTR: 0.168.192.in-addr.net 60 example.com. 
zone.resources << DSZ::PTR.new   "1.10.20.80.in-addr.arpa", 60.to_u32, "::1"
zone.resources << DSZ::PTR.new   "1.10.20.80.mdr", 60.to_u32, "blah.com"

zone.resources << DSZ::SOA.new   "mail", 60.to_u32, "::1",
	"ma.zone.tld", "john\.doe.example.com"

zone.resources << DSZ::NS.new   "mail", 60.to_u32, "::1"

pp! dnsmanagerd.user_zone_add zone

puts "dnsmanager: close"
dnsmanagerd.close
exit 0

