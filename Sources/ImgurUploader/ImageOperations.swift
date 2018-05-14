//
//  ImageOperations.swift
//  ImgurUploader
//
//  Created by Nolan Waite on 2018-05-13.
//  Copyright © 2018 Nolan Waite. All rights reserved.
//

import Foundation
import ImageIO

internal final class ResizeImage: AsynchronousOperation<URL> {
    override func execute() throws {
        throw CocoaError.error(.userCancelled)
    }
}

#if canImport(Photos)
import Photos

internal final class SavePHAsset: AsynchronousOperation<URL> {
    private let asset: PHAsset

    init(_ asset: PHAsset) {
        self.asset = asset
    }

    override func execute() throws {
        throw CocoaError.error(.userCancelled)
    }
}

#endif

#if canImport(UIKit)
import UIKit

internal final class SaveUIImage: AsynchronousOperation<URL> {
    private let image: UIImage

    init(_ image: UIImage) {
        self.image = image
    }

    override func execute() throws {
        throw CocoaError.error(.userCancelled)
    }
}

#endif
