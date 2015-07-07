module BPMN
  class NodeAttributes
    attr_reader :name, :attributes
    def initialize(name, attributes={})
      @name = name
      @attributes = attributes
    end

    def method_missing(sym, *args, &block)
      if respond_to?(sym)
        @attributes[sym.to_s]
      else
        super
      end
    end

    def respond_to?(sym, include_private = false)
      if @attributes.has_key?(sym.to_s)
        true
      else
        super
      end
    end
  end
end
