#ifndef GRASSBLADES_INCLUDED
#define GRASSBLADES_INCLUDED

#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
#include "NMGGrassBladeGraphicsHelpers.hlsl"

struct DrawVertex {
    float3 positionWS;
    float height;
};

struct DrawTriangle {
    float3 lightingNormalWS;
    DrawVertex vertices[3];
};

StructuredBuffer<DrawTriangle> _DrawTriangles;

struct VertexOutput {
    float uv            : TEXCOORD0;
    float3 positionWS   : TEXCOORD1;
    float3 normalWS     : TEXCOORD2;

    float4 positionCS   : SV_POSITION;
};

float4 _BaseColor;
float4 _TipColor;
float4 _SpecularColor;

half4 CalculateSpecular(Light light, float3 normal, float3 viewDir) {
    return saturate(dot(normal, normalize(light.direction + viewDir)));
}

VertexOutput Vertex(uint vertexID: SV_VertexID) {
    // Initialize the output struct
    VertexOutput output = (VertexOutput)0;

    // Get the vertex from the buffer
    // Since the buffer is structured in triangles, we need to divide the vertexID by three
    // to get the triangle, and then modulo by 3 to get the vertex on the triangle
    DrawTriangle tri = _DrawTriangles[vertexID / 3];
    DrawVertex input = tri.vertices[vertexID % 3];

    output.positionWS = input.positionWS;
    output.normalWS = tri.lightingNormalWS;
    output.uv = input.height;
    output.positionCS = TransformWorldToHClip(input.positionWS);

    return output;
}

half4 Fragment(VertexOutput input) : SV_Target {
    float3 normal = input.normalWS;
    
    if(dot(normal, float3(0,1,0) < 0)) normal = -normal; // Flip the normal if it's facing the wrong way
    
    float light = dot(normal, GetMainLight().direction) * 0.5 + 0.5f;
    float3 viewDir = GetViewDirectionFromPosition(input.positionWS);
    Light mainLight = GetMainLight();

    //AO
    float maxHeight = 2.0f;
    light = (input.uv / maxHeight) * light;
    

    return lerp(_BaseColor, _TipColor, light) + CalculateSpecular(mainLight, normal, viewDir);
}

#endif