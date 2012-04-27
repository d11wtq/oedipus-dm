# Oedipus Integration for DataMapper

This gem is a work in progress, binding [Oedipus](https://github.com/d11wtq/oedipus)
with [DataMapper](https://github.com/datamapper/dm-core), in order to support
the querying and updating of Sphinx indexes through DataMapper models.

The gem is not yet published, as it is still in development.

## Usage

All features of Oedipus will ultimately be supported, but I'm documenting as
I complete wrapping the features.

### Define an index method on your model

```
class Post
  include DataMapper::Resource

  property :id,    Serial
  property :title, String
  property :body,  Text

  belongs_to :user

  def self.index
    Oedipus::DataMapper::Index.new(self)
  end
end
```

### Search for resources using the index

``` ruby
Post.index.search("badgers").each do |post|
  puts "Found post #{post.title}"
end
```

#### Filter by attributes

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

``` ruby
Post.index.search("badgers", limit: 30, offset: 60).each do |post|
  puts "Found post #{post.title}"
end
```

## Licensing and Copyright

Refer to the LICENSE file for details.
