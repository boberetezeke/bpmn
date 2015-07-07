require "spec_helper"

describe BPMN::XmlParser do
  context "when the xml only has an end event" do
    let(:end_event_only) {
      '<?xml version="1.0" encoding="UTF-8"?>
       <bpmn:definitions xmlns:bpmn="http://www.omg.org/spec/BPMN/20100524/MODEL" xmlns:bpmndi="http://www.omg.org/spec/BPMN/20100524/DI" xmlns:di="http://www.omg.org/spec/DD/20100524/DI" xmlns:dc="http://www.omg.org/spec/DD/20100524/DC" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" id="Definitions_1" targetNamespace="http://bpmn.io/schema/bpmn">
       <bpmn:process id="Process_1" isExecutable="false">
         <bpmn:endEvent id="EndEvent_03ygbas" />
       </bpmn:process>
      </bpmn:definitions>'
     }

    it "notices it is not complete when there is no start event" do
      expect(BPMN::XmlParser.new(end_event_only).parse.complete?).to be_falsy
    end

    it "returns the reason it is not complete" do
      expect(BPMN::XmlParser.new(end_event_only).parse.incomplete_reason).to eq(:no_start_event)
    end
  end

  context "when the xml only has an start event" do
    let(:start_event_only) {
      '<?xml version="1.0" encoding="UTF-8"?>
       <bpmn:definitions xmlns:bpmn="http://www.omg.org/spec/BPMN/20100524/MODEL" xmlns:bpmndi="http://www.omg.org/spec/BPMN/20100524/DI" xmlns:di="http://www.omg.org/spec/DD/20100524/DI" xmlns:dc="http://www.omg.org/spec/DD/20100524/DC" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" id="Definitions_1" targetNamespace="http://bpmn.io/schema/bpmn">
       <bpmn:process id="Process_1" isExecutable="false">
           <bpmn:startEvent id="StartEvent_1"/>
        </bpmn:process>
     </bpmn:definitions>'
     }

    it "notices it is not complete when there is no start event" do
      expect(BPMN::XmlParser.new(start_event_only).parse.complete?).to be_falsy
    end

    it "returns the reason it is not complete" do
      expect(BPMN::XmlParser.new(start_event_only).parse.incomplete_reason).to eq(:no_end_event)
    end
  end

  context "when the xml only has a start event and stop event but no path between them" do
    let(:start_and_end_event_only) {
      '<?xml version="1.0" encoding="UTF-8"?>
       <bpmn:definitions xmlns:bpmn="http://www.omg.org/spec/BPMN/20100524/MODEL" xmlns:bpmndi="http://www.omg.org/spec/BPMN/20100524/DI" xmlns:di="http://www.omg.org/spec/DD/20100524/DI" xmlns:dc="http://www.omg.org/spec/DD/20100524/DC" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" id="Definitions_1" targetNamespace="http://bpmn.io/schema/bpmn">
       <bpmn:process id="Process_1" isExecutable="false">
          <bpmn:startEvent id="StartEvent_1"/>
          <bpmn:endEvent id="EndEvent_08j1b1p"/>
       </bpmn:process>
    </bpmn:definitions>'
     }

    it "notices it is not complete when there is no start event" do
      expect(BPMN::XmlParser.new(start_and_end_event_only).parse.complete?).to be_falsy
    end

    it "returns the reason it is not complete" do
      expect(BPMN::XmlParser.new(start_and_end_event_only).parse.incomplete_reason).to eq(:no_path_between_start_and_stop)
    end
  end

  context "when the xml only has a connected start and end event" do
    let(:simple) {
      '<?xml version="1.0" encoding="UTF-8"?>
       <bpmn:definitions xmlns:bpmn="http://www.omg.org/spec/BPMN/20100524/MODEL" xmlns:bpmndi="http://www.omg.org/spec/BPMN/20100524/DI" xmlns:di="http://www.omg.org/spec/DD/20100524/DI" xmlns:dc="http://www.omg.org/spec/DD/20100524/DC" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" id="Definitions_1" targetNamespace="http://bpmn.io/schema/bpmn">
       <bpmn:process id="Process_1" isExecutable="false">
         <bpmn:startEvent id="StartEvent_1">
           <bpmn:outgoing>SequenceFlow_12x5xl1</bpmn:outgoing>
         </bpmn:startEvent>
         <bpmn:endEvent id="EndEvent_03ygbas">
           <bpmn:incoming>SequenceFlow_12x5xl1</bpmn:incoming>
         </bpmn:endEvent>
         <bpmn:sequenceFlow id="SequenceFlow_12x5xl1" sourceRef="StartEvent_1" targetRef="EndEvent_03ygbas" />
       </bpmn:process>
      </bpmn:definitions>'
    }

    it "parses a xml diagram that has only a start and end" do
      expect(BPMN::XmlParser.new(simple).parse.paths.size).to eq(1)
    end

    it "notices it is complete when there is a path from start to end" do
      expect(BPMN::XmlParser.new(simple).parse.complete?).to be_truthy
    end
  end

  context "when the xml has an exclusive gateway to two processes and ends" do
    let(:xml) { 
      '<?xml version="1.0" encoding="UTF-8"?>
       <bpmn:definitions xmlns:bpmn="http://www.omg.org/spec/BPMN/20100524/MODEL" xmlns:bpmndi="http://www.omg.org/spec/BPMN/20100524/DI" xmlns:di="http://www.omg.org/spec/DD/20100524/DI" xmlns:dc="http://www.omg.org/spec/DD/20100524/DC" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" id="Definitions_1" targetNamespace="http://bpmn.io/schema/bpmn">
       <bpmn:process id="Process_1" isExecutable="false">
          <bpmn:startEvent id="StartEvent_1">
             <bpmn:outgoing>SequenceFlow_10rse3m</bpmn:outgoing>
          </bpmn:startEvent>
          <bpmn:exclusiveGateway id="ExclusiveGateway_0vpr7ey" name="failure?">
             <bpmn:incoming>SequenceFlow_10rse3m</bpmn:incoming>
             <bpmn:outgoing>SequenceFlow_0etj4b6</bpmn:outgoing>
             <bpmn:outgoing>SequenceFlow_0ixuqui</bpmn:outgoing>
          </bpmn:exclusiveGateway>
          <bpmn:sequenceFlow id="SequenceFlow_10rse3m" sourceRef="StartEvent_1" targetRef="ExclusiveGateway_0vpr7ey"/>
          <bpmn:task id="Task_1vdx3tv" name="Handle failure:{role:nurse;length:5}">
             <bpmn:incoming>SequenceFlow_0etj4b6</bpmn:incoming>
             <bpmn:outgoing>SequenceFlow_0j3bjz3</bpmn:outgoing>
          </bpmn:task>
          <bpmn:endEvent id="EndEvent_1hg5lpm" name="Bad end">
             <bpmn:incoming>SequenceFlow_0j3bjz3</bpmn:incoming>
          </bpmn:endEvent>
          <bpmn:sequenceFlow id="SequenceFlow_0j3bjz3" sourceRef="Task_1vdx3tv" targetRef="EndEvent_1hg5lpm"/>
          <bpmn:task id="Task_0a1r5dv" name="Handle success:{role:doctor;length:10}">
             <bpmn:incoming>SequenceFlow_0ixuqui</bpmn:incoming>
             <bpmn:outgoing>SequenceFlow_0m2lrfh</bpmn:outgoing>
          </bpmn:task>
          <bpmn:endEvent id="EndEvent_053m21u" name="Good end">
             <bpmn:incoming>SequenceFlow_0m2lrfh</bpmn:incoming>
          </bpmn:endEvent>
          <bpmn:sequenceFlow id="SequenceFlow_0m2lrfh" sourceRef="Task_0a1r5dv" targetRef="EndEvent_053m21u"/>
          <bpmn:sequenceFlow id="SequenceFlow_0etj4b6" name="fail:{percentage: 30}" sourceRef="ExclusiveGateway_0vpr7ey" targetRef="Task_1vdx3tv"/>
          <bpmn:sequenceFlow id="SequenceFlow_0ixuqui" name="success:{percentage: 70}" sourceRef="ExclusiveGateway_0vpr7ey" targetRef="Task_0a1r5dv"/>
       </bpmn:process>'
    }

    it "has two paths from start to end" do
      expect(BPMN::XmlParser.new(xml).parse.paths.size).to eq(2)
    end

    it "has a task with the correctly set name" do
      expect(BPMN::XmlParser.new(xml).parse.nodes['Task_1vdx3tv'].name).to eq("Handle failure")
    end

    it "has a task with the correctly set role" do
      expect(BPMN::XmlParser.new(xml).parse.nodes['Task_1vdx3tv'].role).to eq("nurse")
    end

    it "has a task with the correctly set length" do
      expect(BPMN::XmlParser.new(xml).parse.nodes['Task_1vdx3tv'].length).to eq(5)
    end

    it "has an exclusive gateway with two exit nodes" do
      expect(BPMN::XmlParser.new(xml).parse.nodes['ExclusiveGateway_0vpr7ey'].name).to eq("failure?")
    end

    it "has an exclusive gateway with two exit nodes" do
      expect(BPMN::XmlParser.new(xml).parse.nodes['ExclusiveGateway_0vpr7ey'].exit_node_attributes.size).to eq(2)
    end

    it "has an exclusive gateway whose edges have percentages add up to 100" do
      expect(BPMN::XmlParser.new(xml).parse.nodes['ExclusiveGateway_0vpr7ey'].exit_node_attributes.map{|en| en.percentage}.inject(0){|sum, n| sum+n}).to eq(100)
    end

  end
end
