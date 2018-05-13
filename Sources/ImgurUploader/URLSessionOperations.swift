//
//  URLSessionOperations.swift
//  ImgurUploader
//
//  Created by Nolan Waite on 2018-05-13.
//  Copyright © 2018 Nolan Waite. All rights reserved.
//

import Foundation

internal final class FetchURL<T: Decodable>: AsynchronousOperation<T> {
    private var task: URLSessionDataTask?

    enum Error: Swift.Error {
        case missingData
    }

    struct APIResponse<T: Decodable>: Decodable {
        let data: Either<T, APIError>
        let status: Int
        let success: Bool
    }

    struct APIError: Decodable, Swift.Error {
        let error: String

        var localizedDescription: String { return error }
    }

    enum Either<T: Decodable, U: Decodable>: Decodable {
        case left(T), right(U)

        init(from decoder: Decoder) throws {
            do {
                self = .left(try T(from: decoder))
            } catch {
                self = .right(try U(from: decoder))
            }
        }
    }

    init(urlSession: URLSession, request: URLRequest) {
        super.init()

        task = urlSession.dataTask(with: request) { data, response, error in
            if let error = error {
                return self.finish(.failure(error))
            }

            guard let data = data else {
                return self.finish(.failure(Error.missingData))
            }

            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .secondsSince1970

            do {
                let response = try decoder.decode(APIResponse<T>.self, from: data)
                switch response.data {
                case .left(let value):
                    self.finish(.success(value))
                case .right(let error):
                    self.finish(.failure(error))
                }
            } catch {
                self.finish(.failure(error))
            }
        }
    }

    override func execute() throws {
        log(.debug, "starting \(self) with url \(task?.originalRequest?.url as Any)")
        task?.resume()
    }

    override func cancel() {
        task?.cancel()
        super.cancel()
    }
}

internal final class UploadFormData: AsynchronousOperation<ImgurUploader.UploadResponse> {
    override func execute() throws {
        throw CocoaError.error(.userCancelled)
    }
}
