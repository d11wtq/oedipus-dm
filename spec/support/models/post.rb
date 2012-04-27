class Post
  include DataMapper::Resource

  property :id,         Serial
  property :title,      String
  property :body,       Text
  property :view_count, Integer

  belongs_to :user
end
