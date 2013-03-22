# Off the Rails!
## Techniques for Building Clean Rails Apps
### (Maybe Part 1?)
### Todd Evanoff - 9mmedia

---

# What's the Problem with the Rails Way?

* For small, well-defined apps, not much!
* But, once apps grow and more complexity is added, lines tend to get blurred
* Pure Rails MVC can get messy quickly
* "Fat Model" is a bad paradigm
* Controllers inevitably end up getting bogged down with misplaced business logic
* Forms writing directly to the data model can be a PITA, and a security issue
* Views often become a mess of markup, css, and ruby logic
* Did I forget anything?!

---

# Caveats

* While I think these are good principles to be mindful of, context is king
* Usually end up with more files and code
* Probably unnecessary on small projects
* Usually best to start simple, with tests, and then refactor pieces that prove difficult to change

---

# Development Goals

* Managing Complexity
* Readability
* Testability
* Arguably most importantly: Managing Change!

---

# How?

* Some basic OOP
  * DRY
  * Single Responsibility Principle
  * Encapsulation
  * Tell, Don't Ask
* Patterns
  * Decorators
  * Visitors
* DCI (Data, Context, and Interactions)

---

# The Letter V

---

# Views

* Logic in views is always an ugly mess. ALWAYS!
* Also not reusable and hard to test
* The Rails (view) helpers give you reuse and testability, but they are as non-OO as you can get
* This is how users interact with your system, so they shouldn't be fragile messes

---

# Presenters

* The glue between models and a view
* Presenters are basically Decorators used to encapsulate view logic
* Also used to keep related view methods close to the model they represent
* Different Presenters for different view types (HTML page vs API results)
* Use this and throw out those Rails view helpers
* Simple to build yourself, or the Draper gem is a good implementation

---

# Draper

* Single model

```ruby
def show
  @article = ArticleDecorator.decorate(Article.find(params[:id]))
end
```

```ruby
class ArticleDecorator < Draper::Decorator
  delegate_all
  decorates_association :author

  def published_at
    source.published_at.strftime("%A, %B %e")
  end
end
```

---

# Draper

* Collection

```ruby
@article = ArticleDecorator.decorate_collection(Article.order(:name))
```

```ruby
@article = ArticlesDecorator.decorate(Article.find(Article.order(:name)))
```

```ruby
class ArticlesDecorator < Draper::CollectionDecorator
  def total_articles
    ...
  end
end
```

---

# Some Other View-Level Tidbits

* There's a ton we could go over to keep the markup/css/js clean, but that's another techtalk (I vote for Javi!)
* Consistency! Consistent naming of ids, classes, files, etc helps reign in the complexity
* Decide if you're going to use dashed or underscors in id/class names and stick with it
* If you're accessing an element through javascript, give it a class that starts with "js-" for the JS access, but don't style on it

---

# The Letter C

---

# Controllers

* Handle user actions
* Take in data from the user
* Execute some defined use case
* Render or return results back to user

---

# Controllers

* Often have different paths for an action (user path vs admin path, for example)
* It's so easy for business logic to creep into controller methods, but this is bad!
  * Rules out any future reuse
  * Makes their tests more complicated and fragile (testing all the paths!)
  * They extend a Rails class, so you're coupling your business logic to your framework

---

# Service Objects (Strategies)

* Hide business logic in a plain, well-named class
* Here's a controller action with too much logic
 
```ruby
def reviews
  deal = Deal.find(params[:id])
  @type = params[:type]
  @results = {}

  case @type.to_sym
  when :yelp
    @results = YelpReviewFinder.new(deal.yelp_id).reviews if deal.yelp_id
  when :city_grid
    @results = CityGridReviewFinder.new(deal.city_grid_id).reviews if deal.city_grid_id
  end

  respond_to do |format|
    format.js
    format.json { render json: @results }
  end
end
```

---

# Service Objects (Strategies)

* Let's move that info to a plain ole' ruby object

```ruby
class DealReviewsFinder

  YELP      = :yelp
  CITY_GRID = :city_grid

  def initialize(deal_id)
    @deal_id = deal_id
  end

  def reviews(review_type)
    self.send("#{review_type}_reviews")
  end

  private

    def deal
      @deal ||= Deal.find(@deal_id)
    end

    def yelp_reviews
      return {} if deal.yelp_id.nil?
      YelpReviewFinder.new(deal.yelp_id).reviews
    end

    def city_grid_reviews
      return {} if deal.city_grid_id.nil?
      CityGridReviewFinder.new(deal.city_grid_id).reviews
    end
end
```

---

# Service Objects (Strategies)

* And now our controller is much simpler
* It just uses its params to ask our Service Object to do the heavy lifting

```ruby
def reviews
  @type = params[:type]
  @results = DealReviewsFinder.new(params[:id]).reviews(@type)

  respond_to do |format|
    format.js
    format.json { render json: @results }
  end
end
```

---

