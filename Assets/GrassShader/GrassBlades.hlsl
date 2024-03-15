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

float _AmbientIntensity;
float4 _vecAmbient;

float _DiffuseIntensity;

float _SpecularPower;
float _SpecularIntensity;

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
    float3 InNormal = input.normalWS;
    
    if(dot(InNormal, float3(0,1,0) < 0)) InNormal = -InNormal; // Flip the normal if it's facing the wrong way
    
    float light = dot(InNormal, GetMainLight().direction) * 0.5 + 0.5f;
    float3 viewDir = GetViewDirectionFromPosition(_WorldSpaceCameraPos);
    Light mainLight = GetMainLight();

    // //AO
     float maxHeight = 2.0f;
     light = (input.uv / maxHeight) * light;
    

    // return lerp(_BaseColor, _TipColor, light) + (CalculateSpecular(mainLight, normal, viewDir) * _SpecularColor);

    // Calculate the ambient term: 
  float4 Ambient = _AmbientIntensity * _vecAmbient; 
  // Calculate the diffuse term: 
    InNormal = normalize(InNormal); 
    float4 Diffuse = _DiffuseIntensity * float4(mainLight.color.r, mainLight.color.g, mainLight.color.b, 1) * saturate(dot(-mainLight.direction, InNormal)); 
  // Fetch the pixel color from the color map: 
    float4 Color = lerp(_BaseColor, _TipColor, light); 
  // Calculate the reflection vector: 
    float3 R = normalize(2 * dot(InNormal, -mainLight.direction) * InNormal + mainLight.direction); 
  // Calculate the speculate component: 
    float Specular = pow(saturate(dot(R, normalize(viewDir))), _SpecularPower) * _SpecularIntensity; 
  // Calculate final color: 
    return (Ambient + Diffuse + Specular) * Color; 
}

#endif