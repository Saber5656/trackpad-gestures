import Testing
import Foundation
@testable import TrackpadCore

struct RegressionTests {
    let caps:Set<Capability>=[.multiTouch,.contactIdentity,.normalizedCoordinates]
    func points(_ phase:ContactPhase,_ x:Double=0.2,_ y:Double=0.3)->[Contact] { (0..<3).map { Contact(id:"\($0)",x:x+Double($0)*0.06,y:y,phase:phase) } }
    func frame(_ t:Double,_ contacts:[Contact],capabilities:Set<Capability>?=nil,scope:String?=nil,mods:Set<Modifier>=[],interference:FrameInterference?=nil)->NormalizedFrame {
        .init(timestamp:t,sessionID:"s",transport:.simulation,capabilities:capabilities ?? caps,contacts:contacts,appScope:scope,modifiers:mods,interference:interference)
    }
    func gesture(_ id:String="tap",kind:GestureKind = .tap,priority:Int=0,cooldown:Double=0.5)->GestureDefinition {
        .init(id:id,name:id,kind:kind,actionID:"beep",fingerCount:3,movementThreshold:0.1,maxDuration:2,priority:priority,cooldown:cooldown)
    }
    @Test func missingContactCapabilitiesNeverRecognizes() {
        let engine=GestureEngine(definitions:[gesture()])
        _=engine.process(frame(0,points(.began),capabilities:[]))
        #expect(engine.process(frame(0.1,points(.ended),capabilities:[])).events.isEmpty)
    }
    @Test func oneFingerDefinitionsRejectedByCodecAndEngine() {
        let g=GestureDefinition(id:"one",name:"one",kind:.tap,actionID:"beep",fingerCount:1)
        #expect(throws:(any Error).self) { try ProfileCodec.encode(.init(profiles:[.init(id:"p",name:"p",gestures:[g],actions:[.init(id:"beep",kind:.systemAction(.beep))])])) }
        let engine=GestureEngine(definitions:[g])
        _=engine.process(frame(0,[points(.began)[0]]))
        #expect(engine.process(frame(0.1,[points(.ended)[0]])).events.isEmpty)
    }
    @Test func staggeredLandingAndLiftingCompletesExactlyOnce() {
        let engine=GestureEngine(definitions:[gesture()])
        _=engine.process(frame(0,[points(.began)[0]]))
        _=engine.process(frame(0.03,[points(.stationary)[0],points(.began)[1],points(.began)[2]]))
        #expect(engine.process(frame(0.1,[points(.ended)[0],points(.stationary)[1],points(.stationary)[2]])).events.isEmpty)
        #expect(engine.process(frame(0.15,[points(.ended)[1],points(.ended)[2]])).events.count == 1)
        #expect(engine.process(frame(0.16,[])).events.isEmpty)
    }
    @Test func repeatedBeganAndMissingTerminalCancel() {
        for bad in [points(.began),Array(points(.moved).dropLast())] {
            let engine=GestureEngine(definitions:[gesture()]); _=engine.process(frame(0,points(.began)))
            #expect(engine.process(frame(0.1,bad)).events.isEmpty)
            #expect(engine.process(frame(0.2,points(.ended))).events.isEmpty)
        }
    }
    @Test func idleGapDoesNotLoseFirstGestureAndCooldownPersists() {
        let engine=GestureEngine(definitions:[gesture(cooldown:1)])
        _=engine.process(frame(0,[])); _=engine.process(frame(10,points(.began)))
        #expect(engine.process(frame(10.1,points(.ended))).events.count == 1)
        _=engine.process(frame(10.2,points(.began)))
        #expect(engine.process(frame(10.3,points(.ended))).events.isEmpty)
        _=engine.process(frame(10.4,[])); _=engine.process(frame(11.2,points(.began)))
        #expect(engine.process(frame(11.3,points(.ended))).events.count == 1)
    }
    @Test func incoherentMotionCannotTapOrSwipe() {
        let engine=GestureEngine(definitions:[gesture(),gesture("swipe",kind:.swipe(.right))])
        _=engine.process(frame(0,points(.began)))
        let spread=[Contact(id:"0",x:0.05,y:0.3,phase:.moved),Contact(id:"1",x:0.26,y:0.3,phase:.moved),Contact(id:"2",x:0.47,y:0.3,phase:.moved)]
        _=engine.process(frame(0.1,spread))
        #expect(engine.process(frame(0.2,points(.ended))).events.isEmpty)
    }
    @Test func outAndBackMovementDoesNotBecomeTap() {
        let engine=GestureEngine(definitions:[gesture()]); _=engine.process(frame(0,points(.began)))
        _=engine.process(frame(0.1,points(.moved,0.5)))
        #expect(engine.process(frame(0.2,points(.ended))).events.isEmpty)
    }
    @Test func failedHighPriorityTapDoesNotHideSwipeCandidate() {
        let engine=GestureEngine(definitions:[gesture(priority:99),gesture("swipe",kind:.swipe(.right))])
        _=engine.process(frame(0,points(.began)))
        #expect(engine.process(frame(0.2,points(.ended,0.5))).events.first?.gestureID == "swipe")
    }
    @Test func scopeModifierCapabilityChangesAndNativeInputCancel() {
        let changes=[frame(0.1,points(.moved),scope:"com.example.Other"),frame(0.1,points(.moved),mods:[.shift]),frame(0.1,points(.moved),capabilities:caps.union([.pressure])),frame(0.1,points(.moved),interference:.scroll),frame(0.1,points(.moved),interference:.pinch),frame(0.1,points(.moved),interference:.rotate)]
        for changed in changes {
            let engine=GestureEngine(definitions:[gesture()]); _=engine.process(frame(0,points(.began)))
            _=engine.process(changed); #expect(engine.process(frame(0.2,points(.ended))).events.isEmpty)
        }
    }
    @Test func malformedOutOfOrderAndGapRecoverAtEmptyBoundary() {
        for bad in [frame(-1,points(.moved)),frame(0,points(.moved)),frame(2,points(.moved)),frame(0.1,[Contact(id:"0",x:.nan,y:0.3,phase:.moved)])] {
            let engine=GestureEngine(definitions:[gesture()]); _=engine.process(frame(0,points(.began)))
            _=engine.process(bad); #expect(engine.process(frame(2.1,points(.ended))).events.isEmpty)
            _=engine.process(frame(3,[])); _=engine.process(frame(3.1,points(.began)))
            #expect(engine.process(frame(3.2,points(.ended))).events.count == 1)
        }
    }
    @Test func seededFuzzIsDeterministicBoundedAndNeverDuplicatesWinner() {
        var seed:UInt64=0xfeedbeef
        for _ in 0..<1000 {
            let a=GestureEngine(definitions:[gesture(),gesture("b")]); let b=GestureEngine(definitions:[gesture("b"),gesture()])
            var emitted=0
            for i in 0..<12 {
                seed = seed &* 6364136223846793005 &+ 1
                let phase:ContactPhase=[.began,.moved,.stationary,.ended,.cancelled][Int(seed%5)]
                let x=Double((seed>>8)%140)/100
                let f=frame(Double(i)/100,points(phase,x))
                let left=a.process(f),right=b.process(f)
                #expect(left == right); #expect(left.events.count <= 1); emitted += left.events.count
            }
            #expect(emitted <= 1)
        }
    }
    @Test func configRejectsBadBundleScopeAndUnsupportedShapes() {
        let action=ActionDefinition(id:"a",kind:.launch(bundleID:"com..bad/evil"))
        #expect(throws:(any Error).self) { try ProfileCodec.encode(.init(profiles:[.init(id:"p",name:"p",actions:[action])])) }
        let g=GestureDefinition(id:"g",name:"g",kind:.tap,actionID:"a",fingerCount:3,applicationScope:"not a bundle id")
        #expect(throws:(any Error).self) { try ProfileCodec.encode(.init(profiles:[.init(id:"p",name:"p",gestures:[g],actions:[.init(id:"a",kind:.systemAction(.beep))])])) }
    }
}

