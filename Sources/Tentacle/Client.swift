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
        return Result(try JSONSerialization.jsonObject(with: data))
    }
}

extension URL {
    internal func url(with queryItems: [URLQueryItem]) -> URL {
        var components = URLComponents(url: self, resolvingAgainstBaseURL: true)!
        components.queryItems = (components.queryItems ?? []) + queryItems
        return components.url!
    }
    
    internal init(_ server: Server, _ endpoint: Client.Endpoint, page: UInt? = nil, pageSize: UInt? = nil) {
        let queryItems = [ ("page", page), ("per_page", pageSize) ]
            .filter { _, value in value != nil }
            .map { name, value in URLQueryItem(name: name, value: "\(value!)") }

        let url = URL(string: server.endpoint)!
            .appendingPathComponent(endpoint.path)
            .url(with: endpoint.queryItems)
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

    internal static func create<Request: RequestType>(_ url: URL, _ request: Request, _ method: HTTPMethod, _ credentials: Client.Credentials?, contentType: String? = Client.APIContentType) -> URLRequest {
        var URLRequest = create(url, credentials, contentType: contentType)
        URLRequest.httpMethod = method.rawValue

        let object = request.encode().JSONObject()
        if let payload = try? JSONSerialization.data(withJSONObject: object, options: []) {
            URLRequest.httpBody = payload
        }

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
                    fatalError("Request neither succeeded nor failed: \(request.url)")
                }
			}

			serialDisposable.inner = ActionDisposable {
				task.cancel()
			}

			task.resume()
		}
	}
}

enum HTTPMethod: String {
    case get = "GET"
    case post = "POST"
    case put = "PUT"
    case head = "HEAD"
    case options = "OPTIONS"
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
    
    /// A GitHub API endpoint.
    internal enum Endpoint {
        // https://developer.github.com/v3/repos/releases/#get-a-release-by-tag-name
        case releaseByTagName(owner: String, repository: String, tag: String)
        
        // https://developer.github.com/v3/repos/releases/#list-releases-for-a-repository
        case releasesInRepository(owner: String, repository: String)
        
        // https://developer.github.com/v3/users/#get-a-single-user
        case userInfo(login: String)

        // https://developer.github.com/v3/issues/#list-issues
        case assignedIssues

        // https://developer.github.com/v3/issues/#list-issues-for-a-repository
        case issuesInRepository(owner: String, repository: String)

        // https://developer.github.com/v3/issues/comments/#list-comments-on-an-issue
        case commentsOnIssue(number: Int, owner: String, repository: String)

        // https://developer.github.com/v3/users/#get-the-authenticated-user
        case authenticatedUser

        // https://developer.github.com/v3/repos/#list-your-repositories
        case repositories

        // https://developer.github.com/v3/repos/#list-user-repositories
        case repositoriesForUser(user: String)

        // https://developer.github.com/v3/repos/#list-organization-repositories
        case repositoriesForOrganization(organization: String)

        // https://developer.github.com/v3/repos/#list-all-public-repositories
        case publicRepositories

        // https://developer.github.com/v3/repos/contents/#get-contents
        case content(owner: String, repository: String, path: String, ref: String?)

        // https://developer.github.com/v3/repos/branches/#list-branches
        case branches(owner: String, repository: String)

        internal var path: String {
            switch self {
            case let .releaseByTagName(owner, repo, tag):
                return "/repos/\(owner)/\(repo)/releases/tags/\(tag)"
            case let .releasesInRepository(owner, repo):
                return "/repos/\(owner)/\(repo)/releases"
            case let .userInfo(login):
                return "/users/\(login)"
            case .assignedIssues:
                return "/issues"
            case let .issuesInRepository(owner, repository):
                return "/repos/\(owner)/\(repository)/issues"
            case let .commentsOnIssue(issue, owner, repository):
                return "/repos/\(owner)/\(repository)/issues/\(issue)/comments"
            case .authenticatedUser:
                return "/user"
            case .repositories:
                return "/user/repos"
            case let .repositoriesForUser(user):
                return "/users/\(user)/repos"
            case let .repositoriesForOrganization(organisation):
                return "/orgs/\(organisation)/repos"
            case .publicRepositories:
                return "/repositories"
            case let .content(owner, repository, path, _):
                return "/repos/\(owner)/\(repository)/contents/\(path)"
            case let .branches(owner, repository):
                return "/repos/\(owner)/\(repository)/branches"
            }
        }
        
