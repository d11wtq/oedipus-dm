# Oedipus Sphinx Integration for DataMapper

This gem is a work in progress, binding [Oedipus](https://github.com/d11wtq/oedipus)
with [DataMapper](https://github.com/datamapper/dm-core), in order to support
the querying and updating of Sphinx indexes through DataMapper models.

The gem is not yet published, as it is still in development.

## Usage

All features of Oedipus will ultimately be supported, but I'm documenting as
I complete wrapping the features.

### Configure Oedipus

Oedipus must be configured to connect to a SphinxQL host.  The older searchd
interface is not supported.

``` ruby
require "oedipus-dm"

Oedipus::DataMapper.configure do |config|
  config.host = "localhost"
  config.port = 9306
end
```

In Rails you can do this in an initializer for example.  If you prefer not to
use a global configuration, it is possible to specify how to connect on a
per-index basis instead.

### Defining an Index

The most basic way to connect sphinx index with your model is to define a
`.index` method on the model itself.  Oedipus doesn't directly mix behaviour
into your models by default, as experience suggests this makes testing in
isolation more difficult (note that you can easily have a standalone `Index`
that wraps your model, if you prefer this).

For a non-realtime index, something like the following would work fine.

``` ruby
class Post
  include DataMapper::Resource

  property :id,         Serial
  property :title,      String
  property :body,       Text
  property :view_count, Integer

  belongs_to :user

  def self.index
    @index ||= Oedipus::DataMapper::Index.new(self)
  end
end
```

Oedipus will use the `storage_name` of your model as the index name in Sphinx.
If you need to use a different name, pass the `:name` option to the Index.

``` ruby
def self.index
  @index ||= Oedipus::DataMapper::Index.new(self, name: :posts_rt)
end
```

If you have not globally configured Oedipus, or want to specify different
connection settings, pass the `:connection` option.

``` ruby
def self.index
  @index ||= Oedipus::DataMapper::Index.new(
    self,
    connection: Oedipus.connect("localhost:9306")
  )
end
```

#### Map fields and attributes with your model

By default, the only field that Oedipus will map with your model is the `:id`
attribute, which it will try to map with the key of your model.  This
configuration will work fine for non-realtime indexes in most cases, but it
is not optimized for many cases.

When Oedipus finds search results, it pulls out all the attributes defined in
your index, then tries to map them to instances of your model.  Mapping `:id`
alone means that DataMapper will load all of your resources from the database
when you first try to access any other attribute.

Chances are, you have some attributes in your index that can be mapped to your
model, avoiding the extra database hit.  You can add these mappings like so.

``` ruby
Oedipus::DataMapper::Index.new(self) do |idx|
  idx.map :user_id
  idx.map :views, with: :view_count
end
```

`Index#map` takes the name of the attribute in your index.  By default it will
map 1:1 with a property of the same name in your model.  If the property name
in your model differs from that in the index, you may specify that with the
`:with` option, as you see with the `:views` attribute above.

Now when Oedipus loads your search results, they will be loaded with `:id`,
`:user_id` and `:view_count` pre-loaded.

#### Complex mappings

The attributes in your index may not always be literal copies of the
properties in your model.  If you need to provide an ad-hoc loading mechanism,
you can pass a lambda as a `:set` option, which specifies how to set the
value onto the resource.  To give a contrived example:

``` ruby
Oedipus::DataMapper::Index.new(self) do |idx|
  idx.map :x2_views, set: ->(r, v) { r.view_count = v/2 }
end
```

For realtime indexes, the `:get` counterpart exists, which specifies how to
retrieve the value from your resource, for inserting into the index.

``` ruby
Oedipus::DataMapper::Index.new(self) do |idx|
  idx.map :x2_views, set: ->(r, v) { r.view_count = v/2 }, get: ->(r) { r.view_count * 2 }
end
```

### Search for resources using the index

The `Index` class provides a `#search` method, which accepts the same
arguments as the underlying oedipus gem, but returns collections of
DataMapper resources, instead of Hashes.

``` ruby
Post.index.search("badgers").each do |post|
  puts "Found post #{post.title}"
end
```

#### Filter by attributes

As with the main oedipus gem, attribute filters are specified as options, with
the notable difference that you may use DataMapper's Symbol operators, for
style/semantic reasons.

``` ruby
Post.index.search("badgers", :views.gt => 1000).each do |post|
  puts "Found post #{post.title}"
end
```

Of course, the non-Symbol operators provided by Oedipus are supported too:

``` ruby
Post.index.search("badgers", views: Oedipus.gt(1000)).each do |post|
  puts "Found post #{post.title}"
end
```

#### Order the results

This works as with the main oedipus gem, but you may use DataMapper's notation
for style/semantic reasons.

``` ruby
Post.index.search("badgers", order: [:views.desc]).each do |post|
  puts "Found post #{post.title}"
end
```

Oedipus' Hash notation is supported too:

``` ruby
Post.index.search("badgers", order: {views: :desc}).each do |post|
  puts "Found post #{post.title}"
end
```

#### Apply limits and offsets

This is done just as you would expect.

``` ruby
Post.index.search("badgers", limit: 30, offset: 60).each do |post|
  puts "Found post #{post.title}"
end
```

## Realtime index management

Oedipus allows you to keep realtime indexes up-to-date as your models change.

The index definition remains the same, but there are some considerations to
be made.

Since realtime indexes are updated whenever something changes on your models,
you must also list the fulltext fields in the mappings for your index, so that
they can be saved.  Note that the fields are not returned in Sphinx search
results, however; they will be lazy-loaded if you try to access them in the
returned collection.

``` ruby
Oedipus::DataMapper::Index.new(self) do |idx|
  idx.map :title
  idx.map :body
  idx.map :user_id
  idx.map :views, with: :view_count
end
```

### Inserting a resource into the index

You can invoke `#insert` on the index, passing in the resource.  The resource
*must* be saved and *must* have a key.

``` ruby
Post.index.insert(a_post)
```

In practice, to keep things in sync, you should do this in an `after :create`
hook on your model.

``` ruby
class Post
  # ... snip ...

  after(:create) { model.index.insert(self) }
end
```

### Updating resource in the index

**NOTE** This behaviour is currently broken in SphinxQL... you should use
`#replace` instead.  I have patches in progress for Sphinx itself.

Invoke `#update` on the index, passing in the resource.  The resource
*must* be saved and *must* have a key.

``` ruby
Post.index.update(a_post)
```

In practice, to keep things in sync, you should do this in an `after :update`
hook on your model.

``` ruby
class Post
  # ... snip ...

  after(:update) { model.index.update(self) }
end
```

### Replacing a resource in the index

Replacing a resource is much like updating it, except that it is completely
overwritten.  Although SphinxQL in theory supports updates, it has never
worked in practice, so you should use this method for now (current Sphinx
version 2.0.4 at time of writing).

``` ruby
Post.index.replace(a_post)
```

In practice, to keep things in sync, you should do this in an `after :update`
hook on your model.

``` ruby
class Post
  # ... snip ...

  after(:update) { model.index.replace(self) }
end
```

You can also use this as a convenience, removing the need for both
`after :create` and `after :update` hooks.  Just put it inside a single
`after :save` hook, which will work in both cases.

``` ruby
class Post
  # ... snip ...

  # works for both inserts and updates
  after(:save) { model.index.replace(self) }
end
```

### Deleting a resource from the index

You can invoke `#delete` on the index, passing in the resource.  The resource
*must* be saved and *must* have a key.

``` ruby
Post.index.delete(a_post)
```

In practice, to keep things in sync, you should do this in an `before :destroy`
hook on your model.  Note the use of `before` instead of `after`, in order to
avoid returning missing data in your search results.

``` ruby
class Post
  # ... snip ...

  before(:destroy) { model.index.delete(self) }
end
```

## Licensing and Copyright

Refer to the LICENSE file for details.
