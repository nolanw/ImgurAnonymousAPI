//
//  TemporaryFolderOperations.swift
//  ImgurUploader
//
//  Created by Nolan Waite on 2018-05-13.
//  Copyright © 2018 Nolan Waite. All rights reserved.
//

import Foundation

internal struct TemporaryFolder {
    let url: URL
}

internal final class MakeTempFolder: AsynchronousOperation<TemporaryFolder> {
    override func execute() throws {
        let url = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        log(.debug, "creating temporary folder at \(url)")
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true, attributes: nil)

        log(.debug, "did create temporary folder at \(url)")
        finish(.success(TemporaryFolder(url: url)))
    }
}

internal final class DeleteTempFolder: AsynchronousOperation<Void> {
    override func execute() throws {
        do {
            let tempFolder = try firstDependencyValue(ofType: TemporaryFolder.self)
            let url = tempFolder.url

            log(.debug, "deleting temporary folder at \(url)")
            try FileManager.default.removeItem(at: url)

            log(.debug, "did delete temporary folder at \(url)")
            finish(.success(()))
        } catch let error as CocoaError where error.code == .fileNoSuchFile {
            finish(.success(()))
        } catch {
            log(.info, "failed to delete temporary folder: \(error)")
            finish(.failure(error))
        }
    }
}
