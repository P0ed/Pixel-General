import Network

struct Address {
	var host: String
	var port: UInt16
}

extension Address {

	static var defaultPort: UInt16 { 9899 }

	static var `default`: Address {
		Address(host: "localhost", port: defaultPort)
	}

	init?(_ string: String) {
		let parts = string.split(separator: ":")
		if let host = parts.first.map(String.init), !host.isEmpty {
			let port = parts.count > 1 ? UInt16(parts[1]) ?? Self.defaultPort : Self.defaultPort
			self = Address(host: host, port: port)
		} else {
			return nil
		}
	}

	var string: String {
		"\(host):\(port)"
	}

	static var me: Address {
		Address(host: lanAddress, port: defaultPort)
	}
}

private var localhost: String { "127.0.0.1" }

private var lanAddress: String {
	var first: UnsafeMutablePointer<ifaddrs>?
	guard unsafe getifaddrs(&first) == 0 else { return localhost }
	defer { unsafe freeifaddrs(first) }

	var fallback: String?
	var next = unsafe first
	while let current = unsafe next {
		let ifa = unsafe current.pointee
		defer { unsafe next = ifa.ifa_next }

		guard let sa = unsafe ifa.ifa_addr,
			  unsafe sa.pointee.sa_family == UInt8(AF_INET),
			  unsafe ifa.ifa_flags & UInt32(IFF_LOOPBACK) == 0
		else { continue }

		var host = [CChar](repeating: 0, count: Int(NI_MAXHOST))
		guard unsafe getnameinfo(
			sa, socklen_t(sa.pointee.sa_len),
			&host, socklen_t(host.count),
			nil, 0, NI_NUMERICHOST
		) == 0 else { continue }

		let name = String(safeCString: host)
		if unsafe String(cString: ifa.ifa_name) == "en0" { return name }
		if fallback == nil { fallback = name }
	}
	return fallback ?? localhost
}
