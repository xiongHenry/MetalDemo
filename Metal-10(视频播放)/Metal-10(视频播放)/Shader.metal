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
 1.顶点坐标
 2.纹理坐标
 3.当前处理顶点index
 */
vertex RasterizerData vertexShader2(device packed_float2 *posotion [[buffer(0)]],
                                    device packed_float2 *textureCoordinates [[buffer(1)]],
                                    uint vid[[vertex_id]]) {
    
    RasterizerData outData;
    outData.position = float4(posotion[vid], 0.0, 1.0);
    outData.texCoords = textureCoordinates[vid];
    
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


constant float SquareSize = 63.0 / 512.0;
/*
 1.纹理数据
 2.纹理坐标
 */
fragment float4 abaoFragmentShader(RasterizerData inVertex [[stage_in]],
                                   texture2d<float> textureY [[texture(0)]], // texture 表明是纹理数据
                                   texture2d<float> textureUV [[texture(1)]], // texture 表明是纹理数据
                                   texture2d<float> lutTexture [[texture(2)]],
                                   constant XTConvertMatrix *convertMarix [[buffer(0)]] // buffer表示名缓存数据
                                   ) {
    
    /*
     归一化
     */
    
    //取样器
    constexpr sampler textureSampler (mag_filter::linear,
                                      min_filter::linear
                                      );
    
    float3 yuv = float3(textureY.sample(textureSampler, inVertex.texCoords).r,
                        (textureUV.sample(textureSampler, inVertex.texCoords).rg));
    float3 rgb = convertMarix[0].matrix * (yuv + convertMarix[0].offset);
    float4 textureColor = float4(rgb, 1.0);
    ///取像素返回
//    float4 textureColor = originalTexture.sample(textureSampler, inVertex.texCoords);
    
    /// 0 ~ 64
    float blueColor = textureColor.b * 63.0h; //蓝色部分[0, 63] 共64种
    
    float2 quad1; //第一个方格的位置
    quad1.y = floor(floor(blueColor) * 0.125);
    quad1.x = floor(blueColor) - (quad1.y * 8.0);
    
    float2 quad2; //第二个方格的位置
    quad2.y = floor(ceil(blueColor) * 0.125);
    quad2.x = ceil(blueColor) - (quad2.y * 8.0);
    
    /*
     SquareSize 是一个小格子在这整个图片的纹理宽度
     */
    
    float2 texPos1; // 计算rgb在第一个格子中对应的位置
    texPos1.x = (quad1.x * 0.125) + (SquareSize * textureColor.r);
    texPos1.y = (quad1.y * 0.125) + (SquareSize * textureColor.g);
    
    float2 texPos2; // 同上
    texPos2.x = (quad2.x * 0.125) + (SquareSize * textureColor.r);
    texPos2.y = (quad2.y * 0.125) + (SquareSize * textureColor.g);
    
    float4 newColor1 = lutTexture.sample(textureSampler, texPos1); // 正方形1的颜色值
    float4 newColor2 = lutTexture.sample(textureSampler, texPos2); // 正方形2的颜色值
    
    float4 newColor = mix(newColor1, newColor2, fract(blueColor)); // 根据小数点的部分进行mix
    
    return float4(newColor.rgb, textureColor.w);// 不修改alpha值
}
