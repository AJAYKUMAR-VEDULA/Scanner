//
//  OCRScanner.swift
//  Scanner
//
//  Created by AJ on 07/09/20.
//  Copyright © 2020 AJ. All rights reserved.
//

import Foundation
import Vision
import VisionKit

protocol OCRScannerDelegate : class {
    func sendRecognizedText(code: String)
}

@available(iOS 13.0, *)
class OCRScanner {
    
    var textRequest = VNRecognizeTextRequest()
    var delegate : OCRScannerDelegate?
    
    func configureOCR() {
        textRequest = VNRecognizeTextRequest { (request, error) in
            guard error == nil else { return }
            self.processRequest(for: request)
        }
    }
    
    func processRequest(for request:VNRequest){
        guard let observations = request.results as? [VNRecognizedTextObservation] else { return }
        var ocrText = ""
        for observation in observations {
            guard let topCandidate = observation.topCandidates(1).first else { return }
            ocrText += topCandidate.string + "\n"
        }
        DispatchQueue.main.async {
            var code = ocrText.replacingOccurrences(of: "\n", with: "")
            code = code.replacingOccurrences(of: " ", with: "")
            self.delegate?.sendRecognizedText(code: code)
        }
        textRequest.recognitionLevel = .accurate
        textRequest.recognitionLanguages = ["en-US", "en-GB"]
        textRequest.usesLanguageCorrection = true
    }
    
    func processImage(_ image: UIImage) {
        recognizeTextInImage(image)
    }
    
    func recognizeTextInImage(_ image: UIImage) {
        let handler = VNImageRequestHandler(cgImage: image.cgImage!, options: [:])
        do {
            try handler.perform([textRequest])
        } catch {
            print(error.localizedDescription)
        }
    }
}

