# TetraNetwork
`TetraNetwork` is an slightly opinionated networking framework with only the minimal functionalities and no bloater. Use this library if you only need to make only a few API calls and nothing else as this library doesn't offer much other than that :)

TetraNetwork does provide in-memory cache capability. It also buffers pending requests, meaning if a request is waiting for the response and `TetraNetwork` receives another request that has the same hash, it will not send the subsequent request but simply waits for the reponse from the first one and returns it to all pending requests.<br/>
TetraNetwork support the old-style callback, Combine, as well as async method.

## Usage

#### Create a request class
`TetraNetwork` uses `TetraNetworkRequest` objects to make network calls, so comform to that protocol in order to create requests.
`TetraNetwork` also provide `DefaultTetraNetworkRequest` as a default implementation of `TetraNetworkRequest`. You can either use this default implementation or implement your own conformance. Note that `DefaultTetraNetworkRequest` also conforms to `TetraNetworkCachable` and `TetraNetworkBufferable` (these will be explained later). However, the hash of this implementation works by combining all the info of the request including the body. So if you're request total space (memory volume) is big and you intend to use buffering and cache, consider implement your own request in order to save memory usage.<br/>
In the example below, I choose to use `DefaultTetraNetworkRequest`:
```Swift
let request = DefaultTetraNetworkRequest(baseUrl: "https://my-domain.com",
                                         paths: ["v2", "abc", "def"],
                                         method: .GET,
                                         headers: ["headerKey": 123456],
                                         queries: ["key1": 1, "key2": "2"])
```

#### Error handling
`TetraNetwok` forces you to use `TetraNetworError`. It only returns error that conforms to this protocol.
```Swift
enum SampleError: TetraNetworkError {
    case noConnection
    case dontCare
    
    init(from respose: TetraNetworkRawResponse) {
        switch respose {
        case .failure(_):
            self = .noConnection
        case .success((_, _)):
            self = .dontCare
        }
    }
}
```

#### Request config
For each request to be made, `TetraNetwork` relies on the provided `TetraNetworkConfig` and the request to determine the behavior. Things like whether or not to cache the result, the cache duration and priority, etc.
```Swift
let config = TetraRequestConfig(shouldCache: true,
                                useCache: true,
                                bufferEnabled: true,
                                cacheDuration: 400,
                                cachePriority: .high)
```

#### Buffering and Cache
`TetraNetwork` supports caching and buffering (buffer identical requests, make only 1 request and return result to all). In order for this to work, your request has to conform `TetraCachable` and `TetraBufferable`. These two protocols have the same requirement of a `hash` value, but `TetraNetwork` uses type check so they are kept separately. <br/>
The rule are: If 2 request can use the same cache or buffered together, their `hash` has to be the same. Please don't confuse this with the native `Hashable`.

#### Call the API
```Swift
let worker = TetraNetworkWorker(cacheCapacity: 10)

// Handler
worker.makeRequest(request, config: config) { (result: Result<Int, SampleError>) in
    // do something interesting with the result
}

// Combine
var cancellables = Set<AnyCancellable>()
worker.makeRequest(request, cancellables: &cancellables)
    .sink { _ in
        // code here will get executed right after the handling block below
    } receiveValue: { (result: Result<Int, SampleError>) in
        // do something interesting with the result
    }
    .store(in: &cancellables)

// Async
let result: Result<Int, SampleError> = await worker.makeRequest(request, config: config)
// do something interesting with the result
```
