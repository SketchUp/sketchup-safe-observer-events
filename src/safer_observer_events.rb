# Mixin module providing methods to safely react with model changes to observer
# events.
#
# @example Manually deferring model changes.
#   class MySaferEntitiesObserver < Sketchup::EntitiesObserver
#  
#     include SaferObserverEvents
#  
#     def onElementAdded(entities, entity)
#       # Cache some data.
#       @cache ||= []
#       @cache << entity
#       # Change the model.
#       defer_model_change(entity) {
#         # Entity might already be invalid. Make sure to check for that.
#         return if entity.deleted?
#         if entity.is_a?(Sketchup::Face)
#           entity.erase!
#         else
#           entity.set_attribute('MeMyselfAndI', 'LickIt', 'IOweIt!')
#         end
#       }
#     end
#  
#   end # class
#  
#   observer = MySaferEntitiesObserver.new
#   Sketchup.active_model.entities.add_observer(observer)
#
# @example Automatic Wrapping
#   class MySaferEntitiesObserver < Sketchup::EntitiesObserver
#   
#     include SaferObserverEvents
#   
#     def safer_onElementAdded(entities, entity)
#       # Entity might already be invalid. Make sure to check for that.
#       return if entity.deleted?
#       if entity.is_a?(Sketchup::Face)
#         entity.erase!
#       else
#         entity.set_attribute('MeMyselfAndI', 'LickIt', 'IOweIt!')
#       end
#     end
#   
#   end # class
#   
#   observer = MySaferEntitiesObserver.new
#   Sketchup.active_model.entities.add_observer(observer)
module SaferObserverEvents

  VERSION = '1.0.2'.freeze

  # Safely defer the execution of the block and wrap everything in an operation.
  #
  # @param [Sketchup::Model, #model]
  # @return [Nil]
  def defer_model_change(model, &block)
    # Allow an object with a #model method to be used.
    unless model.is_a?(Sketchup::Model)
      if model.respond_to?(:model)
        model = model.model
      end
    end
    # Ensure we have a valid model before attemping to perform any action.
    unless model.is_a?(Sketchup::Model) && model.valid?
      raise ArgumentError, "Need a valid model (#{model.inspect})"
    end
    executed = false
    timer_id = UI.start_timer(0, false) {
      # Opening a modal window will cause this non-repeating timer to repeat.
      # to work around this we explicitly stop it, just to be safe.
      #UI.stop_timer(timer_id)
      # (!) Calling UI.stop_timer appear to make SketchUp prone to crashing so
      #     we will instead keep this variable instead to prevent triggering
      #     the event multiple times.
      break if executed
      executed = true
      # Ensure that the operation is transparent so the Undo stack isn't
      # cluttered.
      #
      # NOTE: In SketchUp 8 M1 and older the name of the operation would
      #       change with transparent operations. No workaround for this.
      #       Since SketchUp 8 M2 the name will remain unchanged.
      model.start_operation('Observer Event Change', true, false, true)
      #begin
        block.call
      #rescue => e
        # (!) Do NOT abort the operation! Aborting transparent operations will
        #     abort the previous one as well - not desired!
        #model.abort_operation
        #raise e
      #end
      model.commit_operation
    }
    nil
  end

  def self.included(target_module)

    unless Sketchup.version.to_i > 6
      raise "#{self} requires SketchUp 7 or higher"
    end

    # Forward observer events to safe wrapper. This is needed in case the
    # observer didn't subclass an Observer prototype.
    def method_missing(symbol, *args, &block)
      safe_symbol = "safer_#{symbol}"
      if respond_to?(safe_symbol)
        model = find_model_argument(*args)
        defer_model_change(model) {
          send(safe_symbol, *args, &block)
        }
      else
        super
      end
    end

    # When the observer sub-classes a template observer we must inject
    # forwarding methods that will ensure the safe wrappers are called.
    target_module.instance_methods.grep(/on[A-Z]/).each { |symbol|
      safe_symbol = "safer_#{symbol}"
      target_module.class_eval {
        define_method(symbol) { |*args|
          # Call original method just in case a sub-class implements a non-safe
          # event callback.
          super(*args)
          # Now trigger the safe method.
          if respond_to?(safe_symbol)
            model = find_model_argument(*args)
            defer_model_change(model) {
              send(safe_symbol, *args)
            }
          end
        } # define method
      }
    }

    # SketchUp might query the observer instance before calling it. We must
    # intercept this and check if there is a safe method to handle the
    # observer callback.
    # Due to a bug in SketchUp overriding the `respond_to?` method might cause
    # a crash under OSX. This was only needed for observers that didn't
    # sub-class a template observer.
=begin
    unless method_defined?(:safe_observer_event_respond_to_backup?)
      alias :safe_observer_event_respond_to_backup? :respond_to?
      def respond_to?(*args)
        # First check if the object responds to that method.
        unless safe_observer_event_respond_to_backup?(*args)
          # If it doesn't then check if there is a safe_ version of the method.
          args[0] = "safer_#{args[0]}"
          return safe_observer_event_respond_to_backup?(*args)
        end
        true
      end
    end
=end

  end

  private

  # Forward the arguments from an observer to this utility method that will
  # attempt to find the relevant model for the given entities/objects.
  #
  # @param [Mixed]
  # @return [Sketchup::Model, Nil]
  def find_model_argument(*args)
    # First a valid model object is searched for.
    model = args.find { |arg|
      arg.is_a?(Sketchup::Model) && arg.valid?
    }
    # Then we look for objects that might return a valid model object.
    unless model
      entity ||= args.find { |arg|
        arg.respond_to?(:model) &&
        arg.model.is_a?(Sketchup::Model) && arg.model.valid?
      }
      if entity
        model = entity.model
      end
    end
    # We should only return valid objects.
    unless model && model.valid?
      return nil
    end
    model
  end

end # module
