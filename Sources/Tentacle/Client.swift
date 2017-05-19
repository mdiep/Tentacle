//
//  Client.swift
//  Tentacle
//
//  Created by Matt Diephouse on 3/3/16.
//  Copyright © 2016 Matt Diephouse. All rights reserved.
//

import Argo
import Foundation
import ReactiveSwift
import Result

extension JSONSerialization {
    internal static func deserializeJSON(_ data: Data) -> Result<Any, AnyError> {
        return materialize(try JSONSerialization.jsonObject(with: data))
    }
}

extension URL {
    internal func url(with queryItems: [URLQueryItem]) -> URL {
        var components = URLComponents(url: self, resolvingAgainstBaseURL: true)!
        components.queryItems = (components.queryItems ?? []) + queryItems
        return components.url!
    }
    
    internal init(_ server: Server, _ request: Request, page: UInt? = nil, pageSize: UInt? = nil) {
        let queryItems = [ ("page", page), ("per_page", pageSize) ]
            .filter { _, value in value != nil }
            .map { name, value in URLQueryItem(name: name, value: "\(value!)") }

        let url = URL(string: server.endpoint)!
            .appendingPathComponent(request.path)
            .url(with: request.queryItems)
            .url(with: queryItems)

        self.init(string: url.absoluteString)!
    }
}

extension URLRequest {
    internal static func create(_ url: URL, _ credentials: Client.Credentials?, contentType: String? = Client.APIContentType) -> URLRequest {
        var request = URLRequest(url: url)
        
        request.setValue(contentType, forHTTPHeaderField: "Accept")
        
        if let userAgent = Client.userAgent {
            request.setValue(userAgent, forHTTPHeaderField: "User-Agent")
        }
        
        if let credentials = credentials {
            request.setValue(credentials.authorizationHeader, forHTTPHeaderField: "Authorization")
        }
        
        return request
    }

    internal static func create(_ url: URL, _ body: Data?, _ method: Request.Method, _ credentials: Client.Credentials?, contentType: String? = Client.APIContentType) -> URLRequest {
        var URLRequest = create(url, credentials, contentType: contentType)
        URLRequest.httpMethod = method.rawValue
        URLRequest.httpBody = body
        return URLRequest
    }
}

extension URLSession {
	/// Returns a producer that will download a file using the given request. The file will be
	/// deleted after the producer terminates.
	internal func downloadFile(_ request: URLRequest) -> SignalProducer<URL, AnyError> {
		return SignalProducer { observer, disposable in
			let serialDisposable = SerialDisposable()
			let handle = disposable.add(serialDisposable)

			let task = self.downloadTask(with: request) { (url, response, error) in
				// Avoid invoking cancel(), or the download may be deleted.
				handle.remove()

				if let url = url {
					observer.send(value: url)
					observer.sendCompleted()
				} else if let error = error {
					observer.send(error: AnyError(error))
                } else {
                    fatalError("Request neither succeeded nor failed: \(String(describing: request.url))")
                }
			}

			serialDisposable.inner = ActionDisposable {
				task.cancel()
			}

			task.resume()
		}
	}
}

internal struct Request {
    enum Method: String {
        case get = "GET"
        case post = "POST"
        case put = "PUT"
        case head = "HEAD"
        case options = "OPTIONS"
    }
    
    var method: Method
    var path: String
    var queryItems: [URLQueryItem]
    var body: Data?
    
    init(method: Method = .get, path: String, queryItems: [URLQueryItem] = [], body: Data? = nil) {
        self.method = method
        self.path = path
        self.queryItems = queryItems
        self.body = body
    }
}

extension Request: Hashable {
    var hashValue: Int {
        return method.hashValue
            ^ path.hashValue
            ^ queryItems.map { $0.hashValue }.reduce(0, ^)
            ^ (self.body?.hashValue ?? 0)
    }
    
    static func == (lhs: Request, rhs: Request) -> Bool {
        return lhs.method == rhs.method
            && lhs.path == rhs.path
            && lhs.queryItems == rhs.queryItems
            && lhs.body == rhs.body
    }
}

extension Request {
    static func get(_ path: String, queryItems: [URLQueryItem] = []) -> Request {
        return Request(method: .get, path: path, queryItems: queryItems)
    }
    
