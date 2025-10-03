import Foundation

/// Token bucket rate limiter for enterprise DoS protection
@available(iOS 15.0, macOS 12.0, *)
public final class RateLimiter: @unchecked Sendable {
    
    private let queue = DispatchQueue(label: "com.novinintelligence.ratelimiter")
    private var tokens: Double
    private let maxTokens: Double
    private let refillRate: Double  // tokens per second
    private var lastRefill: Date
    
    /// Initialize rate limiter
    /// - Parameters:
    ///   - maxTokens: Maximum tokens (burst capacity)
    ///   - refillRate: Tokens added per second (sustained rate)
    public init(maxTokens: Double = 100, refillRate: Double = 100) {
        self.maxTokens = maxTokens
        self.refillRate = refillRate
        self.tokens = maxTokens
        self.lastRefill = Date()
    }
    
    /// Check if request is allowed
    /// - Parameter cost: Token cost (default 1)
    /// - Returns: True if allowed, false if rate limited
    public func allow(cost: Double = 1.0) -> Bool {
        return queue.sync {
            // Refill tokens based on time passed
            let now = Date()
            let elapsed = now.timeIntervalSince(lastRefill)
            let newTokens = elapsed * refillRate
            tokens = min(maxTokens, tokens + newTokens)
            lastRefill = now
            
            // Check if we have enough tokens
            if tokens >= cost {
                tokens -= cost
                return true
            } else {
                return false
            }
        }
    }
    
    /// Reset rate limiter (for testing)
    public func reset() {
        queue.sync {
            tokens = maxTokens
            lastRefill = Date()
        }
    }
    
    /// Get current token count (for monitoring)
    public func getCurrentTokens() -> Double {
        return queue.sync { tokens }
    }
}




