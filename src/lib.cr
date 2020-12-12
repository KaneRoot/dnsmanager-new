require "uuid"

# YAML UUID parser
def UUID.new(ctx : YAML::ParseContext, node : YAML::Nodes::Node)
	ctx.read_alias(node, UUID) do |obj|
		return UUID.new obj
	end

	if node.is_a?(YAML::Nodes::Scalar)
		value = node.value
		ctx.record_anchor(node, value)
		UUID.new value
	else
		node.raise "Expected UUID, not #{node.class.name}"
	end
end

module YAML
	# change dates in YAML formated content
	def self.human_dates(content : String)
		new_lines = Array(String).new
		content.each_line do |line|
			case line
			when /(?<date>.*date):[ \t]+NOW[ \t]*(?<op>[-+])[ \t]*(?<rand>rand)?[ \t]*(?<delta>[0-9]+) *(?<scale>[a-z]+)?/
				date = $~["date"]
				op   = $~["op"]
				delta = $~["delta"].to_i
				rand = $~["rand"] rescue nil
				scale = $~["scale"] rescue nil # days, hours

				unless rand.nil?
					old = delta
					delta = Random.rand(delta)
				end

				vdelta = delta.days
				case scale
				when /day/
					# default one
				when /hour/
					vdelta = delta.hours
				else
					# puts "scale infered: days"
				end

				yaml_date = Time::Format::YAML_DATE.format(Time.local + vdelta)
				case op
				when /-/
					yaml_date = Time::Format::YAML_DATE.format(Time.local - vdelta)
					# puts "-"
				when /\+/
					# default one
					# puts "+"
				else
					# puts "date operation not understood: #{op}, + infered"
				end

				new_lines << "#{date}: #{yaml_date}"
				next
			when /(?<date>.+date):[ \t]+NOW[ \t]*$/
				date = $~["date"]
				yaml_date = Time::Format::YAML_DATE.format(Time.local)

				new_lines << "#{date}: #{yaml_date}"
				next
			when /(?<date>[a-z]+_date):[ \t]+NOW[ \t]*$/
				date = $~["date"]
				yaml_date = Time::Format::YAML_DATE.format(Time.local)

				new_lines << "#{date}: #{yaml_date}"
				next
			# when /(?<date>[a-z]+_date):/
			# 	puts "date that does not compute: #{line}"
			end
			new_lines << line
		end

		new_lines.join "\n"
	end
end

class Array(T)
	def self.from_yaml_files(files)
		values = Array(T).new
		files.each do |file|
			raise "File doesn't exist #{file}" unless File.exists? file
			from_yaml_file(file).each do |v|
				values << v
			end
		end
		values
	end

	def self.from_yaml_file(file)
		from_yaml_content File.read file
	end

	def self.from_yaml_content(input_content)
		content = YAML.human_dates input_content

		values = Array(T).new

		begin
			values << T.from_yaml content
		rescue e
			Baguette::Log.warning "reading the input #{e}"
			begin
				Array(T).from_yaml(content).each do |b|
					values << b
				end
			rescue e
				raise "wrong YAML content: #{e}"
			end
		end

		values
	end

	def self.from_json_files(files)
		values = Array(T).new
		files.each do |file|
			raise "File doesn't exist #{file}" unless File.exists? file
			from_json_file(file).each do |v|
				values << v
			end
		end
		values
	end

	def self.from_json_file(file)
		from_json_content File.read file
	end

	def self.from_json_content(content)
		values = Array(T).new

		begin
			values << T.from_json content
		rescue e
			begin
				Array(T).from_json(content).each do |b|
					values << b
				end
			rescue e
				raise "wrong JSON content: #{e}"
			end
		end

		values
	end
end
