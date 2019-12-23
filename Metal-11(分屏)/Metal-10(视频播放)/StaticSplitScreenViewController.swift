//
//  StaticSplitScreenViewController.swift
//  Metal-10(视频播放)
//
//  Created by 熊涛 on 2019/12/19.
//  Copyright © 2019 xiong_tao. All rights reserved.
//

import UIKit
import AVFoundation

class StaticSplitScreenViewController: UIViewController, XTVideoMovieDelegate {
    
    var movie: XTVideoMovie?
    var asset: AVAsset!
    var count = 0
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        configMovie()
        setupUI()
        // Do any additional setup after loading the view.
    }
    
    
    func setupUI() {
        view.backgroundColor = .white
        view.addSubview(renderView)
        view.addSubview(start)
        view.addSubview(dismiss)
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        renderView.frame = view.bounds
        start.frame = CGRect(x: view.bounds.width*0.5 - 150, y: view.bounds.height - 150, width: 100, height: 50)
        dismiss.frame = CGRect(x: view.bounds.width*0.5 + 50, y: view.bounds.height - 150, width: 100, height: 50)
    }
    
    func configMovie() {
        guard let path = Bundle.main.path(forResource: "v0200f830000bngvvsj2ap95jt9tm5e0", ofType: "MP4") else { return  }
        asset = AVAsset(url: URL(fileURLWithPath: path))
        let item = AVPlayerItem(asset: asset)
        movie = XTVideoMovie(items: [item])
        movie?.delegate = self
    }
    
    // MARK: - XTVideoMovieDelegate
    func perpare(at currentTime: CMTime) {
        print("time -- \(CMTimeGetSeconds(currentTime))")
    }
    
    func perpare(at pixelBuffer: CVPixelBuffer) {
        renderView.setupBuffer(pixelBuffer: pixelBuffer)
    }
    
    // MARK: - action
    @objc func start(button: UIButton) {
        movie?.play()
    }
    
    @objc func dismiss(button: UIButton) {
        movie?.stop()
        dismiss(animated: true, completion: nil)
    }
    
    // MARK: - lazy
    lazy var renderView: XTRenderView = {
        let v = XTRenderView(frame: self.view.bounds)
        return v
    }()
    
    lazy var start: UIButton = {
        let b = UIButton()
        b.backgroundColor = .red
        b.setTitleColor(.white, for: .normal)
        b.setTitle("start", for: .normal)
        b.addTarget(self, action: #selector(start(button:)), for: .touchUpInside)
        return b
    }()
    
    lazy var dismiss: UIButton = {
        let b = UIButton()
        b.backgroundColor = .red
        b.setTitleColor(.white, for: .normal)
        b.setTitle("dismiss", for: .normal)
        b.addTarget(self, action: #selector(dismiss(button:)), for: .touchUpInside)
        return b
    }()
}
