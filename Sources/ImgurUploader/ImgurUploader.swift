// Public domain. https://github.com/nolanw/ImgurUploader

import Foundation

// something something credits. something something client vs. user credits. something something post credits. something something 5 times in a month = banned for the month.
public final class ImgurUploader {

    // link to the "register an application" page? reiterate "non-commercial usage only"?
    public init(clientID: String) {
        urlSession = URLSession(configuration: {
            let config = URLSessionConfiguration.ephemeral
            config.httpAdditionalHeaders = ["Authorization": "Client-ID \(clientID)"]
            return config
        }())
    }

    // Implementation detail :)
    private let urlSession: URLSession
}

// MARK: - Photos.framework support

#if canImport(Photos)
import Photos

@available(macOS 10.13, *)
extension ImgurUploader {

    // uses rate limit credits
    // returned progress supports cancellation
    // completion block called on main queue
    public func upload(_ asset: PHAsset, completion: (_ result: Result<UploadResponse>) -> Void) -> Progress {
        return .init()
    }
}
#endif

// MARK: - UIKit support

#if canImport(UIKit)
import UIKit

extension ImgurUploader {
    // uses rate limit credits
    // returned progress supports cancellation
    // completion block called on main queue
    public func upload(_ image: UIImage, completion: (_ result: Result<UploadResponse>) -> Void) -> Progress {
        return .init()
    }

    // returned progress supports cancellation
    // completion block called on main queue
    public func upload(_ info: UIImagePickerControllerInfo, completion: (_ result: Result<UploadResponse>) -> Void) -> Progress {
        return .init()
    }

    // mention UIImagePickerControllerDelegate etc.?
    public typealias UIImagePickerControllerInfo = [String: Any]
}
#endif

// MARK: - Upload types

extension ImgurUploader {

    // blah blah error may be CocoaError.userCancelled (check if that's actually a type?) or ImgurUploader.Error or probably other things
    public enum Result<T> {
        case success(T)
        case failure(Swift.Error)
    }

    // blah blah parsed HTTP response from Imgur
    public struct UploadResponse {
        public let id: String
        public let link: URL
        public let postLimit: PostLimit? // optional because if the info is missing or formatted unexpectedly it doesn’t mean the upload failed
        public let rateLimit: RateLimit? // optional for same reason as above
    }

    public enum Error: Swift.Error {
        case invalidClientID
    }
}

// MARK: - Rate limiting

extension ImgurUploader {

    // blah blah upload responses include a POST limit, explain how that works (hourly? from IP address? check docs)
    public struct PostLimit {
        public let allocation: Int
        public let remaining: Int
        public let timeUntilReset: TimeInterval
    }

    // does not seem to use credits (thankfully)
    // does not include POST limits
    // returned progress supports cancellation
    // completion block called on main queue
    public func checkRateLimitStatus(completion: (_ result: Result<RateLimit>) -> Void) -> Progress {
        return .init()
    }

    // blah blah client vs. user rate limit etc.
    public struct RateLimit {
        public let clientAllocation: Int
        public let clientRemaining: Int
        // there’s no client reset date but it’s a "per day" thing (not sure what time zone)
        public let userAllocation: Int
        public let userRemaining: Int
        public let userResetDate: Date
    }
}

// MARK: - Delete uploaded images

extension ImgurUploader {

    // (presumably) uses credits
    // returned progress supports cancellation
    // completion block called on main queue
    public func delete(_ deleteHash: DeleteHash, completion: (_ result: Result<Void>) -> Void) -> Progress {
        return .init()
    }

    public struct DeleteHash: RawRepresentable {
        public let rawValue: String
        public init(rawValue: String) { self.rawValue = rawValue }
    }
}

// MARK: - Exciting implementation details!
