
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
