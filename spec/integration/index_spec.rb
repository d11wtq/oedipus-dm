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
      @user_a = User.create(username: "bob")
      @user_b = User.create(username: "abi")
      [
        @a = Post.create(
          title:      "Badgers on the run",
          body:       "Big badger little badger",
          view_count: 7,
          user:       @user_a
        ),
        @b = Post.create(
          title:      "Do it for the badgers!",
          body:       "The badgers need you",
          view_count: 11,
          user:       @user_a
        ),
        @c = Post.create(
          title:      "Talk to the hand, not to the badgers",
          body:       "Cos this badger ain't listening",
          view_count: 6,
          user:       @user_b
        ),
        @d = Post.create(
          title:      "Rabbits doing rabbity things",
          body:       "Being all cute, with their floppy little ears",
          view_count: 9,
          user:       @user_a
        )
      ].each do |p|
        conn[:posts_rt].insert(p.id, title: p.title, body: p.body, views: p.view_count, user_id: p.user.id)
      end
    end

    it "returns a datamapper collection" do
      index.search("badgers").should be_a_kind_of(DataMapper::Collection)
    end

    it "returns models of the correct type" do
      index.search("badgers").map(&:model).should == [Post, Post, Post]
    end

    it "loads the records matching the search" do
      index.search("badgers", order: :id).collect { |p| { id: p.id, title: p.title } }.should == [
        { id: @a.id, title: @a.title },
        { id: @b.id, title: @b.title },
        { id: @c.id, title: @c.title }
      ]
    end

    it "provides the count for the total number of records matched" do
      index.search("badgers", limit: 2).total_found.should == 3
    end

    it "provides the count for the number of records returned" do
      index.search("badgers", limit: 2).count.should == 2
    end

    describe "symbol operators" do
      describe "Symbol.not" do
        it "works like Oedipus.not" do
          index.search("badgers", :user_id.not => @user_a.id, order: :id).map(&:id).should == [@c.id]
        end
      end

      describe "Symbol.gt" do
        it "works like Oedipus.gt" do
          index.search("badgers", :views.gt => 7, order: :id).map(&:id).should == [@b.id]
        end
      end

      describe "Symbol.gte" do
        it "works like Oedipus.gte" do
          index.search("badgers", :views.gte => 7, order: :id).map(&:id).should == [@a.id, @b.id]
        end
      end

      describe "Symbol.lt" do
        it "works like Oedipus.lt" do
          index.search("badgers", :views.lt => 7, order: :id).map(&:id).should == [@c.id]
        end
      end

      describe "Symbol.lte" do
        it "works like Oedipus.lte" do
          index.search("badgers", :views.lte => 7, order: :id).map(&:id).should == [@a.id, @c.id]
        end
      end
    end
  end
end
