//
//  TemporaryFolderOperations.swift
//  ImgurUploader
//
//  Created by Nolan Waite on 2018-05-13.
//  Copyright © 2018 Nolan Waite. All rights reserved.
//

import Foundation

internal final class MakeTempFolder: AsynchronousOperation<URL> {
    override func execute() throws {
        let url = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
        log(.debug, "creating temporary folder at \(url)")
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true, attributes: nil)

        log(.debug, "did create temporary folder at \(url)")
        finish(.success(url))
    }
}

internal final class DeleteTempFolder: AsynchronousOperation<Bool> {
    override func execute() throws {
        let makeOp = try firstDependency(of: MakeTempFolder.self)

        guard let url = makeOp.result?.value else {
            log(.debug, "could not find temporary URL among dependencies")
            return finish(.success(false))
        }

        do {
            log(.debug, "deleting temporary folder at \(url)")
            try FileManager.default.removeItem(at: url)

            log(.debug, "did delete temporary folder at \(url)")
            finish(.success(true))
        } catch let error as CocoaError where error.code == .fileNoSuchFile {
            log(.debug, "nothing to delete at \(url)")
            finish(.success(true))
        } catch {
            log(.info, "failed to delete temporary folder at \(url), ignoring \(error)")
            finish(.success(false))
        }
    }
}