struct VocabularyTests {
    @Test func twoThroughFiveFingerTapHoldAndEveryDirection() {
        let h=RegressionTests()
        let kinds:[GestureKind]=[.tap,.hold,.swipe(.up),.swipe(.down),.swipe(.left),.swipe(.right)]
        for n in 2...5 { for kind in kinds {
            let g=GestureDefinition(id:"g",name:"g",kind:kind,actionID:"a",fingerCount:n,movementThreshold:0.1,cooldown:0)
            let engine=GestureEngine(definitions:[g])
            let start=(0..<n).map{Contact(id:String($0),x:0.4+Double($0)*0.04,y:0.4,phase:.began)}
            var dx=0.0,dy=0.0
            if case .swipe(let direction)=kind { switch direction { case .up:dy=0.2;case .down:dy = -0.2;case .left:dx = -0.2;case .right:dx=0.2 } }
            let end=start.map{Contact(id:$0.id,x:$0.x+dx,y:$0.y+dy,phase:.ended)}
            _=engine.process(h.frame(0,start))
            #expect(engine.process(h.frame(kind == .hold ? 0.7:0.2,end)).events.count == 1)
        } }
    }
    @Test func rejectedFutureGapDoesNotPoisonValidClockForever() {
        let h=RegressionTests(),engine=GestureEngine(definitions:[RegressionTests().gesture()])
        _=engine.process(h.frame(0,h.points(.began)))
        _=engine.process(h.frame(1e100,h.points(.moved)))
        _=engine.process(h.frame(0.2,[]))
        _=engine.process(h.frame(0.3,h.points(.began)))
        #expect(engine.process(h.frame(0.4,h.points(.ended))).events.count == 1)
    }
}

struct IdleInterferenceTests {
    @Test func nativeOnlyIdleInputDoesNotConsumeNextSequence() {
        let h=RegressionTests()
        for source in 0...1 {
            let engine=GestureEngine(definitions:[h.gesture()])
            if source==0 { _=engine.process(h.frame(0,[],interference:.pinch)) } else { engine.cancel() }
            _=engine.process(h.frame(0.1,h.points(.began)))
            #expect(engine.process(h.frame(0.2,h.points(.ended))).events.count==1)
        }
    }
}
