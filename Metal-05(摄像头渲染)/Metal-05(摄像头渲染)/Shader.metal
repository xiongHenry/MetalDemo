//
//  Shader.metal
//  Metail-01(清屏)
//
//  Created by 熊涛 on 2019/9/27.
//  Copyright © 2019 熊涛. All rights reserved.
//

#include <metal_stdlib>
using namespace metal;

#import "XTShaderType.h"

typedef struct {
    float4 position [[position]];
    float2 texCoords;
}RasterizerData;

/*
 1.顶点坐标
 2.纹理坐标
 3.当前处理顶点index
 */
vertex RasterizerData vertexShader(constant XTVertex *vertices[[buffer(0)]], uint vid[[vertex_id]]) {
    
    RasterizerData outData;
    outData.position = float4(vertices[vid].position, 0.0, 1.0);
    outData.texCoords = vertices[vid].textureCoordinates;
    
    return outData;
}

/*
 1.纹理数据
 2.纹理坐标
 */
fragment float4 fragmentShader(RasterizerData inVertex [[stage_in]], texture2d<float> tex2d [[texture(0)]]) {
    
    //取样器
    constexpr sampler textureSampler (mag_filter::linear,
                                      min_filter::linear
                                      );
    ///取像素返回
    return tex2d.sample(textureSampler, inVertex.texCoords);
}
