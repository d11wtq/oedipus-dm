# Oedipus Integration for DataMapper

This gem is a work in progress, binding [Oedipus](https://github.com/d11wtq/oedipus)
with [DataMapper](https://github.com/datamapper/dm-core), in order to support the
querying and updating of Sphinx indexes through DataMapper models.

Too early to say more, but in essence it will allow you to do things like:

``` ruby
Post.index.search(
  "badgers | farmers",
  :views.gte => 100,
  :order     => [:relevance.desc]
)
```

As with the underlying Oedipus gem, updating, deleting from and inserting into
realtime indexes will be supported, as will faceted searching.

## Licensing and Copyright

Refer to the LICENSE file for details.
