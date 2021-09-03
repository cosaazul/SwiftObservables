//
//  Observable.swift  
//
//  Copyright © 2019 3Hour Software. All rights reserved.
//
// Purpose: Property wrapper that adds did/will set connectivity to Observers


/// Declare this wrapper on any property using `@Observable` to access
/// the Observer system w/o involving NSObject/Obj-C KPO.  It adds code
/// to manage `Observation` arrays, and provide didSet/willSet-like triggers.
@propertyWrapper public class Observable<Value> {

    // ------------------------ APIs ------------------------

    /// observe
    ///
    /// Call this to observe an object declared with the `@Observable` attribute,
    /// specifying whether the `ObservationFunc` will be called before (`.will`),
    /// after (`.did`), or both (`.all`).  It returns an `Observation` object that can be
    /// used to change when the observation closure gets called, or to disable the
    /// observation.  This object can be ignored, in which case the observation
    /// will persist in its original state for the life of the observed item.
    public func observe(_ type: ObservationType, using call: @escaping ObservationFunc) -> Observation {
        let o = Observation(type)
        if callbacks != nil {
            callbacks!.append((o, call))
        }
        else {
            callbacks = [(o, call)]
        }
        return o    // the caller may store this so it can modify its state later on
    }   // observe


    /// bind
    ///
    /// Call this to bind the Observable to another observable object, which is
    /// passed as an argument.  This creates a `.did` Observation in both objects
    /// associated with the local ObserverFunc 'bindingObserver', and tracks
    /// that observation in the 'binding' property.  The closure, defined within
    /// this class, uses the binding property to safely force each Observable to
    /// be set to the value of the other whenever one of them changes.  The
    /// function returns `false` if there is already binding associated with this
    /// object.  You must call `unbind()` in order to release the two Observables
    /// before binding one to a different one.  It is presently unknown how this
    /// may behave within the context of threads, so assume it is unsafe/unpredictable.
    public func bind(_ obj: Observable<Value>) -> Bool {
        let b = (binding == nil)
        if (b) {
            // us watching them
            binding = obj.observe(.did, using: bindingObserver)
            obj.cobinding = binding
            // them watching us
            obj.binding = observe(.did, using: obj.bindingObserver)
            cobinding = obj.binding
        }
        return b
    }   // bind


    /// unbind
    ///
    /// Call this to release two Observables from a previous call to `bind()`.  The
    /// call will return `false` if either object is not bound to the other, or not
    /// bound to anything.  Otherwise, the binding observation is released for each
    /// object and the function returns` true`.  It is presently unknown how this may
    /// behave within the context of threads, so assume it is unsafe/unpredictable.
    public func unbind(_ obj: Observable<Value>) -> Bool {
        if let o = binding, let o2 = obj.binding, obj.remove(o) {
            binding = nil
            cobinding = nil
            if remove(o2) {
                obj.binding = nil
                obj.cobinding = nil
                return true
            }
             else {
                /// This should never happen through a normal use of the `bind()`
                /// and `unbind()` APIs, since it means this object was bound to
                /// the other, but not vice versa.  The assertion warns of the
                /// problem, but it is possible the caller constructed this setup
                /// on purpose by directly manipulating these objects.  In that
                /// case, our one-sided binding is removed and the other object's
                /// binding remains intact.  If you are looking here because of
                /// the assertion is unexpected, this is likely a bug and should be
                /// reported as such.  If you looking here annoyed that we asserted
                /// over your clever and non-standard manipulation of bindings, feel
                /// free to remove this assertion.
                assertionFailure("Unbind() was called, but while this object was bound to the other, the reverse was not true, which is normally an invalid program state.")
            }
        }
        return false
    }   // unbind


    /// remove
    ///
    /// Call this to delete an `Observation` from the Observable.  If the observation
    /// is not associated with this Observable, the function returns `false`,
    /// otherwise the item and associated closure are deleted from the closure array.
    /// It is not necessary to call `remove()` since you can simply deactivate an
    /// Observation by setting its state to `.disable.`  However, `unbind()` uses it to
    /// explicitly verify that the passed in object is actually bound to the
    /// Observable, so no one accidentally unbinds two unrelated items and creates
    /// multiple orphaned bindings.
    public func remove(_ o: Observation) -> Bool {
        if (callbacks != nil) && !callbacks!.isEmpty {
            // There's something to search
            let iEnd = callbacks!.count
            for i in 0 ..< iEnd {
                if callbacks![i].observation === o {
                    callbacks!.remove(at: i)
                    return true
                }
            }
        }
        return false
    }   // remove
    
    
    // ------------------------ Definitions ------------------------

    /// callback format
    ///
    /// Declare your observation closure to match this signature and pass it observe()
    public typealias ObservationFunc = (_ newValue: Value, _ oldValue: Value?) -> Void


