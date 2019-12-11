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
    float4 position [[position]]; /// position修饰符表示这个是顶点
    float2 texCoords; /// 纹理坐标
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
fragment float4 fragmentShader(RasterizerData inVertex [[stage_in]], //stage_in表示这个数据来自光栅化
                               texture2d<float> textureY [[texture(0)]], // texture 表明是纹理数据
                               texture2d<float> textureUV [[texture(1)]], // texture 表明是纹理数据
                               constant XTConvertMatrix *convertMarix [[buffer(0)]] // buffer表示名缓存数据
                               ) {
    
    //取样器
    constexpr sampler textureSampler (mag_filter::linear,
                                      min_filter::linear
                                      );
    
    float3 yuv = float3(textureY.sample(textureSampler, inVertex.texCoords).r,
                        (textureUV.sample(textureSampler, inVertex.texCoords).rg));
    float3 rgb = convertMarix[0].matrix * (yuv + convertMarix[0].offset);
    
    return float4(rgb, 1.0);
}
