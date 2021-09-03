//
//  Observation.swift  
//
//  Copyright © 2021 cosaazul. All rights reserved.
//
// Purpose: An object that mediates observation settings between an Observable and an observer.


// Use this to specify the callback type the observation represents
public enum ObservationType { case disabled, all, did, will }


// An Observation indicates how an Observable should invoke the closure
// registered on it through the observe() API, which creates and returns
// the object.  The Observation describes the closure via the ObservationType,
// indicating if it is a willSet or didSet observation, both, or inactive.

// An Observation is stored in a simple array by the Observable associated
// with it and communicates the intention of the observer that created it.
// The observer can set its type just once, or it can store the Observation,
// allowing it to communicate changes to the Observable holding it.
public class Observation {

    // This property is computed based on the state of the observation type
    public var isEnabled: Bool {
        return kind != .disabled
    }   // isEnabled
    
    // This property can be used to control whether one, both, or none of the callbacks are triggered
    public var kind: ObservationType
    
    
    // default
    public init(_ type: ObservationType) {
        kind = type
    }   // init

}   // Observation