    // https://developer.github.com/v3/issues/#list-issues
    static func assignedIssues() -> Request {
        return get("/issues")
    }
    
    // https://developer.github.com/v3/users/#get-the-authenticated-user
    static func authenticatedUser() -> Request {
        return get("/user")
    }
    
    // https://developer.github.com/v3/repos/#list-your-repositories
    static func repositories() -> Request {
        return get("/user/repos")
    }
    
    // https://developer.github.com/v3/repos/#list-organization-repositories
    static func repositories(forOrganization organization: String) -> Request {
        return get("/orgs/\(organization)/repos")
    }
    
    // https://developer.github.com/v3/repos/#list-all-public-repositories
    static func publicRepositories() -> Request {
        return get("/repositories")
    }
}

/// A GitHub API Client
public final class Client {
    /// The type of content to request from the GitHub API.
    internal static let APIContentType = "application/vnd.github.v3+json"
    
    /// The type of content to request from the GitHub API when downloading assets
    /// from releases.
    internal static let DownloadContentType = "application/octet-stream"
    
    /// An error from the Client.
    public enum Error: Swift.Error {
        /// An error occurred in a network operation.
        case networkError(Swift.Error)
        
        /// An error occurred while deserializing JSON.
        case jsonDeserializationError(Swift.Error)
        
        /// An error occurred while decoding JSON.
        case jsonDecodingError(DecodeError)
        
        /// A status code, response, and error that was returned from the API.
        case apiError(Int, Response, GitHubError)
        
        /// The requested object does not exist.
        case doesNotExist
    }
    
    /// Credentials for the GitHub API.
    internal enum Credentials {
        case token(String)
        case basic(username: String, password: String)
        
        var authorizationHeader: String {
            switch self {
            case let .token(token):
                return "token \(token)"
            case let .basic(username, password):
                let data = "\(username):\(password)".data(using: String.Encoding.utf8)!
                let encodedString = data.base64EncodedString()
                return "Basic \(encodedString)"
            }
        }
    }
    
    /// The user-agent to use for API requests.
    public static var userAgent: String?
    
    /// The Server that the Client connects to.
    public let server: Server
    
    /// Whether the Client is authenticated.
    public var isAuthenticated: Bool {
        return credentials != nil
    }
    
    /// The Credentials for the API.
    private let credentials: Credentials?

    /// The `URLSession` instance to use.
    private let urlSession: URLSession
    
    /// Create an unauthenticated client for the given Server.
    public init(_ server: Server, urlSession: URLSession = .shared) {
        self.server = server
        self.credentials = nil
        self.urlSession = urlSession
    }
    
    /// Create an authenticated client for the given Server with a token.
    public init(_ server: Server, token: String, urlSession: URLSession = .shared) {
        self.server = server
        self.credentials = .token(token)
        self.urlSession = urlSession
    }
    
    /// Create an authenticated client for the given Server with a username and password.
    public init(_ server: Server, username: String, password: String, urlSession: URLSession = .shared) {
        self.server = server
        self.credentials = .basic(username: username, password: password)
        self.urlSession = urlSession
    }
    
    /// Fetch the releases in the given repository, starting at the given page.
    ///
    /// This method will automatically fetch all pages. Each value in the returned signal producer
    /// will be the response and releases from a single page.
    ///
    /// https://developer.github.com/v3/repos/releases/#list-releases-for-a-repository
    public func releases(in repository: Repository, page: UInt = 1, perPage: UInt = 30) -> SignalProducer<(Response, [Release]), Error> {
        return fetchMany(repository.releases, page: page, pageSize: perPage)
    }
    
    /// Fetch the release corresponding to the given tag in the given repository.
    ///
    /// If the tag exists, but there's not a correspoding GitHub Release, this method will return a
    /// `.DoesNotExist` error. This is indistinguishable from a nonexistent tag.
    public func release(forTag tag: String, in repository: Repository) -> SignalProducer<(Response, Release), Error> {
        return fetchOne(repository.release(forTag: tag))
    }
    
    /// Downloads the indicated release asset to a temporary file, returning the URL to the file on
    /// disk.
    ///
    /// The downloaded file will be deleted after the URL has been sent upon the signal.
    public func download(asset: Release.Asset) -> SignalProducer<URL, Error> {
        return urlSession
            .downloadFile(URLRequest.create(asset.apiURL, credentials, contentType: Client.DownloadContentType))
            .mapError { Error.networkError($0.error) }
    }
    
