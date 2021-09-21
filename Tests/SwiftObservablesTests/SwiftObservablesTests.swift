    import XCTest
    @testable import SwiftObservables

    // for clarity in the tests
    let defaultValue_x = 15
    let defaultValue_label = "test"

    // A collection of items to watch during tests
    class ObservableItems {
        @Observable var x = defaultValue_x
        @Observable var label = defaultValue_label
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
            XCTAssertEqual(gTestItems.x, defaultValue_x)
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
            XCTAssertEqual(captureOld_X, defaultValue_x)
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
        }   // testObservable


        // Test of the bind() and unbind() calls
        func testBinding() {
            // just validating the starting state of the tests
            _reset_all()
            XCTAssertEqual(gTestItems.label, defaultValue_label)
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
        }   // testBinding


        func testObservations() {
            // test that Observation objects behave as expected
            let ob = Observation(.did)

            // Verify the initial state
            XCTAssertEqual(ob.kind, .did)
            XCTAssertTrue(ob.isEnabled)
            XCTAssertFalse(ob.isObsolete)

            // test disabling it
            ob.kind = .disabled
            XCTAssertEqual(ob.kind, .disabled)
            XCTAssertFalse(ob.isEnabled)
            XCTAssertFalse(ob.isObsolete)

            // test that it can be reactivated
            ob.kind = .did
            XCTAssertEqual(ob.kind, .did)
            XCTAssertTrue(ob.isEnabled)
            XCTAssertFalse(ob.isObsolete)

            // test that it can be set to .will
            ob.kind = .will
            XCTAssertEqual(ob.kind, .will)
            XCTAssertTrue(ob.isEnabled)
            XCTAssertFalse(ob.isObsolete)

            // test that it can be set to .all
            ob.kind = .all
            XCTAssertEqual(ob.kind, .all)
            XCTAssertTrue(ob.isEnabled)
            XCTAssertFalse(ob.isObsolete)

            // test that it can be obsoleted, disabling it
            ob.isObsolete = true
            XCTAssertEqual(ob.kind, .disabled)
            XCTAssertFalse(ob.isEnabled)
            XCTAssertTrue(ob.isObsolete)

            // test that obsolescence is permanent
            ob.isObsolete = false
            XCTAssertTrue(ob.isObsolete)
            ob.kind = .will
            XCTAssertEqual(ob.kind, .disabled)
            XCTAssertFalse(ob.isEnabled)
        }   // testObservations


        func testObsolescence() {
            // Verify isObsolete works as intended on live Observations

            // a bunch of counters to monitor our test closures
            var count1 = 0
            var count2 = 0
            var count3 = 0
            var count4 = 0

            // establish a bunch of observations
            let items = ObservableItems()
            let ob1 = items.$x.observe(.did) { _, _ in
                count1 += 1
            }
            // sanity check that above step altered nothing
            XCTAssertEqual(count1, 0)

            let ob2 = items.$x.observe(.will) { _, _ in
                count2 += 1
            }
            // sanity check that above step altered nothing
            XCTAssertEqual(count2, 0)

            let ob3 = items.$x.observe(.did) { _, _ in
                count3 += 1
            }
            // sanity check that above step altered nothing
            XCTAssertEqual(count3, 0)

            let ob4 = items.$x.observe(.all) { _, _ in
                count4 += 1     // this counter will increase by 2 using .all
            }
            // sanity check that above step altered nothing
            XCTAssertEqual(count4, 0)

            // baseline tests to show closures are triggered
            items.x = 100
            XCTAssertEqual(count1, 1)
            XCTAssertEqual(count2, 1)
            XCTAssertEqual(count3, 1)
            XCTAssertEqual(count4, 2)   // ob4 is .all, so it gets called twice

            ob2.isObsolete = true
            items.x = 200
            XCTAssertEqual(count1, 2)
            XCTAssertEqual(count2, 1)   // this should not be called anymore
            XCTAssertEqual(count3, 2)
            XCTAssertEqual(count4, 4)   // ob4 is .all, so called x2

            // exercise the replace-an-obsolete code, though there is currently
            // no direct test to prove it happened vs just got tacked onto
            // the end.  It at least shows it isn't breaking the other closures
            // and would catch the case where the new closure failed to install
            // because of bugs in the replace code (which did happen when I 1st
            // wrote the test).
            var count5 = 0
            let ob5 = items.$x.observe(.did) { _, _ in
                count5 += 1
            }
            items.x = 300
            XCTAssertEqual(count1, 3)
            XCTAssertEqual(count2, 1)   // technically this closure no longer exists
            XCTAssertEqual(count3, 3)
            XCTAssertEqual(count4, 6)   // ob4 is .all, so called x2
            XCTAssertEqual(count5, 1)

            // obsolete multiple items
            ob1.isObsolete = true
            ob4.isObsolete = true
            items.x = 400
            XCTAssertEqual(count1, 3)   // no longer called
            XCTAssertEqual(count2, 1)   // no longer exists
            XCTAssertEqual(count3, 4)
            XCTAssertEqual(count4, 6)   // no longer called
            XCTAssertEqual(count5, 2)

            // exercise automatic removal in addition to replacement
            var count6 = 0
            let ob6 = items.$x.observe(.will) { _, _ in
                count6 += 1
            }
            items.x = 500
            XCTAssertEqual(count1, 3)   // no longer exists
            XCTAssertEqual(count2, 1)   // no longer exists
            XCTAssertEqual(count3, 5)
            XCTAssertEqual(count4, 6)   // no longer exists
            XCTAssertEqual(count5, 3)
            XCTAssertEqual(count6, 1)

            // add another before removing a bunch
            var count7 = 0
            let ob7 = items.$x.observe(.did) { _, _ in
                count7 += 1
            }
            items.x = 600
            XCTAssertEqual(count1, 3)   // no longer exists
            XCTAssertEqual(count2, 1)   // no longer exists
            XCTAssertEqual(count3, 6)
            XCTAssertEqual(count4, 6)   // no longer exists
            XCTAssertEqual(count5, 4)
            XCTAssertEqual(count6, 2)
            XCTAssertEqual(count7, 1)

            // exercise remove() releasing obsolete items.  Like
            // the replace code in observe() there is currently
            // no direct test that it really happens, since once
            // you disable an item it won't get called whether it
            // remains in the array or not, but this at least
            // tries to show that it doesn't mess up any later
            // functioning, like adding more observers.
            ob3.isObsolete = true
            ob7.isObsolete = true
            XCTAssertTrue(items.$x.remove(ob5))
            items.x = 700
            XCTAssertEqual(count1, 3)   // no longer exists
            XCTAssertEqual(count2, 1)   // no longer exists
            XCTAssertEqual(count3, 6)   // automatically removed
            XCTAssertEqual(count4, 6)   // no longer exists
            XCTAssertEqual(count5, 4)   // manually removed (above)
            XCTAssertEqual(count6, 3)
            XCTAssertEqual(count7, 1)   // automatically removed

            // finally test cleanse(), which is really just a
            // special case of remove(), first without anything
            // being in there to cleanse.
            items.$x.cleanse()
            items.x = 800
            XCTAssertEqual(count1, 3)   // no longer exists
            XCTAssertEqual(count2, 1)   // no longer exists
            XCTAssertEqual(count3, 6)   // no longer exists
            XCTAssertEqual(count4, 6)   // no longer exists
            XCTAssertEqual(count5, 4)   // no longer exists
            XCTAssertEqual(count6, 4)
            XCTAssertEqual(count7, 1)   // no longer exists

            // let's add a couple back in just for fun
            // before removing them all via cleanse()
            var count8 = 0
            let ob8 = items.$x.observe(.did) { _, _ in
                count8 += 1
            }
            var count9 = 0
            let ob9 = items.$x.observe(.did) { _, _ in
                count9 += 1
            }
            items.x = 900
            XCTAssertEqual(count1, 3)   // no longer exists
            XCTAssertEqual(count2, 1)   // no longer exists
            XCTAssertEqual(count3, 6)   // no longer exists
            XCTAssertEqual(count4, 6)   // no longer exists
            XCTAssertEqual(count5, 4)   // no longer exists
            XCTAssertEqual(count6, 5)
            XCTAssertEqual(count7, 1)   // no longer exists
            XCTAssertEqual(count8, 1)
            XCTAssertEqual(count9, 1)

            // now mark all the remaining ones as obsolete
            ob6.isObsolete = true
            ob8.isObsolete = true
            ob9.isObsolete = true
            items.$x.cleanse()
            XCTAssertEqual(count1, 3)   // no longer exists
            XCTAssertEqual(count2, 1)   // no longer exists
            XCTAssertEqual(count3, 6)   // no longer exists
            XCTAssertEqual(count4, 6)   // no longer exists
            XCTAssertEqual(count5, 4)   // no longer exists
            XCTAssertEqual(count6, 5)   // no longer exists
            XCTAssertEqual(count7, 1)   // no longer exists
            XCTAssertEqual(count8, 1)   // no longer exists
            XCTAssertEqual(count9, 1)   // no longer exists

            // finally let's add one back to the now cleansed array
            var count10 = 0
            _ = items.$x.observe(.did) { _, _ in
                count10 += 1
            }
            items.x = 1000
            XCTAssertEqual(count1, 3)   // no longer exists
            XCTAssertEqual(count2, 1)   // no longer exists
            XCTAssertEqual(count3, 6)   // no longer exists
            XCTAssertEqual(count4, 6)   // no longer exists
            XCTAssertEqual(count5, 4)   // no longer exists
            XCTAssertEqual(count6, 5)   // no longer exists
            XCTAssertEqual(count7, 1)   // no longer exists
            XCTAssertEqual(count8, 1)   // no longer exists
            XCTAssertEqual(count9, 1)   // no longer exists
            XCTAssertEqual(count10, 1)

            struct Observe {
                @Observable var val = 1
            }
            
            let x : Observe? = Observe()
            var y : Observe? = Observe()
            
            _ = x!.$val.bind(y!.$val)
            y = nil
        }   // testObsolescence


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
