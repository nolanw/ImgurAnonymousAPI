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
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true, attributes: nil)
        finish(.success(url))
    }
}

internal final class DeleteTempFolder: AsynchronousOperation<Bool> {
    override func execute() throws {
        let makeOp = try firstDependency(of: MakeTempFolder.self)

        guard let url = makeOp.result?.value else {
            return finish(.success(false))
        }

        do {
            try FileManager.default.removeItem(at: url)
            finish(.success(true))
        } catch {
            finish(.success(false))
        }
    }
}
