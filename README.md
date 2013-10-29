Safer SketchUp Observer Events
==============================

Mix-in module that implements wrappers for executing model changes from observer events safely*.

* **NOTE** It's not 100% safe. There is always possible to break stuff will observers. See example at the bottom of this readme for example.
* **ATTENTION!** Never, ever, ever, use this wrapper methods for events that doesn't modify the model. If you do you will trigger another bug where commiting an empty transparent operation will mess up the Undo stack and possibly crash SketchUp!

Usage
-----

1. Include the `SaferObserverEvents` mix-in module.
2. Append `safer_` in front of the observer events.
3. Done!

Now the event will be deferred until the current operation has finished and it is safe to perform model changes.

As an added bonus, everything will be wrapped into an transparent operation.

```ruby
class MySaferEntitiesObserver < Sketchup::EntitiesObserver

  include SaferObserverEvents

  def safer_onElementAdded(entities, entity)
    # Entity might already be invalid. Make sure to check for that.
    return if entity.deleted?
    if entity.is_a?(Sketchup::Face)
      entity.erase!
    else
      entity.set_attribute('MeMyselfAndI', 'LickIt', 'IOweIt!')
    end
  end

end # class

observer = MySaferEntitiesObserver.new
Sketchup.active_model.entities.add_observer(observer)
```

Manually Deferring Actions
----------------------------

If you don't want to defer everything in the observer event you can manually defer just a block of it using `defer_model_change`. The only argument it takes is a `Sketchup::Model` object or an object with an `#model` method that returns `Sketchup::Model`.

```ruby
class MySaferEntitiesObserver < Sketchup::EntitiesObserver

  include SaferObserverEvents

  def onElementAdded(entities, entity)
    # Cache some data.
    @cache ||= []
    @cache << entity
    # Change the model.
    defer_model_change(entity) {
      # Entity might already be invalid. Make sure to check for that.
      return if entity.deleted?
      if entity.is_a?(Sketchup::Face)
        entity.erase!
      else
        entity.set_attribute('MeMyselfAndI', 'LickIt', 'IOweIt!')
      end
    }
  end

end # class
```

Beware of Gremlins!
-------------------

It is still possible to break stuff, for instance if anyone is doing stuff like this in a model where we have attached our first example:
```ruby
# Example of bad program design, do UI interaction before starting to work on
# the model.
model = Sketchup.active_model
entities = model.active_entities
face = entities.add_face(
  Geom::Point3d.new(0,0,0),
  Geom::Point3d.new(9,0,0),
  Geom::Point3d.new(9,9,0),
  Geom::Point3d.new(0,9,0)
)
face.material = 'red'
UI.messagebox('Look over there!')
# (!) SaferObserverEvents will kick in here!
face.material = 'green' # This is raise error before the face is gone.
```
