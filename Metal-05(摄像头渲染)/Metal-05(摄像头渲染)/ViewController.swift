//
//  ViewController.swift
//  Metal-05(摄像头渲染)
//
//  Created by 熊涛 on 2019/10/15.
//  Copyright © 2019 熊涛. All rights reserved.
//

import UIKit
import AVFoundation
import Metal
import MetalKit

class ViewController: UIViewController, AVCaptureVideoDataOutputSampleBufferDelegate,MTKViewDelegate {
   
    var captureSession: AVCaptureSession!
    var captureDevice: AVCaptureDevice!
    var captureInput: AVCaptureInput!
    var captureOutput: AVCaptureVideoDataOutput!
    
    let cameraQueue = DispatchQueue.init(label: "cameraCaptureQueue")
    
    var commandQueue: MTLCommandQueue!
    var library: MTLLibrary!
    var pipelineState: MTLRenderPipelineState!
    var vertexBuffer: MTLBuffer!
    
    
    var textureCache: CVMetalTextureCache?
    var texture: MTLTexture?
    
    
    
    
    lazy var mtkView: MTKView = {
        let v = MTKView()
        v.device = MTLCreateSystemDefaultDevice()
        v.delegate = self
        v.framebufferOnly = false
        return v
    }()
   
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
        setupUI()
        getPipelineState()
        getVertexBuffer()
        configCamera()
    }
    
    func setupUI() {
        self.view.insertSubview(mtkView, at: 0)
        mtkView.frame = view.bounds
        commandQueue = mtkView.device!.makeCommandQueue()
        library = mtkView.device!.makeDefaultLibrary()
        /// 创建Core Video 的纹理缓存
        CVMetalTextureCacheCreate(kCFAllocatorDefault, nil, self.mtkView.device!, nil, &textureCache)
    }

    func configCamera() {
        captureSession = AVCaptureSession()
        
        var inputCamera: AVCaptureDevice? = nil
        let devices = AVCaptureDevice.devices(for: AVMediaType.video)
        for device in devices {
            if device.position == .back {
                inputCamera = device
            }
        }
        
        guard let inputDevice: AVCaptureDevice = inputCamera else {
            return
        }
        captureDevice = inputDevice
        do {
            captureInput = try AVCaptureDeviceInput(device: captureDevice)
        }catch {
            
        }
        
        if captureSession.canAddInput(captureInput) {
            captureSession.addInput(captureInput)
        }
        
        captureOutput = AVCaptureVideoDataOutput()
        captureOutput.alwaysDiscardsLateVideoFrames = false
        captureOutput.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String : kCVPixelFormatType_32BGRA]
        captureOutput.setSampleBufferDelegate(self, queue: cameraQueue)
        
        if captureSession.canAddOutput(captureOutput) {
            captureSession.addOutput(captureOutput)
        }
        
        let connection = captureOutput.connection(with: AVMediaType.video)
        connection?.videoOrientation = .portrait //设置方向
        /// 开始捕捉
        captureSession.startRunning()
        
    }
    
    
    // MARK: - AVCaptureVideoDataOutputSampleBufferDelegate
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        //通过 CMSampleBuffer 获取 CVPixelBuffer
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            return
        }
        /// 获取图像宽高
        let width = CVPixelBufferGetWidth(pixelBuffer)
        let height = CVPixelBufferGetHeight(pixelBuffer)
        
        /// 得到纹理缓存 CVMetalTexture
        var metalTexture: CVMetalTexture? = nil
        let status = CVMetalTextureCacheCreateTextureFromImage(kCFAllocatorDefault, textureCache!, pixelBuffer, nil, MTLPixelFormat.bgra8Unorm, width, height, 0, &metalTexture)
        if status == kCVReturnSuccess {
            mtkView.drawableSize = CGSize(width: width, height: height)
            /// 得到MTLTexture  Metal纹理
            texture = CVMetalTextureGetTexture(metalTexture!)
        }
    }
    
    
    // MARK: - MTKViewDelegate
    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
        
    }
    
    
    func draw(in view: MTKView) {
        //把MTKView作为目标纹理
        guard let _texture = texture, let drawingTexture = view.currentDrawable?.texture else {
            return
        }
        // 清屏
        let renderPassDescriptor = MTLRenderPassDescriptor()
        renderPassDescriptor.colorAttachments[0].clearColor = MTLClearColorMake(0.48, 0.74, 0.92, 1)
        renderPassDescriptor.colorAttachments[0].texture = drawingTexture
        renderPassDescriptor.colorAttachments[0].loadAction = .clear
        renderPassDescriptor.colorAttachments[0].storeAction = .store
        
        //渲染指令
        let commandBuffer = commandQueue.makeCommandBuffer()
        let renderCommandEncoder = commandBuffer?.makeRenderCommandEncoder(descriptor: renderPassDescriptor)
        
        //设置渲染管线
        renderCommandEncoder?.setRenderPipelineState(pipelineState)
        //设置顶点数据
        renderCommandEncoder?.setVertexBuffer(vertexBuffer, offset: 0, index: 0)
        ///设置纹理数据
        renderCommandEncoder?.setFragmentTexture(_texture, index: 0)
        
        // 绘制图形
        renderCommandEncoder?.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: 4)
        
        
        renderCommandEncoder?.endEncoding()
        commandBuffer?.present(view.currentDrawable!)
        commandBuffer?.commit()
    }
    
    /// 渲染管线
    func getPipelineState() {
        let vertexFunction = library.makeFunction(name: "vertexShader")
        let fragmentFunction = library.makeFunction(name: "fragmentShader")
     
        let pipelineDescriptor = MTLRenderPipelineDescriptor()
        pipelineDescriptor.colorAttachments[0].pixelFormat = MTLPixelFormat.bgra8Unorm
        pipelineDescriptor.vertexFunction = vertexFunction
        pipelineDescriptor.fragmentFunction = fragmentFunction
        
        pipelineState = try! mtkView.device!.makeRenderPipelineState(descriptor: pipelineDescriptor)
    }
    
    /// 顶点数据
    func getVertexBuffer() {
        let vertices = [
            XTVertex(position: [-1, -1], textureCoordinates: [0.0, 1.0]),
            XTVertex(position: [-1, 1], textureCoordinates: [0.0, 0.0]),
            XTVertex(position: [1, -1], textureCoordinates: [1.0, 1.0]),
            XTVertex(position: [1, 1], textureCoordinates: [1.0, 0.0]),
        ]
        vertexBuffer = mtkView.device?.makeBuffer(bytes: vertices, length: MemoryLayout<XTVertex>.size * 4, options: .cpuCacheModeWriteCombined)
    }
    
  
}

