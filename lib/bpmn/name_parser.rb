module BPMN
  class NameParser
    class Error < Exception
      def full_message(msg)
        "#{msg}. Valid format is: descriptive name | descriptive name:{role: value} | descriptive name:{role: value; length: other_value}"
      end
    end

    class NoClosingBraceError < Error
      def message
        full_message("no closing brace found for attributes")
      end
    end

    class InvalidAttributesFormatError < Error
      def initialize(name, attributes_str)
        @name = name
        @attributes_str = attributes_str
      end

      def message
        full_message("attributes '#{@attributes_str} for #{@name} are in an invalid format")
      end
    end

    def initialize(name)
      @name = name.strip
    end

    def parse
      if /^.*:{/.match(@name)
        if m =/^(.*):{(.*)}$/.match(@name)
          name = m[1]
          attributes_str = m[2]

          attributes = parse_attributes(attributes_str)

          BPMN::NodeAttributes.new(name, attributes)
        else
          raise NoClosingBraceError.new
        end
      else
        BPMN::NodeAttributes.new(@name)
      end
    end

    def parse_attributes(attributes_str)
      attributes_list = attributes_str.split(/;/).map{|s| s.strip}

      attributes = {}
      attributes_list.each do |attribute|
        if m = /^([^:]*):([^:]*)$/.match(attribute)
          key, value = m.captures.map{|c| c.strip}
          attributes[key] = value
        else
          raise InvalidAttributesFormatError.new(@name, attributes_str)
        end
      end

      attributes
    end
  end
end
