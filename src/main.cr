require "http/server"
require "option_parser"

require "authd"

service_name = "dnsmanager"
verbosity = 1
authd_key_file = nil

require "./parser"

begin
	authd = AuthD::Client.new
	authd.key = File.read(Context.authd_key_file.not_nil!).chomp

	server = HTTP::Server.new do |context|
		context.response.content_type = "text/plain"
		pp! context.request
		context.response.print "Hello. New version of DNSManager, soon."
	end

	address = server.bind_tcp Context.activation_server_port
	puts "Listening on http://#{address}"
	server.listen

rescue e
	puts "Error: #{e}"
	exit 1
end
