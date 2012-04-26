require "spec_helper"

describe Oedipus::DataMapper::Index do
  include Oedipus::RSpec::TestHarness

  before(:all) do
    set_data_dir File.expand_path("../../data", __FILE__)
    set_searchd  ENV["SEARCHD"]
    start_searchd
  end

  after(:all) { stop_searchd }

  before(:each) do
    Post.destroy!
    empty_indexes
  end

  let(:conn) do
    Oedipus::Connection.new(searchd_host)
  end

  let(:index) do
    Oedipus::DataMapper::Index.new(Post, name: :posts_rt, connection: conn)
  end

  describe "#search" do
    before(:each) do
      [
        Post.create(
          title:      "Badgers on the run",
          body:       "Big badger little badger",
          view_count: 7
        ),
        Post.create(
          title:      "Do it for the badgers!",
          body:       "The badgers need you",
          view_count: 7
        ),
        Post.create(
          title:      "Rabbits doing rabbity things",
          body:       "Being all cute, with their floppy little ears",
          view_count: 9
        )
      ].each do |p|
        conn[:posts_rt].insert(p.id, title: p.title, body: p.body, views: p.view_count)
      end
    end

    it "returns a datamapper collection" do
      index.search("badgers").should be_an_instance_of(DataMapper::Collection)
    end

    it "loads the correct records" do
      index.search("badgers", order: :id).map(&:id).should == [1, 2]
    end
  end
end
