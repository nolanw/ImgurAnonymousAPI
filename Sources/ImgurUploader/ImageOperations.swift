//
//  ImageOperations.swift
//  ImgurUploader
//
//  Created by Nolan Waite on 2018-05-13.
//  Copyright © 2018 Nolan Waite. All rights reserved.
//

import Foundation
import ImageIO

internal struct ImageFile {
    let url: URL
}

internal enum ImageError: Error {
    case destinationCreationFailed
    case indeterminateFileSize
    case missingCGImage
    case missingPhotoResource
    case sourceCreationFailed
}

// Haven't tested whether they mean 10^6, 2^20, or something else so we'll pick the smallest.
private let tenMegabytes = 10_000_000

internal final class ResizeImage: AsynchronousOperation<ImageFile> {
    override func execute() throws {
        let tempFolder = try firstDependencyValue(ofType: TemporaryFolder.self)
        let originalImage = try firstDependencyValue(ofType: ImageFile.self)
        log(.debug, "someone wants to resize \(originalImage) in \(tempFolder)")

        guard let originalByteSize = try originalImage.url.resourceValues(forKeys: [.fileSizeKey]).fileSize else {
            throw ImageError.indeterminateFileSize
        }

        if originalByteSize <= tenMegabytes {
            log(.debug, "original image is within the file size limit so there's nothing to resize")
            return finish(.success(originalImage))
        } else {
            log(.debug, "original image is too large, will need to resize")
        }

        guard let imageSource = CGImageSourceCreateWithURL(originalImage.url as CFURL, nil) else {
            throw ImageError.sourceCreationFailed
        }

        var resizedImageURL = tempFolder.url
            .appendingPathComponent("resized", isDirectory: false)
            .appendingPathExtension(originalImage.url.pathExtension)

        // Is kCGImageSourceSubsampleFactor superior to kCGImageSourceThumbnailMaxPixelSize? No idea! Sounds good though so let's try it first. Probably worth testing someday.
        for factor in [2, 4, 8] {
            guard
                let thumbnail = CGImageSourceCreateThumbnailAtIndex(imageSource, 0, [
                    kCGImageSourceCreateThumbnailFromImageAlways: true,
                    kCGImageSourceCreateThumbnailWithTransform: true,
                    kCGImageSourceSubsampleFactor: factor] as NSDictionary),
                let destination = CGImageDestinationCreateWithURL(resizedImageURL as CFURL, CGImageSourceGetType(imageSource) ?? kUTTypePNG, 1, nil)
                else { continue }

            CGImageDestinationAddImage(destination, thumbnail, nil)
            guard CGImageDestinationFinalize(destination) else { break }

            resizedImageURL.removeCachedResourceValue(forKey: .fileSizeKey)
            guard
                let resourceValues = try? resizedImageURL.resourceValues(forKeys: [.fileSizeKey]),
                let byteSize = resourceValues.fileSize
                else { break }

            if byteSize <= tenMegabytes {
                log(.debug, "scaled image by a factor of \(factor) is within the file size limit")
                return finish(.success(ImageFile(url: resizedImageURL)))
            } else if byteSize > originalByteSize {
                log(.debug, "subsample factor is producing a larger image, this ain't working")
                break
            }
        }

        log(.error, "subsample failed to produce an image within the file size limit, so it's time do a plain ol' resize using kCGImageSourceThumbnailMaxPixelSize")

        throw CocoaError.error(.userCancelled)
    }
}

#if canImport(Photos)
import Photos

internal final class SavePHAsset: AsynchronousOperation<ImageFile> {
    private let asset: PHAsset

    init(_ asset: PHAsset) {
        self.asset = asset
    }

    override func execute() throws {
        let tempFolder = try firstDependencyValue(ofType: TemporaryFolder.self)

        let resources = PHAssetResource.assetResources(for: asset)
        guard
            let photo = resources.first(where: { $0.type == .fullSizePhoto })
            ?? resources.first(where: { $0.type == .photo })
            else { throw ImageError.missingPhotoResource }

        let imageURL: URL = {
            if photo.originalFilename.isEmpty {
                let ext = UTTypeCopyPreferredTagWithClass(photo.uniformTypeIdentifier as CFString, kUTTagClassFilenameExtension)?.takeRetainedValue() as String? ?? "jpg"
                return tempFolder.url
                    .appendingPathComponent("original", isDirectory: false)
                    .appendingPathExtension(ext)
            } else {
                return tempFolder.url
                    .appendingPathComponent(photo.originalFilename, isDirectory: false)
            }
        }()

        let options = PHAssetResourceRequestOptions()
        options.isNetworkAccessAllowed = true

        log(.debug, "saving \(asset) to \(imageURL)")
        PHAssetResourceManager.default().writeData(for: photo, toFile: imageURL, options: options, completionHandler: { error in
            if let error = error {
                self.finish(.failure(error))
            } else {
                self.finish(.success(ImageFile(url: imageURL)))
            }
        })
    }
}

#endif

#if canImport(UIKit)
import MobileCoreServices
import UIKit

internal final class SaveUIImage: AsynchronousOperation<ImageFile> {
    private let image: UIImage

    init(_ image: UIImage) {
        self.image = image
    }

    override func execute() throws {
        let tempFolder = try firstDependencyValue(ofType: TemporaryFolder.self)
        let imageURL = tempFolder.url.appendingPathComponent("original.png", isDirectory: false)

        guard let cgImage = image.cgImage else {
            throw ImageError.missingCGImage
        }

        guard let destination = CGImageDestinationCreateWithURL(imageURL as CFURL, kUTTypePNG, 1, nil) else {
            throw ImageError.destinationCreationFailed
        }

        CGImageDestinationAddImage(destination, cgImage, {
            var options: [AnyHashable: Any] = [:]

            options[kCGImagePropertyHasAlpha] = true

            options[kCGImagePropertyOrientation] = image.imageOrientation.cgOrientation.rawValue

            if #available(iOS 9.3, *) {
                options[kCGImageDestinationOptimizeColorForSharing] = true
            }

            return options as NSDictionary
        }())

        log(.debug, "saving \(image) to \(imageURL)")
        CGImageDestinationFinalize(destination)

        finish(.success(ImageFile(url: imageURL)))
    }
}

private extension UIImageOrientation {
    var cgOrientation: CGImagePropertyOrientation {
        switch self {
        case .up:
            return .up
        case .down:
            return .down
        case .left:
            return .left
        case .right:
            return .right
        case .upMirrored:
            return .upMirrored
        case .downMirrored:
            return .downMirrored
        case .leftMirrored:
            return .leftMirrored
        case .rightMirrored:
            return .rightMirrored
        }
    }
}

#endif
