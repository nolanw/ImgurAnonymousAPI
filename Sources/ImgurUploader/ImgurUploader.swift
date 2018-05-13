// Public domain. https://github.com/nolanw/ImgurUploader

import Foundation

// something something credits. something something client vs. user credits. something something post credits. something something 5 times in a month = banned for the month.
public final class ImgurUploader {

    // link to the "register an application" page? reiterate "non-commercial usage only"?
    public init(clientID: String) {
        queue = OperationQueue()
        queue.name = "com.nolanw.ImgurUploader"

        urlSession = URLSession(configuration: {
            let config = URLSessionConfiguration.ephemeral
            config.httpAdditionalHeaders = ["Authorization": "Client-ID \(clientID)"]
            return config
        }())
    }

    public static var logger: ((_ level: LogLevel, _ message: () -> String) -> Void)?

    public enum Error: Swift.Error {
        case invalidClientID
        case noUploadableImageFromImagePicker
    }

    public enum LogLevel: Comparable {
        case debug, info, error

        public static func < (lhs: LogLevel, rhs: LogLevel) -> Bool {
            switch (lhs, rhs) {
            case (.debug, .info), (.debug, .error):
                return true
            case (.info, .error):
                return true
            case (.debug, _), (.info, _), (.error, _):
                return false
            }
        }
    }

    // Implementation details :)
    private let queue: OperationQueue
    private let urlSession: URLSession
}

internal func log(_ level: ImgurUploader.LogLevel, _ message: @autoclosure () -> String) {
    ImgurUploader.logger?(level, message)
}

// MARK: - Photos.framework support

#if canImport(Photos)
import Photos

@available(macOS 10.13, *)
extension ImgurUploader {

    // uses rate limit credits
    // returned progress supports cancellation
    // completion block called on main queue
    @discardableResult
    public func upload(_ asset: PHAsset, completion: @escaping (_ result: Result<UploadResponse>) -> Void) -> Progress {
        let upload = UploadFormData()
        let ops: [Operation] = [
            MakeTempFolder(),
            SavePHAsset(),
            WriteMultipartFormData(),
            upload,
            DeleteTempFolder()]

        for (one, two) in zip(ops, ops.dropFirst()) {
            one.addDependency(two)
        }

        log(.debug, "starting upload of \(asset)")
        queue.addOperations(ops, waitUntilFinished: false)

        let progress = Progress(totalUnitCount: 1)
        progress.cancellationHandler = {
            log(.debug, "cancelling upload of \(asset)")
            for op in ops {
                op.cancel()
            }
        }

        let completionOp = BlockOperation {
            let result = upload.result!
            log(.debug, "finishing upload of \(asset) with \(result)")
            progress.completedUnitCount = 1
            completion(result)
        }
        completionOp.addDependency(ops.last!)
        OperationQueue.main.addOperation(completionOp)

        return progress
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
    @discardableResult
    public func upload(_ image: UIImage, completion: @escaping (_ result: Result<UploadResponse>) -> Void) -> Progress {
        let upload = UploadFormData()
        let ops: [Operation] = [
            MakeTempFolder(),
            SaveUIImage(),
            WriteMultipartFormData(),
            upload,
            DeleteTempFolder()]

        for (one, two) in zip(ops, ops.dropFirst()) {
            one.addDependency(two)
        }

        log(.debug, "starting upload of \(image)")
        queue.addOperations(ops, waitUntilFinished: false)

        let progress = Progress(totalUnitCount: 1)
        progress.cancellationHandler = {
            log(.debug, "cancelling upload of \(image)")
            for op in ops {
                op.cancel()
            }
        }

        let completionOp = BlockOperation {
            let result = upload.result!
            log(.debug, "finishing upload of \(image) with \(result)")
            progress.completedUnitCount = 1
            completion(result)
        }
        completionOp.addDependency(ops.last!)
        OperationQueue.main.addOperation(completionOp)

        return progress
    }

    // returned progress supports cancellation
    // completion block called on main queue
    @discardableResult
    public func upload(_ info: UIImagePickerControllerInfo, completion: @escaping (_ result: Result<UploadResponse>) -> Void) -> Progress {

        var asset: PHAsset? {
            if #available(iOS 11.0, *), let asset = info[UIImagePickerControllerPHAsset] as? PHAsset {
                return asset
            } else if let assetURL = info[UIImagePickerControllerReferenceURL] as? URL {
                return PHAsset.fetchAssets(withALAssetURLs: [assetURL], options: nil).firstObject
            } else {
                return nil
            }
        }

        var image: UIImage? {
            return info[UIImagePickerControllerEditedImage] as? UIImage
                ?? info[UIImagePickerControllerOriginalImage] as? UIImage
        }

        if let asset = asset {
            return upload(asset, completion: completion)
        } else if let image = image {
            return upload(image, completion: completion)
        } else {
            log(.error, "no uploadable images from image picker info: \(info)")
            let progress = Progress(totalUnitCount: 1)
            progress.completedUnitCount = 1

            OperationQueue.main.addOperation {
                completion(.failure(ImgurUploader.Error.noUploadableImageFromImagePicker))
            }

            return progress
        }
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

        public var value: T? {
            switch self {
            case .success(let value):
                return value
            case .failure:
                return nil
            }
        }
    }

