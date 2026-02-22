import CoreVideo
import Foundation

/// Thread-safe LRU frame buffer cache for the precision-mode decode path.
///
/// Stores decoded CVPixelBuffers keyed by frame index. Keeps up to `capacity`
/// entries; when full, the oldest entry (FIFO) is evicted. Call `evict(beyond:of:)`
/// after each step to trim entries that have scrolled out of the look-ahead window.
final class FrameCache: @unchecked Sendable {

    private struct Entry {
        let frameIndex: Int
        let buffer: CVPixelBuffer
    }

    private var entries: [Entry] = []
    private let capacity: Int
    private let lock = NSLock()

    init(capacity: Int = 8) {
        self.capacity = capacity
    }

    /// Returns the cached buffer for `frameIndex`, or nil on a miss.
    func lookup(_ frameIndex: Int) -> CVPixelBuffer? {
        lock.withLock {
            entries.first { $0.frameIndex == frameIndex }?.buffer
        }
    }

    /// Inserts (or replaces) the buffer for `frameIndex`.
    /// Evicts the oldest entry if the cache is already at capacity.
    func insert(_ buffer: CVPixelBuffer, forFrame frameIndex: Int) {
        lock.withLock {
            entries.removeAll { $0.frameIndex == frameIndex }
            if entries.count >= capacity { entries.removeFirst() }
            entries.append(Entry(frameIndex: frameIndex, buffer: buffer))
        }
    }

    /// Removes all entries whose frame index is more than `window` frames
    /// away from `center`, keeping the cache focused around the playhead.
    func evict(beyond window: Int, of center: Int) {
        lock.withLock {
            entries.removeAll { abs($0.frameIndex - center) > window }
        }
    }

    /// Removes all cached entries (call on video open / player reset).
    func clear() {
        lock.withLock { entries.removeAll() }
    }
}
