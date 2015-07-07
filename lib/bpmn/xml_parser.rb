require "rgl-fold"
require "rgl/adjacency"

module BPMN
  class XmlParser
    class Error < Exception
    end

    class AttributeRequiredError < Error
      def initialize(node_type, attribute_name)
        @node_type = node_type
        @attribute_name = attribute_name
      end

      def message
        "for node type '#{@node_type}', attribute #{@attribute_name} is required"
      end
    end

    class InvalidAttributeFormatError < Error
      def initialize(attribute_name, attribute_value)
        @attribute_name = attribute_name
        @attribute_value = attribute_value
      end

      def message
        "for attribute '#{@attribute_name}', the value #{@attribute_value} is in an invalid format"
      end
    end

    class AllOutgoingGatewayEdgesRequireAttributesError < Error
      def initialize(gateway_name)
        @gateway_name = gateway_name
      end

      def message
        "all edges out of gateway '#{@gateway_name}', need to have names and percentages"
      end
    end

    class AllOutgoingGatewayEdgePercentagesMustBe100Error < Error
      def initialize(gateway_name)
        @gateway_name = gateway_name
      end

      def message
        "all edges out of gateway '#{@gateway_name}', need to have percentages that add to 100"
      end
    end

    class Node
      def initialize(xml_attributes)
        @xml_attributes = xml_attributes
        if @xml_attributes["name"]
          @attributes = BPMN::NameParser.new(@xml_attributes["name"].value).parse
          validate_and_set_node_specific_attributes
        end
      end

      def name
        @attributes ? @attributes.name : nil
      end

      def id
        @xml_attributes["id"].value
      end

      # Overridables ==============================

      # Node attributes ---------------------------

      def start_event?
        false
      end

      def end_event?
        false
      end

      def gateway?
        false
      end

      def takes_time?
        false
      end

      # Node behaviors ----------------------------

      #
      # override to require specific attributes and types
      #
      def validate_and_set_node_specific_attributes
      end

      #
      # override to check outgoing nodes at the end
      #
      def validate_outgoing_nodes
      end

      #
      # override to add exit nodes during parsing
      #
      def add_exit_node(target_node, edge_name)
      end
    end

    class StartEvent < Node
      def start_event?
        true
      end
    end

    class EndEvent < Node
      def end_event?
        true
      end
    end

    class ExclusiveGateway < Node
      attr_reader :exit_node_attributes
      def initialize(*args)
        super(*args)
        @exit_node_attributes = []
      end

      def gateway?
        true
      end

      def validate_outgoing_nodes
        percentage_sum = 0
        @exit_node_attributes.each do |gateway_outgoing_edge|
          if gateway_outgoing_edge.attributes.nil?
            raise AllOutgoingGatewayEdgesRequireAttributesError.new(name)
          end
          percentage_sum += gateway_outgoing_edge.percentage
        end

        raise AllOutgoingGatewayEdgePercentagesMustBe100Error.new(name) unless percentage_sum == 100
      end

      def add_exit_node(target_node, edge_name)
        @exit_node_attributes.push(GatewayOutgoingEdge.new(target_node, edge_name))
      end
    end

    class GatewayOutgoingEdge
      attr_reader :target_node, :attributes, :percentage
      def initialize(target_node, edge_name)
        @target_node = target_node
        if edge_name
          @attributes = BPMN::NameParser.new(edge_name.value).parse
        end

        if !@attributes.respond_to?(:percentage)
          raise AttributeRequiredError.new("gateway outgoing edge", :percentage)
        elsif @attributes.percentage !~ /^\d+$/
          raise InvalidAttributeFormatError.new(:percentage, @attributes.percentage)
        else
          @percentage = @attributes.percentage.to_i
        end
      end

      def name
        @attributes.name
      end
    end

    class Task < Node
      attr_reader :role, :length
      def validate_and_set_node_specific_attributes
        if @attributes.respond_to?(:role)
          @role = @attributes.role
        else
          raise AttributeRequiredError.new("task", :role)
        end

        if !@attributes.respond_to?(:length)
          raise AttributeRequiredError.new("task", :length)
        elsif @attributes.length !~ /^\d+$/
          raise InvalidAttributeFormatError.new(:length, @attributes.length)
        else
          @length = @attributes.length.to_i
        end
      end

      def takes_time?
        true
      end

      def time_length
        @length
      end
    end

    HUMAN_INCOMPLETE_REASONS = {
      no_start_event: "there is no start event",
      no_end_event:   "there is no end event",
      no_path_between_start_and_stop: "there is no path between start and stop events"
    }

    attr_reader :graph, :nodes, :start_event, :end_events

    def initialize(xml)
      @xml = xml
      @paths = []
      @graph = RGL::DirectedAdjacencyGraph.new
      @graph.extend RGLFold
      @end_events = []
      @nodes = {}
    end

    def parse
      @parsed_xml = Nokogiri::XML(@xml)

      @parsed_xml.xpath("//bpmn:process").children.each do |c|
        case c.name
        when "startEvent"
          @start_event = add_node(c, StartEvent)
        when "endEvent"
          @end_events.push(add_node(c, EndEvent))
        when "exclusiveGateway"
          add_node(c, ExclusiveGateway)
        when "task"
          add_node(c, Task)
        when "sequenceFlow"
          source_node = @nodes[c.attributes["sourceRef"].value]
          target_node = @nodes[c.attributes["targetRef"].value]
          if source_node && target_node
            @graph.add_edge source_node, target_node

            source_node.add_exit_node(target_node, c.attributes["name"])
          end
        when "text"
          # ignore text nodes (nodes that are generated between tags)
        else
          raise "unknown xml node: #{c.name}, #{c.attributes}"
        end
      end

      @nodes.values.each do |node|
        node.validate_outgoing_nodes
      end

      self
    end

    def parse_and_handle_errors
      begin
        parse
      rescue BPMN::XmlParser::Error => e
        @error = e
      rescue BPMN::NameParser::Error => e
        @error = e
      end

      self
    end

    def add_node(xml_node, klass)
      node = klass.new(xml_node.attributes)
      @graph.add_vertex(node)
      @nodes[xml_node.attributes["id"].value] = node
      node
    end

    def paths
      @graph.fold(@start_event, []) {|accum, vertex| accum + [vertex]}
    end

    def paths_end_in_end_event?
      paths.inject(false) {|sum, path| sum || @end_events.include?(path.last)}
    end

    def complete?
      incomplete_reason.nil?
    end

    def incomplete_reason
      return nil if @error # this info is not accurate if there was an exception

      if !@start_event
        :no_start_event
      elsif @end_events.empty?
        :no_end_event
      elsif !paths_end_in_end_event?
        :no_path_between_start_and_stop
      else
        nil
      end
    end

    def simulatable?
      complete? && !@error
    end

    def human_incomplete_reason
      HUMAN_INCOMPLETE_REASONS[incomplete_reason]
    end

    def human_non_simulatable_reason
      if !complete?
        HUMAN_INCOMPLETE_REASONS[incomplete_reason]
      else
        @error.message
      end
    end
  end
end
