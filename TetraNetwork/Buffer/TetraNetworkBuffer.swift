//
//  TetraNetworkBuffer.swift
//  TetraNetwork
//
//  Created by Son Nguyen on 3/1/22.
//

import Foundation
import Combine

internal class TetraNetworkBuffer {
    private var handlers: [AnyHashable: [TetraNetworkRawResponseHandler]] = [:]
    private var futures: [AnyHashable: Any] = [:]
    private var futurePromises: [AnyHashable: Any] = [:]
    private var continuations: [AnyHashable: [Any]] = [:]
    
    func isAlreadyInPendingHandlers(_ hash: AnyHashable) -> Bool {
        return handlers.keys.contains(hash)
    }
    
    func isAlreadyInPendingFutures(_ hash: AnyHashable) -> Bool {
        return futures.keys.contains(hash)
    }
    
    func isAlreadyInPendingContinuations(_ hash: AnyHashable) -> Bool {
        return continuations.keys.contains(hash)
    }
    
    func addToPendingHandlers(_ hash: AnyHashable,
                              handler: @escaping TetraNetworkRawResponseHandler) {
        if handlers[hash] != nil {
            handlers[hash]?.append(handler)
        } else {
            handlers[hash] = [handler]
        }
    }
    
    @available(iOS 13.0, *)
    func getFuture(_ hash: AnyHashable) -> Future<TetraNetworkRawResponse, Never> {
        if let future = futures[hash] as? Future<TetraNetworkRawResponse, Never> {
            return future
        }
        
        let future = Future<TetraNetworkRawResponse, Never> { [weak self] promise in
            self?.futurePromises[hash] = promise
        }
        
        futures[hash] = future
        
        return future
    }
    
    @available(iOS 13.0, *)
    func getResponse(_ hash: AnyHashable) async -> TetraNetworkRawResponse {
        let closure = { [weak self] (continuation: CheckedContinuation<TetraNetworkRawResponse, Never>) in
            if self?.continuations[hash] != nil {
                self?.continuations[hash]?.append(continuation)
            } else {
                self?.continuations[hash] = [continuation]
            }
        }
        
        return await withCheckedContinuation(closure)
    }
    
    func resolvePendingItem(for hash: AnyHashable,
                            response: URLResponse?,
                            data: Data?,
                            error: Error?) {
        let handlers = handlers.removeValue(forKey: hash)
        
        if let error = error {
            handlers?.forEach({ handler in
                handler(.failure(error))
            })
            
            if #available(iOS 13.0, *) {
                let promise = futurePromises
                    .removeValue(forKey: hash) as? Future<TetraNetworkRawResponse, Never>.Promise
                promise?(.success(.failure(error)))
                
                let continuations = continuations[hash] as? [CheckedContinuation<TetraNetworkRawResponse, Never>]
                continuations?.forEach({ continuation in
                    continuation.resume(with: .success(.failure(error)))
                })
            }
        } else {
            handlers?.forEach({ handler in
                handler(.success((response, data)))
            })
            
            if #available(iOS 13.0, *) {
                let promise = futurePromises
                    .removeValue(forKey: hash) as? Future<TetraNetworkRawResponse, Never>.Promise
                promise?(.success(.success((response, data))))
                
                let continuations = continuations[hash] as? [CheckedContinuation<TetraNetworkRawResponse, Never>]
                continuations?.forEach({ continuation in
                    continuation.resume(with: .success(.success((response, data))))
                })
            }
        }
        
        futures.removeValue(forKey: hash)
    }
}
