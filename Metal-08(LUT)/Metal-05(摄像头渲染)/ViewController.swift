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
    var computePipelineState: MTLComputePipelineState!
    var vertexBuffer: MTLBuffer!
    
    
    var textureCache: CVMetalTextureCache?
    var texture: MTLTexture?
    var destTexture: MTLTexture?
    
    var groupSize: MTLSize!
    var groupCount: MTLSize!
    var viewportSize: CGSize!
    
    var lutTexture: MTLTexture!
    
    
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
        configCamera()
        getPipelineState()
        getVertexBuffer()
        getDestTexture()
        setupThreadGroup()
    }
    
    func setupUI() {
        self.view.insertSubview(mtkView, at: 0)
        mtkView.frame = view.bounds
        commandQueue = mtkView.device!.makeCommandQueue()
        library = mtkView.device!.makeDefaultLibrary()
        /// 创建Core Video 的纹理缓存
        CVMetalTextureCacheCreate(kCFAllocatorDefault, nil, self.mtkView.device!, nil, &textureCache)
        
        /// lut纹理
        lutTexture = newTexture(UIImage(named: "lut_01")!)
        print("lutTexture -- \(lutTexture)")
    }

    func configCamera() {
        
        viewportSize = CGSize(width: 1920, height: 1080)
        
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
        viewportSize = CGSize(width: size.width, height: size.height)
    }
    
    
    func draw(in view: MTKView) {
        //把MTKView作为目标纹理
        guard let _texture = texture, let drawingTexture = view.currentDrawable?.texture else {
            return
        }
        
        /// 每次渲染都要单独创建一个commandBuffer
        let commandBuffer = commandQueue.makeCommandBuffer()
        
        
        // 清屏
        let renderPassDescriptor = MTLRenderPassDescriptor()
        renderPassDescriptor.colorAttachments[0].clearColor = MTLClearColorMake(0.48, 0.74, 0.92, 1)
        renderPassDescriptor.colorAttachments[0].texture = drawingTexture
        renderPassDescriptor.colorAttachments[0].loadAction = .clear
        renderPassDescriptor.colorAttachments[0].storeAction = .store
        
        //渲染指令
        let renderCommandEncoder = commandBuffer?.makeRenderCommandEncoder(descriptor: renderPassDescriptor)
        
        //设置渲染管线
        renderCommandEncoder?.setRenderPipelineState(pipelineState)
        //设置顶点数据
        renderCommandEncoder?.setVertexBuffer(vertexBuffer, offset: 0, index: 0)
        ///设置纹理数据
        renderCommandEncoder?.setFragmentTexture(_texture, index: 0)
        renderCommandEncoder?.setFragmentTexture(lutTexture, index: 1)
        
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
 
    /// 目标纹理
    func getDestTexture() {
        let textureDescriptor = MTLTextureDescriptor()
        textureDescriptor.pixelFormat = MTLPixelFormat.bgra8Unorm
        textureDescriptor.width = Int(viewportSize.width)
        textureDescriptor.height = Int(viewportSize.height)
        textureDescriptor.usage = [.shaderWrite, .shaderRead]
        destTexture = mtkView.device?.makeTexture(descriptor: textureDescriptor)
    }
    
    func setupThreadGroup() {
        groupSize = MTLSizeMake(16, 16, 1)  // 太大某些GPU不支持，太小效率低；
        let w = (Int(viewportSize.width) + groupSize.width
        - 1)/groupSize.width
        let h = (Int(viewportSize.height) + groupSize.height
        - 1)/groupSize.height
        groupCount = MTLSizeMake(w, h, 1)
    }
    
    func newTexture(_ image: UIImage) -> MTLTexture {
        let imageRef = image.cgImage!
        let width = imageRef.width
        let height = imageRef.height
        let colorSpace = CGColorSpaceCreateDeviceRGB() //s色域
        let rawData = calloc(height * width * 4, MemoryLayout<UInt8>.size) //图片存储数据的指针
        let bitsPerComponent = 8 //指定每一个像素中组件的位数(bits，二进制位)。例如：对于32位格式的RGB色域，你需要为每一个部分指定8位
        let bytesPerPixel = 4
        let bytesPerRow = width * bytesPerPixel
        let context = CGContext(data: rawData,
                  width: width,
                  height: height,
                  bitsPerComponent: bitsPerComponent,
                  bytesPerRow: bytesPerRow,
                  space: colorSpace,
                  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue)
        context?.draw(imageRef, in: CGRect(x: 0, y: 0, width: width, height: height))
        let textureDescriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .rgba8Unorm, width: width, height: height, mipmapped: false)
        let texture = mtkView.device?.makeTexture(descriptor: textureDescriptor)
        let region = MTLRegionMake2D(0, 0, width, height)
        texture?.replace(region: region, mipmapLevel: 0, withBytes: rawData!, bytesPerRow: bytesPerRow)
        free(rawData)
        return texture!
    }
}

