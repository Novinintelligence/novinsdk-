// © 2025 Oliver Herbert. Proprietary and Confidential. All rights reserved.
// Use, copying, and distribution of this software are permitted only in accordance
// with a separate written license agreement from the owner.
//
//  SplitMix64.swift
//  intelligence
//
//  Seeded pseudo-random number generator for deterministic variation
//

import Foundation

/// Fast, high-quality 64-bit PRNG for deterministic randomness
struct SplitMix64 {
    private var state: UInt64
    
    init(seed: UInt64) {
        self.state = seed
    }
    
    mutating func next() -> UInt64 {
        state &+= 0x9e3779b97f4a7c15
        var z = state
        z = (z ^ (z &>> 30)) &* 0xbf58476d1ce4e5b9
        z = (z ^ (z &>> 27)) &* 0x94d049bb133111eb
        return z ^ (z &>> 31)
    }
}
