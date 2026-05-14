import Foundation

func runWithDeadline(
	_ deadline: TimeInterval,
	_ work: @escaping @Sendable () -> Void
) -> Bool {
	let semaphore = DispatchSemaphore(value: 0)
	DispatchQueue.global(qos: .userInitiated).async {
		work()
		semaphore.signal()
	}
	return semaphore.wait(timeout: .now() + deadline) == .success
}