        internal var queryItems: [URLQueryItem] {
            switch self {
            case let .content(_, _, _, ref?):
                return [ URLQueryItem(name: "ref", value: ref) ]
            default:
                return []
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
        precondition(repository.server == server)
        return fetchMany(.releasesInRepository(owner: repository.owner, repository: repository.name), page: page, pageSize: perPage)
    }
    
    /// Fetch the release corresponding to the given tag in the given repository.
    ///
    /// If the tag exists, but there's not a correspoding GitHub Release, this method will return a
    /// `.DoesNotExist` error. This is indistinguishable from a nonexistent tag.
    public func release(forTag tag: String, in repository: Repository) -> SignalProducer<(Response, Release), Error> {
        precondition(repository.server == server)
        return fetchOne(.releaseByTagName(owner: repository.owner, repository: repository.name, tag: tag))
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
    public func user(login: String) -> SignalProducer<(Response, UserInfo), Error> {
        return fetchOne(.userInfo(login: login))
    }

    /// Fetch the currently authenticated user
    public func authenticatedUser() -> SignalProducer<(Response, UserInfo), Error> {
        return fetchOne(.authenticatedUser)
    }

    public func assignedIssues(page: UInt = 1, perPage: UInt = 30) -> SignalProducer<(Response, [Issue]), Error> {
        return fetchMany(.assignedIssues, page: page, pageSize: perPage)
    }

    public func issues(in repository: Repository, page: UInt = 1, perPage: UInt = 30) -> SignalProducer<(Response, [Issue]), Error> {
        precondition(repository.server == server)
        return fetchMany(.issuesInRepository(owner: repository.owner, repository: repository.name), page: page, pageSize: perPage)
    }

    /// Fetch the comments posted on an issue
    public func comments(onIssue issue: Int, in repository: Repository, page: UInt = 1, perPage: UInt = 30) -> SignalProducer<(Response, [Comment]), Error> {
        precondition(repository.server == server)
        return fetchMany(.commentsOnIssue(number: issue, owner: repository.owner, repository: repository.name), page: page, pageSize: perPage)
    }

    /// Fetch the authenticated user's repositories
    public func repositories(page: UInt = 1, perPage: UInt = 30) -> SignalProducer<(Response, [RepositoryInfo]), Error> {
        return fetchMany(.repositories, page: page, pageSize: perPage)
    }

    /// Fetch the repositories for a specific user
    public func repositories(forUser user: String, page: UInt = 1, perPage: UInt = 30) -> SignalProducer<(Response, [RepositoryInfo]), Error> {
        return fetchMany(.repositoriesForUser(user: user), page: page, pageSize: perPage)
    }

    /// Fetch the repositories for a specific organisation 
    public func repositories(forOrganization organization: String, page: UInt = 1, perPage: UInt = 30) -> SignalProducer<(Response, [RepositoryInfo]), Error> {
        return fetchMany(.repositoriesForOrganization(organization: organization), page: page, pageSize: perPage)
    }

    /// Fetch the public repositories on Github
    public func publicRepositories(page: UInt = 1, perPage: UInt = 30) -> SignalProducer<(Response, [RepositoryInfo]), Error> {
        return fetchMany(.publicRepositories, page: page, pageSize: perPage)
    }

    /// Fetch the content for a path in the repository
    public func content(atPath path: String, in repository: Repository, atRef ref: String? = nil) -> SignalProducer<(Response, Content), Error> {
        return fetchOne(.content(owner: repository.owner, repository: repository.name, path: path, ref: ref))
    }

    /// Create a file in a repository
    public func create(file: File, atPath path: String, in repository: Repository, inBranch branch: String? = nil) -> SignalProducer<(Response, FileResponse), Error> {
        return send(file, to: .content(owner: repository.owner, repository: repository.name, path: path, ref: branch), using: .put)
    }

    /// Update a file in a repository
    public func update(file: File, atPath path: String, sha: SHA, in repository: Repository, inBranch branch: String? = nil) -> SignalProducer<(Response, FileResponse), Error> {
        let update = Update(file: file, path: path, sha: sha)
        return send(update, to: .content(owner: repository.owner, repository: repository.name, path: path, ref: branch), using: .put)
    }

    /// Get branches for a repository
    public func branches(in repository: Repository, page: UInt = 1, perPage: UInt = 30) -> SignalProducer<(Response, [Branch]), Error> {
        return fetchMany(.branches(owner: repository.owner, repository: repository.name), page: page, pageSize: perPage)
    }

    /// Fetch an endpoint from the API.
    private func fetch(_ endpoint: Endpoint, page: UInt?, pageSize: UInt?) -> SignalProducer<(Response, Any), Error> {
        let url = URL(server, endpoint, page: page, pageSize: pageSize)

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
        (_ endpoint: Endpoint) -> SignalProducer<(Response, Resource), Error> where Resource.DecodedType == Resource
    {
        return fetch(endpoint, page: nil, pageSize: nil)
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
        (_ endpoint: Endpoint, page: UInt?, pageSize: UInt?) -> SignalProducer<(Response, [Resource]), Error> where Resource.DecodedType == Resource
    {
        let nextPage = (page ?? 1) + 1
        return fetch(endpoint, page: page, pageSize: pageSize)
            .attemptMap { response, JSON in
                return decode(JSON)
                    .map { resource in
                        (response, resource)
                    }
                    .mapError(Error.jsonDecodingError)
            }
            .flatMap(.concat) { response, JSON -> SignalProducer<(Response, [Resource]), Error> in
                return SignalProducer(value: (response, JSON))
                    .concat(response.links["next"] == nil ? SignalProducer.empty : self.fetchMany(endpoint, page: nextPage, pageSize: pageSize))
            }
    }

    internal func send<Request: RequestType>(_ request: Request, to endpoint: Endpoint, using method: HTTPMethod) -> SignalProducer<(Response, Request.Response), Error> where Request.Response == Request.Response.DecodedType {
        let urlRequest = URLRequest.create(URL(server, endpoint), request, method, credentials)

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

extension Client.Endpoint: Hashable {
    internal static func ==(lhs: Client.Endpoint, rhs: Client.Endpoint) -> Bool {
        switch (lhs, rhs) {
        case let (.releaseByTagName(owner1, repo1, tag1), .releaseByTagName(owner2, repo2, tag2)):
            return owner1 == owner2 && repo1 == repo2 && tag1 == tag2
        case let (.releasesInRepository(owner1, repo1), .releasesInRepository(owner2, repo2)):
            return owner1 == owner2 && repo1 == repo2
        case let (.userInfo(login1), .userInfo(login2)):
            return login1 == login2
        default:
            return false
        }
    }

    internal var hashValue: Int {
        switch self {
        case let .releaseByTagName(owner, repo, tag):
            return owner.hashValue ^ repo.hashValue ^ tag.hashValue
        case let .releasesInRepository(owner, repo):
            return owner.hashValue ^ repo.hashValue
        case let .userInfo(login):
            return login.hashValue
        case .assignedIssues:
            return "AssignedIssues".hashValue
        case .issuesInRepository(let owner, let repository):
            return "Issues".hashValue ^ owner.hashValue ^ repository.hashValue
        case .commentsOnIssue(let issue, let owner, let repository):
            return issue.hashValue ^ owner.hashValue ^ repository.hashValue
        case .authenticatedUser:
            return "authenticated-user".hashValue
        case .repositories:
            return "Repositories".hashValue
        case .repositoriesForUser(let user):
            return user.hashValue
        case .repositoriesForOrganization(let organisation):
            return organisation.hashValue
        case .publicRepositories:
            return "PublicRepositories".hashValue
        case let .content(owner, repository, path, ref):
            return "File".hashValue ^ owner.hashValue ^ repository.hashValue ^ path.hashValue ^ (ref?.hashValue ?? 0)
        case let .branches(owner, repository):
            return "Branches".hashValue ^ owner.hashValue ^ repository.hashValue
        }
    }
}
