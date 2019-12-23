//
//  XTRenderView2.swift
//  Metal-10(视频播放)
//
//  Created by 熊涛 on 2019/12/19.
//  Copyright © 2019 xiong_tao. All rights reserved.
//

import UIKit

class XTRenderView2: XTRenderView {

    var textureBuffer1: (MTLTexture, MTLTexture)?
    var textureBuffer2: (MTLTexture, MTLTexture)?
    var textureBuffer3: (MTLTexture, MTLTexture)?
    var textureBuffer4: (MTLTexture, MTLTexture)?
    
    var pixelBuffer1: CVPixelBuffer?
    var pixelBuffer2: CVPixelBuffer?
    var pixelBuffer3: CVPixelBuffer?
    var pixelBuffer4: CVPixelBuffer?
    
    
    var textureCount: Float = 0
    var uniformBuffer: MTLBuffer!
    
    
    override func setupPipelineState() {
        let vf = library.makeFunction(name: "vertexShader2")
        let ff = library.makeFunction(name: "fragmentShader2")
        
        let p = MTLRenderPipelineDescriptor()
        p.colorAttachments[0].pixelFormat = MTLPixelFormat.bgra8Unorm
        p.vertexFunction = vf
        p.fragmentFunction = ff
        pipelineState = try! device.makeRenderPipelineState(descriptor: p)
        
        setupUniformBuffer()
    }
    
    func addTextureCount() {
        textureCount += 1
//        setupUniformBuffer()
    }
    
    func setupUniformBuffer() {
        let uniform = [XTUniform(textureCount: textureCount)]
        uniformBuffer = device.makeBuffer(bytes: uniform, length: MemoryLayout<XTUniform>.size, options: .storageModeShared)
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
//            renderCommandEncoder.setFragmentBuffer(uniformBuffer, offset: 0, index: 1)
            let uniform = [XTUniform(textureCount: textureCount)]
            let uniformBuffer = device.makeBuffer(bytes: uniform, length: MemoryLayout<XTUniform>.size, options: .storageModeShared)
            renderCommandEncoder.setFragmentBuffer(uniformBuffer, offset: 0, index: 1)
            
            let wY = CVPixelBufferGetWidthOfPlane(pixelBuffer, 0)
            let hY = CVPixelBufferGetHeightOfPlane(pixelBuffer, 0)
            let vs = transformVertices(vertex: vertexs, inputSize: CGSize(width: wY, height: hY), drawableSize: mtkView.drawableSize)
            let vertexBuffer = device.makeBuffer(bytes: vs, length: MemoryLayout<Float>.size * 8, options: [])
            let textureVerBuffer = device.makeBuffer(bytes: textureCoordinates, length: MemoryLayout<Float>.size * 8, options: [])
            renderCommandEncoder.setVertexBuffer(vertexBuffer, offset: 0, index: 0)
            renderCommandEncoder.setVertexBuffer(textureVerBuffer, offset: 0, index: 1)
            
            
            guard let (y, uv) = setupTexture(encoder: renderCommandEncoder, pixelBuffer: pixelBuffer) else {
                return
            }
            renderCommandEncoder.setFragmentTexture(y, index: 0)
            renderCommandEncoder.setFragmentTexture(uv, index: 1)
            
            if textureCount == 1, textureBuffer1 == nil {
                pixelBuffer1 = pixelBuffer
                textureBuffer1 = setupTexture(encoder: renderCommandEncoder, pixelBuffer: pixelBuffer1!)
            }
            if textureCount == 2, textureBuffer2 == nil {
                pixelBuffer2 = pixelBuffer
                textureBuffer2 = setupTexture(encoder: renderCommandEncoder, pixelBuffer: pixelBuffer2!)
            }
            if textureCount == 3, textureBuffer3 == nil {
                pixelBuffer3 = pixelBuffer
                textureBuffer3 = setupTexture(encoder: renderCommandEncoder, pixelBuffer: pixelBuffer3!)
            }
            if textureCount >= 4, textureBuffer4 == nil {
                pixelBuffer4 = pixelBuffer
                textureBuffer4 = setupTexture(encoder: renderCommandEncoder, pixelBuffer: pixelBuffer4!)
            }
            
            if textureBuffer1 != nil {
                let (y, uv) = textureBuffer1!
                renderCommandEncoder.setFragmentTexture(y, index: 2)
                renderCommandEncoder.setFragmentTexture(uv, index: 3)
            }
            if textureBuffer2 != nil {
                let (y, uv) = textureBuffer2!
                renderCommandEncoder.setFragmentTexture(y, index: 4)
                renderCommandEncoder.setFragmentTexture(uv, index: 5)
            }
            if textureBuffer3 != nil {
                let (y, uv) = textureBuffer3!
                renderCommandEncoder.setFragmentTexture(y, index: 6)
                renderCommandEncoder.setFragmentTexture(uv, index: 7)
            }
            if textureBuffer4 != nil {
                let (y, uv) = textureBuffer4!
                renderCommandEncoder.setFragmentTexture(y, index: 8)
                renderCommandEncoder.setFragmentTexture(uv, index: 9)
            }
            
            
            renderCommandEncoder.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: 4)
            renderCommandEncoder.endEncoding()
            commandBuffer.present(currentDrawable)
            commandBuffer.commit()
        }
    }

}
