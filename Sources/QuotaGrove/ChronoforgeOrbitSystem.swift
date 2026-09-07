import CoreGraphics
import Foundation

enum ChronoforgeOrbitKind: CaseIterable, Equatable {
    case verdigris
    case brass
    case cinnabar
    case silver

    static func forTheme(_ theme: QuotaTheme) -> ChronoforgeOrbitKind {
        switch theme {
        case .forest: return .verdigris
        case .autumn: return .brass
        case .apocalypse: return .cinnabar
        case .wasteland: return .silver
        }
    }
}

struct ChronoforgeOrbit {
    let kind: ChronoforgeOrbitKind
    var position: CGPoint
    var velocity: CGVector
    var driftPhase: CGFloat
    let driftSpeed: CGFloat
    let driftAmplitude: CGFloat
    var rotation: CGFloat
    let angularVelocity: CGFloat
    var ringPhase: CGFloat
    let ringVelocity: CGFloat
    var satellitePhase: CGFloat
    let satelliteVelocity: CGFloat
    var pulsePhase: CGFloat
    let pulseSpeed: CGFloat
    let size: CGFloat
    let depth: CGFloat
    let ringTilt: CGFloat
    var age: TimeInterval
    let lifetime: TimeInterval

    var isVisible: Bool { age >= 0 && age < lifetime }

    var lifeProgress: CGFloat {
        guard lifetime > 0 else { return 1 }
        return min(1, max(0, CGFloat(age / lifetime)))
    }

    var opacity: CGFloat {
        guard isVisible else { return 0 }
        let fadeIn = min(1, age / 0.26)
        let fadeOut = min(1, (lifetime - age) / 0.72)
        let distanceFade = 1 - pow(max(0, lifeProgress - 0.68) / 0.32, 1.4) * 0.52
        return CGFloat(min(fadeIn, fadeOut)) * distanceFade
    }

    var renderedPosition: CGPoint {
        CGPoint(
            x: position.x + cos(driftPhase * 0.72) * driftAmplitude,
            y: position.y + sin(driftPhase) * driftAmplitude * 0.72
        )
    }

    var pulse: CGFloat { 0.82 + (sin(pulsePhase) + 1) * 0.09 }
    var distanceScale: CGFloat { 1 - max(0, lifeProgress - 0.76) / 0.24 * 0.2 }
}

struct ChronoforgeOrbitSystem {
    static let ambientOrbitCount = 4
    static let orbitsPerPercentagePoint = 3
    static let maximumAnimatedDrop = 4
    static let manualBurstWaveCounts = [1, 3, 7, 4, 2]
    static let manualBurstOrbitCount = manualBurstWaveCounts.reduce(0, +)

    private(set) var orbits: [ChronoforgeOrbit] = []
    private var random = SeededChronoforgeRandom(seed: 0x4348_524F_4E4F_4647)

    var isEmpty: Bool { orbits.isEmpty }
    var visibleCount: Int { orbits.lazy.filter(\.isVisible).count }

    mutating func emitAmbient(for theme: QuotaTheme, in size: CGSize) {
        appendOrbits(
            count: Self.ambientOrbitCount,
            theme: theme,
            size: size,
            baseDelay: 0,
            delayStep: 0.2,
            burst: false
        )
    }

    mutating func emit(forPercentageDrop drop: Int, theme: QuotaTheme, in size: CGSize) {
        let steps = min(max(0, drop), Self.maximumAnimatedDrop)
        guard steps > 0 else { return }
        appendOrbits(
            count: steps * Self.orbitsPerPercentagePoint,
            theme: theme,
            size: size,
            baseDelay: 0,
            delayStep: 0.13,
            burst: false
        )
    }

    mutating func emitManualBurst(for theme: QuotaTheme, in size: CGSize) {
        guard size.width > 0, size.height > 0 else { return }
        orbits.removeAll(keepingCapacity: true)
        let waveDelays: [Double] = [0, 0.28, 0.6, 0.94, 1.3]
        for (wave, count) in Self.manualBurstWaveCounts.enumerated() {
            appendOrbits(
                count: count,
                theme: theme,
                size: size,
                baseDelay: waveDelays[wave],
                delayStep: 0.065,
                burst: true
            )
        }
    }

    mutating func advance(by deltaTime: TimeInterval) {
        let delta = min(max(deltaTime, 0), 1.0 / 15.0)
        guard delta > 0 else { return }
        let step = CGFloat(delta)

        for index in orbits.indices {
            orbits[index].age += delta
            guard orbits[index].age >= 0 else { continue }
            orbits[index].driftPhase += orbits[index].driftSpeed * step
            orbits[index].ringPhase += orbits[index].ringVelocity * step
            orbits[index].satellitePhase += orbits[index].satelliteVelocity * step
            orbits[index].pulsePhase += orbits[index].pulseSpeed * step
            orbits[index].rotation += orbits[index].angularVelocity * step

            let current = sin(orbits[index].driftPhase * 0.86 + orbits[index].depth * .pi)
            switch orbits[index].kind {
            case .verdigris:
                orbits[index].velocity.dy += current * 0.3 * step
            case .brass:
                orbits[index].velocity.dy += current * 0.22 * step
                orbits[index].velocity.dx *= 0.9995
            case .cinnabar:
                orbits[index].velocity.dy += current * 0.72 * step
                orbits[index].velocity.dx += cos(orbits[index].driftPhase * 1.41) * 0.24 * step
            case .silver:
                orbits[index].velocity.dy += current * 0.1 * step
                orbits[index].velocity.dx *= 0.9988
            }

            orbits[index].position.x += orbits[index].velocity.dx * step
            orbits[index].position.y += orbits[index].velocity.dy * step
        }

        orbits.removeAll { orbit in
            orbit.age >= orbit.lifetime
                || orbit.position.x < -orbit.size * 5
                || orbit.position.y < -orbit.size * 5
                || orbit.position.y > 270 + orbit.size * 5
        }
    }

