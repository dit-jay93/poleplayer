import Foundation
import simd

public enum LUTDimension: Equatable {
    case lut3D(size: Int)
    case lut1D(size: Int)
}

public struct LUTCube {
    public let size: Int
    public let dimension: LUTDimension
    public let domainMin: SIMD3<Float>
    public let domainMax: SIMD3<Float>
    public let values: [SIMD3<Float>]

    public init(size: Int, dimension: LUTDimension, domainMin: SIMD3<Float>, domainMax: SIMD3<Float>, values: [SIMD3<Float>]) {
        self.size = size
        self.dimension = dimension
        self.domainMin = domainMin
        self.domainMax = domainMax
        self.values = values
    }
}

public enum LUTCubeError: Error, LocalizedError {
    case missingSize
    case invalidLine(String)
    case invalidDataCount(expected: Int, actual: Int)

    public var errorDescription: String? {
        switch self {
        case .missingSize:
            return "LUT_3D_SIZE or LUT_1D_SIZE not found."
        case .invalidLine(let line):
            return "Invalid LUT line: \(line)"
        case .invalidDataCount(let expected, let actual):
            return "Expected \(expected) LUT entries, found \(actual)."
        }
    }
}

public extension LUTCube {
    static func load(url: URL) throws -> LUTCube {
        let contents = try String(contentsOf: url, encoding: .utf8)
        return try parse(contents)
    }

    static func parse(_ contents: String) throws -> LUTCube {
        var size: Int? = nil
        var dimension: LUTDimension? = nil
        var domainMin = SIMD3<Float>(0, 0, 0)
        var domainMax = SIMD3<Float>(1, 1, 1)
        var values: [SIMD3<Float>] = []

        let lines = contents.components(separatedBy: .newlines)
        for rawLine in lines {
            let line = rawLine.trimmingCharacters(in: .whitespacesAndNewlines)
            if line.isEmpty || line.hasPrefix("#") {
                continue
            }
            if line.uppercased().hasPrefix("TITLE") {
                continue
            }
            if line.uppercased().hasPrefix("LUT_3D_SIZE") {
                let parts = line.split(separator: " ")
                if let last = parts.last, let parsed = Int(last) {
                    size = parsed
                    dimension = .lut3D(size: parsed)
                    continue
                }
                throw LUTCubeError.invalidLine(line)
            }
            if line.uppercased().hasPrefix("LUT_1D_SIZE") {
                let parts = line.split(separator: " ")
                if let last = parts.last, let parsed = Int(last) {
                    size = parsed
                    dimension = .lut1D(size: parsed)
                    continue
                }
                throw LUTCubeError.invalidLine(line)
            }
            if line.uppercased().hasPrefix("DOMAIN_MIN") {
                let parts = line.split(separator: " ")
                guard let vals = parseFloats(parts, count: 3, dropFirst: 1) else {
                    throw LUTCubeError.invalidLine(line)
                }
                domainMin = SIMD3<Float>(vals[0], vals[1], vals[2])
                continue
            }
            if line.uppercased().hasPrefix("DOMAIN_MAX") {
                let parts = line.split(separator: " ")
                guard let vals = parseFloats(parts, count: 3, dropFirst: 1) else {
                    throw LUTCubeError.invalidLine(line)
                }
                domainMax = SIMD3<Float>(vals[0], vals[1], vals[2])
                continue
            }

            let parts = line.split(separator: " ")
            // 알 수 없는 키워드 줄(첫 토큰이 알파벳으로 시작) → 조용히 건너뜀
            if let first = parts.first, first.first?.isLetter == true {
                continue
            }
            guard let valuesLine = parseFloats(parts, count: 3, dropFirst: 0) else {
                throw LUTCubeError.invalidLine(line)
            }
            values.append(SIMD3<Float>(valuesLine[0], valuesLine[1], valuesLine[2]))
        }

        guard let size, let dimension else {
            throw LUTCubeError.missingSize
        }

        let expected: Int
        switch dimension {
        case .lut3D(let s): expected = s * s * s
        case .lut1D(let s): expected = s
        }

        if values.count != expected {
            throw LUTCubeError.invalidDataCount(expected: expected, actual: values.count)
        }

        return LUTCube(size: size, dimension: dimension, domainMin: domainMin, domainMax: domainMax, values: values)
    }
}

private func parseFloats(_ parts: [Substring], count: Int, dropFirst: Int) -> [Float]? {
    guard parts.count >= dropFirst + count else { return nil }
    let slice = parts.dropFirst(dropFirst).prefix(count)
    var output: [Float] = []
    output.reserveCapacity(count)
    for part in slice {
        guard let value = Float(part) else { return nil }
        output.append(value)
    }
    return output
}
