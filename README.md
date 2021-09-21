# SwiftObservables

This is a Swift implementation of an observer-observable pattern (including binding) that
attempts to mimic value observing without the need for NSObject inheritance, using 
built-in language features of Swift (e.g. property-wrappers).

Note that I did this as an exercise to get a feel for Swift capabilities, so it isn't necessarily as 
comprehensive as what is offered by NSObject or intending to be better than SwiftUI bindng 
property observers, which some of this work pre-dates the existence of. Still, it covers some 
of the basic observing behaviors and gives a mechanism for watching and reacting to specific 
property changes in a standardized way, without the user needing to construct property-
specific `didSet`/`willSet` functions.

With v1.0.0, bindings no longer create strong reference cycles.  Additionally, a mechanism is
provided for observers to passively release their closures after they no longer have direct
access to the observed object.  See the _Obsoleting Closures_ section for a discussion on
observation closure handling.


## Basic Usage
Make a property observable by declaring it with the `@Observable` atttribute:

    @Observable var x = 1

Other areas of code can then observe that property by calling the `observe()` func and 
passing a closure.  Since this functionality is implemented using property wrappers, you 
access all observable calls via the  `$` (projected value) syntax:

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

It is not necessary to preserve the `Observation` that `observe()` returns if you never intend 
to change it during the lifetime of the observed property.  But since it is independent of that
property, storing or capturing the observation won't impact the lifecycle of what's being
observed.

The closure that the `observe()` func accepts is of the form:

    ObservationFunc = (_ newValue: Value, _ oldValue: Value?) -> Void

where `Value` is the type of the observed property.  The closure is the same for both `.did`
and `.will` observations.  However, the `oldValue` parameter will only be non-nil during
a `.did` observation.  Using the examples above, `myClosure` might look like this:

    func myClosure ( _ new: Int, _ old: Int? ) {
        print("I just saw x change!")
    }

Remember, any observer closures that capture values from surrounding code will keep those
items alive during the lifetime of the observed object.  If those objects, in turn -- especially via
an implicitly captured `self` -- reference the observed object (in particular, the `@Observable`
property wrapper itself), you can inadvertantly create a strong reference cycle between the
observer and the observed.  So make sure to use capture lists or other techniques
(e.g. `remove()` or `isObsolete`) to avoid or manage this.

Observations are maintained in an array associated wth each observable, so separate calls to 
`observe()` on the same property are permitted, allowing multiple closures to monitor the 
same thing.  The order of execution of these closures is generally determined by the order
in which the `observe()` calls were made, though even that is not guaranteed if previous
observations have been marked `isObsolete` prior to new ones being added (see _Obsoleting
Closures_ section).  A future improvement could be to assign priorities to an `Observation`
to support cases where closure execution order needs to be controlled.


## Binding
Two properties can be bound together if they are each declared as an `@Observable` and the 
`bind()` call is made.  Note you must use the `$` (projected value) syntax for both during the
call since you are establishing the connection between their `@Observable` attributes:

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

Unlke `observe()` though, only one binding per property is allowed.  `bind()` rerturns `false` 
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

The binding relationship is also weak, so is automatically severed if one of the objects
is freed.  In such a case, the observation for the remaining half of the binding is marked
obsolete (see _Obsoleting Closures_), meaning it will be purged or replaced at a later time.


## Removing an Observation
If your code captures the `Observation` object returned from the `observe()` call, you can 
use it to permanently delete the observation from the observed object.  This is not strictly 
necessary since you can disable the callback by setting the `Observation` type to
`.disabled` .  However, you might want to do so for efficiency purposes, or to truly dispose of
the associated closure that might otherwise be kept alive by the inactive observation reference.
To do thiis, simply pass the `Observation` to the `remove()` call, using the `$` (projected
value) syntax:

    if $x.remove( ob ) {
        print("x is no longer being observed by myClousure.")
    }
    else {
        print("That observation no longer exists")
    }

`remove()` returns `false` if the passed in `Observation` is not associated with the
`@Observable` property it is called on.  This is hamless, and may indicate an earlier call to 
`remove()`.  Otherwise, the `Observation` is removed from the property's observation array 
and the associated closure reference is released.

Note that `remove()` requires you to have access to the observed object in order to make the
call.  If you need to remove observation closures in circumstances where code no longer has
that access, or you otherwise want to passively release your closures, you can obsolete them
instead (see _Obsoleting Closure_ section).


## Obsoleting Closures
The  `observe()` call creates a strong reference to the passed-in closure that keeps it in
memory as long as the observed object persists.  If the closure is meant to remain active for
the entire lifetime of the observed object this is fine.  In other cases, `remove()` is available,
but only for situations in which the observing code still has access to the observed object.  To
avoid requiring the closure or other code to artificially maintain a reference to the observed
object, just for the sake of calling `remove()`, v1.0.0 introduces the concept of obsoleting,
which marks an observation for later release.

To mark an observation obsolete, store or capture the `Observation` object (see _Basic
Usage_ section) returned from`observe()`.  When the closure is no longer needed, set the
`isObsolete` property to `true`:

    ob.isObsolete = true

Once this is done, the observation is automatically set to the `.disabled` state so the closure
will not be called again:

    if (!ob.isEnabled) {
        print("It is automatically shut off.")      // this will print
    }

Once an observation is marked obsolete it cannot be reversed:

    ob.isObsolete = false   // this is ignored
    if (ob.isObsolete) {
        print("It can't be undone!")    // this will print
    }
    
Likewise, the `kind` property becomes unchangeable for an obsolete closure:

    ob.kind = .will     // this is ignored now
    if (ob.kind == .will) {
        print("Sorry, you'll never see this message.")  // this never prints
    }

Obsolete closures are not immediately released, but will be purged (or replaced) during any
future call to `observe()`, `remove()`, `bind()`, or `unbind()` for that observable.  Since
there is no guarantee this may ever occur, v1.0.0 also introduces the `cleanse()` call, which
code associated with the observed object may make to periodically flush obsolete closures
from the property's closure array:

    $x.cleanse()    // any obsoleted closures have now been removed for this object

A future enhancement may introduce a mechanism to globally release all obsolete closures
immediately for all observables in memory.
