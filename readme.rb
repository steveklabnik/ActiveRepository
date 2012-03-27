# MOTIVATION:  As rails apps are growing, people are noticing the drawbacks
# of the ActiveRecord pattern.  Several apps I have seen, and several
# developers I have spoken to are looking towards other patterns for object
# persistence.  The major drawback with ActiveRecord is that the notion
# of the domain object is conflated with what it means to store/retrieve
# it in any given format (like sql, json, key/value, etc).
#
# This is an attempt to codify the Repository pattern in a way that would
# feel comfortable to beginner and seasoned Ruby developers alike.
#
# In the spirit of "make it look the way you want it to work, then make it
# work like that", here is a vision of the Repository pattern ala Ruby. I
# don't want to fault ActiveRecord for being an implementation of the
# ActiveRecord pattern; At RailsConf 2006, in his keynote, Martin Fowler
# said that ActiveRecord was "the most faithful implementation of the
# Activerecord pattern [he] had ever seen", and he was the one that
# documented that pattern in the first place.  So lets respect AR for what
# it is, and look at the repository pattern, done with Rails Flair.



# Person is a plain old Ruby object. It knows nothing about its persistence,
# but as a domain model, it knows something about its own attributes,
# relationships to other domain objects, as well as understands what it
# means to be 'valid'. Of course, it also has behavior.

class Person
  include ActiveModel::Relationships
  include ActiveModel::Validations
  
  has_many :hobbies
  belongs_to :fraternity
  
  attr_accessor :name
  attr_accessor :password
  attr_accessor :sex
  attr_accessor :born_on
  
  validates_presence_of :name, :password
  
  def favorite_drink
    if born_on < 7.years.ago
      "apple juice"
    elsif born_on < 18.years.ago
      "coke or pepsi"
    elsif < 21.years.ago
      "mountain dew"
    else
      "beer"
    end
  end
end

# conventions like _on and _at are still used.


# The person has no clue it is 'Persistent Capable'.  All of that is handled
# in the Repository.  Notice we could call the Repo anything we want.

class PersonStore < ActiveRepository::Base
  repository_for :person
  
  # other things that control the persistence can go here
  table :users
  encrypts_attribute :password
  map_attribute_to_column :sex, :gender
end

# I'm using inheritance here to enforce an opinion.  Of course this could
# be a mixin, but my current thoughts are that this Repository should only
# ever be a repository - after all, we are trying to get away from
# ActiveRecord's notion of "I'm the model and my own data store!".
# Inheritance would be an appropriate way to signal this *is a* repository.
# My fear is as a mixin, someone would think they are being clever by mixing
# the repository directly into the domain model, essentially recreating
# ActiveRecord and making this effort all for nothing.

# I would really like to have the ability to 'new' model objects as normal:

p = Person.new

# but it might be necessary to create them through the store, like:

p = PersonStore.create #, or
p = PersonStore.build

# saving is no longer done on the object, but through the repository

PersonStore.save(p)

# the save would be smart enough to call is_valid? if Validations were present.

# all the usual finder suspects are on the repository
p = PersonStore.find(5)
p = PersonStore.first
p = PersonStore.all
p = PersonStore.find_by_name("Chris")

# we could also create things like scopes, etc.


# Since Person is nothing special, you could easily swap in a different
# persistance Repository:

class PersonStore < RedisRepository::Base
...
end

# or even:

class PersonStore < RestfulResource::Repository
  repository_for :person
  base_uri "http://coolstuff.livingsocial.com"
end


# Swapping repositories might give you radically different methods (only an
# ActiveRepository would give you a find_by_sql method, for instance), but
# thats ok.  The "Persistant Capable" classes don't change with a change in
# the persistence mechanism. The "Persistent Aware" classes, like the
# controllers, would.  

# And it might even be possible to have multiple repositories in the same
# app...

class PersonStore < ActiveRepository::Base
#...
end

# and

class RemotePersonStore < RestfulResource::Repository
#...
end

# and then you could do stuff like:

p = RemotePersonStore.find(5)
PersonStore.save(p)

# and essentially use two repositories as an ETL engine.


# One nice thing we get from ActiveRecord would have to change slightly -
# the migrations.
# Actually, the migrations could work pretty much as they do now, but devs
# would have to make the corresponding attr_accessor declarations in their
# models.
#
# if an attr_accessor was declared that didn't have a corresponding column in
# the db, then it could warn on application init.  That warning for that field
# could be silenced in the repository with something like:

not_persisted :current_location

# and in reverse, if a migration added a column that couldn't map to an
# attr_accessor, it could warn unless the repo had a line like:

ignore_column :eye_color

# The generator could stick the attr_accessors in the class
# automatically if we wanted it to.  I wouldn't do anything 'magical' like
# have the persistence engine inject it with meta... that would make the
# attributes hard to discover, and could make multiple repositories in an
# app step on each other in nondeterministic ways.  By having attr_accessors,
# the model becomes the 'system of record' for what it means to be that
# kind of domain object.  I like that.

# (of course, nosql dbs may have their own requirements met with their own
# dsls).

# You could even have the store do something like:

synthetic_field :age, { Date.today - born_on }

# while you could do exactly the same thing by adding 'age' method to the
# model, having it in he Repository could be useful for an ETL task, for
# defining the transform step.  Imagine one database that has a born_on
# field, and another one that has an age field, and you are transforming
# data to go into the one with age...  in the store with the born_on,
# set the store to have a synthetic field :age.  In the other store, set
# it to ignore the born_on date. Then in the model you define attr_reader
# for :age.  Both stores see the domain model as exactly what it needs in
# order to make each database happy, and the domain model code stays clean.
#
# if you needed to map an attribute to a different column:

map_attribute_to_column :sex, :gender

# One potentially awesome tweak to the dsl is how this would
# handle polymorphic tables:

class PersonStore < ActiveRepository::Base
  repository_for :person
  repository_for :client
  repository_for :administrator
  polymorphic_model_column :type # would automatically store the class
                                 # type, just like AR polymorphism
end



# Given this pattern, I think relationship declarations go in the models,
# since there they can add the appropriate methods to return collections,
# etc, and since the repo knows what models it is supposed to manage, it can
# get access to the same knowledge to do whatever it needs to do.  If they
# were declared in the repo, it would be inappropriate for the model to
# introspect there, otherwise the model would become 'persistence aware'.
# They 'feel' a little attr_accessor-like things to me.

# Finally, while the model as code looks completely unaware of its storage,
# underneath the covers at runtime the repository could 'enhance' it with
# things like dirty flags for fields, is_dirty? & is_new? methods, etc.
# In fact, for years I used an object-oriented database in Java named
# Versant, and it had a 'bytecode enhancement' step that did exactly this
# during the compile - it modified the classes bytecode with dirty flags
# and other persistence helpers.

