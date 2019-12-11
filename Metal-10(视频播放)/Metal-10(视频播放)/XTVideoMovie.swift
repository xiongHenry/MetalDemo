//
//  XTVideoMovie.swift
//  Metal-10(视频播放)
//
//  Created by 熊涛 on 2019/12/11.
//  Copyright © 2019 xiong_tao. All rights reserved.
//

import UIKit
import AVFoundation

protocol XTVideoMovieDelegate: class {
    func perpare(at pixelBuffer: CVPixelBuffer)
    func perpare(at currentTime: CMTime)
}

class XTVideoMovie: NSObject, AVPlayerItemOutputPullDelegate {

    weak var delegate: XTVideoMovieDelegate?
    
    
    var aqPlayer: AVQueuePlayer?
    var displayLink: CADisplayLink?
    var playerItems: [AVPlayerItem] = []
    var outputs: [AVPlayerItemVideoOutput] = []
    
    var playIndex = 0
    
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    init(items: [AVPlayerItem]) {
        super.init()
        initDisplayLink()
        setupItems(items: items)
    }
    
    func initDisplayLink() {
        displayLink = CADisplayLink(target: self, selector: #selector(displayLinkCallBack(_:)))
        displayLink?.add(to: .current, forMode: .common)
        displayLink?.isPaused = true
    }
    
    @objc func displayLinkCallBack(_ displayLink: CADisplayLink) {
        processPixelBuffer(at: aqPlayer?.currentItem?.currentTime())
    }
    
    func setupItems(items: [AVPlayerItem]) {
        playerItems = items
        for item in items {
            NotificationCenter.default.addObserver(self, selector: #selector(playEnd(notification:)), name: .AVPlayerItemDidPlayToEndTime, object: item)
            
            let outputSetting: [String : Any] = [kCVPixelBufferPixelFormatTypeKey as String : kCVPixelFormatType_420YpCbCr8BiPlanarFullRange]
            let output = AVPlayerItemVideoOutput(outputSettings: outputSetting)
            output.setDelegate(self, queue: DispatchQueue.main)
            item.add(output)
            outputs.append(output)
        }
        
        aqPlayer = AVQueuePlayer(items: items)
    }
    
    func play() {
        if playerItems.count > 0 {
            aqPlayer?.play()
            displayLink?.isPaused = false
        }
    }
    
    func pause() {
        if aqPlayer?.rate != 0 {
            aqPlayer?.pause()
            displayLink?.isPaused = true
        }
    }
    
    func reset() {
        playIndex = 0
        pause()
        aqPlayer?.seek(to: .zero)
        play()
    }
    
    func processPixelBuffer(at time: CMTime?) {
        guard let outputTime = time else {
            return
        }
        guard outputs[playIndex].hasNewPixelBuffer(forItemTime: outputTime) else {
            return
        }
        
        /// 当前时间
        var currentTime = outputTime
        for i in 0..<playIndex {
            currentTime = CMTimeAdd(currentTime, playerItems[i].asset.duration)
        }
        
        /// 获取新的pixelBuffer
        guard let pixelBuffer = outputs[playIndex].copyPixelBuffer(forItemTime: outputTime, itemTimeForDisplay: nil) else {
            return
        }
        
        /// 回调
        delegate?.perpare(at: pixelBuffer)
        delegate?.perpare(at: currentTime)
    }
    
    @objc func playEnd(notification: Notification) {
        playIndex += 1
        
        if playIndex >= playerItems.count {
            print("播放结束")
            displayLink?.isPaused = true
        }
    }
    
    // MARK: - AVPlayerItemOutputPullDelegate
    func outputMediaDataWillChange(_ Ysender: AVPlayerItemOutput) {
        guard displayLink?.isPaused ?? false else {
            return
        }
        displayLink?.isPaused = false
    }
    
    func outputSequenceWasFlushed(_ output: AVPlayerItemOutput) {
        
    }
}
