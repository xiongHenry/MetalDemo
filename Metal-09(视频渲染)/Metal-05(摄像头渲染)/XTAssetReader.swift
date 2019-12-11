//
//  XTAssetReader.swift
//  Metal-05(摄像头渲染)
//
//  Created by 熊涛 on 2019/11/5.
//  Copyright © 2019 熊涛. All rights reserved.
//

import UIKit
import AVFoundation

protocol XTAssetReaderDelegate {
    func processBuffer(sampleBuffer: CMSampleBuffer)
}

class XTAssetReader {
 
    var delegate: XTAssetReaderDelegate?
    
    
    var assetReader: AVAssetReader?
    var readerVideoTrackOutput: AVAssetReaderTrackOutput?
    var videoUrl: URL?
    var lock: NSLock?
    
    
    var previousFrameTime = CMTime.zero
    var previousActualFrameTime = CFAbsoluteTimeGetCurrent()
    var videoEncodingIsFinished = false
    
    
    init(_ url: URL) {
        videoUrl = url
        lock = NSLock()
        customInit()
    }
    
    func customInit() {
        guard let url = videoUrl else {
            return
        }
        /*
         AVURLAssetPreferPreciseDurationAndTimingKey: 指示asset是否应准备好指示精确的持续时间并按时间提供精确的随机访问
         */
        let options: [String : Any] = [AVURLAssetPreferPreciseDurationAndTimingKey : true]
        let asset = AVURLAsset(url: url, options: options)
        asset.loadValuesAsynchronously(forKeys: ["tracks"]) { [weak self] in
            DispatchQueue.global().async {
                var error: NSError? = nil
                let status = asset.statusOfValue(forKey: "tracks", error: &error)
                if status != .loaded {
                    print("error --- \(error)")
                    return
                }
                self?.process(with: asset)
            }
        }
    }
    
    func process(with asset: AVAsset) {
        print("process asset")
        lock?.lock()
        do {
            assetReader = try AVAssetReader.init(asset: asset)
        }catch {
            print("AVAssetReader init fail")
            return
        }
        
        //        let outputSettings:[String:Any] = [kCVPixelBufferMetalCompatibilityKey as String: true,
        //        (kCVPixelBufferPixelFormatTypeKey as String):NSNumber(value:Int32(kCVPixelFormatType_420YpCbCr8BiPlanarFullRange))]
        let outputSetting: [String : Any] = [kCVPixelBufferPixelFormatTypeKey as String : kCVPixelFormatType_420YpCbCr8BiPlanarFullRange]
        readerVideoTrackOutput = AVAssetReaderTrackOutput(track: asset.tracks(withMediaType: .video)[0], outputSettings: outputSetting)
        readerVideoTrackOutput?.alwaysCopiesSampleData = false
        assetReader?.add(readerVideoTrackOutput!)
        
        if !assetReader!.startReading() {
            print("error reading file")
        }
        
        lock?.unlock()
    }
    
    func start() {
        DispatchQueue.global().async {
            while self.assetReader!.status == .reading {
                self.readNextVideoFrame()
            }
            
            if self.assetReader!.status == .completed {
                self.assetReader?.cancelReading()
            }
        }
    }
    
    func readNextVideoFrame() {
        if assetReader!.status == .reading, !videoEncodingIsFinished {
            if let sampleBuffer = readerVideoTrackOutput!.copyNextSampleBuffer() {
                // Do this outside of the video processing queue to not slow that down while waiting
                let currentSampleTime = CMSampleBufferGetOutputPresentationTimeStamp(sampleBuffer)
                let differenceFromLastFrame = CMTimeSubtract(currentSampleTime, previousFrameTime)
                let currentActualTime = CFAbsoluteTimeGetCurrent()
                
                let frameTimeDifference = CMTimeGetSeconds(differenceFromLastFrame)
                let actualTimeDifference = currentActualTime - previousActualFrameTime
                
                if (frameTimeDifference > actualTimeDifference) {
                    usleep(UInt32(round(1000000.0 * (frameTimeDifference - actualTimeDifference))))
                }
                
                previousFrameTime = currentSampleTime
                previousActualFrameTime = CFAbsoluteTimeGetCurrent()
                
                process(moiveFrame: sampleBuffer)
                CMSampleBufferInvalidate(sampleBuffer)
            }
        }else {
            videoEncodingIsFinished = true
        }
    }
    
    func process(moiveFrame: CMSampleBuffer) {
        delegate?.processBuffer(sampleBuffer: moiveFrame)
    }
    
    func readBuffer() -> CMSampleBuffer? {
        lock?.lock()
        
        var sampleBuffer: CMSampleBuffer? = nil
        
        if (readerVideoTrackOutput != nil) {
            sampleBuffer = readerVideoTrackOutput?.copyNextSampleBuffer()
        }
        
        if let assetReader = assetReader, assetReader.status == .completed {
            readerVideoTrackOutput = nil
            customInit()
        }
        
        lock?.unlock()
        return sampleBuffer
    }
    
    
    
}

