# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Instrumenter do
  describe 'VERSION' do
    it 'is a semantic version string' do
      expect(klass::VERSION).to match(/\A\d+\.\d+\.\d+\z/)
    end
  end

  describe '.instrument' do
    let(:prefix) { :rspec_client_api }
    let(:target) { Module.new }
    let(:client_class) { stub_const('RspecClientApi', Class.new) }
    let(:host_class) do
      target_module = target

      Class.new do
        include target_module
      end
    end
    let(:host) { host_class.new }
    let(:payload) { { method: 'get', url: 'https://example.test/people' } }

    before do
      described_class.instrument(target, prefix, client_class)
    end

    it 'defines an instrument method on the target' do
      expect(target.instance_methods(false)).to include(:instrument)
    end

    it 'delegates notifications with the prefixed event name and payload' do
      allow(ActiveSupport::Notifications).to receive(:instrument).and_return(:ok)

      result = host.instrument('request', payload)

      expect(result).to eq(:ok)
      expect(ActiveSupport::Notifications).to have_received(:instrument).with('request.rspec_client_api', payload)
    end

    it 'forwards the instrumented block' do
      allow(ActiveSupport::Notifications).to receive(:instrument) do |_name, _payload, &block|
        block.call
      end

      expect(host.instrument('request', payload) { :from_block }).to eq(:from_block)
    end

    it 'creates only a log subscriber when Rails integrations are unavailable' do
      instrumentation = client_class::Instrumentation

      expect(instrumentation.const_defined?(:LogSubscriber, false)).to be(true)
      expect(instrumentation.const_defined?(:ControllerRuntime, false)).to be(false)
      expect(instrumentation.const_defined?(:Railtie, false)).to be(false)
    end

    it 'resolves the instrumented class from the prefix when none is provided' do
      resolved_target = Module.new
      resolved_class = stub_const('RspecResolvedClient', Class.new)

      described_class.instrument(resolved_target, :rspec_resolved_client)

      expect(resolved_class.const_defined?(:Instrumentation, false)).to be(true)
    end
  end
end
