# In the spirit of "make it look the way you want it to work, then make it
# work like that", here is a vision of the Repository pattern ala Ruby. I
# don't want to fault ActiveRecord for being an implementation of the
# ActiveRecord pattern; At RailsConf 2006, in his keynote, Martin Fowler
# said that ActiveRecord was "the most faithful implementation of the
# Activerecord pattern [he] had ever seen", and he was the one that
# documented that pattern in the first place.  So lets respect it for what
# it is, and look at the repository pattern, done with Rails Flair.



# While Person is a plain old Ruby object, inheriting from something like
# ActiveModel::Relationships gives part of the dsl we are used to.  the clues
# from that dsl could also be used by Repository implementations.

class Person
  include ActiveModel::Relationships

  has_many :hobbies
  belongs_to :fraternity
  
  attr_accessor :name
  attr_accessor :password
  attr_accessor :sex
  attr_accessor :born_on
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


# I would really like to have the ability to 'new' model objects as normal:

p = Person.new

# but it might be necessary to create them through the store, like:

p = PersonStore.create #, or
p = PersonStore.build

# saving is no longer done on the object, but through the repository

PersonStore.save(p)

# all the usual finder suspects are on the repository
p = PersonStore.find(5)
p = PersonStore.first
p = PersonStore.all
p = PersonStore.find_by_name("Chris")

# we could also create things like scopes, etc.


# Since Person is nothing special, you could easily swap in something like:

Class PersonStore < RedisRepository::Base
...
end

# or even:

Class PersonStore < RestfulResource::Repository
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

Class PersonStore < ActiveRepository::Base
#...
end

# and

Class RemotePersonStore < RestfulResource::Repository
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

# (of course, nosql dbs may have their own requirements met with their own
# dsls).

# You could even have the store do something like:

synthetic_field :age, { Date.today - born_on }

# and as shown above, if you wanted a different attribute name, you could:

map_attribute_to_column :sex, :gender

# One potentially awesome tweak to the dsl is how this would
# handle polymorphic tables:

class PersonStore < ActiveRepository::Base
  repository_for :person
  repository_for :client
  repository_for :administrator
  polymorphic_model_column :type
end



# Given this pattern, I relationship declarations go in the models,
# since there they can add the appropriate methods to return collections,
# etc, and since the repo knows what its supposed to manage, it can get 
# access to the same knowledge to do whatever it needs to do.  If they were
# declared in the repo, it would be inappropriate for the model to
# introspect there, otherwise the model would become 'persistence aware'.
# They 'feel' a little attr_accessor-like things to me.

# Finally, while the model as code looks completely unaware of its storage,
# underneath the covers at runtime the repository could 'enhance' it with
# things like dirty flags for fields, is_dirty? & is_new? methods, etc.
# In fact, for years I used an object-oriented database in Java named
# Versant, and it had a 'bytecode enhancement' step that did exactly this
# during the compile - it modified the classes bytecode with dirty flags
# and other persistence helpers.




