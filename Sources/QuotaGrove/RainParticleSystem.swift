import CoreGraphics
import Foundation

struct RainDrop {
    var position: CGPoint
    var fallSpeed: CGFloat
    var windSpeed: CGFloat
    var length: CGFloat
    var lineWidth: CGFloat
    var opacity: CGFloat
    var depth: CGFloat
    var curvature: CGFloat
    var shimmerPhase: CGFloat
    var shimmerSpeed: CGFloat

    var shimmer: CGFloat {
        0.86 + (sin(shimmerPhase) + 1) * 0.07
    }
}

struct RainSplash {
    var position: CGPoint
    var age: TimeInterval
    var lifetime: TimeInterval
    var size: CGFloat

    var progress: CGFloat { min(1, max(0, CGFloat(age / lifetime))) }
    var opacity: CGFloat { 1 - progress }
}

struct RainParticleSystem {
    private(set) var drops: [RainDrop] = []
    private(set) var splashes: [RainSplash] = []
    private var random = SeededRainRandom(seed: 0x5241_494E_4752_4F56)

    var isEmpty: Bool { drops.isEmpty && splashes.isEmpty }

    mutating func start(in size: CGSize) {
        drops.removeAll(keepingCapacity: true)
        splashes.removeAll(keepingCapacity: true)
        guard size.width > 0, size.height > 0 else { return }

        addDrops(count: 30, depth: 0.08...0.34, in: size)
        addDrops(count: 22, depth: 0.4...0.72, in: size)
        addDrops(count: 12, depth: 0.78...1, in: size)
    }

    mutating func advance(by deltaTime: TimeInterval, in size: CGSize) {
        let delta = min(max(deltaTime, 0), 1.0 / 15.0)
        guard delta > 0, size.width > 0, size.height > 0 else { return }

        for index in drops.indices {
            drops[index].position.x += drops[index].windSpeed * delta
            drops[index].position.y -= drops[index].fallSpeed * delta
            drops[index].shimmerPhase += drops[index].shimmerSpeed * CGFloat(delta)
            if drops[index].position.y < -drops[index].length {
                if drops[index].depth > 0.62,
                   random.unit() < 0.54,
                   drops[index].position.x > 2,
                   drops[index].position.x < size.width - 2 {
                    splashes.append(RainSplash(
                        position: CGPoint(x: drops[index].position.x, y: 5),
                        age: 0,
                        lifetime: random.double(in: 0.26...0.44),
                        size: random.cgFloat(in: 2.8...6.4) * (0.68 + drops[index].depth * 0.42)
                    ))
                }
                respawn(dropAt: index, in: size)
            }
        }

        for index in splashes.indices { splashes[index].age += delta }
        splashes.removeAll { $0.age >= $0.lifetime }
        if splashes.count > 24 { splashes.removeFirst(splashes.count - 24) }
    }

    mutating func removeAll() {
        drops.removeAll(keepingCapacity: true)
        splashes.removeAll(keepingCapacity: true)
    }

    private mutating func addDrops(count: Int, depth: ClosedRange<CGFloat>, in size: CGSize) {
        for _ in 0..<count {
            let selectedDepth = random.cgFloat(in: depth)
            drops.append(makeDrop(depth: selectedDepth, in: size, initial: true))
        }
    }

    private mutating func respawn(dropAt index: Int, in size: CGSize) {
        let depth = drops[index].depth
        drops[index] = makeDrop(depth: depth, in: size, initial: false)
    }

    private mutating func makeDrop(depth: CGFloat, in size: CGSize, initial: Bool) -> RainDrop {
        let speed = 64 + depth * 142 + random.cgFloat(in: -13...18)
        let length = 3.2 + depth * 16.8 + random.cgFloat(in: -1.2...2.2)
        let y = initial
            ? random.cgFloat(in: -length...(size.height + length * 2.4))
            : size.height + random.cgFloat(in: 4...(size.height * 0.72 + 10))
        return RainDrop(
            position: CGPoint(
                x: random.cgFloat(in: -8...(size.width * 1.24)),
                y: y
            ),
            fallSpeed: speed,
            windSpeed: -(22 + depth * 32 + random.cgFloat(in: 0...12)),
            length: max(2.5, length),
            lineWidth: max(0.08, 0.09 + depth * 0.55 + random.cgFloat(in: -0.025...0.055)),
            opacity: min(0.78, 0.14 + depth * 0.52 + random.cgFloat(in: -0.025...0.065)),
            depth: depth,
            curvature: random.cgFloat(in: -0.42...0.42) * depth,
            shimmerPhase: random.cgFloat(in: 0...(2 * .pi)),
            shimmerSpeed: random.cgFloat(in: 2.2...4.8)
        )
    }
}

private struct SeededRainRandom {
    private var state: UInt64

    init(seed: UInt64) { state = seed }

    mutating func next() -> UInt64 {
        state = state &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407
        return state
    }

    mutating func unit() -> Double {
        Double(next() >> 11) / Double(1 << 53)
    }

    mutating func double(in range: ClosedRange<Double>) -> Double {
        range.lowerBound + (range.upperBound - range.lowerBound) * unit()
    }

    mutating func cgFloat(in range: ClosedRange<CGFloat>) -> CGFloat {
        range.lowerBound + (range.upperBound - range.lowerBound) * CGFloat(unit())
    }

}
