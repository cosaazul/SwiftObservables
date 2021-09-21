//
//  Observation.swift  
//
//  Copyright © 2021 cosaazul. All rights reserved.
//
// Purpose: An object that mediates observation settings between an Observable and an observer.


/// Use this to specify the callback type an Observation represents
public enum ObservationType { case disabled, all, did, will }


/// An `Observation` indicates how an `Observable` should invoke the closure
/// registered on it through the `observe()` API, which creates and returns
/// the object.  The observation describes the closure via the `ObservationType`,
/// indicating if it is a willSet or didSet observation, both, or inactive.
///
/// An Observation is stored in a simple array by the observable associated
/// with it and communicates the intention of the observer that created it.
/// The observer can set its type just once, or it can store the Observation,
/// allowing it to communicate changes to the observable holding it.
///
/// An observation can be placed in a permanent `.disabled` state by setting
/// `isObsolete` to `true`, after which it cannot  be set back to `false`.
/// Besides guaranteeing the associated closure is never again called, this state
/// also signals certain code areas to release the observation and its closure.
/// Binding uses this mechanism to release its co-binding observation when one
/// side of the relationship goes out of scope.
public class Observation {

    public init(_ type: ObservationType) {
        _kind = type
    }   // init


    // Computed based on the observation type
    public var isEnabled: Bool {
        return kind != .disabled
    }   // isEnabled


    // Controls whether one, both, or none of the callbacks are triggered
    public var kind: ObservationType {
        // When marked purged, observation is disabled & access to _kind is lost
        get {
            return _bDead ? .disabled : _kind
        }
        
        set {
            _kind = _bDead ? .disabled : newValue
        }
    }   // kind


    // Obsolete an observation, telling some code areas to purge or replace it
    public var isObsolete: Bool  {
        get { return _bDead }
        
        set {
            if (newValue) {
                _bDead = newValue
            }
        }
    }   // isObsolete


    // ----------------------- private----------------------- //
    // Tracks whether the observation that should be removed or replaced
    private var _bDead = false
    
    // The obervation state
    private var _kind : ObservationType
}   // Observation
