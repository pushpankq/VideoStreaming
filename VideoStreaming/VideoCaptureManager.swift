//
//  VideoCaptureManager.swift
//  VideoStreaming
//
//  Created by Pushpank Kumar on 06/03/24.
//

import AVFoundation

// AVCaptureDevice -> represents our iPhone’s input device, such as camera or mic
// AVCaptureOutput -> can deliver captured data to a file or stream
// we need to set its delegate so the delegate can take raw picture data
// AVCaptureSession -> You can think AVCaptureSession as a bridge between AVCaptureDevice and AVCaptureOutput that let them have a connection.

class VideoCaptureManager {
    
    private enum SessionSetupResult {
        case success
        case notAuthorized
        case configurationFailed
    }
    
    private enum ConfigurationError: Error {
        case cannotAddInput
        case cannotAddOutput
        case defaultDeviceNotExist
    }
    
    private let session = AVCaptureSession()
    private let videoOutput = AVCaptureVideoDataOutput()
    
    // MARK: - DispatchQueues to make the most of multithreading
    private let sessionQueue = DispatchQueue(label: "session.queue")
    private let videoOutputQueue = DispatchQueue(label: "video.output.queue")
    
    private var setupResult: SessionSetupResult = .success
    
    
    private func requestCameraAuthorizationIfNeeded() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            break
        case .notDetermined:
            sessionQueue.suspend()
            AVCaptureDevice.requestAccess(for: .video) { granted in
                if !granted {
                    self.setupResult = .notAuthorized
                }
                self.sessionQueue.resume()
            }
        default:
            setupResult = .notAuthorized
        }
    }
    
    private func addVideoDeviceInputToSession() throws {
        
        do {
            var defaultVideoDevice: AVCaptureDevice?
            
            if let dualCameraDevice = AVCaptureDevice.default(.builtInDualCamera, for: .video, position: .back) {
                defaultVideoDevice = dualCameraDevice
            } else if let dualWideCameraDevice = AVCaptureDevice.default(.builtInDualWideCamera, for: .video, position: .back) {
                defaultVideoDevice = dualWideCameraDevice
            } else if let backCameraDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) {
                defaultVideoDevice = backCameraDevice
            } else if let frontCameraDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front) {
                defaultVideoDevice = frontCameraDevice
            }
            
            guard let videoDevice = defaultVideoDevice else {
                print("Default video device is unavailable.")
                setupResult = .configurationFailed
                session.commitConfiguration()
                throw ConfigurationError.defaultDeviceNotExist
            }
            
            let videoDeviceInput = try AVCaptureDeviceInput(device: videoDevice)
            
            if session.canAddInput(videoDeviceInput) {
                session.addInput(videoDeviceInput)
            } else {
                setupResult = .configurationFailed
                session.commitConfiguration()
                throw ConfigurationError.cannotAddInput
            }

        } catch {
            setupResult = .configurationFailed
            session.commitConfiguration()
            throw error
        }
        
    }
    
    private func addVideoOutputToSession() throws {
        if session.canAddOutput(videoOutput) {
            session.addOutput(videoOutput)
        } else {
            setupResult = .configurationFailed
            session.commitConfiguration()
            throw ConfigurationError.cannotAddOutput
        }
    }
    
    private func configureSession() {
        if setupResult != .success {
                return
        }
        
        session.beginConfiguration()
        
        if session.canSetSessionPreset(.iFrame1280x720) {
            session.sessionPreset = .iFrame1280x720
        }
        
        do {
            try addVideoDeviceInputToSession()
            try addVideoOutputToSession()
            if let connection = session.connections.first {
                 connection.videoOrientation = .portrait
            }
        } catch {
            print("error ocurred : \(error.localizedDescription)")
            return

        }
        session.commitConfiguration()
    }
    
    private func startSessionIfPossible() {
        switch self.setupResult {
        case .success:
            session.startRunning()
        case .notAuthorized:
            print("camera usage not authorized")
        case .configurationFailed:
            print("configuration failed")
        }
    }
    
    init() {
        sessionQueue.async {
            self.requestCameraAuthorizationIfNeeded()
        }

        sessionQueue.async {
            self.configureSession()
        }
        
        sessionQueue.async {
            self.startSessionIfPossible()
        }
    }
    
    func setVideoOutputDelegate(with delegate: AVCaptureVideoDataOutputSampleBufferDelegate) {
        // AVCaptureVideoDataOutput has a method named 'setSampleBufferDelegate' which set the object
        // to receive raw picture data
        videoOutput.setSampleBufferDelegate(delegate, queue: videoOutputQueue)
    }

}
