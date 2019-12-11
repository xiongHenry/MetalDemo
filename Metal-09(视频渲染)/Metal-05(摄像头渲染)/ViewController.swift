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

class ViewController: UIViewController, AVCaptureVideoDataOutputSampleBufferDelegate,MTKViewDelegate, XTAssetReaderDelegate {
   
    var captureSession: AVCaptureSession!
    var captureDevice: AVCaptureDevice!
    var captureInput: AVCaptureInput!
    var captureOutput: AVCaptureVideoDataOutput!
    
    let cameraQueue = DispatchQueue.init(label: "cameraCaptureQueue")
    
    
    ///
    var commandQueue: MTLCommandQueue!
    var library: MTLLibrary!
    var pipelineState: MTLRenderPipelineState!
    var vertexBuffer: MTLBuffer!
    var matrix: MTLBuffer!
    
    var textureCache: CVMetalTextureCache?
    var texture: MTLTexture?
    
    var reader: XTAssetReader!
    
    lazy var mtkView: MTKView = {
        let v = MTKView()
        v.device = MTLCreateSystemDefaultDevice()
//        v.delegate = self
        v.framebufferOnly = false
        return v
    }()
   
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
        
        
        let path = Bundle.main.path(forResource: "sd1571912154_2", ofType: "MP4")
        reader = XTAssetReader(URL(fileURLWithPath: path!))
        reader.delegate = self
        
        setupUI()
        getPipelineState()
        getVertexBuffer()
        getMatrix()
    }
    
    func setupUI() {
        self.view.insertSubview(mtkView, at: 0)
        mtkView.frame = view.bounds
        commandQueue = mtkView.device!.makeCommandQueue()
        library = mtkView.device!.makeDefaultLibrary()
        /// 创建Core Video 的纹理缓存
        CVMetalTextureCacheCreate(kCFAllocatorDefault, nil, self.mtkView.device!, nil, &textureCache)
    }
    
    
    // MARK: - XTAssetReaderDelegate
    func processBuffer(sampleBuffer: CMSampleBuffer) {
        draw(sampleBuffer: sampleBuffer)
    }
    
    
    
    // MARK: - MTKViewDelegate
    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
        
    }
    
    
    func draw(in view: MTKView) {
        //把MTKView作为目标纹理
        guard let drawingTexture = view.currentDrawable?.texture, let sampleBuffer = reader.readBuffer() else {
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
        
        let w = mtkView.drawableSize.width
        let h = mtkView.drawableSize.height
        renderCommandEncoder?.setViewport(MTLViewport(originX: 0, originY: 0, width: Double(w), height: Double(h), znear: -1.0, zfar: 1.0))
        
        //设置渲染管线
        renderCommandEncoder?.setRenderPipelineState(pipelineState)
        //设置顶点数据
        renderCommandEncoder?.setVertexBuffer(vertexBuffer, offset: 0, index: 0)
        ///设置纹理数据
        setupTexture(with: renderCommandEncoder!, sampleBuffer: sampleBuffer)
        ///设置转换矩阵
        renderCommandEncoder?.setFragmentBuffer(matrix, offset: 0, index: 0)
        
        // 绘制图形
        renderCommandEncoder?.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: 4)
        
        
        renderCommandEncoder?.endEncoding()
        commandBuffer?.present(view.currentDrawable!)
        commandBuffer?.commit()
    }
    
    func draw(sampleBuffer: CMSampleBuffer) {
        print("current ---- \(CFAbsoluteTimeGetCurrent())")
        
        //把MTKView作为目标纹理
        guard let drawingTexture = mtkView.currentDrawable?.texture else {
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
        
        let w = mtkView.drawableSize.width
        let h = mtkView.drawableSize.height
        renderCommandEncoder?.setViewport(MTLViewport(originX: 0, originY: 0, width: Double(w), height: Double(h), znear: -1.0, zfar: 1.0))
        
        //设置渲染管线
        renderCommandEncoder?.setRenderPipelineState(pipelineState)
        //设置顶点数据
        renderCommandEncoder?.setVertexBuffer(vertexBuffer, offset: 0, index: 0)
        ///设置纹理数据
        setupTexture(with: renderCommandEncoder!, sampleBuffer: sampleBuffer)
        ///设置转换矩阵
        renderCommandEncoder?.setFragmentBuffer(matrix, offset: 0, index: 0)
        
        // 绘制图形
        renderCommandEncoder?.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: 4)
        
        
        renderCommandEncoder?.endEncoding()
        commandBuffer?.present(mtkView.currentDrawable!)
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
        vertexBuffer = mtkView.device?.makeBuffer(bytes: vertices, length: MemoryLayout<XTVertex>.size * 4, options: .storageModeShared)
    }
    
    /// 转换矩阵
    func getMatrix() {
        let col1 = simd_float3(1.0, 1.0, 1.0)
        let col2 = simd_float3(0.0, -0.343, 1.765)
        let col3 = simd_float3(1.4, -0.711, 0.0)
        let kColorConversion601FullRangeMatrix = matrix_float3x3(columns: (col1, col2, col3))
        let kColorConversion601FullRangeOffset = simd_float3(-(16.0/255.0), -0.5, -0.5)
        let matrix = [XTConvertMatrix(matrix: kColorConversion601FullRangeMatrix, offset: kColorConversion601FullRangeOffset)]
        self.matrix = mtkView.device?.makeBuffer(bytes: matrix, length: MemoryLayout<XTConvertMatrix>.size, options: .storageModeShared)
    }
    
    /// 设置纹理
    func setupTexture(with encoder: MTLRenderCommandEncoder, sampleBuffer: CMSampleBuffer) {
        
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            return
        }
        
        var textureY: MTLTexture?
        var textureUV: MTLTexture?
        
        var status: CVReturn = kCVReturnSuccess
        
        
        /// texture Y
        let widthY = CVPixelBufferGetWidthOfPlane(pixelBuffer, 0)
        let heightY = CVPixelBufferGetHeightOfPlane(pixelBuffer, 0)
        let pixelFormatY = MTLPixelFormat.r8Unorm
        
        var metalTextureY: CVMetalTexture? = nil
        status = CVMetalTextureCacheCreateTextureFromImage(kCFAllocatorDefault, textureCache!, pixelBuffer, nil, pixelFormatY, widthY, heightY, 0, &metalTextureY)
        if status == kCVReturnSuccess {
            textureY = CVMetalTextureGetTexture(metalTextureY!)
        }
        
        
        /// texture UV
        let widthUV = CVPixelBufferGetWidthOfPlane(pixelBuffer, 1)
        let heightUV = CVPixelBufferGetHeightOfPlane(pixelBuffer, 1)
        let pixelFormatUV = MTLPixelFormat.rg8Unorm
        
        var metalTextureUV: CVMetalTexture? = nil
        status = CVMetalTextureCacheCreateTextureFromImage(kCFAllocatorDefault, textureCache!, pixelBuffer, nil, pixelFormatUV, widthUV, heightUV, 1, &metalTextureUV)
        if status == kCVReturnSuccess {
            textureUV = CVMetalTextureGetTexture(metalTextureUV!)
        }
        
        /// 设置纹理打编码器中
        if textureY != nil && textureUV != nil{
            encoder.setFragmentTexture(textureY, index: 0)
            encoder.setFragmentTexture(textureUV, index: 1)
        }
        /// 释放
        CMSampleBufferInvalidate(sampleBuffer)
    }
    
    
    @IBAction func startAction(_ sender: UIButton) {
        reader.start()
    }
    
}

