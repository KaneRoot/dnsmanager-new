
class Context
	class_property verbosity = 1
	class_property authd_key_file : String? = nil
	class_property activation_server_port : Int32 = 9000
end


OptionParser.parse do |parser|

	parser.on "-v verbosity-level", "--verbosity level", "Verbosity." do |opt|
		Context.verbosity = opt.to_i
	end

	parser.on "-p port", "--port port", "Listening port." do |port|
		Context.activation_server_port = port.to_i
	end

	parser.on "-K key-file", "--key-file file", "Key file." do |opt|
		Context.authd_key_file = opt
	end

	parser.on "-h", "--help", "Show this help" do
		puts parser
		exit 0
	end
end
