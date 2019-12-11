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


constant float SquareSize = 63.0 / 512.0;
/*
 1.纹理数据
 2.纹理坐标
 */
fragment float4 fragmentShader(RasterizerData inVertex [[stage_in]],
                               texture2d<float> originalTexture [[texture(0)]],
                               texture2d<float> lutTexture [[texture(1)]]) {

    /*
     归一化
     */

    //取样器
    constexpr sampler textureSampler (mag_filter::linear,
                                      min_filter::linear
                                      );
    ///取像素返回
    float4 textureColor = originalTexture.sample(textureSampler, inVertex.texCoords);

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


constant half sobelStep = 2.0;
constant half3 kRec709Luma = half3(0.2126, 0.7152, 0.0722); // 把rgba转成亮度值

kernel void sobelKernel(texture2d<half, access::read> sourceTexutre [[texture(0)]],
                        texture2d<half, access::write> destTexture [[texture(1)]],
                        uint2 grid [[thread_position_in_grid]]) {
    
    /*
     
     行数     9个像素          位置
     上     | * * * |      | 左 中 右 |
     中     | * * * |      | 左 中 右 |
     下     | * * * |      | 左 中 右 |
     
     */
    
    half4 topLeft = sourceTexutre.read(uint2(grid.x - sobelStep, grid.y - sobelStep)); //左上
    half4 top = sourceTexutre.read(uint2(grid.x, grid.y - sobelStep)); //上
    half4 topRight = sourceTexutre.read(uint2(grid.x + sobelStep, grid.y - sobelStep)); //右上
    half4 centerLeft = sourceTexutre.read(uint2(grid.x - sobelStep, grid.y)); // 中左
//    half4 center = sourceTexutre.read(uint2(grid.x, grid.y)); // 中
    half4 centerRight = sourceTexutre.read(uint2(grid.x + sobelStep, grid.y)); // 中右
    half4 bottomLeft = sourceTexutre.read(uint2(grid.x - sobelStep, grid.y + sobelStep)); //左下
    half4 bottom = sourceTexutre.read(uint2(grid.x, grid.y + sobelStep)); //下
    half4 bottomRight = sourceTexutre.read(uint2(grid.x + sobelStep, grid.y + sobelStep)); //右下
    
    half4 h = -topLeft - top * 2.0 - topRight + bottomLeft + bottom * 2.0 + bottomRight;
    half4 v = - topLeft - centerLeft * 2.0 - bottomRight + topRight + centerRight * 2 + bottomRight;
    
    
    half grayH = dot(h.rgb, kRec709Luma); //转换成亮度
    half grayV = dot(v.rgb, kRec709Luma); //转换成亮度
    
    // sqrt(h^2 + v^2)，相当于求点到(h, v)的距离，所以可以用length
    half color = length(half2(grayH, grayV));
    
    destTexture.write(half4(color, color, color, 1), grid); //协会对应纹理
    
}
