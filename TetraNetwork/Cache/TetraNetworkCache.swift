//
//  TetraNetworkCache.swift
//  TetraNetwork
//
//  Created by Son Nguyen on 3/1/22.
//

import Foundation
import Combine

internal class TetraNetworkCache {
    
    private var cache: [AnyHashable: TetraNetworkCacheData] = [:]
    private let maxCapacity: Int
    
    
    init(maxCapacity: Int) {
        self.maxCapacity = maxCapacity
    }
    
    func addCache(for hash: AnyHashable,
                  data: Data,
                  duration: TimeInterval,
                  priority: TetraNetworkCachePriority) {
        clearInvalidCache()
        
        let availableVolume = trimCache(toFit: data.count)
        guard data.count <= maxCapacity - availableVolume else {
            return
        }
        
        let data = TetraNetworkCacheData(data: data,
                                         expirationTime: Date().addingTimeInterval(duration),
                                         priority: priority)
        
        cache[hash] = data
    }
    
    func getCache(for hash: AnyHashable) -> Data? {
        clearInvalidCache()
        
        guard let cacheData = cache[hash], cacheData.isValid else {
            return nil
        }
        return cacheData.data
    }
    
    private func trimCache(toFit newVolume: Int) -> Int {
        var volume = cache.values.reduce(0) { partialResult, data in
            partialResult + data.data.count
        }
        volume += newVolume
        
        if volume > maxCapacity {
            var sortedKeys = cache.keys.sorted { [weak self] leftKey, rightKey in
                guard let self = self,
                      let left = self.cache[leftKey],
                      let right = self.cache[rightKey] else {
                          return true
                      }
                
                return left.priority.rawValue < right.priority.rawValue
                    || left.expirationTime.compare(right.expirationTime) == .orderedAscending
            }
            
            while volume > maxCapacity {
                let key = sortedKeys.removeFirst()
                let data = cache.removeValue(forKey: key)
                volume -= data?.data.count ?? 0
            }
        }
        
        return maxCapacity - volume
    }
    
    private func clearInvalidCache() {
        cache.keys
            .filter({ [weak self] in !(self?.cache[$0]?.isValid ?? false) })
            .forEach({ [weak self] in self?.cache.removeValue(forKey: $0) })
    }
}
