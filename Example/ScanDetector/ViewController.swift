//
//  ViewController.swift
//  ScanDetector
//
//  Created by Jack-1202 on 03/03/2022.
//  Copyright (c) 2022 Jack-1202. All rights reserved.
//

import UIKit
import ScanDetector
import AVFoundation

class ViewController: UIViewController {
    
    lazy var captureController: CaptureViewController = {
        let captureConfig = CaptureConfig()
            .isAutoCaptureEnabled(false)
            .idShowAutoFocus(false)
        let controller = CaptureViewController(withCaptureConfig: captureConfig, quadViewConfig: nil)
        return controller
    }()
    
    lazy var quadView: QuadView = {
        let view = QuadView(withConfig: QuadViewConfig())
        return view
    }()

    lazy var shutterButton: UIButton = {
        let button = UIButton(frame: CGRect(x: 0, y: 400, width: 100, height: 100))
        button.backgroundColor = .white
        button.translatesAutoresizingMaskIntoConstraints = false
        button.addTarget(self, action: #selector(captureImage(_:)), for: .touchUpInside)
        return button
    }()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        addChildViewController(captureController)
        view.addSubview(captureController.view)
        view.addSubview(shutterButton)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        quadView.removeQuadrilateral()
        UIApplication.shared.isIdleTimerDisabled = true
    }
    
    override public func viewDidLayoutSubviews() {
    }
    
    override public func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        UIApplication.shared.isIdleTimerDisabled = false
    }

    @objc private func captureImage(_ sender: UIButton) {
        shutterButton.isUserInteractionEnabled = false
        captureController.captureImage()
    }
}
