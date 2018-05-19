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
    case missingCGImage
    case missingPhotoResource
}

internal final class ResizeImage: AsynchronousOperation<ImageFile> {
    override func execute() throws {
        let tempFolder = try firstDependencyValue(ofType: TemporaryFolder.self)
        let originalImage = try firstDependencyValue(ofType: ImageFile.self)

        log(.info, "someone wants to resize \(originalImage) in \(tempFolder)")

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
