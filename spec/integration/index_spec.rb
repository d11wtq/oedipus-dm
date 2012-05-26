require "spec_helper"

describe Oedipus::DataMapper::Index do
  include_context "oedipus test rig"
  include_context "oedipus posts_rt"

  before(:each) do
    Post.destroy!
    User.destroy!
  end

  let(:conn) { connection }

  let(:index) do
    Oedipus::DataMapper::Index.new(Post, name: :posts_rt, connection: conn) do |idx|
      idx.map :id
      idx.map :title
      idx.map :body
      idx.map :user_id
      idx.map :views, with: :view_count
    end
  end

  describe "#insert" do
    let(:user) do
      User.create(username: "bob")
    end

    let(:post) do
      Post.create(
        title:      "There was one was a badger",
        body:       "And a nice one he was.",
        user:       user,
        view_count: 98
      )
    end

    before(:each) { index.insert(post) }

    it "inserts the object into the index" do
      conn[:posts_rt].fetch(post.id)[:user_id].should == user.id
    end

    it "uses the defined mappings" do
      conn[:posts_rt].fetch(post.id)[:views].should == 98
    end
  end

  describe "#fetch" do
    let(:user) do
      User.create(username: "bob")
    end

    let(:post) do
      Post.create(
        title:      "There was one was a badger",
        body:       "And a nice one he was.",
        user:       user,
        view_count: 98
      )
    end

    before(:each) do
      conn[:posts_rt].insert(
        post.id,
        title:   post.title,
        body:    post.body,
        user_id: post.user_id,
        views:   post.view_count
      )
    end

    it "fetches an individual resource from the index" do
      index.fetch(post.id).should == post
    end
  end

  pending "the sphinxql grammar does not currently support this, though I'm patching it" do
    describe "#update" do
      let(:user) do
        User.create(username: "bob")
      end

      let(:post) do
        Post.create(
          title:      "There was one was a badger",
          body:       "And a nice one he was.",
          user:       user,
          view_count: 98
          )
      end

      before(:each) do
        conn[:posts_rt].insert(post.id, title: "Not this", body: "Or this", views: 0, user_id: 100)
        index.update(post)
      end

      it "updates the object in the index" do
        conn[:posts_rt].fetch(post.id)[:user_id].should == user.id
      end

      it "uses the defined mappings" do
        conn[:posts_rt].fetch(post.id)[:views].should == 98
      end
    end
  end

  describe "#replace" do
    let(:user) do
      User.create(username: "bob")
    end

    let(:post) do
      Post.create(
        title:      "There was one was a badger",
        body:       "And a nice one he was.",
        user:       user,
        view_count: 98
      )
    end

    before(:each) do
      conn[:posts_rt].insert(post.id, title: "Not this", body: "Nor this", user_id: 100, views: 0)
      index.replace(post)
    end

    it "updates the object in the index" do
      conn[:posts_rt].fetch(post.id)[:user_id].should == user.id
    end

    it "uses the defined mappings" do
      conn[:posts_rt].fetch(post.id)[:views].should == 98
    end
  end

  describe "#delete" do
    let(:user) do
      User.create(username: "bob")
    end

    let(:post) do
      Post.create(
        title:      "There was one was a badger",
        body:       "And a nice one he was.",
        user:       user,
        view_count: 98
      )
    end

    before(:each) do
      conn[:posts_rt].insert(post.id, title: "Not this", body: "Nor this", user_id: 100, views: 0)
      index.delete(post)
    end

    it "removes the object in the index" do
      conn[:posts_rt].fetch(post.id).should be_nil
    end
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

    it "handles the attribute mappings" do
      index.search("badgers", order: :id).collect { |p| { view_count: p.view_count } }.should == [
        { view_count: @a.view_count },
        { view_count: @b.view_count },
        { view_count: @c.view_count }
      ]
    end

    it "provides the count for the total number of records matched" do
      index.search("badgers", limit: 2).total_found.should == 3
    end

    it "provides the count for the number of records returned" do
      index.search("badgers", limit: 2).count.should == 2
    end

    it "loads the models directly from the index" do
      index.search("badgers").each do |p|
        Post.user_id.loaded?(p).should be_true
      end
    end

    it "allows lazy-loading of the non-indexed attributes" do
      index.search("badgers").each do |p|
        Post.created_at.loaded?(p).should be_false
      end
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

      describe "Symbol.asc" do
        it "is converted to Hash notation" do
          index.search("badgers", order: :id.asc).map(&:id).should == [@a.id, @b.id, @c.id]
        end

        context "inside an array" do
          it "is converted to Hash notation" do
            index.search("badgers", order: [:id.asc]).map(&:id).should == [@a.id, @b.id, @c.id]
          end
        end
      end

      describe "Symbol.desc" do
        it "is converted to Hash notation" do
          index.search("badgers", order: :id.desc).map(&:id).should == [@c.id, @b.id, @a.id]
        end

        context "inside an array" do
          it "is converted to Hash notation" do
            index.search("badgers", order: [:id.desc]).map(&:id).should == [@c.id, @b.id, @a.id]
          end
        end
      end
    end

    describe "pagination" do
      before(:each) do
        [
          @e = Post.create(
            title:      "Badgers again",
            body:       "Blah blah badger",
            view_count: 20,
            user:       @user_a
          ),
          @f = Post.create(
            title:      "Don't take my badger!",
            body:       "Badgers are afraid of the dark",
            view_count: 21,
            user:       @user_a
          ),
          @g = Post.create(
            title:      "You seen one badger, you seen em all",
            body:       "Badgers, they're all the same",
            view_count: 4,
            user:       @user_b
          )
        ].each do |p|
          conn[:posts_rt].insert(p.id, title: p.title, body: p.body, views: p.view_count, user_id: p.user.id)
        end
      end

      context "with :per_page specified" do
        context "with :page => 1" do
          it "returns the first page of the results" do
            index.search("badgers", order: :id, pager: {page: 1, per_page: 2}).map(&:id).should == [@a.id, @b.id]
          end

          it "provides a #pager with #current_page = 1" do
            index.search("badgers", order: :id, pager: {page: 1, per_page: 2}).pager.current_page.should == 1
          end
        end

        context "with :page => 2" do
          it "returns the second page of the results" do
            index.search("badgers", order: :id, pager: {page: 2, per_page: 2}).map(&:id).should == [@c.id, @e.id]
          end

          it "provides a #pager with #current_page = 2" do
            index.search("badgers", order: :id, pager: {page: 2, per_page: 2}).pager.current_page.should == 2
          end
        end
      end
    end

    describe "with :facets" do
      it "returns the main results in the collection" do
        index.search(
          "badgers",
          order: :id,
          facets: {
            popular: {:views.gte => 7}
          }
        ).map(&:id).should == [@a.id, @b.id, @c.id]
      end

      it "returns the facets inside the collection" do
        index.search(
          "badgers",
          order: :id,
          facets: {
            popular: {:views.gte => 7}
          }
        ).facets[:popular].map(&:id).should == [@a.id, @b.id]
      end

      it "provides data on the matches inside the facets" do
        index.search(
          "badgers",
          order: :id,
          facets: {
            popular: {:views.gte => 7}
          }
        ).facets[:popular].total_found.should == 2
      end

      context "in n-dimensions" do
        it "returns the nested facets inside the child collection" do
          index.search(
            "badgers",
            order: :id,
            facets: {
              popular: {
                :views.gte => 7,
                :facets    => {
                  running: "%{query} & run"
                }
              }
            }
          ).facets[:popular].facets[:running].total_found.should == 1
        end
      end
    end
  end

  describe "#multi_search" do
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

    it "returns a Hash mapping the search names with their collections" do
      index.multi_search(
        popular_badgers: ["badgers", :views.gte => 7],
        rabbits:         "rabbits"
      ).should be_a_kind_of(Hash)
    end
  end
end
