require 'spec_helper'

require 'pe_build/config'

describe PEBuild::Config::PEBootstrap do
  let(:machine)  { double('machine') }
  let(:ui)       { double('ui') }

  before(:each)  { allow(machine).to receive(:ui).and_return ui }

  context 'when finalized with default values' do
    before(:each) { subject.finalize! }

    it 'passes validation' do
      errors = subject.validate(machine)

      expect(errors).to include('PE Bootstrap' => [])
    end
  end

  describe 'answer_extras' do
    it 'defaults to an empty Array' do
      subject.finalize!

      expect(subject.answer_extras).to be_a(Array)
    end

    context 'when validated with a non-array value' do
      it 'records an error' do
        subject.answer_extras = {'' => ''}

        subject.finalize!
        errors = subject.validate(machine)

        expect(errors['PE Bootstrap'].to_s).to match(/Answer_extras.*got a Hash/)
      end
    end
  end

  describe 'version' do
    it "produces a deprecation warning when greater than or equal to #{PEBuild::Config::PEBootstrap::AGENT_DEPRECATED_VERSION} and role is set to agent" do
      subject.role = :agent
      subject.version = '2015.2.0'

      subject.finalize!
      errors = subject.validate(machine)

      expect(ui).to_receive(:warn)
    end
  end

  # TODO: Spec test the validation functions. Not critical right now since it
  # is pretty much testing tests. But, having specs is a good way for people to
  # see precisely _what_ is allowed.

end
