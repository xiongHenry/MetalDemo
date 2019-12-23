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
    
    let vertexs: [Float] = [-1.0, 1.0, 1.0, 1.0, -1.0, -1.0, 1.0, -1.0]
    let textureCoordinates: [Float] = [0.0, 0.0, 1.0, 0.0, 0.0, 1.0, 1.0, 1.0]
    
    
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
//        setupVertexBuffer()
        setupMarrix()
    }
    
    func configDefaultDevice() {
        device = MTLCreateSystemDefaultDevice()
        library = device.makeDefaultLibrary()
        commandQueue = device.makeCommandQueue()
        CVMetalTextureCacheCreate(kCFAllocatorDefault, nil, device, nil, &textureCache)
    }
    
    func setupPipelineState() {
        let vf = library.makeFunction(name: "vertexShader2")
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
    
    func setupTexture(encoder: MTLRenderCommandEncoder, pixelBuffer: CVPixelBuffer) -> (MTLTexture, MTLTexture)? {
        
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
        if textureY != nil && textureUV != nil {
            return (textureY, textureUV) as? (MTLTexture, MTLTexture)
        }
        return nil
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
            renderCommandEncoder.setFragmentBuffer(matrix, offset: 0, index: 0)
            guard let (y, uv) = setupTexture(encoder: renderCommandEncoder, pixelBuffer: pixelBuffer) else {
                return
            }
            renderCommandEncoder.setFragmentTexture(y, index: 0)
            renderCommandEncoder.setFragmentTexture(uv, index: 1)
            
            
            let wY = CVPixelBufferGetWidthOfPlane(pixelBuffer, 0)
            let hY = CVPixelBufferGetHeightOfPlane(pixelBuffer, 0)
            let vs = transformVertices(vertex: vertexs, inputSize: CGSize(width: wY, height: hY), drawableSize: mtkView.drawableSize)
            let vertexBuffer = device.makeBuffer(bytes: vs, length: MemoryLayout<Float>.size * 8, options: [])
            let textureVerBuffer = device.makeBuffer(bytes: textureCoordinates, length: MemoryLayout<Float>.size * 8, options: [])
            renderCommandEncoder.setVertexBuffer(vertexBuffer, offset: 0, index: 0)
            renderCommandEncoder.setVertexBuffer(textureVerBuffer, offset: 0, index: 1)
            
            
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
    
    /// 顶点转换
    func transformVertices(vertex: [Float], inputSize: CGSize, drawableSize: CGSize) -> [Float] {
        
        let inputAspectRatio = inputSize.height / inputSize.width
        let drawableAspectRatio = drawableSize.height / drawableSize.width
        
        var xRatio: Float = 1.0
        var yRatio: Float = 1.0
        
        if inputAspectRatio > drawableAspectRatio {
            yRatio = 1.0
            xRatio = Float((inputSize.width / drawableSize.width) * (drawableSize.height / inputSize.height))
        }else {
            xRatio = 1.0
            yRatio = Float((inputSize.height / drawableSize.height) * (drawableSize.width / inputSize.width))
        }
        
        let value1 = vertex[0] * xRatio
        let value2 = vertex[1] * yRatio
        
        let value3 = vertex[2] * xRatio
        let value4 = vertex[3] * yRatio
        
        let value5 = vertex[4] * xRatio
        let value6 = vertex[5] * yRatio
        
        let value7 = vertex[6] * xRatio
        let value8 = vertex[7] * yRatio
        
        return [value1, value2, value3, value4, value5, value6, value7, value8]
    }
    
    // MARK: - lazy
    lazy var mtkView: MTKView = {
        let v = MTKView()
        v.device = self.device
        v.framebufferOnly = false
        return v
    }()
}