    /// Fetch the user with the given login.
    public func user(login: String) -> SignalProducer<(Response, UserProfile), Error> {
        return fetchOne(User(login).profile)
    }

    /// Fetch the currently authenticated user
    public func authenticatedUser() -> SignalProducer<(Response, UserProfile), Error> {
        return fetchOne(.authenticatedUser())
    }

    public func assignedIssues(page: UInt = 1, perPage: UInt = 30) -> SignalProducer<(Response, [Issue]), Error> {
        return fetchMany(.assignedIssues(), page: page, pageSize: perPage)
    }

    public func issues(in repository: Repository, page: UInt = 1, perPage: UInt = 30) -> SignalProducer<(Response, [Issue]), Error> {
        return fetchMany(repository.issues, page: page, pageSize: perPage)
    }

    /// Fetch the comments posted on an issue
    public func comments(onIssue issue: Int, in repository: Repository, page: UInt = 1, perPage: UInt = 30) -> SignalProducer<(Response, [Comment]), Error> {
        return fetchMany(repository.comments(onIssue: issue), page: page, pageSize: perPage)
    }

    /// Fetch the authenticated user's repositories
    public func repositories(page: UInt = 1, perPage: UInt = 30) -> SignalProducer<(Response, [RepositoryInfo]), Error> {
        return fetchMany(.repositories(), page: page, pageSize: perPage)
    }

    /// Fetch the repositories for a specific user
    public func repositories(forUser user: String, page: UInt = 1, perPage: UInt = 30) -> SignalProducer<(Response, [RepositoryInfo]), Error> {
        return fetchMany(User(user).repositories, page: page, pageSize: perPage)
    }

    /// Fetch the repositories for a specific organisation 
    public func repositories(forOrganization organization: String, page: UInt = 1, perPage: UInt = 30) -> SignalProducer<(Response, [RepositoryInfo]), Error> {
        return fetchMany(.repositories(forOrganization: organization), page: page, pageSize: perPage)
    }

    /// Fetch the public repositories on Github
    public func publicRepositories(page: UInt = 1, perPage: UInt = 30) -> SignalProducer<(Response, [RepositoryInfo]), Error> {
        return fetchMany(.publicRepositories(), page: page, pageSize: perPage)
    }

    /// Fetch the content for a path in the repository
    public func content(atPath path: String, in repository: Repository, atRef ref: String? = nil) -> SignalProducer<(Response, Content), Error> {
        return fetchOne(repository.content(atPath: path, atRef: ref))
    }

    /// Create a file in a repository
    public func create(file: File, atPath path: String, in repository: Repository, inBranch branch: String? = nil) -> SignalProducer<(Response, FileResponse), Error> {
        return send(repository.create(file: file, atPath: path, inBranch: branch))
    }

    /// Update a file in a repository
    public func update(file: File, atPath path: String, sha: SHA, in repository: Repository, inBranch branch: String? = nil) -> SignalProducer<(Response, FileResponse), Error> {
        let update = Update(file: file, path: path, sha: sha)
        return send(update, to: .content(owner: repository.owner, repository: repository.name, path: path, ref: branch), using: .put)
    }

    /// Get branches for a repository
    public func branches(in repository: Repository, page: UInt = 1, perPage: UInt = 30) -> SignalProducer<(Response, [Branch]), Error> {
        return fetchMany(repository.branches, page: page, pageSize: perPage)
    }

    /// Fetch the tree for a repository reference
    public func tree(in repository: Repository, atRef ref: String = "HEAD", recursive: Bool = false) -> SignalProducer<(Response, Tree), Error> {
        return fetchOne(repository.tree(atRef: ref, recursive: recursive))
    }

    /// Create a tree in a repository
    public func create(tree: [Tree.Entry], basedOn base: String?, in repository: Repository) -> SignalProducer<(Response, FileResponse), Error> {
        return send(repository.create(tree: tree, basedOn: base))
    }

    /// Fetch a request from the API.
    private func fetch(_ request: Request, page: UInt?, pageSize: UInt?) -> SignalProducer<(Response, Any), Error> {
        let url = URL(server, request, page: page, pageSize: pageSize)

        return fetch(URLRequest.create(url, credentials))
    }

