    import XCTest
    @testable import SwiftObservables
    
    // A collection of items to watch during tests
    class ObservableItems {
        @Observable var x = 15
        @Observable var label = "test"
    }   // ObservableItems


    // make the items outside the class, just for the sake of
    // showing you can watch across scopes
    let gTestItems = ObservableItems()
    

    // testing class
    final class SwiftObserverTests: XCTestCase {
        // track number of hits to each callback
        var counter_X = 0
        var counter_2nd_watcher = 0
        var counter_Label = 0
        
        // monitor old value of X
        var captureNew_X = 0                // captures newValue in closure
        var captureOld_X = 0                // captures oldValue in closure
        var bPossibleDidClosure_X = false   // indicates that .did happened
        var bPossibleWillClosure_X = false  // indicates that .will happened

        // monitor old value of label
        var bPossibleDidClosure_Label = false   // see above
        var bPossibleWillClosure_Label = false  // see above

        // a property to bind with label
        @Observable var bound_label = "anything"
        @Observable var another_label = "to test one binding at a time"


        // testing closure for ObservableItems.x
        func watchingX(_ newValue: Int, _ oldValue: Int?) {
            // Indicate that we arrived here
            counter_X += 1

            // Record what we saw
            captureNew_X = newValue

            // That this is actually a .did or .will is not directly
            // communicated, so we're inferring it from the state
            // of the 'oldValue' arg.  The test just validates its
            // expectation against these results, though a more exhaustive
            // test could probably be devised.
            if (oldValue == nil) {
                bPossibleWillClosure_X = true
            }
            else {
                captureOld_X = oldValue!    // also capture oldValue
                bPossibleDidClosure_X = true
             }
        }   // watchingX


        // second closure to validate multiple observers on the same item
        func alsoWatchingX(_ newValue: Int, _ oldValue: Int?) {
            // Indicate we also arrived here
            counter_2nd_watcher += 1
            
            // we use this one just to test that multiple observers
            // can attach to the same item, thus we don't interact
            // with the .did/.will booleans here.
            
            
        }   // alsoWatchingX


        // testing closure for ObservableItems.label
        func watching_Label(_ newValue: String, _ oldValue: String?) {
            // Indicate that we arrived here
            counter_Label += 1
            
            // That this is actually a .did or .will is not directly
            // communicated, so we're inferring it from the state
            // of the 'oldValue' arg.  The test just validates its
            // expectation against these results, though a more exhaustive
            // test could probably be devised.
            if (oldValue == nil) {
                bPossibleWillClosure_Label = true
            }
            else {
                bPossibleDidClosure_Label = true
            }
        }   // watching_Label


        // @Observable tests, including observe() and remove() calls
        func testObservable() {
            // just validating the starting state of the tests
            _reset_all()
            XCTAssertEqual(gTestItems.x, 15)
            XCTAssertEqual(counter_X, 0)
            XCTAssertEqual(counter_2nd_watcher, 0)
            XCTAssertEqual(captureNew_X, 0)
            XCTAssertEqual(captureOld_X, 0)
            XCTAssertFalse(bPossibleDidClosure_X)
            XCTAssertFalse(bPossibleWillClosure_X)
            
            // change X and see if the observation was triggered
            let ob = gTestItems.$x.observe(.did, using: watchingX)
            gTestItems.x = 10
            XCTAssertEqual(counter_X, 1)
            XCTAssertEqual(counter_2nd_watcher, 0)
            XCTAssertEqual(captureNew_X, 10)
            XCTAssertEqual(captureOld_X, 15)
            XCTAssertTrue(bPossibleDidClosure_X)
            XCTAssertFalse(bPossibleWillClosure_X)
            
            // change the observation to .will
            _reset_flags()
            ob.kind = .will
            gTestItems.x = 20
            XCTAssertEqual(counter_X, 2)
            XCTAssertEqual(counter_2nd_watcher, 0)
            XCTAssertEqual(captureNew_X, 20)
            XCTAssertEqual(captureOld_X, 0)         // .will publishes no oldValue
            XCTAssertFalse(bPossibleDidClosure_X)
            XCTAssertTrue(bPossibleWillClosure_X)
            
            // change the observation to .all
            _reset_flags()
            ob.kind = .all
            gTestItems.x = 30
            XCTAssertEqual(counter_X, 4)            // closure called twice this time
            XCTAssertEqual(counter_2nd_watcher, 0)
            XCTAssertEqual(captureNew_X, 30)
            XCTAssertEqual(captureOld_X, 20)
            XCTAssertTrue(bPossibleDidClosure_X)
            XCTAssertTrue(bPossibleWillClosure_X)
            
            // add another observer
            _reset_flags()
            let ob2 = gTestItems.$x.observe(.did, using: alsoWatchingX)
            gTestItems.x = 40
            XCTAssertEqual(counter_X, 6)
            XCTAssertEqual(counter_2nd_watcher, 1)
            XCTAssertEqual(captureNew_X, 40)
            XCTAssertEqual(captureOld_X, 30)
            XCTAssertTrue(bPossibleDidClosure_X)
            XCTAssertTrue(bPossibleWillClosure_X)

            // change 1st closure back to .did
            _reset_flags()
            ob.kind = .did
            gTestItems.x = 50
            XCTAssertEqual(counter_X, 7)            // closure called for each type
            XCTAssertEqual(counter_2nd_watcher, 2)
            XCTAssertEqual(captureNew_X, 50)
            XCTAssertEqual(captureOld_X, 40)
            XCTAssertTrue(bPossibleDidClosure_X)
            XCTAssertFalse(bPossibleWillClosure_X)

            // disable the 1st closure
            _reset_flags()
            ob.kind = .disabled
            gTestItems.x = 60
            XCTAssertEqual(counter_X, 7)            // closure shouldn't be called
            XCTAssertEqual(counter_2nd_watcher, 3)  // but this one still should
            XCTAssertEqual(captureNew_X, 0)         // again, this closure isn't called
            XCTAssertEqual(captureOld_X, 0)         // ditto
            XCTAssertFalse(bPossibleDidClosure_X)
            XCTAssertFalse(bPossibleWillClosure_X)

            // closures are called even if new == oldValue
            _reset_flags()
            gTestItems.x = 60
            XCTAssertEqual(counter_X, 7)            // closure shouldn't be called
            XCTAssertEqual(counter_2nd_watcher, 4)  // but this one still should
            XCTAssertEqual(captureNew_X, 0)         // again, this closure isn't called
            XCTAssertEqual(captureOld_X, 0)         // ditto
            XCTAssertFalse(bPossibleDidClosure_X)
            XCTAssertFalse(bPossibleWillClosure_X)

            // remove the 1st closure
            _reset_flags()
            XCTAssertTrue(gTestItems.$x.remove(ob))
            gTestItems.x = 70
            XCTAssertEqual(counter_X, 7)            // closure shouldn't be called
            XCTAssertEqual(counter_2nd_watcher, 5)  // but this one still should
            XCTAssertEqual(captureNew_X, 0)         // again, this closure isn't called
            XCTAssertEqual(captureOld_X, 0)         // ditto
            XCTAssertFalse(bPossibleDidClosure_X)
            XCTAssertFalse(bPossibleWillClosure_X)

            // try to remove it a second time, which fail nicely
            XCTAssertFalse(gTestItems.$x.remove(ob))

            // remove the 2nd closure
            _reset_flags()
            XCTAssertTrue(gTestItems.$x.remove(ob2))
            gTestItems.x = 80
            XCTAssertEqual(counter_X, 7)            // closure shouldn't be called
            XCTAssertEqual(counter_2nd_watcher, 5)  // neither should this one
            XCTAssertEqual(captureNew_X, 0)         // again, this closure isn't called
            XCTAssertEqual(captureOld_X, 0)         // ditto
            XCTAssertFalse(bPossibleDidClosure_X)
            XCTAssertFalse(bPossibleWillClosure_X)
        }   // func testObservable


        // Test of the bind() and unbind() calls
        func testBinding() {
            // just validating the starting state of the tests
            _reset_all()
            XCTAssertEqual(gTestItems.label, "test")
            XCTAssertEqual(bound_label, "anything")
            XCTAssertEqual(counter_Label, 0)
            
            /// My initial test intended to create a local variable to bind
            /// to, but because `XCTAssert...()` use autoclosures for its
            /// parameters, this triggers an error stating the "Closure captures
            /// _var' before it is declared", which I presume is a consequence
            /// of how Swift generates the capture list for the escaping closure
            /// vs. a wrapped property.  I get the same error if I use other
            /// wrapped properties (e.g. SwiftUI's @State) so this is just a
            /// limitation on property wrappers, not @Observable in particular.
            ///
            ///     @Observable var watch = "anything"
            ///     XCTAssertTrue($watch.bind(gTestItems.$label))
            
            // bind the two together and change one of them
            XCTAssertTrue($bound_label.bind(gTestItems.$label))
            bound_label = "changed"
            XCTAssertEqual(gTestItems.label, bound_label)
            XCTAssertEqual(gTestItems.label, "changed") // just being explicit

            // change in the other direction
            gTestItems.label = "different"
            XCTAssertEqual(gTestItems.label, bound_label)
            XCTAssertEqual(bound_label, "different")
            
            // make sure general observing still works
            _ = gTestItems.$label.observe(.did, using: watching_Label)
            gTestItems.label = "again"
            XCTAssertEqual(gTestItems.label, bound_label)   // make sure bnding worked
            XCTAssertEqual(counter_Label, 1)    // and watching_Label was called

            // likewise make sure other observers see changes from the binding
            bound_label = "more"
            XCTAssertEqual(bound_label, gTestItems.label)   // make sure it changed
            XCTAssertEqual(counter_Label, 2)    // and watching_Label saw it

            // verify only one binding is allowed at a time
            XCTAssertFalse($bound_label.bind($another_label))
            
            // see that unbind works
            XCTAssertTrue($bound_label.unbind(gTestItems.$label))
            bound_label = "independent"
            XCTAssertNotEqual(bound_label, gTestItems.label)
            
            // make sure binding still works
            XCTAssertTrue($bound_label.bind($another_label))
            another_label = "now we're joined"
            XCTAssertEqual(bound_label, another_label)

            // test that unbinding fails for an unbound object
            XCTAssertFalse($bound_label.unbind(gTestItems.$label))
            another_label = "we're still together"
            XCTAssertEqual(bound_label, another_label)

            // test that unbinding works if callers are reversed
            XCTAssertTrue($another_label.unbind($bound_label))
            another_label = "free again!"
            XCTAssertNotEqual(another_label, bound_label)
        }   // func testBinding


        private func _reset_all() {
            // set all the tracking variables back to initial states
            counter_X = 0
            counter_2nd_watcher = 0
            counter_Label = 0
            _reset_flags()
        }   // _reset_all


        private func _reset_flags() {
            // this is just a place to reset any tracking
            // variables that should be placed into their
            // default state between tests
            captureNew_X = 0
            captureOld_X = 0
            bPossibleDidClosure_X = false
            bPossibleWillClosure_X = false
            bPossibleDidClosure_Label = false
            bPossibleWillClosure_Label = false
        }   // _reset_flags


    }   // class SwiftObserverTests
