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

float CalculateSpecular(Light light, float3 normal, float3 viewDir) {
    float3 R = normalize(2 * dot(normal, light.direction) * normal - light.direction); 
    float Specular = pow(saturate(dot(R, normalize(viewDir))), 1) * 1; 

    return Specular;
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

    InputData lightingInput = (InputData)0;
    lightingInput.positionWS = input.positionWS;
    lightingInput.normalWS = input.normalWS; // No need to normalize, triangles share a normal
    lightingInput.viewDirectionWS = GetViewDirectionFromPosition(input.positionWS); // Calculate the view direction
    lightingInput.shadowCoord = CalculateShadowCoord(input.positionWS, input.positionCS);

    // Lerp between the base and tip color based on the blade height
    float colorLerp = input.uv;
    float3 albedo = lerp(_BaseColor.rgb, _TipColor.rgb, colorLerp);

    SurfaceData surfaceInput = (SurfaceData)0;
    surfaceInput.albedo = albedo;
    surfaceInput.alpha = 1;
    surfaceInput.specular = 0;
    surfaceInput.smoothness = 0;
    surfaceInput.occlusion = 1;
    
    return UniversalFragmentPBR(lightingInput, surfaceInput);
}

#endif