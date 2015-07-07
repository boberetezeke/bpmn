require "spec_helper"

describe BPMN::NameParser do
  it "returns the name" do
    expect(BPMN::NameParser.new("This is a name").parse.name).to eq("This is a name")
  end

  context "when there is a name with invalid attributes" do
    context "when there is a name with an attributes start but no end" do
      it "raises a NoClosingBrace error" do
        expect{BPMN::NameParser.new("name:{").parse.name}.to raise_error BPMN::NameParser::NoClosingBraceError
      end
    end

    context "when there is a name with an attributes multiple colons" do
      it "raises a InvalidAttributesFormatError error" do
        expect{BPMN::NameParser.new("name:{role: nurse : shifty}").parse.name}.to raise_error BPMN::NameParser::InvalidAttributesFormatError
      end
    end
  end

  context "when there is a name with a valid attributes" do
    context "when there is a name with an attribute" do
      let(:name) { "This is a name:{role: nurse}" }

      it "returns only the name portion" do
        expect(BPMN::NameParser.new(name).parse.name).to eq("This is a name")
      end

      it "returns the simple attribute when one exists" do
        expect(BPMN::NameParser.new(name).parse.role).to eq("nurse")
      end
    end

    context "when there is a name with multiple attributes" do
      let(:name) { "This is a name:{role: nurse; length: 10}" }

      it "returns only the name portion" do
        expect(BPMN::NameParser.new(name).parse.name).to eq("This is a name")
      end

      it "returns the first attribute when asked for" do
        expect(BPMN::NameParser.new(name).parse.role).to eq("nurse")
      end

      it "returns the second attribute when asked for" do
        expect(BPMN::NameParser.new(name).parse.length).to eq("10")
      end
    end
  end
end
