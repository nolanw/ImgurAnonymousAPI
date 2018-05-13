//
//  WriteMultipartFormData.swift
//  ImgurUploader
//
//  Created by Nolan Waite on 2018-05-13.
//  Copyright © 2018 Nolan Waite. All rights reserved.
//

internal final class WriteMultipartFormData: AsynchronousOperation<Void> {
    override func execute() throws {
        throw CocoaError.error(.userCancelled)
    }
}
