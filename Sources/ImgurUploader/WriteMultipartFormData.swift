//
//  WriteMultipartFormData.swift
//  ImgurUploader
//
//  Created by Nolan Waite on 2018-05-13.
//  Copyright © 2018 Nolan Waite. All rights reserved.
//

import Foundation
import ImageIO
import MobileCoreServices

internal struct FormDataFile {
    let boundary: String
    let url: URL
}

internal final class WriteMultipartFormData: AsynchronousOperation<FormDataFile> {
    override func execute() throws {
        let tempFolder = try firstDependencyValue(ofType: TemporaryFolder.self)
        let imageFile = try firstDependencyValue(ofType: ImageFile.self)

        let uti = CGImageSourceCreateWithURL(imageFile.url as CFURL, nil)
            .flatMap { CGImageSourceGetType($0) }
        let mimeType = uti.flatMap { UTTypeCopyPreferredTagWithClass($0, kUTTagClassMIMEType)?.takeRetainedValue() as String? }
            ?? "application/octet-stream"

        let requestBodyURL = tempFolder.url
            .appendingPathComponent("request", isDirectory: false)
            .appendingPathExtension("dat")

        let boundary = makeBoundary()

        let queue = DispatchQueue(label: "ImgurUploader write multipart/form-data")
        let output = DispatchIO(
            __type: DispatchIO.StreamType.stream.rawValue,
            path: requestBodyURL.path,
            oflag: O_CREAT | O_WRONLY,
            mode: S_IRUSR | S_IWUSR | S_IRGRP | S_IROTH,
            queue: queue,
            handler: { error in
                if error == 0 {
                    log(.debug, "done writing at \(requestBodyURL)")
                } else {
                    log(.error, "could not create multipart/form-data request file at \(requestBodyURL)")
                }
        })

        let start = [
            "--\(boundary)",
            "Content-Disposition: form-data; name=\"image\"; filename=\"image\"",
            "Content-Type: \(mimeType)",
            "\r\n"]
            .joined(separator: "\r\n")
            .data(using: .utf8)!
        let topData = start.withUnsafeBytes { ptr in
            return DispatchData(bytes: UnsafeRawBufferPointer(start: ptr, count: start.count))
        }
        log(.debug, "writing \(start) to \(requestBodyURL)")
        output.write(offset: 0, data: topData, queue: queue, ioHandler: { done, data, error in
            if done {
                if error == 0 {
                    log(.debug, "finished writing start")
                } else {
                    log(.error, "couldn't write top data: error \(error)")
                }
            }
        })

        let input = DispatchIO(
            __type: DispatchIO.StreamType.stream.rawValue,
            path: imageFile.url.path,
            oflag: O_RDONLY,
            mode: 0,
            queue: queue,
            handler: { error in
                if error == 0 {
                    log(.debug, "done reading at \(imageFile.url)")
                } else {
                    log(.error, "couldn't open image file for copying: \(imageFile.url)")
                }
        })

        input.read(offset: 0, length: Int(bitPattern: SIZE_MAX), queue: queue, ioHandler: { done, data, error in
            log(.debug, "read some input! done = \(done), data = \(data as Any), error = \(error)")

            if error != 0 {
                log(.error, "couldn't read some of image file at \(imageFile.url): \(error)")
                input.close()
                output.close(flags: .stop)
                return
            }

            if let data = data {
                output.write(offset: 0, data: data, queue: queue, ioHandler: { done, data, error in
                    if error == 0 {
                        log(.debug, "wrote some of image file")
                    } else {
                        input.close(flags: .stop)
                        log(.error, "couldn't write some of image file to \(requestBodyURL): \(error)")
                    }
                })
            }

            if done {
                let end = "\r\n--\(boundary)--".data(using: .utf8)!
                let bottomData = end.withUnsafeBytes { ptr in
                    return DispatchData(bytes: UnsafeRawBufferPointer(start: ptr, count: end.count))
                }
                output.write(offset: 0, data: bottomData, queue: queue, ioHandler: { done, data, error in
                    if error != 0 {
                        log(.error, "couldn't write bottom data: error \(error)")
                    }

                    if done {
                        output.close()
                        self.finish(.success(FormDataFile(boundary: boundary, url: requestBodyURL)))
                    }
                })
            }
        })
    }
}

private func makeBoundary() -> String {
    let randos = (0..<16).map { _ in return boundaryDigits.randomElement }
    return String(randos)
}

private let boundaryDigits = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789"

private extension Collection {
    var randomElement: Element {
        return self[index(startIndex, offsetBy: Int(arc4random_uniform(UInt32(count))))]
    }
}
