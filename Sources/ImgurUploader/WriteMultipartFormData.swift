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

internal enum WriteError: Error {
    case couldNotReadImageFile
    case couldNotReadPartOfImageFile
    case failedWritingBottomData
    case failedWritingImageToOutputFile
    case failedWritingToOutputFile
    case failedWritingTopData
}

internal final class WriteMultipartFormData: AsynchronousOperation<FormDataFile> {
    override func execute() throws {
        let tempFolder = try firstDependencyValue(ofType: TemporaryFolder.self)
        let imageFile = try firstDependencyValue(ofType: ImageFile.self)

        let uti = CGImageSourceCreateWithURL(imageFile.url as CFURL, nil)
            .flatMap { CGImageSourceGetType($0) }
        let mimeType = uti
            .flatMap { UTTypeCopyPreferredTagWithClass($0, kUTTagClassMIMEType)?.takeRetainedValue() as String? }
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
                    return self.finish(.failure(WriteError.failedWritingToOutputFile))
                }
        })

        let topData = makeTopData(boundary: boundary, mimeType: mimeType)
        output.write(offset: 0, data: topData, queue: queue, ioHandler: { done, data, error in
            if done {
                if error == 0 {
                    log(.debug, "finished writing start")
                } else {
                    log(.error, "couldn't write top data: error \(error)")
                    return self.finish(.failure(WriteError.failedWritingTopData))
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
                    return self.finish(.failure(WriteError.couldNotReadImageFile))
                }
        })

        input.read(offset: 0, length: Int(bitPattern: SIZE_MAX), queue: queue, ioHandler: { readDone, readData, readError in
            log(.debug, "read some image file! done = \(readDone), byte count = \(readData?.count as Any), error = \(readError)")

            if readDone, readError != 0 {
                log(.error, "couldn't read some of image file at \(imageFile.url): \(readError)")
                output.close(flags: .stop)
                return self.finish(.failure(WriteError.couldNotReadPartOfImageFile))
            }

            if let data = readData {
                output.write(offset: 0, data: data, queue: queue, ioHandler: { writeDone, writeData, writeError in
                    if writeDone {
                        if writeError == 0 {
                            log(.debug, "wrote some of image file")
                        } else {
                            log(.error, "couldn't write some of image file to \(requestBodyURL): \(writeError)")
                            input.close(flags: .stop)
                            return self.finish(.failure(WriteError.failedWritingImageToOutputFile))
                        }
                    }
                })
            }

            if readDone {
                writeBottom()
            }
        })

        func writeBottom() {
            let bottomData = makeBottomData(boundary: boundary)
            output.write(offset: 0, data: bottomData, queue: queue, ioHandler: { done, data, error in
                if done {
                    if error == 0 {
                        return self.finish(.success(FormDataFile(boundary: boundary, url: requestBodyURL)))
                    } else {
                        log(.error, "couldn't write bottom data: error \(error)")
                        return self.finish(.failure(WriteError.failedWritingBottomData))
                    }
                }
            })
        }
    }
}

private func makeBoundary() -> String {
    let randos = (0..<16).map { _ in return boundaryDigits.randomElement }
    return String(randos)
}

private let boundaryDigits = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789"

private func makeTopData(boundary: String, mimeType: String) -> DispatchData {
    let top = [
        "--\(boundary)",
        "Content-Disposition: form-data; name=\"image\"; filename=\"image\"",
        "Content-Type: \(mimeType)",
        "\r\n",
        ]
        .joined(separator: "\r\n")
        .data(using: .utf8)!
    return top.withUnsafeBytes {
        DispatchData(bytes: UnsafeRawBufferPointer(start: $0, count: top.count))
    }
}

private func makeBottomData(boundary: String) -> DispatchData {
    let end = "\r\n--\(boundary)--".data(using: .utf8)!
    return end.withUnsafeBytes {
        DispatchData(bytes: UnsafeRawBufferPointer(start: $0, count: end.count))
    }
}

private extension Collection {
    var randomElement: Element {
        return self[index(startIndex, offsetBy: Int(arc4random_uniform(UInt32(count))))]
    }
}
