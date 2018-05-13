//
//  ImageOperations.swift
//  ImgurUploader
//
//  Created by Nolan Waite on 2018-05-13.
//  Copyright © 2018 Nolan Waite. All rights reserved.
//

#if canImport(Photos)
import Foundation
import Photos

internal final class SavePHAsset: AsynchronousOperation<URL> {
    override func execute() throws {
        throw CocoaError.error(.userCancelled)
    }
}

#endif

#if canImport(UIKit)
import UIKit

internal final class SaveUIImage: AsynchronousOperation<URL> {
    override func execute() throws {
        throw CocoaError.error(.userCancelled)
    }
}

#endif
