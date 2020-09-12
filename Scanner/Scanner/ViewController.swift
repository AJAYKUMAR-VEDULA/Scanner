//
//  ViewController.swift
//  Scanner
//
//  Created by AJAY KUMAR on 07/09/20.
//  Copyright © 2020 AJ. All rights reserved.
//

import UIKit
import AVFoundation
import AudioToolbox
import Vision
import VisionKit

class ViewController: UIViewController, AVCaptureMetadataOutputObjectsDelegate {
    
    @IBOutlet weak var cameraView: UIView!
    @IBOutlet weak var kQRCode: UIButton!
    @IBOutlet weak var kBarCode: UIButton!
    @IBOutlet weak var kOCR: UIButton!
    @IBOutlet weak var kDataMatrix: UIButton!
    @IBOutlet weak var scannerLabel: UILabel!
    @IBOutlet weak var scnText: UIButton!
    private let captureSession = AVCaptureSession()
    private var captureDevice: AVCaptureDevice?
    private var captureSessionLayer: AVCaptureVideoPreviewLayer?
    private var timer = Timer()
    private var metadataOutput = AVCaptureMetadataOutput()
    private var metaDataObject : [AVMetadataObject.ObjectType] = []
    private var stillImageOutput = AVCapturePhotoOutput()
    internal static var kOCRScanner = OCRScanner()
    var imageView = UIImageView()
    var cropImageRect = CGRect()
    let blueColor = UIColor.blue
    let grayColor = UIColor.gray
    var kOCRScanner = false
    let kQRText = "Scanning QR Code"
    let kBarText = "Scanning Bar Code"
    let kMatrixText = "Scanning Data Matrix Code"
    let kOCRText = "Scanning Text"
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        ViewController.kOCRScanner.configureOCR()
        ViewController.kOCRScanner.delegate = self
        addObservers()
        setupScanner(QR: true, Bar: false, DataMatrix: false, OCR: false)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        startCamera()
        configOCRScreen()
        setupScanner(QR: true, Bar: false, DataMatrix: false, OCR: false)
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        captureSessionLayer?.frame = cameraView.bounds
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        stopCamera()
    }
    
    func configOCRScreen() {
        imageView = setupGuideLineArea()
        cameraView.addSubview(imageView)
        cropImageRect = imageView.frame
        if !self.kOCRScanner {
            self.disableOCRScanner()
        }
    }
    
    
    func setupScanner(QR: Bool, Bar: Bool, DataMatrix: Bool, OCR: Bool) {
        if !QR { kQRCode.setTitleColor(grayColor, for: .normal) }
        else { scannerLabel.text = kQRText;kQRCode.setTitleColor(blueColor, for: .normal);metaDataObject = [.qr];disableOCRScanner() }
        if !Bar { kBarCode.setTitleColor(grayColor, for: .normal) }
        else { scannerLabel.text = kBarText;kBarCode.setTitleColor(blueColor, for: .normal);metaDataObject = [.code128, .ean8, .ean13, .pdf417, .code39, .code93];disableOCRScanner() }
        if !DataMatrix { kDataMatrix.setTitleColor(grayColor, for: .normal) }
        else { scannerLabel.text = kMatrixText;kDataMatrix.setTitleColor(blueColor, for: .normal);metaDataObject = [.dataMatrix];disableOCRScanner() }
        if !OCR {kOCR.setTitleColor(grayColor, for: .normal) }
        else { scannerLabel.text = kOCRText;kOCR.setTitleColor(blueColor, for: .normal);metaDataObject = [];enableOCRScanner() }
    }
    
    func disableOCRScanner() {
        kOCRScanner = false
        scnText.isHidden = true
        imageView.isHidden = true
    }
    
    func enableOCRScanner() {
        kOCRScanner = true
        scnText.isHidden = false
        imageView.isHidden = false
    }
    
    @IBAction func kQRCodeButton(_ sender: Any) {
        setupScanner(QR: true, Bar: false, DataMatrix: false, OCR: false)
    }
    @IBAction func kBarCodeButton(_ sender: Any) {
        setupScanner(QR: false, Bar: true, DataMatrix: false, OCR: false)
    }
    @IBAction func kOCRCodeButton(_ sender: Any) {
        
        setupScanner(QR: false, Bar: false, DataMatrix: false, OCR: true)
    }
    @IBAction func kDataMatrixButton(_ sender: Any) {
        setupScanner(QR: false, Bar: false, DataMatrix: true, OCR: false)
    }
    @IBAction func scanTextButton(_ sender: Any) {
        if #available(iOS 13.0, *) {
           clickPhoto()
        } else {
            showAlert(title: "Failed", message: "Your device does not support Text Scanning. Please update to iOS 13 or more to use it")
        }
    }
    
    private func startCamera() {
        captureSession.sessionPreset = AVCaptureSession.Preset.high
        captureDevice = AVCaptureDevice.default(for: .video)
        captureSessionLayer = AVCaptureVideoPreviewLayer(session: captureSession)
        captureSessionLayer!.videoGravity = AVLayerVideoGravity.resizeAspectFill
        captureSessionLayer!.frame = cameraView.layer.bounds
        cameraView.layer.addSublayer(captureSessionLayer!)
        stillImageOutput.isHighResolutionCaptureEnabled = true
        removeInputsAndOutputs()
        do {
            if let cd = captureDevice {
                let input = try AVCaptureDeviceInput(device: cd)
                captureSession.addInput(input)
            }
        }
        catch {
            print("Error")
        }
        addCaptureSessionOutput()
        self.captureSession.startRunning()
    }
    
    
    private func stopCamera() {
        guard captureSession.isRunning else { return }
        captureSession.stopRunning()
        removeInputsAndOutputs()
        captureSessionLayer?.removeFromSuperlayer()
        captureSessionLayer = nil
        captureDevice = nil
    }
    
    func addCaptureSessionOutput() {
        if (captureSession.canAddOutput(metadataOutput)) {
            captureSession.addOutput(metadataOutput)
            metadataOutput.setMetadataObjectsDelegate(self, queue: DispatchQueue.main)
            metadataOutput.metadataObjectTypes = metadataOutput.availableMetadataObjectTypes
        } else {
            return
        }
        
        if (captureSession.canAddOutput(stillImageOutput)) {
            captureSession.addOutput(stillImageOutput)
        } else {
            return
        }
    }
    
    func setupGuideLineArea() -> UIImageView {
        let edgeInsets:UIEdgeInsets = UIEdgeInsets.init(top: 22, left: 22, bottom: 22, right: 22)
        let resizableImage = (UIImage(named: "OCRScanner")?.resizableImage(withCapInsets: edgeInsets, resizingMode: .stretch))!
        let imageSize = CGSize(width: cameraView.frame.width-20, height: cameraView.frame.height/2)
        let imageView = UIImageView(image: resizableImage)
        imageView.frame.size = imageSize
        imageView.center = CGPoint(x: cameraView.bounds.midX, y: cameraView.bounds.midY )
        return imageView
    }
    
    func metadataOutput(_ output: AVCaptureMetadataOutput, didOutput metadataObjects: [AVMetadataObject], from connection: AVCaptureConnection) {
        if let metadataObject = metadataObjects.first, metaDataObject.contains(metadataObject.type) {
            guard let readableObject = metadataObject as? AVMetadataMachineReadableCodeObject else { return }
            guard let stringValue = readableObject.stringValue else { return }
            AudioServicesPlaySystemSound(SystemSoundID(kSystemSoundID_Vibrate))
            stopCamera()
            showAlert(title: "Code Found", message: stringValue)
            print(stringValue)
        }
    }
    
    private func addObservers() {
        NotificationCenter.default.addObserver(self, selector: #selector(willEnterForeground), name: UIApplication.willEnterForegroundNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(didEnterBackground), name: UIApplication.didEnterBackgroundNotification, object: nil)
    }
    
    @objc func willEnterForeground() {
        guard navigationController?.topViewController == self else { return }
        startCamera()
        configOCRScreen()
    }
    
    @objc func didEnterBackground() {
        stopCamera()
    }
    
    private func removeInputsAndOutputs() {
        for case let output as AVCaptureOutput in captureSession.outputs {
            captureSession.removeOutput(output)
        }
        for case let input as AVCaptureInput in captureSession.inputs {
            captureSession.removeInput(input)
        }
    }
    
    func clickPhoto() {
        var photoSettings: AVCapturePhotoSettings
        if #available(iOS 11.0, *) {
            photoSettings = AVCapturePhotoSettings.init(format: [AVVideoCodecKey: AVVideoCodecType.jpeg])
            photoSettings.isAutoStillImageStabilizationEnabled = true
            photoSettings.flashMode = .off
            stillImageOutput.capturePhoto(with: photoSettings, delegate: self)
        }
    }
    
    func showAlert(title: String, message: String) {
        DispatchQueue.main.async {
            let okAction = UIAlertAction(title: "Scan Again", style: .default) {
                UIAlertAction in
                self.startCamera()
                self.configOCRScreen()
            }
            let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
            alert.addAction(okAction)
            self.present(alert, animated: true, completion: nil)
        }
    }
}

