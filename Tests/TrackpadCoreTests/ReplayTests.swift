import Foundation
import Testing
@testable import TrackpadCore

struct ReplayTests {
    struct Fixture:Decodable { let provenance:String; let definitions:[GestureDefinition]; let frames:[NormalizedFrame]; let expectedIDs:[String] }
    @Test func replayAllGoldenFixturesFromDisk() throws {
        for name in ["recognized","rejected","cancelled","ambiguous"] {
            let url=try #require(Bundle.module.url(forResource:name,withExtension:"json",subdirectory:"Fixtures"))
            let fixture=try JSONDecoder().decode(Fixture.self,from:Data(contentsOf:url))
            #expect(fixture.provenance.hasPrefix("synthetic"))
            let first=GestureEngine(definitions:fixture.definitions),second=GestureEngine(definitions:fixture.definitions.reversed())
            let results=fixture.frames.map { frame in let a=first.process(frame),b=second.process(frame); #expect(a==b); return a }
            #expect(results.flatMap(\.events).map(\.gestureID) == fixture.expectedIDs)
        }
    }
    @Test func zoneAndThresholdBoundariesAreExplicit() {
        #expect(GestureOrdering.zoneContains(.top,x:0.5,y:0.8))
        #expect(!GestureOrdering.zoneContains(.top,x:0.5,y:0.799))
        #expect(GestureOrdering.zoneContains(.bottomLeft,x:0.2,y:0.2))
        let helpers=RegressionTests()
        for (move,expected) in [(0.099,true),(0.1,true),(0.101,false)] {
            let engine=GestureEngine(definitions:[helpers.gesture(cooldown:0)])
            _=engine.process(helpers.frame(0,helpers.points(.began)))
            #expect((!engine.process(helpers.frame(0.2,helpers.points(.ended,0.2+move))).events.isEmpty) == expected)
        }
    }
    @Test func scopeCapabilityAndPriorityOrderIsSharedWithConflictUI() {
        let h=RegressionTests()
        let plain=h.gesture("plain",priority:100)
        let scoped=GestureDefinition(id:"scoped",name:"scoped",kind:.tap,actionID:"a",fingerCount:3,applicationScope:"com.example.Editor",priority:-100)
        #expect(GestureOrdering.precedes(scoped,plain))
        let capable=GestureDefinition(id:"specific",name:"specific",kind:.tap,actionID:"a",fingerCount:3,requiredCapabilities:[.pressure])
        #expect(GestureOrdering.precedes(capable,plain))
        #expect(GestureOrdering.potentiallyOverlaps(plain,scoped))
        let hold=GestureDefinition(id:"hold",name:"hold",kind:.hold,actionID:"a",fingerCount:3,minDuration:0,maxDuration:1)
        #expect(GestureOrdering.potentiallyOverlaps(plain,hold))
        let other=GestureDefinition(id:"other",name:"other",kind:.tap,actionID:"a",fingerCount:3,modifiers:[.shift])
        #expect(!GestureOrdering.potentiallyOverlaps(plain,other))
    }
    @Test func syntheticPerformanceSample() {
        let h=RegressionTests(),engine=GestureEngine(definitions:[RegressionTests().gesture(cooldown:0)])
        var durations:[Double]=[]; var fired=0
        for i in 0..<3000 {
            let start=ProcessInfo.processInfo.systemUptime
            _=engine.process(h.frame(Double(i),h.points(.began)))
            fired += engine.process(h.frame(Double(i)+0.2,h.points(.ended))).events.count
            durations.append((ProcessInfo.processInfo.systemUptime-start)*1_000_000)
        }
        #expect(fired==3000)
        durations.sort()
        print("Synthetic 2-frame sequence, 3000 iterations: p50=\(durations[1500]) us p95=\(durations[2850]) us max=\(durations.last!) us; not hardware latency")
    }
}