    // ------------------------ Properties ------------------------

    /// observation closure
    ///
    /// All the observations created by a call to our `observe()` or `bind()`
    /// APIs are stored in this array.  Whenever the `set()` call for our wrapped
    /// property is triggered by a value update, it handles each closure according
    /// to the state of the `Observation` object co-located with it.
    private var callbacks: [(observation: Observation, func: ObservationFunc)]?


    /// binding observation
    ///
    /// If we are bound to another object -- and we can only be bound to one at
    /// a time -- we track our own observation on the other object here.  We can
    /// then use this reference to manipulate the observaton state if necessary.
    ///
    private var binding: Observation? = nil


    /// cobinding observation
    ///
    /// If we are bound to another object -- and we can only be bound to one at
    /// a time -- it has its bnding observation stored in our callback array.  We
    /// track that observation here, avoiding the need to search the array whenever
    /// any binding related logic is invoked.
    ///
    private var cobinding: Observation? = nil


    // ------------------------ Binding Closure ------------------------
    func bindingObserver(_ newValue: Value, _ oldValue: Value?) {
        guard let _ = binding, let co = cobinding, let call = callbacks else {
            /// This shouldn't be possible, it means another object is bound to
            /// us, but we're not bound to it or vice versa.  It is possible to create such a
            /// set up on purpose by directly manipulating the binding parameters
            /// of objects outside the `bind()` and `unbind()` APIs, but that is not
            /// the intended behavior.  If you did that, congrats, very clever,
            /// feel free to remove this assertion.  Othwewise, if you are here,
            /// this is an invalid program state and should be reported as a bug.
            fatalError("Binding closure triggered on an object that has no binding observation set.")
        }
        guard oldValue != nil else {
            /// This shouldn't happen, but per the above comments maybe you are
            /// trying to do something clever, in which case remove this assertion.
            /// Otherwise, this is a bug so please report it.
            fatalError("Binding closure called with 'oldValue' set to nil.  Bindings are 'didSet' observations, so this should never happen and implies a 'willSet' observation triggered this code.")
        }
        /// Our companion object has changed, so update our value to match.  If it
        /// is the only thing observing us, just update the underlying value since
        /// that avoids all the `set()` logic.  If anything else is watching, we turn
        /// off the binding observation to avoid a recursive echo back the to thing
        /// that informed us it just changed.
        if call.count > 1 {
            co.kind = .disabled
                wrappedValue = newValue     // trigger the other observers
            co.kind = .did
        }
        else {
            _value = newValue
        }
    }   // bindingObserver


    // ------------------------ Wrapped Property ------------------------

    // wrapped property
    private var _value: Value


    // projected value
    public var projectedValue: Observable<Value> {
        get { return self }
     }   // computed

    
    // wrapped property -- this triggers the calls to did/will for any observers
    public var wrappedValue: Value {
        get { return _value }
        
        set {
            /// try to minimize the number of calls needed since we are doing this w/every value change,
            /// so only look at the callbacks if there are any at all, and only walk the entire array
            /// if there is more than one entry, otherwise we can process the one more efficiently
            if (callbacks != nil), !callbacks!.isEmpty {
                // then see if we should walk an array or just call the only item
                if callbacks!.count > 1 {
                    // though it adds some calling overhead, I put this bit in a func for readibility
                    array_walk(_value, newValue)
                }
                else if callbacks![0].observation.isEnabled {
                    // there is only one active observation, check to see what callbacks it's watching
                    let type = callbacks![0].observation.kind
                    let call = callbacks![0].func
                    if (type != .did) {
                        // it was either .will or .all
                        call(newValue, nil)
                    }
                    // note we avoid storing oldValue if .will isn't being watched
                    if (type != .will) {
                        // it was either .did or .all
                        let oldValue = _value
                        _value = newValue
                        call(newValue, oldValue)
                    }
                    else {
                        _value = newValue   // it was only watching willSet
                    }
                }
                else {
                    _value = newValue   // something was once watching, but isn't at present
                }
            }
            else {
                 _value = newValue      // there was nothing watching us
            }
        }   // set
    }   // wrapped value


    // required for initial values
    public init(wrappedValue: Value) {
        _value = wrappedValue
    }   // init


    // ------------------------ private ------------------------
    private func array_walk(_ old: Value, _ new: Value) {
        // process any active .will or .all observations
        let iEnd = callbacks!.count
        for i in 0 ..< iEnd {
            let o = callbacks![i].observation
            if o.isEnabled && (o.kind != .did) {
                callbacks![i].func(new, nil)
            }
        }
         _value = new
        // process any active .did or .all observations
        for i in 0 ..< iEnd {
            let o = callbacks![i].observation
            if o.isEnabled && (o.kind != .will) {
                callbacks![i].func(new, old)
            }
        }
    }   // array_walk


}   // Observable (property wrapper)
