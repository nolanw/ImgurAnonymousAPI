//
//  AsynchronousOperation.swift
//  ImgurUploader
//
//  Created by Nolan Waite on 2018-05-13.
//  Copyright © 2018 Nolan Waite. All rights reserved.
//

import Foundation

internal class AsynchronousOperation<T>: Foundation.Operation {
    private let queue = DispatchQueue(label: "com.nolanw.ImgurUploader.async-operation-state", attributes: .concurrent)
    private(set) var result: Result<T>?
    private var _state: AsynchronousOperationState = .ready

    @objc private dynamic var state: AsynchronousOperationState {
        get { return queue.sync { _state } }
        set {
            willChangeValue(for: \.state)
            queue.sync(flags: .barrier) {
                log(.debug, "operation \(self) is now \(newValue)")
                _state = newValue
            }
            didChangeValue(for: \.state)
        }
    }

    final override var isReady: Bool {
        return super.isReady && state == .ready
    }

    final override var isExecuting: Bool {
        return state == .executing
    }

    final override var isFinished: Bool {
        return state == .finished
    }

    final override var isAsynchronous: Bool {
        return true
    }

    override class func keyPathsForValuesAffectingValue(forKey key: String) -> Set<String> {
        var keyPaths = super.keyPathsForValuesAffectingValue(forKey: key)
        switch key {
        case "isExecuting", "isFinished", "isReady":
            keyPaths.insert("state")
        default:
            break
        }
        return keyPaths
    }

    override func start() {
        super.start()

        if isCancelled {
            return finish(.failure(CocoaError.error(.userCancelled)))
        }

        state = .executing
        do {
            try execute()
        } catch {
            finish(.failure(error))
        }
    }

    func execute() throws {
        fatalError("\(type(of: self)) must override \(#function)")
    }

    final func finish(_ result: Result<T>) {
        self.result = result
        state = .finished
    }
}

extension AsynchronousOperation {
    func firstDependency<T>(of operationType: T.Type) throws -> T {
        if let op = dependencies.lazy.compactMap({ $0 as? T }).first {
            return op
        } else {
            throw MissingDependency(dependentOperationType: T.self)
        }
    }

    struct MissingDependency: Error {
        let dependentOperationType: Any.Type
    }
}

@objc private enum AsynchronousOperationState: Int, CustomStringConvertible {
    case ready, executing, finished

    var description: String {
        switch self {
        case .ready: return "ready"
        case .executing: return "executing"
        case .finished: return "finished"
        }
    }
}
