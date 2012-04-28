class Post
  include DataMapper::Resource

  property :id,         Serial
  property :title,      String
  property :body,       Text
  property :view_count, Integer
  property :created_at, DateTime

  belongs_to :user
end
