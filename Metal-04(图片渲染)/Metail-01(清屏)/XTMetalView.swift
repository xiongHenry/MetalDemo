//
//  XTMetalView.swift
//  Metail-01(清屏)
//
//  Created by 熊涛 on 2019/9/25.
//  Copyright © 2019 熊涛. All rights reserved.
//

import UIKit
import Metal

class XTMetalView: UIView {

    //1. Metal 提供给开发者与 GPU 交互的能力。而这能力，则需要依赖 MTLDevice 来实现。
    /*
     一个 MTLDevice 对象代表一个可以执行指令的 GPU。
     MTLDevice 协议提供了查询设备功能、创建 Metal 其他对象等方法。
     */
    var device: MTLDevice?
    //2.渲染管线
    var pipelineState: MTLRenderPipelineState!
    ///3.纹理
    var texture: MTLTexture?
    ///4.顶点坐标
    var vertexBuffer: MTLBuffer?
    
    
    
    // MARK: -  init
    override init(frame: CGRect) {
        super.init(frame: frame)
        commonInit()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        commonInit()
    }
    
    /*
     了解 Core Animation 的朋友一定知道，实际上负责渲染的是 CALayer，而 UIView 主要做内容的管理和事件的响应
     Core Animation 定义了 CAMetalLayer 类，它的 content 是由 Metal 进行渲染的
     */
    var metalLayer: CAMetalLayer {
        return layer as! CAMetalLayer
    }
    
    override class var layerClass: AnyClass {
        return CAMetalLayer.self
    }
    
    
    // MARK: - private
    private func commonInit() {
        device = MTLCreateSystemDefaultDevice()
        
        setpipelineState()
        setTexture()
        setVextexBuffer()
    }
    
    // MARK: - 顶点坐标
    func setVextexBuffer() {
        let vertices = [
            XTVertex(position: [-1, -1], textureCoordinates: [0.0, 1.0]),
            XTVertex(position: [-1, 1], textureCoordinates: [0.0, 0.0]),
            XTVertex(position: [1, -1], textureCoordinates: [1.0, 1.0]),
            XTVertex(position: [1, 1], textureCoordinates: [1.0, 0.0]),
        ]
        vertexBuffer = device?.makeBuffer(bytes: vertices, length: MemoryLayout<XTVertex>.size * 4, options: .cpuCacheModeWriteCombined)
    }
    
    // MARK: - 渲染管线
    func setpipelineState() {
        let library = device?.makeDefaultLibrary()
        let vertexFunction = library?.makeFunction(name: "vertexShader")
        let fragmentFunction = library?.makeFunction(name: "fragmentShader")
        
        
        let pipelineDescriptor = MTLRenderPipelineDescriptor()
        pipelineDescriptor.colorAttachments[0].pixelFormat = metalLayer.pixelFormat
        pipelineDescriptor.vertexFunction = vertexFunction
        pipelineDescriptor.fragmentFunction = fragmentFunction
        
        pipelineState = try! device?.makeRenderPipelineState(descriptor: pipelineDescriptor)
    }

    // MARK: - texture
    func setTexture() {
        guard let image = UIImage(named: "lena") else { return }
        texture = newTexture(image)
    }
    
    func newTexture(_ image: UIImage) -> MTLTexture {
        let imageRef = image.cgImage!
        let width = imageRef.width
        let height = imageRef.height
        let colorSpace = CGColorSpaceCreateDeviceRGB() //色域
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
        let texture = device?.makeTexture(descriptor: textureDescriptor)
        let region = MTLRegionMake2D(0, 0, width, height)
        texture?.replace(region: region, mipmapLevel: 0, withBytes: rawData!, bytesPerRow: bytesPerRow)
        free(rawData)
        return texture!
    }
    
    override func didMoveToWindow() {
        super.didMoveToWindow()
        render()
    }
    
    func render() {
        guard let drawable = metalLayer.nextDrawable() else {
            return
        }
        /// 渲染的指令
        /*
         texture：关联的纹理，即渲染目标。必须设置，不然内容不知道要渲染到哪里。不设置会报错：failed assertion `No rendertargets set in RenderPassDescriptor.'
         loadAction：决定前一次 texture 的内容需要清除、还是保留
         storeAction：决定这次渲染的内容需要存储、还是丢弃
         clearColor：当 loadAction 是 MTLLoadActionClear 时，则会使用对应的颜色来覆盖当前 texture（用某一色值逐像素写入）
         */
        let renderPassDescriptor = MTLRenderPassDescriptor()
        renderPassDescriptor.colorAttachments[0].clearColor = MTLClearColorMake(0.48, 0.74, 0.92, 1)
        renderPassDescriptor.colorAttachments[0].texture = drawable.texture
        renderPassDescriptor.colorAttachments[0].loadAction = .clear
        renderPassDescriptor.colorAttachments[0].storeAction = .store
        
        /// 渲染的指令，Metal管理,提交指令
        let commandQueue = device?.makeCommandQueue()
        let commandBuffer = commandQueue?.makeCommandBuffer()
        let renderCommandEncoder = commandBuffer?.makeRenderCommandEncoder(descriptor: renderPassDescriptor)
        
        ///
        ///1.设置渲染管线
        renderCommandEncoder?.setRenderPipelineState(pipelineState!)
        ///2.顶点数据
        renderCommandEncoder?.setVertexBuffer(vertexBuffer, offset: 0, index: 0)
        ///3.设置纹理数据
        renderCommandEncoder?.setFragmentTexture(texture, index: 0)
        //4.绘制三角形
        /*
         注意:必须先设置渲染管线后才能设置基础图元类型
         */
        renderCommandEncoder?.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: 4)
        
        renderCommandEncoder?.endEncoding()
        commandBuffer?.present(drawable)
        commandBuffer?.commit()
    }
}
