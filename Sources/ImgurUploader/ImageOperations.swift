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
    case destinationFinalizationFailed
    case indeterminateOriginalFileSize
    case indeterminateThumbnailFileSize
    case missingCGImage
    case missingPhotoResource
    case sourceCreationFailed
    case thumbnailCreationFailed
}

/**
 The documented file size limit for uploaded non-animated images.
 
 We have a couple of candidate sizes:
 
    * 10 MB, per https://api.imgur.com/endpoints/image#image-upload
    * 10 MB, per https://apidocs.imgur.com/#c85c9dfc-7487-4de2-9ecd-66f727cf3139
    * 20 MB, per https://help.imgur.com/hc/en-us/articles/115000083326
 
 As of 2018-11-04, an 18.7 MB file was rejected with "File is over the size limit", so I guess that rules out 20 MB. And a 10,018,523 byte file was similarly rejected, so 10^6 it is!
 */
private let imgurFileSizeLimit = 10_000_000

internal final class ResizeImage: AsynchronousOperation<ImageFile> {
    override func execute() throws {
        let tempFolder = try firstDependencyValue(ofType: TemporaryFolder.self)
        let originalImage = try firstDependencyValue(ofType: ImageFile.self)
        log(.debug, "someone wants to resize \(originalImage) in \(tempFolder)")

        guard let originalByteSize = try originalImage.url.resourceValues(forKeys: [.fileSizeKey]).fileSize else {
            throw ImageError.indeterminateOriginalFileSize
        }
        
        if originalByteSize <= imgurFileSizeLimit {
            log(.debug, "original image is within the file size limit so there's nothing to resize")
            return finish(.success(originalImage))
        } else {
            log(.debug, "original image is too large, will need to resize")
        }

        guard let imageSource = CGImageSourceCreateWithURL(originalImage.url as CFURL, nil) else {
            throw ImageError.sourceCreationFailed
        }
        
        var maxPixelSize: Int
        if
            let properties = CGImageSourceCopyPropertiesAtIndex(imageSource, 0, nil) as NSDictionary?,
            let width = properties[kCGImagePropertyPixelWidth] as? Int,
            let height = properties[kCGImagePropertyPixelHeight] as? Int
        {
            maxPixelSize = max(width, height) / 2
        } else {
            maxPixelSize = 2048 // Gotta start somewhere.
        }

        var resizedImageURL = tempFolder.url
            .appendingPathComponent("resized", isDirectory: false)
            .appendingPathExtension(originalImage.url.pathExtension)
        
        while true {
            guard
                let thumbnail = CGImageSourceCreateThumbnailAtIndex(imageSource, 0, [
                    kCGImageSourceCreateThumbnailFromImageAlways: true,
                    kCGImageSourceCreateThumbnailWithTransform: true,
                    kCGImageSourceThumbnailMaxPixelSize: maxPixelSize,
                    kCGImageSourceShouldCache: false] as NSDictionary),
                let destination = CGImageDestinationCreateWithURL(resizedImageURL as CFURL, CGImageSourceGetType(imageSource) ?? kUTTypePNG, 1, nil) else
            {
                log(.error, "thumbnail creation failed")
                throw ImageError.thumbnailCreationFailed
            }

            CGImageDestinationAddImage(destination, thumbnail, nil)
            guard CGImageDestinationFinalize(destination) else {
                log(.error, "thumbnail could not be saved")
                throw ImageError.destinationFinalizationFailed
            }

            resizedImageURL.removeCachedResourceValue(forKey: .fileSizeKey)
            guard
                let resourceValues = try? resizedImageURL.resourceValues(forKeys: [.fileSizeKey]),
                let byteSize = resourceValues.fileSize else
            {
                log(.error, "could not determine file size of generated thumbnail")
                throw ImageError.indeterminateThumbnailFileSize
            }

            if byteSize <= imgurFileSizeLimit {
                log(.debug, "scaled image down to \(maxPixelSize)px as its larger dimension, which gets it to \(byteSize) bytes, which is within the file size limit")
                return finish(.success(ImageFile(url: resizedImageURL)))
            }
        }
    }
}

#if canImport(Photos)
import Photos

internal final class SavePHAsset: AsynchronousOperation<ImageFile> {
    
    static var hasRequiredPhotoLibraryAuthorization: Bool {
        
        // "Apps linked on or after iOS 10 will crash if [the NSPhotoLibraryUsageDescription] key is not present."
        if #available(iOS 10.0, *), Bundle.main.infoDictionary?["NSPhotoLibraryUsageDescription"] == nil {
            return false
        }
        
        switch PHPhotoLibrary.authorizationStatus() {
        case .denied, .notDetermined, .restricted:
            return false
        case .authorized:
            return true
        }
    }
    
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
            var options: [AnyHashable: Any] = [
                kCGImagePropertyHasAlpha: true,
                kCGImagePropertyOrientation: image.imageOrientation.cgOrientation.rawValue]

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

private extension UIImage.Orientation {
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