* The controller is a bit easier to test
* Don't have to test DealReviewsFinder, it has its own tests
* Just care that @results get assigned

```ruby
describe "GET reviews" do
  it "assigns results from Yelp to @results" do
    DealReviewsFinder.any_instance.stub(:reviews).and_return({ yelp: { yay: true } })
    get :reviews, { id: 1, type: 'yelp' }, valid_session
    assigns(:results).should include({ "yay" => true })
  end
end
```

---

# Is This Better?

* Easier to test, as mentioned above
* Reuse! Now if you need to get deal reviews from a different place (API perhaps?), you can
* You can test DealReviewsFinder outside of the controller context
* If you need to add more review sources, only that class has to change. Your controller won't. 
* But, it will lead to more classes and it is just moving logic out of the models

---

# Proxies

* When relying on a third-party interface, like any gem, I usually create a proxy for it
* This lets you create an interface that makes sense for you use
* Encapsulates access to the other interface, so if it changes you only need to change one class

---

# Proxies

```ruby
class YelpClient
  def initialize(consumer_key = nil, consumer_secret = nil, token = nil, token_secret = nil)
    @consumer_key     = consumer_key    || AppSettings.api.yelp.consumer_key
    @consumer_secret  = consumer_secret || AppSettings.api.yelp.consumer_secret
    @token            = token           || AppSettings.api.yelp.token
    @token_secret     = token_secret    || AppSettings.api.yelp.token_secret

    @client = Yelpr::Client.new do |c|
      c.consumer_key    = @consumer_key
      c.consumer_secret = @consumer_secret
      c.token           = @token
      c.token_secret    = @token_secret
    end
  end

  def search(options = {})
    @client.search(options)
  end

  def find_business(id)
    begin
      @client.business(id)
    rescue
      # yelpr gem throws an exception when business cannot be found
      # TODO fix yelper gem, but this works for now
      nil
    end
  end
end
```

---

# Proxies

* We don't have calls going to the Yelpr gem all over our code
* We only call our own interface
* Easier to mock or stub for tests
* Easier to change if Yelpr does a huge revision between versions
* Easier to yank Yelpr and write our own API logic

---

# The Letter M

---

# Models

* Rails tends to favor a "Fat Model" paradigm, where all business logic is pushed to the Models
* This may work for the small apps, but it falls apart on a complex system
* End up with huge models with many non-related methods
* Complex business rules almost never operate on just one model, usually there's some form of interaction between models
* Behavior could change slightly between similar use cases
* They extend a Rails class, so you're coupling your business logic to your framework and to your persistence mechanism

---

# Value Objects

* Great when you have related attributes and methods that act on those attributes
* Encapsulate conceptually similar methods into a Value Object
* Uses ActiveRecord's composed_of

---

# Value Objects

```ruby
class User < ActiveRecord::Base
  attr_accessible :address_city, address_street
  composed_of :address, mapping: 
    [ %w(address_street street), %w(address_city city) ]
end

class Address
  attr_reader :street, :city

  def initialize(street, city)
    @street, @city = street, city
  end

  # address methods
end
```

---

# ActiveSupport Concerns

* A Rails helper for mixin-in class and instance methods
* Not a bad solution if you are going to be using a concern in multiple models
* Not a good solution if you are just refactoring one model
* Can also use in controllers
* Gives us DRY, but not much else

---

# ActiveSupport Concerns

```ruby
class Address < ActiveRecord::Base
  include Locationable
end
```

_app/models/concerns/locationable.rb:_

```ruby
module Locationable
  extend ActiveSupport::Concern

  included do
    # AR associations, validations, callbacks, etc
    has_one :location, as: :locationable, dependent: :destroy
    attr_accessible :location_attributes
  end

  # some instance methods

  module ClassMethods
    # some class methods
  end

end
```

---

# Non Persistent Models

* Sometimes you want some of the good stuff Rails puts on a model (validations, naming), but without having it backed by a DB table
* This is good for things like search form submission, or forms that update multiple models at once
* In Rails 4, just include ActiveModel::Model
* In Rails 3, just copy that file to your lib dir and include it

---

# Non Persistent Models

* Consider a search form
* You have a ton of params getting sent to the controller, and those need to be used to search on a model
* Some quick and dirty ways of doing this
  * Have the controller parse out the params and pass them to a search method on the model
  * Just pass the "search" key of the params hash to a search method on the model and let it pull them out
* Where does validation/sanitation/coercion happen?

---

# Non Persistent Models

```ruby
class DealFilters
  include ActiveModel::Model

  after_initialize :set_defaults

  attr_accessor :location
  attr_accessor :keywords
  attr_reader :categories
  def categories=(categories)
    @categories = attr_to_a(categories)
  end

  private

    # set default values for unset fields
    def set_defaults
      self.page     = 1 unless page
      self.per_page = 500 unless per_page
    end

    # split input like "1, 2, 3" into an array of integers
    def attr_to_a(s)
      s = s.scan(/\d+/) if s.kind_of? String
      s.map(&:to_i).reject { |i| i <= 0 }
    end
end
```

