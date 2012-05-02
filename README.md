# Oedipus Sphinx Integration for DataMapper

This gem provides a binding between
[Oedipus](https://github.com/d11wtq/oedipus) and
[DataMapper](https://github.com/datamapper/dm-core), in order to support
the querying and updating of Sphinx indexes through DataMapper models.

Oedipus provides a clean interface with Sphinx 2, allowing the use of
realtime indexes and multi-dimensional faceted search via ruby.

  - [Requirements](#requirements)
  - [Installation](#installation)
  - [Usage](#usage)
    - [Configure oedipus](#configure-oedipus)
    - [Defining an index](#defining-an-index)
    - [Fulltext search](#fulltext-search-for-resources-via-the-index)
    - [Faceted search](#faceted-search)
    - [Parallel search](#performing-multiple-searches-in-parallel)
    - [Realtime index management](#realtime-index-management)
    - [Integration with dm-pager](#integration-with-dm-pager-aka-dm-pagination)
    - [Talking direcly to Oedipus](#talking-directly-to-oedipus)

## Requirements

  - Sphinx >= 2.0.2
  - Ruby >= 1.9
  - Mysql client development libraries

## Installation

Via rubygems

    gem install oedipus-dm

## Usage

All features of the main oedipus gem are supported, with some allowance for
the use of DataMapper's operators etc.

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

### Fulltext search for resources, via the index

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

### Integration with dm-pager (a.k.a dm-pagination)

Oedipus integrates well with [dm-pager](https://github.com/visionmedia/dm-pagination),
allowing you to pass a `:pager` option to the `#search` method.  Limits and
offsets will be applied, and the resulting collection will have a `#pager`
method that you can use.

You must have dm-pager loaded for this to work.  Oedipus does not directly
depend on it.

``` ruby
Post.index.search(
  "badgers",
  pager: {
    page:       7,
    per_page:   30,
    page_param: :page
  }
)
```

In the current version it is *not* possible to do something like `search(..).page(2)`,
or rather, doing so will not do what you expect, as the results have already been
loaded.  This is on my radar, however.

### Faceted Search

Oedipus makes faceted searches really easy.  Pass in a `:facets` option, as a
Hash, where each key identifies the facet and the value lists the arguments,
then Oedipus provides the results for each facet nested inside the collection.

Each facet inherits the base search, which it may override in some way, such as
filtering by an attribute, or modifying the fulltext query itself.

The key used to identify the facet can be any arbitrary object, which may be
useful in some application-specific contexts, where the key can carry associated
domain-specific data.

``` ruby
posts = Post.index.search(
  "badgers",
  facets: {
    popular:         {:views.gte => 1000},
    in_title:        "@title (%{query})",
    popular_farming: ["%{query} & farming", {:views.gte => 200}]
  }
)

puts "Found #{posts.total_found} posts about badgers..."
posts.each do |post|
  puts "Title: #{post.title}"
end

puts "Found #{posts.facets[:popular].total_found} popular posts about badgers"
posts.facets[:popular].each do |post|
  puts "Title: #{post.title}"
end

puts "Found #{posts.facets[:in_title].total_found} posts with 'badgers' in the title"
posts.facets[:in_title].each do |post|
  puts "Title: #{post.title}"
end

puts "Found #{posts.facets[:popular_farming].total_count} popular posts about both 'badgers' and 'farming'"
posts.facets[:popular_farming].each do |post|
  puts "Title: #{post.title}"
end
```

The actual arguments to each facet can be either an array (if overriding both
`query` and `options`), or just the query or the options to override.

Oedipus replaces `%{query}` in your facets with whatever the base query was,
which is useful if you want to amend the search, rather than completely
overwrite it (which is also possible).

#### Faceted search with N dimensions

Each facet in a faceted search can in turn contain facets of its own.  This
allows you to perform multi-dimensional faceted searches, where each level
deeper adds a new dimension to the search.  The equivalent tree is returned in
the results.

``` ruby
posts = Post.index.search(
  "badgers",
  facets: {
    popular: {
      :views.gte => 1000,
      :facets    => {
        in_title: "@title (%{query})",
      }
    }
  }
)

puts "Found #{posts.facets[:popular].facets[:in_title].total_found} popular posts with 'badgers' in title"
```

#### Performance tip

A common use of faceted search is to provide links to the full listing for
each facet, but not necessarily to display the actual results.  If you only
need the meta data, such as the count, set `:limit => 0` on each facet. The
result sets for the facets will be empty, but the `#total_found` will still
be reflected.

``` ruby
posts = Post.index.search(
  "badgers",
  facets: {
    popular: {:views.gte => 1000, :limit => 0}
  }
)

puts posts.facets[:popular].total_found
```

### Performing multiple searches in parallel

It is possible to execute multiple searches in a single request, much like
performing a faceted search, but with the exeception that the queries need
not be related to each other in any way.

This is done through `#multi_search`, which accepts a Hash of named searches.

``` ruby
Post.index.multi_search(
  badgers:         "badgers",
  popular_badgers: ["badgers", :views.gte => 1000],
  rabbits:         "rabbits"
).each do |name, results|
  puts "Results for #{name}..."
  results.each do |post|
    puts "Title: #{post.title}"
  end
end
```

The return value is a Hash whose keys match the names of the searches in the
input Hash.  The end result is much like if you had called `#search`
repeatedly, except that Sphinx has a chance to optimize the common parts in
the queries, which it will attempt to do.

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

## Talking directly to Oedipus

If you want to by-pass DataMapper and just go straight to Oedipus, which returns
lightweight results using Arrays and Hashes, you call use the `#raw` method on the
index.

See the [oedipus documentation](https://github.com/d11wtq/oedipus) for details of
how to work with this object.

``` ruby
require 'pp'
pp Post.index.raw.search(
  "badgers",
  user_id: Oedipus.not(7),
  order:   {views: :desc}
)
```

## Licensing and Copyright

Refer to the LICENSE file for details.
