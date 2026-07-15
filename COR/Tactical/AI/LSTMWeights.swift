import Foundation

/// Named float32 tensors of the LSTM policy — the `PGW1` weight-file contract
/// between the trainer (`Train`, MPSGraph) and in-game inference
/// (`LSTMPolicy`). The architecture is fixed by `spec`: every tensor must be
/// present with exactly the cataloged shape, so a loaded file either drives
/// the network verbatim or fails to load — never a silent shape mismatch.
///
/// Layout conventions (shared with the MPSGraph model):
/// - matmul is `y = x @ W + b`, `W` is `[in, out]`;
/// - conv kernels are HWIO `[kh, kw, in, out]` — flattened row-major that is
///   exactly the `[kh·kw·in, out]` matrix an im2col forward multiplies by;
/// - the LSTM gate order in `lstm.wx/wh/b` (`[·, 4H]`) is **i, f, g, o**.
///
/// File format `PGW1`, all integers and floats little-endian:
/// magic `UInt32` "PGW1", version `UInt32`, record count `UInt32`; per record:
/// name length `UInt16` + UTF-8 name, rank `UInt8`, `UInt32` dims, float32
/// payload.
public struct LSTMWeights: Sendable {
	public static let magic: UInt32 = 0x3157_4750	// "PGW1"
	public static let version: UInt32 = 1

	/// Network dimensions. Changing any of these is a new weight contract:
	/// old files stop loading (shape validation), which is the intent.
	public static let trunk = 48		// conv channels
	public static let hidden = 128		// LSTM hidden/cell size
	public static let proj = 16		// per-tile head channels
	public static let fused = trunk + proj	// per-tile concat [trunk ⊕ proj]
	public static let cond = hidden + trunk	// conditioned fc input [h ⊕ trunk[actor]]

	public private(set) var values: [String: [Float]] = [:]

	public subscript(name: String) -> [Float] { values[name] ?? [] }

	/// The full tensor catalog: name → shape. Order is the file order.
	/// conv2…conv4 run dilated (2, 4, 8) and conv5 dense — same 3×3 shapes;
	/// fc1 takes the full-grid mean pool ⊕ the four quadrant mean pools
	/// (5·trunk) ⊕ globals.
	public static let spec: [(name: String, shape: [Int])] = [
		("conv1.w", [3, 3, SimObservation.planeCount, trunk]), ("conv1.b", [trunk]),
		("conv2.w", [3, 3, trunk, trunk]), ("conv2.b", [trunk]),
		("conv3.w", [3, 3, trunk, trunk]), ("conv3.b", [trunk]),
		("conv4.w", [3, 3, trunk, trunk]), ("conv4.b", [trunk]),
		("conv5.w", [3, 3, trunk, trunk]), ("conv5.b", [trunk]),
		("fc1.w", [5 * trunk + SimObservation.globalCount, hidden]), ("fc1.b", [hidden]),
		("lstm.wx", [hidden, 4 * hidden]),
		("lstm.wh", [hidden, 4 * hidden]),
		("lstm.b", [4 * hidden]),
		("kind.w", [hidden, ActionSpace.kinds]), ("kind.b", [ActionSpace.kinds]),
		("actor.proj.w", [hidden, proj]), ("actor.proj.b", [proj]),
		("actor.conv1.w", [1, 1, fused, proj]), ("actor.conv1.b", [proj]),
		("actor.conv2.w", [1, 1, proj, 1]), ("actor.conv2.b", [1]),
		("target.cond.w", [cond, proj]), ("target.cond.b", [proj]),
		("target.conv1.w", [1, 1, fused, proj]), ("target.conv1.b", [proj]),
		("target.conv2.w", [1, 1, proj, 1]), ("target.conv2.b", [1]),
		("slot.fc1.w", [cond, trunk]), ("slot.fc1.b", [trunk]),
		("slot.fc2.w", [trunk, ActionSpace.slots]), ("slot.fc2.b", [ActionSpace.slots]),
		("value.fc1.w", [hidden, trunk]), ("value.fc1.b", [trunk]),
		("value.fc2.w", [trunk, 1]), ("value.fc2.b", [1]),
	]