---

# Non Persistent Models

* And the controller use isn't anything new

```ruby
@deal_filters = DealFilters.new(params[:deal_filters])
if @deal_filters.valid?
  ...
```

---

# Non Persistent Models

* The model will have everything that simple_form and the like need

```ruby
<%= simple_form_for(@deal_filters, url: search_deals_path) do |f| %>
  <%= f.input :keywords %>
  ...
<% end %>
```

---

# Models

* All that ActiveRecord stuff makes DB access really, really easy.
* But should we keep adding responsibilites to these object representations of DB rows?
* Without any added business logic, Models are just data and associations
* Sounds more like a data structure than a business object

---

# Models

* What if we kept our Models thin, and used them only for ActiveRecord concerns?
  * Persistence
  * Associations
  * Validations
  * Scopes
* Models can still have methods, but only if they pertain directly to the data, and not to some particular business scenario
* But this just leads to the "anemic model" anti-pattern. Is there another option?

---

# DCI

* Data, Context, and Interactions
* Aims to separate what the system _IS_ from what the system _DOES_
* It's not the underlying data changes that make the system fragile over time, it's the behavior changes
* Your models are typically used in many different contexts, leading to many different behaviors, which means many uncohesive methods
* Why tie the behavior to the data?

---

# DCI

* The approach is similiar to BDD
* Take a user story and expand it into a use case (define the actors, behavior, success flows, error flows, etc)
* Contexts encapsulate the logic for a use case and handle the interactions between the Actors
* Contexts take the model Data objects (Actors), apply Roles to them, and execute the behavior
* Contexts are just triggered from the controllers

---

# DCI

* Takes an object view of the system instead of a class view
* Adds only the necessary functionality (Roles) to models (Actors) at runtime
* Different from the usual way of doing mixins which is on the class level and lives on all objects all the time!

---

# Publishing an Article

```ruby
class Article < ActiveRecord::Base
  def publish
    # publishing logic
  end
end
```

```ruby
class ArticlesController < ApplicationController
  def publish
    @article = Article.find(param[:id])
    @article.publish

    # handle article not found
  end
end
```

---

* This is decent. The logic of publishing an article is handled by the article, which is good.
* But what a user can only publish articles that they've written?

```ruby
class ArticlesController < ApplicationController
  def publish
    @article = current_user.articles.find(param[:id])
    @article.publish if @article

    # handle article not found
  end
end
```

---

* Getting a little messier. Now what if an admin can publish any article?

```ruby
class ArticlesController < ApplicationController
  def publish
    @article = find_article(param[:id])
    @article.publish if @article

    # handle article not found
  end

  def find_article(id)
    if current_user.admin?
      Article.find(id)
    else
      current_user.articles.find(id)
    end
  end
end
```

---

* Logic is a creeper
* This isn't too bad in this example, but you can see where this would go with a more complicated example
* Where does this stuff belong?
* Certainly not in the controller or the model
* We could just handle this with a service object
* But, this is the section on DCI...

---

# The PublishArticle Context

```ruby
class PublishArticle
  attr_reader :article

  def self.call(article_id)
    PublishArticle.new(article_id).call
  end

  def initialize(article_id)
    @article = find_article
    @article.extend Publisher # this!
  end

  def call
    @article.publish
  end

  module Publisher
    def publish
      # publish logic
    end
  end
end
```

---

# Is This Better?

* Well, it's certainly interesting!
* We're mixin-in functionality to _objects_ at runtime, not to _classes_ at "compile time"
* Our Article model _only_ has the functionality it needs for the specific use case being triggered
* Data models can be different things at different times in the system without carrying that functionality around all the time

---

# Testing the Data and Role

```ruby
describe PublishArticle::Publisher do
  before(:each) do
    article.extend PublishArticle::Publisher
  end

  describe '#publish' do
    it 'publishes the article' do
      ...
    end
  end
end
```

---

# Testing the Context

* Simplified test here, would need to test the logic of find_article and the paths on whether or not an article is found
* (Somebody should totally do a tech talk on advanced rspec-ing!)

```ruby
describe PublishArticle do
  let(:article) { FactoryGirl.build_stubbed(:article) }

  it 'publishes the article' do
    PublishArticle.any_instance.should_receive(:find_article).and_return(article)
    context = PublishArticle.new(article.id)
    context.article.should_recieve(:publish)
    context.call
  end
end
``` 

---

# Closing Thoughts

* Some of these I tend to do all the time, others only as the need arises
* Writers never publish a first draft, why do we push first drafts of code? Write it and then refine, refine, refine!
* Don't go overboard overengineering solutions. Start simple, with tests.
* When something is proving difficult to change, then it's time to take a longer look and refactor.
* When looking at a large class, ask yourself what it does. If you say "and", it should probably be more than one class. Same goes for methods.

---
