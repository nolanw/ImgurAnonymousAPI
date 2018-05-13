//
//  ViewController.swift
//  iOSTestApp
//
//  Created by Nolan Waite on 2018-05-13.
//  Copyright © 2018 Nolan Waite. All rights reserved.
//

import ImgurUploader
import UIKit

final class ViewController: UIViewController {
    private var clientID: String = ""
    private var uploader: ImgurUploader?

    @IBOutlet private var controls: [UIControl]!
    @IBOutlet weak var resultsTextView: UITextView!

    @IBAction func didChangeClientID(_ sender: UITextField) {
        clientID = sender.text ?? ""
        uploader = nil
    }

    @IBAction func didTapCheckRateLimits(_ sender: Any) {
        do {
            let uploader = try obtainUploader()
            beginOperation()
            uploader.checkRateLimitStatus {
                self.endOperation($0)
            }
        } catch {
            alert(error)
        }
    }

    private func beginOperation() {
        view.endEditing(true)

        setIsEnabled(false)
    }

    private func endOperation<T>(_ result: ImgurUploader.Result<T>) {
        switch result {
        case .success(let value):
            self.resultsTextView.text = "hooray!\n\(value)"
        case .failure(let error):
            self.resultsTextView.text = "boo!\n\(error)"
        }

        setIsEnabled(true)
    }

    private func setIsEnabled(_ isEnabled: Bool) {
        for control in controls {
            control.isEnabled = isEnabled
        }
    }

    private func alert(_ error: Error) {
        let alert = UIAlertController(title: "Error", message: "\(error)", preferredStyle: .alert)
        alert.addAction(.init(title: "OK", style: .default))
        present(alert, animated: true)
    }

    private func obtainUploader() throws -> ImgurUploader {
        if let uploader = self.uploader {
            return uploader
        }

        guard !clientID.isEmpty else {
            throw MissingClientID()
        }

        let uploader = ImgurUploader(clientID: clientID)
        self.uploader = uploader
        return uploader
    }
}

struct MissingClientID: Error {}
