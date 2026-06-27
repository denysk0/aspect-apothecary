import Foundation

struct Hex: Hashable, Identifiable {
    let q: Int
    let r: Int

    var id: String { "\(q),\(r)" }

    static let directions = [
        Hex(q: 1, r: 0), Hex(q: 1, r: -1), Hex(q: 0, r: -1),
        Hex(q: -1, r: 0), Hex(q: -1, r: 1), Hex(q: 0, r: 1)
    ]

    func neighbors() -> [Hex] {
        Hex.directions.map { Hex(q: q + $0.q, r: r + $0.r) }
    }

    func distance(to other: Hex) -> Int {
        (abs(q - other.q) + abs(q + r - other.q - other.r) + abs(r - other.r)) / 2
    }

    func line(to other: Hex) -> [Hex] {
        let steps = distance(to: other)
        guard steps > 0 else { return [self] }

        let (ax, az) = (Double(q), Double(r))
        let ay = -ax - az
        let (bx, bz) = (Double(other.q), Double(other.r))
        let by = -bx - bz

        var result: [Hex] = []
        for index in 0...steps {
            let t = Double(index) / Double(steps)
            let x = ax + (bx - ax) * t
            let y = ay + (by - ay) * t
            let z = az + (bz - az) * t
            result.append(Hex.roundedCube(x: x, y: y, z: z))
        }
        return result
    }

    private static func roundedCube(x: Double, y: Double, z: Double) -> Hex {
        var rx = (x).rounded()
        var ry = (y).rounded()
        var rz = (z).rounded()

        let dx = abs(rx - x)
        let dy = abs(ry - y)
        let dz = abs(rz - z)

        if dx > dy && dx > dz {
            rx = -ry - rz
        } else if dy > dz {
            ry = -rx - rz
        } else {
            rz = -rx - ry
        }

        return Hex(q: Int(rx), r: Int(rz))
    }

    static func board(radius: Int) -> [Hex] {
        var cells: [Hex] = []
        for q in -radius...radius {
            let lower = max(-radius, -q - radius)
            let upper = min(radius, -q + radius)
            for r in lower...upper {
                cells.append(Hex(q: q, r: r))
            }
        }
        return cells
    }
}
