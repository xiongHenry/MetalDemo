//
//  XTShaderTypes.h
//  Metail-01(清屏)
//
//  Created by 熊涛 on 2019/9/26.
//  Copyright © 2019 熊涛. All rights reserved.
//

#ifndef XTShaderTypes_h
#define XTShaderTypes_h

#include <simd/simd.h>

typedef struct {
    vector_float2 position; //定点坐标
    vector_float4 color; //定点颜色
} XTVertex;


//用来区分顶点着色器输入参数对应的下标，这里只有顶点数据一项。XTVertexInputIndexVertices 定义的值是 0。
typedef enum XTVertexInputIndex {
    XTVertexInputIndexVertices = 0,
    XTVertexInputIndexCOunt = 1
}XTVertexInputIndex;


#endif /* XTShaderTypes_h */
