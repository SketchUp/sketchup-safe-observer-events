SketchUp Safe Observer Events
=============================

Mix-in module that implements wrappers for executing model changes from observer events safely.

Usage
-----

1. Include the `SafeObserverEvents` mix-in module.
2. Append `safe_` in front of the observer events.
3. Done!

Now the event will be deferred until the current operation has finished and it is safe to perform model changes.

As an added bonus, everything will be wrapped into an transparent operation.

```ruby
class MySafeEntitiesObserver < Sketchup::EntitiesObserver

  include SafeObserverEvents

  def safe_onElementAdded(entities, entity)
    # Entity might already be invalid. Make sure to check for that.
    return if entity.deleted?
    if entity.is_a?(Sketchup::Face)
      entity.erase!
    else
      entity.set_attribute('MeMyselfAndI', 'LickIt', 'IOweIt!')
    end
  end

end # class

observer = MySafeEntitiesObserver.new
Sketchup.active_model.entities.add_observer(observer)
```

Manually Deferring Actions
----------------------------

If you don't want to defer everything in the observer event you can manually defer just a block of it using `defer_model_change`. The only argument it takes is a `Sketchup::Model` object or an object with an `#model` method that returns `Sketchup::Model`.

```ruby
class MySafeEntitiesObserver < Sketchup::EntitiesObserver

  include SafeObserverEvents

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
