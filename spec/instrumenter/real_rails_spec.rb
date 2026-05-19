# frozen_string_literal: true

require 'spec_helper'

REAL_RAILS_ENABLED = ENV['REAL_RAILS'] == '1'

if REAL_RAILS_ENABLED
  begin
    require 'rails'
    require 'action_controller/railtie'
    REAL_RAILS_AVAILABLE = true
  rescue LoadError
    REAL_RAILS_AVAILABLE = false
  end
else
  REAL_RAILS_AVAILABLE = false
end

if REAL_RAILS_AVAILABLE
  RSpec.describe Instrumenter, :real_rails do
    let(:prefix) { :real_rails_client }
    let(:target) { Module.new }
    let(:client_class) { stub_const('RealRailsClient', Class.new) }
    let(:runtime_module) { client_class::Instrumentation::ControllerRuntime }
    let(:railtie_class) { client_class::Instrumentation::Railtie }

    before do
      described_class.instrument(target, prefix, client_class)
    end

    it 'builds real Rails integration types' do
      expect(railtie_class < Rails::Railtie).to be(true)
      expect(runtime_module).to be_a(Module)
    end

    it 'registers a real railtie initializer' do
      initializer = railtie_class.initializers.find { |entry| entry.name == 'real_rails_client.setup_instrumentation' }

      expect(initializer).not_to be_nil
    end
  end
end
