//
//  TetraNetworkWorker.swift
//  TetraNetwork
//
//  Created by Son Nguyen on 3/1/22.
//

import Foundation
import Combine

/// The raw result getting back from a network request.
public typealias TetraNetworkRawResponse = Result<(URLResponse?, Data?), Error>
internal typealias TetraNetworkRawResponseHandler = (TetraNetworkRawResponse) -> Void

/// Use this class to make network call. It support 3 types of method: handler, combine, and async.
final public class TetraNetworkWorker {
    private var cache: TetraNetworkCache?
    private let buffer = TetraNetworkBuffer()
    
    /// Create a worker that has [cacheCapacity] (in MB) as the cache capacity. Specifying [cacheCapacity] to 0 makes this
    /// worker not capable of using cache at all.
    public init(cacheCapacity: Float = 0) {
        if cacheCapacity > 0 {
            cache = TetraNetworkCache(maxCapacity: Int(cacheCapacity * 1000000))
        }
        
    }
    
    /// Make a network call in a handler fashtion. If [config] is not provided, a default config `TetraRequestConfig()` will be used.
    public func makeRequest<D: Decodable, E: TetraNetworkError>(
        _ request: TetraNetworkRequest,
        config: TetraRequestConfig = TetraRequestConfig(),
        handler: @escaping (Result<D, E>) -> Void
    ) {
        if config.useCache, let cacheData: D = getResponseFromCache(for: request) {
            handler(.success(cacheData))
            return
        }
        
        guard !config.bufferEnabled || tryUseHandlerBuffer(request, handler: handler) else {
            return
        }
        
        guard let urlRequest = request.urlRequest else {
            return
        }
        
        URLSession.shared.dataTask(with: urlRequest) { [weak self] data, response, error in
            guard let self = self else {
                return
            }
            
            let resolveBufferSucceeded = self.tryResolveBuffer(object: request,
                                                               response: response,
                                                               data: data,
                                                               error: error)
            
            if !resolveBufferSucceeded {
                handler(TetraNetworkWorker.convertResult(.success((response, data))))
            }
            
            if config.shouldCache {
                self.tryAddToCache(object: request,
                                   data: data,
                                   duration: config.cacheDuration,
                                   priority: config.cachePriority)
            }
        }
    }
    
    /// Make a network call in a combine fashtion. [cancellables] is required and should have the same life cycel as the one you use
    /// for `sink` of the result of this method (best is to use the same set), in the case of buffering is enabled, it will be used internally.
    /// If [config] is not provided, a default config `TetraRequestConfig()` will be used.
    @available(iOS 13.0, *)
    public func makeRequest<D: Decodable, E: TetraNetworkError>(
        _ request: TetraNetworkRequest,
        config: TetraRequestConfig = TetraRequestConfig(),
        cancellables: inout Set<AnyCancellable>
    ) -> AnyPublisher<Result<D, E>, Never> {
        if config.useCache, let cacheData: D = getResponseFromCache(for: request) {
            return Just<Result<D, E>>(.success(cacheData)).eraseToAnyPublisher()
        }
        
        let (needToMakeRequest, publisher): (Bool, AnyPublisher<Result<D, E>, Never>?)
        if config.bufferEnabled {
            (needToMakeRequest, publisher) = tryUseFutureBuffer(request)
        } else {
            (needToMakeRequest, publisher) = (true, nil)
        }
        
        guard needToMakeRequest else {
            return publisher ?? Empty<Result<D, E>, Never>().eraseToAnyPublisher()
        }
        
        guard let urlRequest = request.urlRequest else {
            return Empty<Result<D, E>, Never>().eraseToAnyPublisher()
        }
        
        let newPublisher = URLSession.shared.dataTaskPublisher(for: urlRequest)
            .handleEvents(receiveOutput: { [weak self] (data: Data, response: URLResponse) in
                guard config.shouldCache else {
                    return
                }
                
                self?.tryAddToCache(object: request,
                                    data: data,
                                    duration: config.cacheDuration,
                                    priority: config.cachePriority)
            })
        
        if let publisher = publisher {
            newPublisher.sink { [weak self] completion in
                switch completion {
                case .finished:
                    break
                case .failure(let error):
                    self?.tryResolveBuffer(object: request,
                                           response: nil,
                                           data: nil,
                                           error: error)
                }
            } receiveValue: { [weak self] data, response in
                self?.tryResolveBuffer(object: request,
                                      response: response,
                                      data: data,
                                      error: nil)
            }.store(in: &cancellables)
            
            return publisher
        } else {
            let tempPublisher = newPublisher
                .map { (data, response) -> Result<D, E> in
                    return TetraNetworkWorker.convertResult(.success((response, data)))
                }
            return tempPublisher
                .catch { error -> AnyPublisher<Result<D, E>, Never> in
                    return Just<Result<D, E>>(.failure(E(from: .failure(error)))).eraseToAnyPublisher()
                }
                .eraseToAnyPublisher()
        }
    }
    
