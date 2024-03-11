#ifndef CUSTOM_LIGHTING_INCLUDED
#define CUSTOM_LIGHTING_INCLUDED

#ifndef SHADERGRAPH_PREVIEW
#include "Packages/com.unity.render-pipelines.universal/Editor/ShaderGraph/Includes/ShaderPass.hlsl"
#if (SHADERPASS != SHADERPASS_FORWARD)
#undef REQUIRES_VERTEX_SHADOW_COORD_INTERPOLATOR
#endif
#endif

struct CustomLightingData
{
	// Position and Orientation
    float3 positionWS;
    float3 normalWS;
    float3 viewDirectionWS;
    float4 shadowCoord;
	
	// Surface Attributes
    float3 albedo;
    float smoothness;
    float ambientOcclusion;
	
	// Baked lighting
    float3 bakedGI;
    float4 shadowMask;
    float fogFactor;
    
    // Fresnel Effect
    float edgePower;
    float shadowPower;
    float fresnelStrength;
    
    // Stylized
    float cellAmount;
    float specularStrength;
};

float GetSmoothnessPower(float rawSmoothness)
{
    return exp2(10 * rawSmoothness + 1);
}

#ifndef SHADERGRAPH_PREVIEW

float3 CalculateFresnelEffect(CustomLightingData d, Light light)
{
    float EdgeIllumination = pow(1 - saturate(dot(d.viewDirectionWS, d.normalWS)), d.edgePower);
    float ShadowTerm = pow(saturate(dot(d.normalWS, -(light.direction))), d.shadowPower);

    return (max(step(0.2, (EdgeIllumination * ShadowTerm)), ((EdgeIllumination * ShadowTerm) * 0.25)) * d.fresnelStrength) * light.color;
}

float3 CustomGlobalIllumination(CustomLightingData d)
{
    float3 indirectDiffuse = d.albedo * d.bakedGI * d.ambientOcclusion;
	
    float3 reflectVector = reflect(-d.viewDirectionWS, d.normalWS);
    float fresnel = Pow4(1 - saturate(dot(d.viewDirectionWS, d.normalWS)));
    float3 indirectSpecular = GlossyEnvironmentReflection(reflectVector,
        RoughnessToPerceptualRoughness(1 - d.smoothness),
        d.ambientOcclusion) * fresnel;
	
    return indirectDiffuse + indirectSpecular;
}

float3 CustomLightHandling(CustomLightingData d, Light light)
{
    float3 radiance = light.color * (light.distanceAttenuation * light.shadowAttenuation);
	
    float diffuse = saturate(dot(d.normalWS, light.direction));
    // Voor funky shadows verander naar max function en zet cellAmount op 0
    float steppedDiffuse = min(diffuse, (step(d.cellAmount, diffuse)));
    float specularCalc = saturate(dot(d.normalWS, normalize(light.direction + d.viewDirectionWS)));
    float specularDot = max(specularCalc, step(d.specularStrength, specularCalc));
    float specular = pow(specularDot, GetSmoothnessPower(d.smoothness)) * diffuse;

    float3 color = d.albedo * radiance * (steppedDiffuse + specular);
    color += CalculateFresnelEffect(d, light);
	
    return color;
}

#endif


float3 CalculateCustomLighting(CustomLightingData d)
{
#ifdef SHADERGRAPH_PREVIEW
	float3 lightDir = float3(0.5, 0.5, 0);
	float intensity = saturate(dot(d.normalWS, lightDir)) + 
		pow(saturate(dot(d.normalWS, normalize(d.viewDirectionWS + lightDir))), GetSmoothnessPower(d.smoothness));
	return d.albedo * intensity;
#else
    Light mainLight = GetMainLight(d.shadowCoord, d.positionWS, d.shadowMask);
	
	// In mixed subtractive baked lights, main light must be subtracted from bakedGI val
    MixRealtimeAndBakedGI(mainLight, d.normalWS, d.bakedGI);
	
    float3 color = CustomGlobalIllumination(d);
	// Shade the main light
    color += CustomLightHandling(d, mainLight);
	
#ifdef _ADDITIONAL_LIGHTS
        // Shade additional cone and point lights. Functions in URP/ShaderLibrary/Lighting.hlsl
        uint numAdditionalLights = GetAdditionalLightsCount();
        for (uint lightI = 0; lightI < numAdditionalLights; lightI++) {
            Light light = GetAdditionalLight(lightI, d.positionWS, d.shadowMask);
            color += CustomLightHandling(d, light);
        }
#endif
    
    color = MixFog(color, d.fogFactor);

    return color;
#endif
}

void CalculateCustomLighting_float(float3 Position, float3 Normal, float3 ViewDirection,
	float3 Albedo, float Smoothness, float AmbientOcclusion, float EdgePower, float ShadowPower, float Strength, float CellAmount, float SpecularStrength, 
	float2 LightmapUV,
	out float3 Color)
{

    CustomLightingData d;
    d.positionWS = Position;
    d.normalWS = Normal;
    d.viewDirectionWS = ViewDirection;
    d.albedo = Albedo;
    d.smoothness = Smoothness;
    d.ambientOcclusion = AmbientOcclusion;
    d.edgePower = EdgePower;
    d.shadowPower = ShadowPower;
    d.fresnelStrength = Strength;
    d.cellAmount = CellAmount;
    d.specularStrength = SpecularStrength;
	
#ifdef SHADERGRAPH_PREVIEW
	d.shadowCoord = 0;
	d.bakedGI = 0;
    d.shadowMask = 0;
    d.fogFactor = 0;
#else
    float4 positionCS = TransformWorldToHClip(Position);
#if SHADOWS_SCREEN
		d.shadowCoord = ComputeScreenPos(positionCS);
#else
    d.shadowCoord = TransformWorldToShadowCoord(Position);
#endif
	
    float2 lightmapUV;
    OUTPUT_LIGHTMAP_UV(LightmapUV, unity_LightmapST, lightmapUV);
	
    float3 vertexSH;
    OUTPUT_SH(Normal, vertexSH);
	
    d.bakedGI = SAMPLE_GI(lightmapUV, vertexSH, Normal);
    d.shadowMask = SAMPLE_SHADOWMASK(lightmapUV);
    d.fogFactor = ComputeFogFactor(positionCS.z);
#endif

    Color = CalculateCustomLighting(d);
}

#endif