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
float _PosterizeSteps;

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
    float3 normal = input.normalWS;
    //if(dot(normal, float3(0,1,0)) < 0) normal = -normal;

    InputData lightingInput = (InputData)0;
    lightingInput.positionWS = input.positionWS;
    lightingInput.normalWS = normal; // No need to normalize, triangles share a normal
    lightingInput.viewDirectionWS = GetViewDirectionFromPosition(input.positionWS); // Calculate the view direction
    lightingInput.shadowCoord = CalculateShadowCoord(input.positionWS, input.positionCS);

    // Lerp between the base and tip color based on the blade height
    float colorLerp = input.uv;
    float3 albedo = lerp(_BaseColor.rgb, _TipColor.rgb, colorLerp);
    float4 albedo4 = lerp(_BaseColor, _TipColor, colorLerp);

    SurfaceData surfaceInput = (SurfaceData)0;
    surfaceInput.albedo = albedo;
    surfaceInput.alpha = 1;
    surfaceInput.specular = 1;
    surfaceInput.smoothness = 0.15;
    surfaceInput.occlusion = 1;
    
    return lerp(UniversalFragmentBlinnPhong(lightingInput, surfaceInput), (floor(UniversalFragmentPBR(lightingInput, surfaceInput) / (1 / _PosterizeSteps)) * (1 / _PosterizeSteps)), colorLerp/3.5);
}

#endif