    // blah blah parsed HTTP response from Imgur
    public struct UploadResponse {
        public let id: String
        public let link: URL
        public let postLimit: PostLimit? // optional because if the info is missing or formatted unexpectedly it doesn’t mean the upload failed
        public let rateLimit: RateLimit? // optional for same reason as above
    }
}

internal typealias Result = ImgurUploader.Result

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
    @discardableResult
    public func checkRateLimitStatus(completion: @escaping (_ result: Result<RateLimit>) -> Void) -> Progress {
        let request = URLRequest(url: URL(string: "https://api.imgur.com/3/credits")!)
        let op = FetchURL<RateLimit>(urlSession: urlSession, request: request)
        log(.debug, "checking rate limit status")
        queue.addOperation(op)

        let progress = Progress(totalUnitCount: 1)
        progress.cancellationHandler = {
            log(.debug, "cancelling checking rate limit status")
            op.cancel()
        }

        let completionOp = BlockOperation {
            let result = op.result!
            log(.debug, "did check rate limit status with \(result)")
            progress.completedUnitCount = 1
            completion(result)
        }
        completionOp.addDependency(op)

        OperationQueue.main.addOperation(completionOp)

        return progress
    }

    // blah blah client vs. user rate limit etc.
    public struct RateLimit: Decodable {
        public let clientAllocation: Int
        public let clientRemaining: Int
        // there’s no client reset date but it’s a "per day" thing (not sure what time zone)
        public let userAllocation: Int
        public let userRemaining: Int
        public let userResetDate: Date

        private enum CodingKeys: String, CodingKey {
            case clientAllocation = "ClientLimit"
            case clientRemaining = "ClientRemaining"
            case userAllocation = "UserLimit"
            case userRemaining = "UserRemaining"
            case userResetDate = "UserReset"
        }
    }
}

// MARK: - Delete uploaded images

extension ImgurUploader {

    // (presumably) uses credits
    // returned progress supports cancellation
    // completion block called on main queue
    @discardableResult
    public func delete(_ deleteHash: DeleteHash, completion: @escaping (_ result: Result<Void>) -> Void) -> Progress {
        let url = URL(string: "https://api.imgur.com/3/image/")!
            .appendingPathComponent(deleteHash.rawValue, isDirectory: false)
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"

        let op = FetchURL<Bool>(urlSession: urlSession, request: request)
        log(.debug, "deleting image with \(deleteHash)")
        queue.addOperation(op)

        let progress = Progress(totalUnitCount: 1)
        progress.cancellationHandler = {
            log(.debug, "cancelling deletion with \(deleteHash)")
            op.cancel()
        }

        let completionOp = BlockOperation {
            let result: Result<Void>
            switch op.result! {
            case .success:
                result = .success(())
            case .failure(let error):
                result = .failure(error)
            }

            log(.debug, "did delete image with \(deleteHash)")
            progress.completedUnitCount = 1
            completion(result)
        }
        completionOp.addDependency(op)

        OperationQueue.main.addOperation(completionOp)

        return progress
    }

    public struct DeleteHash: RawRepresentable {
        public let rawValue: String

        public init(rawValue: String) {
            self.rawValue = rawValue
        }
    }
}