	private init() {}

	/// Trainer-side assembly of a checkpoint from tensors read back off the
	/// graph; the caller supplies a spec-complete dictionary.
	public init(values: [String: [Float]]) {
		self.values = values
	}

	// MARK: - IO

	/// Parses and validates a `PGW1` file; `nil` on any malformed byte or any
	/// deviation from `spec` (missing/extra/reshaped tensor).
	public init?(data: Data) {
		var offset = 0

		func read<T: FixedWidthInteger>(_: T.Type) -> T? {
			guard offset + MemoryLayout<T>.size <= data.count else { return nil }
			let v = unsafe data.withUnsafeBytes { raw in
				unsafe raw.loadUnaligned(fromByteOffset: offset, as: T.self)
			}
			offset += MemoryLayout<T>.size
			return T(littleEndian: v)
		}

		guard
			read(UInt32.self) == Self.magic,
			read(UInt32.self) == Self.version,
			let count = read(UInt32.self), count == Self.spec.count
		else { return nil }

		for _ in 0 ..< count {
			guard
				let nameLen = read(UInt16.self),
				offset + Int(nameLen) <= data.count,
				let name = String(data: data.subdata(in: offset ..< offset + Int(nameLen)), encoding: .utf8)
			else { return nil }
			offset += Int(nameLen)

			guard let rank = read(UInt8.self) else { return nil }
			var shape = [Int]()
			for _ in 0 ..< rank {
				guard let dim = read(UInt32.self) else { return nil }
				shape.append(Int(dim))
			}

			let n = shape.reduce(1, *)
			guard
				Self.spec.contains(where: { s in s.name == name && s.shape == shape }),
				values[name] == nil,
				offset + n * 4 <= data.count
			else { return nil }

			values[name] = unsafe [Float](unsafeUninitializedCapacity: n) { buf, filled in
				unsafe data.withUnsafeBytes { raw in
					for i in 0 ..< n {
						unsafe buf[i] = Float(bitPattern: UInt32(littleEndian: unsafe raw.loadUnaligned(
							fromByteOffset: offset + i * 4, as: UInt32.self
						)))
					}
				}
				filled = n
			}
			offset += n * 4
		}
		guard offset == data.count else { return nil }
	}

	public func data() -> Data {
		var out = Data()

		func put<T: FixedWidthInteger>(_ v: T) {
			var le = v.littleEndian
			unsafe withUnsafeBytes(of: &le) { raw in unsafe out.append(contentsOf: raw) }
		}

		put(Self.magic)
		put(Self.version)
		put(UInt32(Self.spec.count))
		for (name, shape) in Self.spec {
			put(UInt16(name.utf8.count))
			out.append(contentsOf: Array(name.utf8))
			put(UInt8(shape.count))
			for dim in shape { put(UInt32(dim)) }
			for v in self[name] { put(v.bitPattern) }
		}
		return out
	}

	// MARK: - Initialization

	/// Seeded random weights (`D20`, a separate instance from any sim's):
	/// uniform ±√(3 / fanIn) per tensor, zero biases except the LSTM forget
	/// gate at +1 — standard so the cell starts out remembering. In COR (not
	/// `Train`) so tests can exercise the full inference path without a
	/// trained file.
	public static func random(seed: UInt64) -> LSTMWeights {
		var rng = D20(seed: seed)

		var w = LSTMWeights()
		for (name, shape) in spec {
			let n = shape.reduce(1, *)
			if name.hasSuffix(".b") {
				w.values[name] = [Float](repeating: 0, count: n)
			} else {
				// HWIO conv fanIn = kh·kw·in; matmul fanIn = in.
				let fanIn = shape.dropLast().reduce(1, *)
				let bound = (3 / Float(fanIn)).squareRoot()
				w.values[name] = (0 ..< n).map { _ in (rng.uniform() * 2 - 1) * bound }
			}
		}
		for i in hidden ..< 2 * hidden { w.values["lstm.b"]![i] = 1 }
		return w
	}
}
