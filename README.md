# SwiftObservables

This is a Swift implementation of an observer-observable pattern (including binding) that
attempts to mimic value observing without the need for NSObject inheritance, using 
built-in language features of Swift (e.g. property-wrappers).

Note that I did this as an exercise to get a feel for Swift capabilities, so it isn't necessarily as 
comprehensive as what is offered by NSObject or intending to be better than SwiftUI bindng 
property observers, which some of this work pre-dates the existence of. Still, it covers some 
of the basic observing behaviors and gives a mechanism for watching and reacting to specific 
property changes in a standardized way, without the user needing to construct property-specific 
`didSet`/`willSet` functions, which the code constructs automatically.

Caveat: As of this writng, bindings create a strong reference cycle between objects.  There is 
a simple fix for this that will show up in a later update.


## Basic Usage
Make a property observable by declaring it with @Observable atttribute:

    @Observable var x = 1

Other areas of code can then observe that property by calling the `observe()` func and 
passing a closure.  Since this functionality is implemented using property wrappers, you 
access all observable calls via the `$` syntax:

    var ob = $x.observe ( .did, using: myClosure )   // invokes 'myClosure' when x is changed

`observe()` accepts an `ObservationType` enum that specifies four states: `.did `(after a 
change occurs), `.will` (before a change occurs), `.all` (before and after a change occurs), 
and `.disabled` (stops the closure from being invoked).

The `observe()` func returns an object of type `Observation`, which can be used to control 
the behavior of the observation at later times.  For example, to disable the closure during a 
period of heavy updating to avoid excessive calls to the closure:

    if (ob.isEnabled) {
        ob.kind = .disable  // temporarily turn off the observation
    }

It is not necessary to capture the `Observation` that `observe()` returns if you never intend 
to change the observation during the lifetime of the object.

The closure that the `observe()` func accepts is of the form:

    ObservationFunc = (_ newValue: Value, _ oldValue: Value?) -> Void

where `Value` is the type of the observed property.  The closure is the same for both `.did` and
`.will` observations.  However, the `oldValue` parameter will only be non-nil during a `.did` 
observation.  Using the examples above, `myClosure` might look like this:

    func myClosure ( _ new: Int, _ old: Int? ) {
        print("I just saw x change!")
    }

Observations are maintained in an array associated wth each observable, so separate calls to 
`observe()` on the same property are permitted, allowing multiple closures to monitor the 
same thing.  The order of execution of the attached closures is currently determined by the 
order the `observe()` calls were executed.  A future improvement could be to assign 
priorities to an `Observation` to support cases where closure execution order needs to be 
controlled.


## Binding
Two properties can be bound together if they are each declared as an `@Observable` and the 
`bind()` call is made.  Note that you must use the `$` syntax for both during the `bind()` call 
since you are establishing the connection between their `Observable` attributes:

    @Observable var x = 1
    @Observable var y = 2

    if $x.bind( $y ) {
        print( "x and y are now bound: \(x) and \(y)" )
    }
    else {
        print( "x is already bound to something else" )
    }

When two properties are bound together, changing one automatically forces the other to have 
the same value:

    x = 8
    print( "x was changed, but so was y: \(y)" ) // y now also == 8
    
    y += 2
    print( "the reverse is also true: \(x)" )   // x and y now == 10

Unlke `observe()`, though, only one binding per property is allowed.  `bind()` rerturns `false` 
if a property is already bound to another from an earlier `bind()` call.  But since a binding is 
just a special type of observation, you can still have other observations attached to a bound 
property since `observe()` sets no limit on the number of observation closures.  So in the 
above examples, `$x.bind()` was okay, even though earlier `$x.observe()` had been called 
with `myClosure`.  In that case, `myClosure` would get called and the value of `y` would be set 
to match `x`, whenever `x` was changed.  In such a set up, `myClosure` would also be called 
whenever a change was made to `y` since `x`is bound to `y`.

When a binding is established, behind the scenes it creates a `.did` observation for both 
objects and establishes a private closure to coordinate their values.  When you no longer 
wish to have two objects bound together call `unbind()` similar to how you called `bind()`:

    $x.unbind( $y )     // x and y are now independent
    
    x = 3               // y remains 10 from the above example
    
As the binding is bidirectional, the order of the unbinding is irrelevant.  The above line would 
have the same outcome if written as `$y.unbind( $x )` -- so your code doesn't need to 
care how `bind()` was called.  Likewise, the original code would all work the same if it had 
been written as `$y.bind( $x )`.


## Removing an Observation
If your code captures the `Observation` object returned from the `observe()` call, you can 
use it to permanently delete the observation from the observed object.  This is not strictly 
necessary since you can disable the callback by setting the `Observation` type to
`.disabled` .  However, you might want to do so for efficiency purposes, or to truly dispose of
the associated closure that might otherwise be kept alive by the inactive observation reference.
To do thiis, simply pass the `Observation` to the `remove()` call, using the `$` syntax:

    if $x.remove( ob ) {
        print("x is no longer being observed by myClousure.")
    }
    else {
        print("That observation no longer exists")
    }

`remove()` returns `false` if the passed in `Observation` is not associated with the
`Observable` property it is called on.  This is hamless, and may indicate an earlier call to 
`remove()`.  Otherwise, the `Observation` is removed from the property's observation array 
and the associated closure reference is released.  Note that `observe()` creates a strong 
reference to the closure passed in (this will be fixed in a future update), so if you do not call 
`remove()` when the observer goes out of scope, the observed object may keep it alive through 
the strong reference to the closure.  The reverse is not true, however: the observation holds no 
reference to the observed object, so observing something does not keep it alive (except in the 
case of binding where both objects observe each other).