@available(iOS 10.0, *)
extension ViewController : AVCapturePhotoCaptureDelegate {
    
    func photoOutput(_ output: AVCapturePhotoOutput, willCapturePhotoFor resolvedSettings: AVCaptureResolvedPhotoSettings) {
        AudioServicesDisposeSystemSoundID(1108)
    }
    
    @available(iOS 11.0, *)
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        guard error == nil else { return }
        guard let imageData = photo.fileDataRepresentation() else { return }
        let orgImage : UIImage = UIImage(data: imageData)!
        let originalSize: CGSize
        let visibleLayerFrame = cropImageRect
        let metaRect = (captureSessionLayer?.metadataOutputRectConverted(fromLayerRect: visibleLayerFrame )) ?? CGRect.zero
        if (orgImage.imageOrientation == UIImage.Orientation.left || orgImage.imageOrientation == UIImage.Orientation.right) {
            originalSize = CGSize(width: orgImage.size.height, height: orgImage.size.width)
        } else {
            originalSize = orgImage.size
        }
        let cropRect: CGRect = CGRect(x: metaRect.origin.x * originalSize.width, y: metaRect.origin.y * originalSize.height, width: metaRect.size.width * originalSize.width, height: metaRect.size.height * originalSize.height).integral
        if let finalCgImage = orgImage.cgImage?.cropping(to: cropRect) {
            let image = UIImage(cgImage: finalCgImage, scale: 1.0, orientation: orgImage.imageOrientation)
            if #available(iOS 13.0, *) {
                ViewController.kOCRScanner.processImage(image)
            }
        }
    }
}

extension ViewController : OCRScannerDelegate {
    func sendRecognizedText(code: String) {
        stopCamera()
        showAlert(title: "Code Found", message: code)
    }
}
