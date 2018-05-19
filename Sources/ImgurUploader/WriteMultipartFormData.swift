//
//  WriteMultipartFormData.swift
//  ImgurUploader
//
//  Created by Nolan Waite on 2018-05-13.
//  Copyright © 2018 Nolan Waite. All rights reserved.
//

import Foundation

internal struct FormDataFile {
    let boundary: String
    let url: URL
}

internal final class WriteMultipartFormData: AsynchronousOperation<FormDataFile> {
    override func execute() throws {
        let tempFolder = try firstDependencyValue(ofType: TemporaryFolder.self)
        let imageFile = try firstDependencyValue(ofType: ImageFile.self)

        log(.info, "someone wants to write \(imageFile) as multipart/form-data to \(tempFolder)")

        throw CocoaError.error(.userCancelled)
    }
}
