//
//  ViewController.swift
//  Metal-10(视频播放)
//
//  Created by 熊涛 on 2019/12/11.
//  Copyright © 2019 xiong_tao. All rights reserved.
//

import UIKit
import AVFoundation

class ViewController: UIViewController, XTVideoMovieDelegate {

    var movie: XTVideoMovie?
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        configMovie()
        // Do any additional setup after loading the view.
    }
    
    func setupUI() {
        view.addSubview(renderView)
        view.addSubview(start)
        view.addSubview(reset)
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        renderView.frame = view.bounds
        start.frame = CGRect(x: (view.bounds.width-100)*0.5, y: view.bounds.height - 150, width: 100, height: 50)
    }
    
    func configMovie() {
//        guard let path = Bundle.main.path(forResource: "v0200f830000bngvvsj2ap95jt9tm5e0", ofType: "MP4") else { return  }
        guard let path = Bundle.main.path(forResource: "IMG_0064", ofType: "MOV") else { return  }
        let item = AVPlayerItem(asset: AVAsset(url: URL(fileURLWithPath: path)))
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
    
    @objc func reset(button: UIButton) {
        movie?.reset()
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
    
    lazy var reset: UIButton = {
        let b = UIButton()
        b.backgroundColor = .red
        b.setTitleColor(.white, for: .normal)
        b.setTitle("reset", for: .normal)
        b.addTarget(self, action: #selector(reset(button:)), for: .touchUpInside)
        return b
    }()

}

