//
//  XTShaderType.h
//  Metail-01(清屏)
//
//  Created by 熊涛 on 2019/9/27.
//  Copyright © 2019 熊涛. All rights reserved.
//

#ifndef XTShaderType_h
#define XTShaderType_h

#import <simd/simd.h>

typedef struct {
    vector_float2 position;
    vector_float2 textureCoordinates;
}XTVertex;

typedef struct {
    matrix_float3x3 matrix;
    vector_float3 offset;
}XTConvertMatrix;

#endif /* XTShaderType_h */
