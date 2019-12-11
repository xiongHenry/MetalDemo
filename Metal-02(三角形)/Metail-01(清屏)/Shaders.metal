//
//  Shaders.metal
//  Metail-01(清屏)
//
//  Created by 熊涛 on 2019/9/26.
//  Copyright © 2019 熊涛. All rights reserved.
//

#include <metal_stdlib>
#import "XTShaderTypes.h"
using namespace metal;

/// 定点着色器返回
typedef struct {
    float4 position [[position]]; //position修饰符表示这个是顶点
    float4 color; //颜色
}RasterizeData;


/// 顶点着色器
/*
 vertices： 顶点数据
 vertex_id: 表示顶点坐标 是顶点每次处理的index，用于定位当前顶点
 */
vertex RasterizeData vertexShader(constant XTVertex *vertices [[buffer(XTVertexInputIndexVertices)]], uint vid[[vertex_id]]) {
    
    RasterizeData outData;
    outData.position = vector_float4(vertices[vid].position, 0.0, 1.0);
    outData.color = vertices[vid].color;
    
    return outData;
}


///片元着色器
/*
 inVertex: 顶点着色器输出经过光栅化传入
 */
fragment float4 fragmentShader(RasterizeData inVertex [[stage_in]]) {
    return inVertex.color;
}
