//
//  XTRenderView.swift
//  Metal-10(视频播放)
//
//  Created by 熊涛 on 2019/12/11.
//  Copyright © 2019 xiong_tao. All rights reserved.
//

import UIKit
import Metal
import MetalKit
import AVFoundation

class XTRenderView: UIView {

    
    var device: MTLDevice!
    var commandQueue: MTLCommandQueue!
    var library: MTLLibrary!
    var pipelineState: MTLRenderPipelineState!
    
    var vertexBuffer: MTLBuffer!
    var matrix: MTLBuffer!
    var textureCache: CVMetalTextureCache!
    
    var pixelBuffer: CVPixelBuffer?
    
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        commit()
        setupUI()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - UI
    func setupUI() {
        addSubview(mtkView)
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        mtkView.frame = bounds
    }
    
    // MARK: - config
    func commit() {
        configDefaultDevice()
        setupPipelineState()
        setupVertexBuffer()
        setupMarrix()
    }
    
    func configDefaultDevice() {
        device = MTLCreateSystemDefaultDevice()
        library = device.makeDefaultLibrary()
        commandQueue = device.makeCommandQueue()
        CVMetalTextureCacheCreate(kCFAllocatorDefault, nil, device, nil, &textureCache)
    }
    
    func setupPipelineState() {
        let vf = library.makeFunction(name: "vertexShader")
        let ff = library.makeFunction(name: "fragmentShader")
        
        let p = MTLRenderPipelineDescriptor()
        p.colorAttachments[0].pixelFormat = MTLPixelFormat.bgra8Unorm
        p.vertexFunction = vf
        p.fragmentFunction = ff
        pipelineState = try! device.makeRenderPipelineState(descriptor: p)
    }
    
    func setupVertexBuffer() {
        let vertices = [
            XTVertex(position: [-1, -1], textureCoordinates: [0.0, 1.0]),
            XTVertex(position: [-1, 1], textureCoordinates: [0.0, 0.0]),
            XTVertex(position: [1, -1], textureCoordinates: [1.0, 1.0]),
            XTVertex(position: [1, 1], textureCoordinates: [1.0, 0.0]),
        ]
        vertexBuffer = device.makeBuffer(bytes: vertices, length: MemoryLayout<XTVertex>.size * 4, options: .storageModeShared)
    }
    
    func setupMarrix() {
        let col1 = simd_float3(1.0, 1.0, 1.0)
        let col2 = simd_float3(0.0, -0.343, 1.765)
        let col3 = simd_float3(1.4, -0.711, 0.0)
        let kColorConversion601FullRangeMatrix = matrix_float3x3(columns: (col1, col2, col3))
        let kColorConversion601FullRangeOffset = simd_float3(-(16.0/255.0), -0.5, -0.5)
        let matrix = [XTConvertMatrix(matrix: kColorConversion601FullRangeMatrix, offset: kColorConversion601FullRangeOffset)]
        self.matrix = device.makeBuffer(bytes: matrix, length: MemoryLayout<XTConvertMatrix>.size, options: .storageModeShared)
    }
    
    func setupTexture(encoder: MTLRenderCommandEncoder, pixelBuffer: CVPixelBuffer) {
        
        var textureY: MTLTexture?
        var textureUV: MTLTexture?
        
        var status: CVReturn = kCVReturnSuccess
        
        /// textureY
        let wY = CVPixelBufferGetWidthOfPlane(pixelBuffer, 0)
        let hY = CVPixelBufferGetHeightOfPlane(pixelBuffer, 0)
        let pfY = MTLPixelFormat.r8Unorm
        
        var metalTextureY: CVMetalTexture? = nil
        status = CVMetalTextureCacheCreateTextureFromImage(kCFAllocatorDefault, textureCache, pixelBuffer, nil, pfY, wY, hY, 0, &metalTextureY)
        if status == kCVReturnSuccess {
            textureY = CVMetalTextureGetTexture(metalTextureY!)
        }
        
        /// textureUV
        let wUV = CVPixelBufferGetWidthOfPlane(pixelBuffer, 1)
        let hUV = CVPixelBufferGetHeightOfPlane(pixelBuffer, 1)
        let pfUV = MTLPixelFormat.rg8Unorm
        
        var metalTextureUV: CVMetalTexture? = nil
        status = CVMetalTextureCacheCreateTextureFromImage(kCFAllocatorDefault, textureCache, pixelBuffer, nil, pfUV, wUV, hUV, 1, &metalTextureUV)
        if status == kCVReturnSuccess {
            textureUV = CVMetalTextureGetTexture(metalTextureUV!)
        }
        
        /// 设置纹理打编码器中
        if textureY != nil && textureUV != nil{
            encoder.setFragmentTexture(textureY, index: 0)
            encoder.setFragmentTexture(textureUV, index: 1)
        }
    }
    
    override func draw(_ rect: CGRect) {
        if let currentDrawable = mtkView.currentDrawable, let pixelBuffer = pixelBuffer {
            guard let commandBuffer = commandQueue.makeCommandBuffer() else {
                return
            }
            
            // 清屏
            let renderPassDescriptor = MTLRenderPassDescriptor()
            renderPassDescriptor.colorAttachments[0].clearColor = MTLClearColorMake(0.48, 0.74, 0.92, 1)
            renderPassDescriptor.colorAttachments[0].texture = currentDrawable.texture
            renderPassDescriptor.colorAttachments[0].loadAction = .clear
            renderPassDescriptor.colorAttachments[0].storeAction = .store
            guard let renderCommandEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor) else {
                return
            }
            
            renderCommandEncoder.setRenderPipelineState(pipelineState)
            renderCommandEncoder.setVertexBuffer(vertexBuffer, offset: 0, index: 0)
            renderCommandEncoder.setFragmentBuffer(matrix, offset: 0, index: 0)
            setupTexture(encoder: renderCommandEncoder, pixelBuffer: pixelBuffer)
            
            renderCommandEncoder.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: 4)
            renderCommandEncoder.endEncoding()
            commandBuffer.present(currentDrawable)
            commandBuffer.commit()
        }
    }
    
    func setupBuffer(pixelBuffer: CVPixelBuffer) {
        self.pixelBuffer = pixelBuffer
        self.draw(mtkView.frame)
    }
    
    // MARK: - lazy
    lazy var mtkView: MTKView = {
        let v = MTKView()
        v.device = self.device
        v.framebufferOnly = false
        return v
    }()
}