    mutating func removeAll() {
        orbits.removeAll(keepingCapacity: true)
    }

    private mutating func appendOrbits(
        count: Int,
        theme: QuotaTheme,
        size: CGSize,
        baseDelay: Double,
        delayStep: Double,
        burst: Bool
    ) {
        guard count > 0, size.width > 0, size.height > 0 else { return }
        let kind = ChronoforgeOrbitKind.forTheme(theme)

        for index in 0..<count {
            let delay = baseDelay + Double(index) * delayStep + random.double(in: 0...0.12)
            let depth = random.cgFloat(in: 0.14...0.98)
            let configuration = initialConfiguration(kind: kind, size: size, burst: burst)
            orbits.append(ChronoforgeOrbit(
                kind: kind,
                position: configuration.position,
                velocity: configuration.velocity,
                driftPhase: random.cgFloat(in: 0...(2 * .pi)),
                driftSpeed: random.cgFloat(in: configuration.driftSpeedRange),
                driftAmplitude: random.cgFloat(in: 1.4...(burst ? 5.2 : 3.8)) * (0.74 + depth * 0.34),
                rotation: random.cgFloat(in: -18...18),
                angularVelocity: random.cgFloat(in: configuration.angularVelocityRange),
                ringPhase: random.cgFloat(in: 0...(2 * .pi)),
                ringVelocity: random.cgFloat(in: configuration.ringVelocityRange),
                satellitePhase: random.cgFloat(in: 0...(2 * .pi)),
                satelliteVelocity: random.cgFloat(in: configuration.satelliteVelocityRange),
                pulsePhase: random.cgFloat(in: 0...(2 * .pi)),
                pulseSpeed: random.cgFloat(in: 1.6...3.2),
                size: random.cgFloat(in: configuration.sizeRange) * (0.72 + depth * 0.42),
                depth: depth,
                ringTilt: random.cgFloat(in: 0.42...0.72),
                age: -delay,
                lifetime: random.double(in: configuration.lifetimeRange)
            ))
        }
    }

    private mutating func initialConfiguration(
        kind: ChronoforgeOrbitKind,
        size: CGSize,
        burst: Bool
    ) -> (
        position: CGPoint,
        velocity: CGVector,
        sizeRange: ClosedRange<CGFloat>,
        lifetimeRange: ClosedRange<Double>,
        driftSpeedRange: ClosedRange<CGFloat>,
        angularVelocityRange: ClosedRange<CGFloat>,
        ringVelocityRange: ClosedRange<CGFloat>,
        satelliteVelocityRange: ClosedRange<CGFloat>
    ) {
        let intensity: CGFloat = burst ? 1.12 : 1
        switch kind {
        case .verdigris:
            return (
                CGPoint(x: random.cgFloat(in: size.width * 0.62...size.width * 1.12), y: random.cgFloat(in: size.height * 0.34...size.height * 0.94)),
                CGVector(dx: -random.cgFloat(in: 8.8...15.5) * intensity, dy: -random.cgFloat(in: 0.6...3.8)),
                4.8...9.2,
                burst ? 2.8...3.7 : 4.7...6.2,
                0.9...1.5,
                -5.4...5.4,
                2.8...5.6,
                3.8...6.4
            )
        case .brass:
            return (
                CGPoint(x: random.cgFloat(in: size.width * 0.64...size.width * 1.1), y: random.cgFloat(in: size.height * 0.3...size.height * 0.92)),
                CGVector(dx: -random.cgFloat(in: 7.2...12.8) * intensity, dy: -random.cgFloat(in: 0.5...3.2)),
                4.8...8.8,
                burst ? 3.0...3.9 : 5.0...6.6,
                0.72...1.22,
                -3.8...3.8,
                2.0...4.2,
                2.8...5.0
            )
        case .cinnabar:
            return (
                CGPoint(x: random.cgFloat(in: size.width * 0.58...size.width * 1.14), y: random.cgFloat(in: size.height * 0.28...size.height * 0.98)),
                CGVector(dx: -random.cgFloat(in: 10.8...18.4) * intensity, dy: -random.cgFloat(in: 0.4...4.8)),
                5.0...9.5,
                burst ? 2.5...3.35 : 4.1...5.7,
                1.1...1.8,
                -8.0...8.0,
                4.0...7.8,
                5.2...8.6
            )
        case .silver:
            return (
                CGPoint(x: random.cgFloat(in: size.width * 0.66...size.width * 1.08), y: random.cgFloat(in: size.height * 0.32...size.height * 0.9)),
                CGVector(dx: -random.cgFloat(in: 5.4...9.4) * intensity, dy: -random.cgFloat(in: 0.3...2.2)),
                4.6...8.4,
                burst ? 3.2...4.1 : 5.6...7.1,
                0.54...0.92,
                -2.2...2.2,
                1.2...2.8,
                1.8...3.6
            )
        }
    }
}

private struct SeededChronoforgeRandom {
    private var state: UInt64

    init(seed: UInt64) {
        state = seed
    }

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