    /// Sends an URLRequest and map response to JSON
    private func fetch(_ urlRequest: URLRequest) -> SignalProducer<(Response, Any), Error> {
        return urlSession
            .reactive
            .data(with: urlRequest)
            .mapError { Error.networkError($0.error) }
            .flatMap(.concat) { data, response -> SignalProducer<(Response, Any), Error> in
                let response = response as! HTTPURLResponse
                let headers = response.allHeaderFields as! [String:String]
                return SignalProducer
                    .attempt {
                        return JSONSerialization.deserializeJSON(data).mapError { Error.jsonDeserializationError($0.error) }
                    }
                    .attemptMap { JSON in
                        if response.statusCode == 404 {
                            return .failure(.doesNotExist)
                        }
                        if response.statusCode >= 400 && response.statusCode < 600 {
                            return decode(JSON)
                                .mapError(Error.jsonDecodingError)
                                .flatMap { error in
                                    .failure(Error.apiError(response.statusCode, Response(headerFields: headers), error))
                            }
                        }
                        return .success(JSON)
                    }
                    .map { JSON in
                        return (Response(headerFields: headers), JSON)
                }
        }
    }
    
    /// Fetch an object from the API.
    internal func fetchOne
        <Resource: ResourceType>
        (_ request: Request) -> SignalProducer<(Response, Resource), Error> where Resource.DecodedType == Resource
    {
        return fetch(request, page: nil, pageSize: nil)
            .attemptMap { response, JSON in
                return decode(JSON)
                    .map { resource in
                        (response, resource)
                    }
                    .mapError(Error.jsonDecodingError)
            }
    }
    
    /// Fetch a list of objects from the API.
    internal func fetchMany
        <Resource: ResourceType>
        (_ request: Request, page: UInt?, pageSize: UInt?) -> SignalProducer<(Response, [Resource]), Error> where Resource.DecodedType == Resource
    {
        let nextPage = (page ?? 1) + 1
        return fetch(request, page: page, pageSize: pageSize)
            .attemptMap { response, JSON in
                return decode(JSON)
                    .map { resource in
                        (response, resource)
                    }
                    .mapError(Error.jsonDecodingError)
            }
            .flatMap(.concat) { response, JSON -> SignalProducer<(Response, [Resource]), Error> in
                return SignalProducer(value: (response, JSON))
                    .concat(response.links["next"] == nil ? SignalProducer.empty : self.fetchMany(request, page: nextPage, pageSize: pageSize))
            }
    }

    internal func send
        <Resource: ResourceType>
        (_ request: Request) -> SignalProducer<(Response, Resource), Error> where Resource.DecodedType == Resource
    {
        let urlRequest = URLRequest.create(URL(server, request), request.body, request.method, credentials)

        return fetch(urlRequest)
            .attemptMap { response, JSON in
                return decode(JSON)
                    .map { resource in
                        (response, resource)
                    }
                    .mapError(Error.jsonDecodingError)
        }
    }
}

extension Client.Error: Hashable {
    public static func ==(lhs: Client.Error, rhs: Client.Error) -> Bool {
        switch (lhs, rhs) {
        case let (.networkError(error1), .networkError(error2)):
            return (error1 as NSError) == (error2 as NSError)

        case let (.jsonDeserializationError(error1), .jsonDeserializationError(error2)):
            return (error1 as NSError) == (error2 as NSError)

        case let (.jsonDecodingError(error1), .jsonDecodingError(error2)):
            return error1 == error2

        case let (.apiError(statusCode1, response1, error1), .apiError(statusCode2, response2, error2)):
            return statusCode1 == statusCode2 && response1 == response2 && error1 == error2

        case (.doesNotExist, .doesNotExist):
            return true

        default:
            return false
        }
    }

    public var hashValue: Int {
        switch self {
        case let .networkError(error):
            return (error as NSError).hashValue

        case let .jsonDeserializationError(error):
            return (error as NSError).hashValue

        case let .jsonDecodingError(error):
            return error.hashValue

        case let .apiError(statusCode, response, error):
            return statusCode.hashValue ^ response.hashValue ^ error.hashValue

        case .doesNotExist:
            return 4
        }
    }
}
