require "rspec"
require "oedipus-dm"
require "oedipus/rspec/test_harness"

Dir[File.expand_path("../support/**/*.rb", __FILE__)].each { |f| require f }

RSpec.configure do |config|
  config.before(:suite) do
    DataMapper::Model.raise_on_save_failure = true
    DataMapper.setup(:default, adapter: :in_memory)
    DataMapper.finalize
  end
end
