//
//  ViewController.swift
//  iOSTestApp
//
//  Created by Nolan Waite on 2018-05-13.
//  Copyright © 2018 Nolan Waite. All rights reserved.
//

import ImgurUploader
import Photos
import UIKit

final class ViewController: UIViewController {
    private var clientID: String = UserDefaults.standard.string(forKey: "Imgur client ID") ?? ""
    private var imagePickerInfo: [UIImagePickerController.InfoKey: Any]?
    private var uploader: ImgurUploader?

    @IBOutlet private var clientIDTextField: UITextField?
    @IBOutlet private var controls: [UIControl]?
    @IBOutlet private var imageButton: UIButton?
    @IBOutlet private var resultsTextView: UITextView?

    override func viewDidLoad() {
        super.viewDidLoad()

        clientIDTextField?.text = clientID
    }

    @IBAction func didChangeClientID(_ sender: UITextField) {
        clientID = sender.text ?? ""
        if let id = sender.text, !id.isEmpty {
            UserDefaults.standard.set(id, forKey: "Imgur client ID")
        } else {
            UserDefaults.standard.removeObject(forKey: "Imgur client ID")
        }

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

    @IBAction func didTapImage(_ sender: Any) {
        let picker = UIImagePickerController()
        picker.delegate = self
        present(picker, animated: true)
    }

    @IBAction func didTapUploadAsPHAsset(_ sender: Any) {
        do {
            let uploader = try obtainUploader()
            let info = try obtainPHAsset()
            beginOperation()
            uploader.upload(info) {
                self.endOperation($0)
            }
        } catch {
            alert(error)
        }
    }

    @IBAction func didTapUploadAsUIImage(_ sender: Any) {
        do {
            let uploader = try obtainUploader()
            let info = try obtainUIImage()
            beginOperation()
            uploader.upload(info) {
                self.endOperation($0)
            }
        } catch {
            alert(error)
        }
    }

    @IBAction func didTapUploadAsWhatever(_ sender: Any) {
        do {
            let uploader = try obtainUploader()
            let info = try obtainImagePickerInfo()
            beginOperation()
            uploader.upload(info) {
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
            resultsTextView?.text = "hooray!\n\(value)"
        case .failure(let error):
            resultsTextView?.text = "boo!\n\(error)"
        }

        setIsEnabled(true)
    }

    private func setIsEnabled(_ isEnabled: Bool) {
        for control in controls ?? [] {
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

    private func obtainImagePickerInfo() throws -> [UIImagePickerController.InfoKey: Any] {
        if let info = imagePickerInfo {
            return info
        } else {
            throw MissingImage()
        }
    }

    private func obtainPHAsset() throws -> PHAsset {
        if #available(iOS 11.0, *), let asset = imagePickerInfo?[.phAsset] as? PHAsset {
            return asset
        } else {
            throw MissingImage()
        }
    }

    private func obtainUIImage() throws -> UIImage {
        if let image = imagePickerInfo?[.editedImage] as? UIImage {
            return image
        } else if let image = imagePickerInfo?[.originalImage] as? UIImage {
            return image
        } else {
            throw MissingImage()
        }
    }
}

struct MissingClientID: Error {}
struct MissingImage: Error {}

extension ViewController: UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {

        imagePickerInfo = info

        let image = info[.editedImage] as? UIImage
            ?? info[.originalImage] as? UIImage
        imageButton?.setImage(image, for: .normal)
        imageButton?.setTitle(image == nil ? "Image" : nil, for: .normal)

        dismiss(animated: true)
    }
}