    /// Make a network call in a async fashtion. If [config] is not provided, a default config `TetraRequestConfig()` will be used.
    @available(iOS 13.0, *)
    public func makeRequest<D: Decodable, E: TetraNetworkError>(
        _ request: TetraNetworkRequest, config: TetraRequestConfig = TetraRequestConfig()
    ) async -> Result<D, E> {
        if config.useCache, let cacheData: D = getResponseFromCache(for: request) {
            return .success(cacheData)
        }
        
        let (needToMakeRequest, result): (Bool, Result<D, E>?)
        if config.bufferEnabled {
            (needToMakeRequest, result) = await tryUseBuffer(request)
        } else {
            (needToMakeRequest, result) = (true, nil)
        }
        
        guard needToMakeRequest else {
            return result ?? .failure(E(from: .success((nil, nil))))
        }
        
        guard let urlRequest = request.urlRequest else {
            return .failure(E(from: .success((nil, nil))))
        }
        
        if #available(iOS 15.0, *) {
            do {
                let (data, response) = try await URLSession.shared.data(for: urlRequest)
                tryResolveBuffer(object: request, response: response, data: data, error: nil)
                
                if config.shouldCache {
                    tryAddToCache(object: request,
                                  data: data,
                                  duration: config.cacheDuration,
                                  priority: config.cachePriority)
                }
                
                return TetraNetworkWorker.convertResult(.success((response, data)))
            } catch (let error) {
                return .failure(E(from: .failure(error)))
            }
        } else {
            return await withCheckedContinuation({ (continuation: CheckedContinuation<Result<D, E>, Never>) in
                URLSession.shared.dataTask(with: urlRequest) { [weak self] data, response, error in
                    let result: Result<D, E>
                    if let error = error {
                        result = TetraNetworkWorker.convertResult(.failure(error))
                    } else {
                        if config.shouldCache {
                            self?.tryAddToCache(object: request,
                                                data: data,
                                                duration: config.cacheDuration,
                                                priority: config.cachePriority)
                        }
                        
                        result = TetraNetworkWorker.convertResult(.success((response, data)))
                    }
                   continuation.resume(with: .success(result))
                }
            })
        }
    }
    
    private func tryUseHandlerBuffer<D: Decodable, E: TetraNetworkError>(
        _ request: TetraNetworkRequest,
        handler: @escaping (Result<D, E>) -> Void
    ) -> Bool {
        guard let bufferable = request as? TetraNetworkBufferable else {
            return true
        }
        
        let needToMakeRequest = buffer.isAlreadyInPendingHandlers(bufferable.hash)
        
        buffer.addToPendingHandlers(bufferable.hash) { result in
            handler(TetraNetworkWorker.convertResult(result))
        }
        
        return needToMakeRequest
    }
    
    @available(iOS 13.0, *)
    private func tryUseFutureBuffer<D: Decodable, E: TetraNetworkError>(
        _ request: TetraNetworkRequest
    ) -> (needToMakeRequest: Bool, publisher: AnyPublisher<Result<D, E>, Never>?) {
        guard let bufferable = request as? TetraNetworkBufferable else {
            return (true, nil)
        }
        
        let needToMakeRequest = !buffer.isAlreadyInPendingFutures(bufferable.hash)
        let publisher = buffer.getFuture(bufferable.hash)
            .map { result -> Result<D, E>? in
                TetraNetworkWorker.convertResult(result)
            }
            .compactMap { $0 }
            .first()
            .eraseToAnyPublisher()
        
        return (needToMakeRequest, publisher)
    }
    
    @available(iOS 13.0, *)
    private func tryUseBuffer<D: Decodable, E: TetraNetworkError>(
        _ request: TetraNetworkRequest
    ) async -> (needToMakeRequest: Bool, result: Result<D, E>?) {
        guard let bufferable = request as? TetraNetworkBufferable else {
            return (true, nil)
        }
        
        let needToMakeRequest = !buffer.isAlreadyInPendingContinuations(bufferable.hash)
        
        if needToMakeRequest {
            Task { [weak self] in
                await self?.buffer.getResponse(bufferable.hash)
            }
            return (needToMakeRequest, nil)
        } else {
            let result = await buffer.getResponse(bufferable.hash)
            return (needToMakeRequest, TetraNetworkWorker.convertResult(result))
        }
    }
    
    private func getResponseFromCache<D: Decodable>(for request: TetraNetworkRequest) -> D? {
        guard request.method == .GET,
              let cachable = request as? TetraNetworkCachable,
              let data = cache?.getCache(for: cachable.hash) else {
            return nil
        }
        
        return try? TetraNetworkWorker.tryConvert(data: data)
    }
    
    @discardableResult
    private func tryResolveBuffer(object: Any,
                                                     response: URLResponse?,
                                                     data: Data?,
                                                     error: Error?) -> Bool {
        guard let bufferable = object as? TetraNetworkBufferable else {
            return false
        }
        
        if let error = error {
            buffer.resolvePendingItem(for: bufferable.hash,
                                      response: nil,
                                      data: nil,
                                      error: error)
        } else {
            buffer.resolvePendingItem(for: bufferable.hash,
                                      response: response,
                                      data: data,
                                      error: nil)
            
        }
        
        return true
    }
    
    private func tryAddToCache(object: Any,
                               data: Data?,
                               duration: TimeInterval,
                               priority: TetraNetworkCachePriority) {
        guard let cachable = object as? TetraNetworkCachable,
              let data = data else {
            return
        }
        
        cache?.addCache(for: cachable.hash,
                        data: data,
                        duration: duration,
                        priority: priority)
    }
    
    private static func convertResult<D: Decodable, E: TetraNetworkError>(
        _ result: Result<(URLResponse?, Data?), Error>
    ) -> Result<D, E> {
        switch result {
        case .success((let response, let data)):
            guard let data = data,
                  let response = response as? HTTPURLResponse,
                  response.statusCode == 200 else {
                      return .failure(E(from: .success((response, data))))
                  }
            
            do {
                let object: D = try tryConvert(data: data)
                return .success(object)
            } catch (let error) {
                return .failure(E(from: .failure(error)))
            }
        case .failure(let error):
            return .failure(E(from: .failure(error)))
        }
    }
    
    private static func tryConvert<D: Decodable>(data: Data) throws -> D {
        return try JSONDecoder().decode(D.self, from: data)
    }
}
