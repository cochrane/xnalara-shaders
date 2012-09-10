/*******************************************************************************
 * Modified by Torsten Kammer (Cochrane)
 *
 * I've added real normal mapping here, but left the interface to the program as
 * it was. So there is still no real support for ambient lighting, specular
 * highlights are always white unless there's a specular texture, and so on.
 *
 * In front of every function, there is a comment block explaining what I did.
 * It's not hard to find: There are no other comments. Other than the changes
 * I've mentioned, this code stays fairly close to the original. I've pointed
 * out ways it could be changed there, too.
 *
 * The original code remains, commented out, for reference.
 */
float4x4 World;
float4x4 View;
float4x4 Projection;

float3 CameraPos;

float3 Light1Dir;
float4 Light1Color;
float Light1Intensity;
float Light1ShadowDepth;

float3 Light2Dir;
float4 Light2Color;
float Light2Intensity;
float Light2ShadowDepth;

float3 Light3Dir;
float4 Light3Color;
float Light3Intensity;
float Light3ShadowDepth;

float BumpShadowAmount; // This is no longer used, but I have no idea what happens if I comment it out and don't tell the rest of the program.
float BumpSpecularAmount;
float BumpSpecularGloss;
float Bump1UVScale;
float Bump2UVScale;
float ReflectionAmount;

Texture DiffuseTexture;
Texture LightmapTexture;
Texture BumpTexture;
Texture MaskTexture;
Texture Bump1Texture;
Texture Bump2Texture;
Texture SpecularTexture;
Texture EnvironmentTexture;

bool DisplayTextures;
bool EnableBumpMaps;

bool UseAlternativeReflection;

float4x4 BoneMatrices[59];


struct VertexShaderInput
{
    float4 Position: POSITION0;
    float4 Normal: NORMAL0;
    float4 Color: COLOR0;
    float2 TexCoord: TEXCOORD0;
    float4 Tangent: TANGENT0;
    float4 BoneIndices: BLENDINDICES0;
    float4 BoneWeights: BLENDWEIGHT0;
};


struct BasicVertexShaderOutput
{
    float4 Position: POSITION0;
    float4 Color: COLOR0;
    float2 TexCoord: TEXCOORD0;
    float3 NormalWorld: TEXCOORD1;
};


struct BumpVertexShaderOutput
{
    float4 Position: POSITION0;
    float4 Color: COLOR0;
    float2 TexCoord: TEXCOORD0;
    float3 PositionWorld: TEXCOORD1;
    float3 NormalWorld: TEXCOORD2; // You could remove this; I don't use it in any pixel shader anymore, but I know too little of DirectX to dare take it out myself. Remember to remove it from the vertex shader, too. Do keep NormalWorld in the struct above!
    float3x3 TangentToWorld: TEXCOORD3;
};


sampler DiffuseTextureSampler = sampler_state { 
	texture = <DiffuseTexture>; 
	magfilter = LINEAR; 
	minfilter = LINEAR; 
	mipfilter = LINEAR; 
	AddressU = wrap;
	AddressV = wrap;
};


sampler LightmapTextureSampler = sampler_state { 
	texture = <LightmapTexture>; 
	magfilter = LINEAR; 
	minfilter = LINEAR; 
	mipfilter = LINEAR; 
	AddressU = wrap;
	AddressV = wrap;
};


sampler BumpTextureSampler = sampler_state { 
	texture = <BumpTexture>; 
	magfilter = LINEAR; 
	minfilter = LINEAR; 
	mipfilter = LINEAR; 
	AddressU = wrap;
	AddressV = wrap;
};


sampler MaskTextureSampler = sampler_state { 
	texture = <MaskTexture>; 
	magfilter = LINEAR; 
	minfilter = LINEAR; 
	mipfilter = LINEAR; 
	AddressU = wrap;
	AddressV = wrap;
};


sampler Bump1TextureSampler = sampler_state { 
	texture = <Bump1Texture>; 
	magfilter = LINEAR; 
	minfilter = LINEAR; 
	mipfilter = LINEAR; 
	AddressU = wrap;
	AddressV = wrap;
};


sampler Bump2TextureSampler = sampler_state { 
	texture = <Bump2Texture>; 
	magfilter = LINEAR; 
	minfilter = LINEAR; 
	mipfilter = LINEAR; 
	AddressU = wrap;
	AddressV = wrap;
};


sampler SpecularTextureSampler = sampler_state { 
	texture = <SpecularTexture>; 
	magfilter = LINEAR; 
	minfilter = LINEAR; 
	mipfilter = LINEAR; 
	AddressU = wrap;
	AddressV = wrap;
};


sampler EnvironmentTextureSampler = sampler_state { 
	texture = <EnvironmentTexture>; 
	magfilter = LINEAR; 
	minfilter = LINEAR; 
	mipfilter = LINEAR; 
	AddressU = wrap;
	AddressV = wrap;
};


float4 BlendColorLayers_2(float4 color1, float4 color2)
{
	float4 color;
	color.rgb = color1.rgb + color2.rgb;
	color.a = color1.a;
	return color;
}


float4 BlendColorLayers_3(float4 color1, float4 color2, float4 color3)
{
	float4 color;
	color.rgb = color1.rgb + color2.rgb + color3.rgb;
	color.a = color1.a;
	return color;
}


float4 GetDiffuseColor(float2 texCoord)
{
	float4 color = tex2D(DiffuseTextureSampler, texCoord);
	if (!DisplayTextures) {
		color.rgb = 0.75;
	}
	return color;
}


float4 GetDiffuseColorShadeless(float2 texCoord)
{
	float4 color = tex2D(DiffuseTextureSampler, texCoord);
	if (!DisplayTextures) {
		color.rgb = 1.0;
	}
	return color;
}


float CalcPhongShadingFactors_1(float3 normal)
{
	float factor1 = saturate(dot(normal, -Light1Dir));
	return factor1;
}


float2 CalcPhongShadingFactors_2(float3 normal)
{
	float factor1 = saturate(dot(normal, -Light1Dir));
	float factor2 = saturate(dot(normal, -Light2Dir));
	return float2(factor1, factor2);
}


float3 CalcPhongShadingFactors_3(float3 normal)
{
	float factor1 = saturate(dot(normal, -Light1Dir));
	float factor2 = saturate(dot(normal, -Light2Dir));
	float factor3 = saturate(dot(normal, -Light3Dir));
	return float3(factor1, factor2, factor3);
}


float4 CalcPhongShadingColor1(float3 normal, float shadingFactor1)
{
	float shading = shadingFactor1;
	shading = lerp(1, shading, Light1ShadowDepth);
	return float4(Light1Color.rgb * shading, 1);
}


float4 CalcPhongShadingColor2(float3 normal, float shadingFactor2)
{
	float shading = shadingFactor2;
	shading = lerp(1, shading, Light2ShadowDepth);
	return float4(Light2Color.rgb * shading, 1);
}


float4 CalcPhongShadingColor3(float3 normal, float shadingFactor3)
{
	float shading = shadingFactor3;
	shading = lerp(1, shading, Light3ShadowDepth);
	return float4(Light3Color.rgb * shading, 1);
}

/*******************************************************************************
 * Original way bumpmaps were handled in XNALara, together with other functions.
 *
 * Not really sure what it does. Overlay seems to be in the 0-1 range. Makes
 * color darker or brighter. Definitely not needed for real normal mapping.
float4 BumpShadowFunc(float4 base, float overlay)
{
	float4 output;
	output.rgb = base.rgb * (base.rgb + 2 * overlay * (1 - base.rgb));
	output.a = base.a;
	return output;
}
*/

/*******************************************************************************
 * Combines several bump colors to one.
 *
 * Nothing to change here, but if you want, you can adjust the weights to have
 * the detail bump maps feature more prominently.
 */
float4 CombineBumpColors(float4 color0, float4 color1, float amount1, float4 color2, float amount2)
{
	float4 color;
	color.rgb = color0.rgb + (color1.rgb - 0.5) * amount1 + (color2.rgb - 0.5) * amount2;
	color.a = color0.a;
	return color;
}

/*******************************************************************************
 * Gets the several bump colors from the samplers for …3 shaders.
 * 
 * Nothing to change here, only the normal for disabled normals was weird.
 */
float4 CombinedBumpColor(BumpVertexShaderOutput input)
{
	if (!EnableBumpMaps) {
		return float4(0.5, 0.5, 1, 1); // Note: After *2-1, will be 0, 0, 1
	}
	else {
		float4 bump0Color = tex2D(BumpTextureSampler, input.TexCoord);
		float4 maskColor = tex2D(MaskTextureSampler, input.TexCoord);	
		float4 bump1Color = tex2D(Bump1TextureSampler, input.TexCoord * Bump1UVScale);
		float4 bump2Color = tex2D(Bump2TextureSampler, input.TexCoord * Bump2UVScale);
		return CombineBumpColors(bump0Color, bump1Color, maskColor.r, bump2Color, maskColor.g);
	}
}

/*******************************************************************************
 * Normal from just one bumpmap.
 * 
 * The special treatment for b is odd; it makes all normals point z+, which is
 * admittedly likely, but not consistent with CombineBumpColors or the way it's
 * normally done.
 *
 * Changed to uniform scaling. You can try changing back and see what you like
 * more.
 */
float3 CalcBumpNormal(float4 bumpColor, BumpVertexShaderOutput input)
{
	//float3 bumpNormalT = float3(bumpColor.rg * 2 - 1, bumpColor.b);
	float3 bumpNormalT = bumpColor.rgb * 2 - 1;	
	return normalize(mul(bumpNormalT, input.TangentToWorld));
}

/*******************************************************************************
 * Get specular factors for one, two or three lights.
 * 
 * The phongShadingFactor in there is odd, but allowable. If you want, take that
 * factor out in the return line and see whether you like the result more;
 * highlights in darker areas should become more noticeable.
 * 
 * Now uses reflect() to get the reflection direction. The original code was
 * correct, but almost impossible to understand if you don't know Householder
 * transformations. There's also a slight chance that HLSL may have a special
 * case for this very common mathematical operation.
 *
 * Since reflect returns a vector with the opposite direction as the old code,
 * I've changed cameraDir to match, so the rest of the code won't notice.
 */
float CalcBumpSpecularFactors_1(float3 bumpNormal, BumpVertexShaderOutput input, float phongShadingFactor)
{
	//float3 bumpNormal2 = bumpNormal * 2;
	//float3 reflLight1Dir = dot(bumpNormal, Light1Dir) * bumpNormal2 - Light1Dir;
	float3 reflLight1Dir = reflect(Light1Dir, bumpNormal);
	//float3 cameraDir = normalize(input.PositionWorld - CameraPos);
	float3 cameraDir = normalize(CameraPos - input.PositionWorld);
	float specularFactor1 = saturate(dot(cameraDir, reflLight1Dir));
	return phongShadingFactor * pow(specularFactor1, BumpSpecularGloss) * BumpSpecularAmount;
}

/*******************************************************************************
 * See above
 */
float2 CalcBumpSpecularFactors_2(float3 bumpNormal, BumpVertexShaderOutput input, float2 phongShadingFactors)
{
	//float3 bumpNormal2 = bumpNormal * 2;
	//float3 reflLight1Dir = dot(bumpNormal, Light1Dir) * bumpNormal2 - Light1Dir;
	//float3 reflLight2Dir = dot(bumpNormal, Light2Dir) * bumpNormal2 - Light2Dir;
	float3 reflLight1Dir = reflect(Light1Dir, bumpNormal);
	float3 reflLight2Dir = reflect(Light2Dir, bumpNormal);
	//float3 cameraDir = normalize(input.PositionWorld - CameraPos);
	float3 cameraDir = normalize(CameraPos - input.PositionWorld);
	float specularFactor1 = saturate(dot(cameraDir, reflLight1Dir));
	float specularFactor2 = saturate(dot(cameraDir, reflLight2Dir));
	return phongShadingFactors * pow(float2(specularFactor1, specularFactor2), BumpSpecularGloss) * BumpSpecularAmount;
}

/*******************************************************************************
 * See above
 */
float3 CalcBumpSpecularFactors_3(float3 bumpNormal, BumpVertexShaderOutput input, float3 phongShadingFactors)
{
	//float3 bumpNormal2 = bumpNormal * 2;
	//float3 reflLight1Dir = dot(bumpNormal, Light1Dir) * bumpNormal2 - Light1Dir;
	//float3 reflLight2Dir = dot(bumpNormal, Light2Dir) * bumpNormal2 - Light2Dir;
	//float3 reflLight3Dir = dot(bumpNormal, Light3Dir) * bumpNormal2 - Light3Dir;
	float3 reflLight1Dir = reflect(Light1Dir, bumpNormal);
	float3 reflLight2Dir = reflect(Light2Dir, bumpNormal);
	float3 reflLight3Dir = reflect(Light3Dir, bumpNormal);
	//float3 cameraDir = normalize(input.PositionWorld - CameraPos);
	float3 cameraDir = normalize(CameraPos - input.PositionWorld);
	float specularFactor1 = saturate(dot(cameraDir, reflLight1Dir));
	float specularFactor2 = saturate(dot(cameraDir, reflLight2Dir));
	float specularFactor3 = saturate(dot(cameraDir, reflLight3Dir));
	return phongShadingFactors * pow(float3(specularFactor1, specularFactor2, specularFactor3), BumpSpecularGloss) * BumpSpecularAmount;
}

/*******************************************************************************
 * Calculates color after specular highlights (and originally, bumpmap darkening
 * is applied.
 *
 * This function originally did too many things, and it did them oddly. It was
 * here that bump maps were applied, by lightening or darkening the diffuse
 * color based on the color values of the bump map (without ever looking at the
 * light sources, of course). That's just wrong.
 *
 * It's other job was to apply the specular color. That is okay and can stay.
 *
 * Not its job was applying the light color attenuated by the diffuse factor
 * ("phong color"). That was done by the shaders instead, directly afterwards.
 * I've added it, to be consisted with ApplyBumpBlendSpecular, which does that.
 * right away. Note that there, the specular factor is not multiplied by the
 * light color, while here it is. That's how it used to be.
 *
 * By the way, note that this applies the diffuse factor twice: Once here, once
 * when calculating the bumpSpecularFactor. Again, that's how XNALara used to do
 * it, so I've kept it.
 *
 * This uses a seperate specular color, which gives very bright highlights. You
 * could also try returning saturate(diffuseColor*(1+specular)), which subdues
 * and colors them, perhaps too much.
 *
 * If you want to add a separate specular light color, it would have to be
 * applied in this function.
 */
//float4 ApplyBumpBlend(float4 diffuseColor, float4 bumpColor, float bumpSpecularFactor)
float4 ApplyBumpBlend(float4 diffuseColor, float bumpSpecularFactor, float4 phongColor)
{
	float4 specular = float4(bumpSpecularFactor, bumpSpecularFactor, bumpSpecularFactor, 0);
	//float4 shadowed = BumpShadowFunc(BumpShadowFunc(diffuseColor, 1 - bumpColor.r), 1 - bumpColor.g);
	//return saturate(lerp(diffuseColor, shadowed, BumpShadowAmount) + specular);
	return saturate(diffuseColor + specular) * phongColor;
}
/*
float4 ApplyBumpBlend(float4 diffuseColor, float4 bumpColor, float bumpSpecularFactor)
{
	float4 specular = float4(bumpSpecularFactor, bumpSpecularFactor, bumpSpecularFactor, 0);
	float4 shadowed = BumpShadowFunc(BumpShadowFunc(diffuseColor, 1 - bumpColor.r), 1 - bumpColor.g);
	return saturate(lerp(diffuseColor, shadowed, BumpShadowAmount) + specular);
}*/

/*******************************************************************************
 * This function shouldn't be used, only by shaders that I forgot to adapt.
 */
float4 BumpShadowFunc(float4 base, float overlay)
{
	float4 output;
	output.rgb = base.rgb * (base.rgb + 2 * overlay * (1 - base.rgb));
	output.a = base.a;
	return output;
}

/*******************************************************************************
 * This version shouldn't be used, only by shaders that I forgot to adapt.
 */
float4 ApplyBumpBlend(float4 diffuseColor, float4 bumpColor, float bumpSpecularFactor)
{
	float4 specular = float4(bumpSpecularFactor, bumpSpecularFactor, bumpSpecularFactor, 0);
	float4 shadowed = BumpShadowFunc(BumpShadowFunc(diffuseColor, 1 - bumpColor.r), 1 - bumpColor.g);
	return saturate(diffuseColor * (1 - BumpShadowAmount) + shadowed * BumpShadowAmount + specular);
}

/*******************************************************************************
 * Same as above, but with an additional specular color, and taking into
 * account the light color.
 *
 * In the original version, this also applied the "phong color", i.e. the light
 * color applied by the diffuse function.
 */
 /*
float4 ApplyBumpBlendSpecular(float4 diffuseColor, float4 bumpColor, float3 bumpSpecularColor, float4 phongColor)
{
	//float4 shadowed = BumpShadowFunc(BumpShadowFunc(diffuseColor, 1 - bumpColor.r), 1 - bumpColor.g);
	//return saturate(lerp(diffuseColor, shadowed, BumpShadowAmount)) * phongColor + float4(bumpSpecularColor, 0);
	return diffuseColor * phongColor + float4(bumpSpecularColor, 0);
}
*/
float4 ApplyBumpBlendSpecular(float4 diffuseColor, float3 bumpSpecularColor, float4 phongColor)
{
	//float4 shadowed = BumpShadowFunc(BumpShadowFunc(diffuseColor, 1 - bumpColor.r), 1 - bumpColor.g);
	//return saturate(lerp(diffuseColor, shadowed, BumpShadowAmount)) * phongColor + float4(bumpSpecularColor, 0);
	return diffuseColor * phongColor + float4(bumpSpecularColor, 0);
}


float4x4 CalcBoneTransform(VertexShaderInput input)
{
	float4x4 boneTransform = 0;
	boneTransform += BoneMatrices[input.BoneIndices[0]] * input.BoneWeights[0];
	boneTransform += BoneMatrices[input.BoneIndices[1]] * input.BoneWeights[1];
	boneTransform += BoneMatrices[input.BoneIndices[2]] * input.BoneWeights[2];
	boneTransform += BoneMatrices[input.BoneIndices[3]] * input.BoneWeights[3];
	return boneTransform;
}


float2 CalculateEnvironmentTexCoord(float3 reflectionDir)
{
	float u;
	if (UseAlternativeReflection) {
		u = (normalize(reflectionDir.xz).x + 1) * 0.5;
	}
	else {
		u = (normalize(reflectionDir.xz).x + 1) * 0.25;
		if (reflectionDir.z < 0) {
			u = 1 - u;
		}
	}
	float v = (reflectionDir.y + 1) * 0.5;
	return float2(u, v);
}


BasicVertexShaderOutput BasicVS(VertexShaderInput input)
{
    BasicVertexShaderOutput output;
    float4x4 WorldViewProjection = mul(mul(World, View), Projection);
    float3x3 World3x3 = (float3x3)World;
    float4x4 boneTransform = CalcBoneTransform(input);
    output.Position = mul(mul(input.Position, boneTransform), WorldViewProjection);
    output.Color = input.Color;
    output.TexCoord = input.TexCoord;
    float3 normal3 = (float3)input.Normal;
    normal3 = mul(normal3, (float3x3)boneTransform);
    output.NormalWorld = normalize(mul(normal3, World3x3));
    return output;
}

/*******************************************************************************
 * Vertex shader for bump mapping.
 *
 * Not much to say here, because I didn't change it, but if you want different
 * orientations for the normals, here is the place. Swap tangentU, tangentV and
 * normal in the float3x3 expression below until you're happy.
 */
BumpVertexShaderOutput BumpVS(VertexShaderInput input)
{
    float4x4 ViewProjection = mul(View, Projection);
    
    BumpVertexShaderOutput output;
    
    float4x4 boneTransform = CalcBoneTransform(input);
    float4x4 fullTransform = mul(boneTransform, World);
    
    float4 positionWorld = mul(input.Position, fullTransform);
    
    output.Position = mul(positionWorld, ViewProjection);
    output.Color = input.Color;
    output.TexCoord = input.TexCoord;

    output.PositionWorld = positionWorld;
    output.NormalWorld = normalize(mul(input.Normal, (float3x3) fullTransform));
    
    float3 tangentU = normalize(input.Tangent);
    float3 tangentV = normalize(cross(input.Normal, tangentU) * input.Tangent.w);
    float3 normal = normalize(input.Normal);
    
    output.TangentToWorld = mul(float3x3(tangentU, tangentV, normal), fullTransform);
    return output;
}

/*******************************************************************************
 * Pixel shaders that don't bumpmap.
 * 
 * I did not touch them, but I don't particularly like them, either.
 */
float4 DiffusePS_1(BasicVertexShaderOutput input) : COLOR0
{
	float4 diffuseColor = GetDiffuseColor(input.TexCoord);
	diffuseColor *= input.Color;
	float phongShadingFactor1 = CalcPhongShadingFactors_1(input.NormalWorld);
	float4 phongShadingColor1 = CalcPhongShadingColor1(input.NormalWorld, phongShadingFactor1);
	float4 color1 = diffuseColor * phongShadingColor1;
	return color1;
}


float4 DiffusePS_2(BasicVertexShaderOutput input) : COLOR0
{
	float4 diffuseColor = GetDiffuseColor(input.TexCoord);
	diffuseColor *= input.Color;
	float2 phongShadingFactors = CalcPhongShadingFactors_2(input.NormalWorld);
	float4 phongShadingColor1 = CalcPhongShadingColor1(input.NormalWorld, phongShadingFactors[0]);
	float4 phongShadingColor2 = CalcPhongShadingColor2(input.NormalWorld, phongShadingFactors[1]);
	float4 color1 = diffuseColor * phongShadingColor1;
	float4 color2 = diffuseColor * phongShadingColor2;
	return BlendColorLayers_2(color1, color2);
}


float4 DiffusePS_3(BasicVertexShaderOutput input) : COLOR0
{
	float4 diffuseColor = GetDiffuseColor(input.TexCoord);
	diffuseColor *= input.Color;
	float3 phongShadingFactors = CalcPhongShadingFactors_3(input.NormalWorld);
	float4 phongShadingColor1 = CalcPhongShadingColor1(input.NormalWorld, phongShadingFactors[0]);
	float4 phongShadingColor2 = CalcPhongShadingColor2(input.NormalWorld, phongShadingFactors[1]);
	float4 phongShadingColor3 = CalcPhongShadingColor3(input.NormalWorld, phongShadingFactors[2]);
	float4 color1 = diffuseColor * phongShadingColor1;
	float4 color2 = diffuseColor * phongShadingColor2;
	float4 color3 = diffuseColor * phongShadingColor3;
	return BlendColorLayers_3(color1, color2, color3);
}


float4 DiffuseLightmapPS_1(BasicVertexShaderOutput input) : COLOR0
{
	float4 diffuseColor = GetDiffuseColor(input.TexCoord);
	diffuseColor *= input.Color;
	float phongShadingFactor = CalcPhongShadingFactors_1(input.NormalWorld);
	float4 phongShadingColor1 = CalcPhongShadingColor1(input.NormalWorld, phongShadingFactor);
	float4 lightmapColor = tex2D(LightmapTextureSampler, input.TexCoord);
	float4 color1 = diffuseColor * phongShadingColor1 * lightmapColor;
	return color1;
}


float4 DiffuseLightmapPS_2(BasicVertexShaderOutput input) : COLOR0
{
	float4 diffuseColor = GetDiffuseColor(input.TexCoord);
	diffuseColor *= input.Color;
	float2 phongShadingFactors = CalcPhongShadingFactors_2(input.NormalWorld);
	float4 phongShadingColor1 = CalcPhongShadingColor1(input.NormalWorld, phongShadingFactors[0]);
	float4 phongShadingColor2 = CalcPhongShadingColor2(input.NormalWorld, phongShadingFactors[1]);
	float4 lightmapColor = tex2D(LightmapTextureSampler, input.TexCoord);
	float4 color1 = diffuseColor * phongShadingColor1 * lightmapColor;
	float4 color2 = diffuseColor * phongShadingColor2 * lightmapColor;
	return BlendColorLayers_2(color1, color2);
}


float4 DiffuseLightmapPS_3(BasicVertexShaderOutput input) : COLOR0
{
	float4 diffuseColor = GetDiffuseColor(input.TexCoord);
	diffuseColor *= input.Color;
	float3 phongShadingFactors = CalcPhongShadingFactors_3(input.NormalWorld);
	float4 phongShadingColor1 = CalcPhongShadingColor1(input.NormalWorld, phongShadingFactors[0]);
	float4 phongShadingColor2 = CalcPhongShadingColor2(input.NormalWorld, phongShadingFactors[1]);
	float4 phongShadingColor3 = CalcPhongShadingColor3(input.NormalWorld, phongShadingFactors[2]);
	float4 lightmapColor = tex2D(LightmapTextureSampler, input.TexCoord);
	float4 color1 = diffuseColor * phongShadingColor1 * lightmapColor;
	float4 color2 = diffuseColor * phongShadingColor2 * lightmapColor;
	float4 color3 = diffuseColor * phongShadingColor3 * lightmapColor;
	return BlendColorLayers_3(color1, color2, color3);
}

/*******************************************************************************
 * Shaders that do bumpmap.
 *
 * The general approach for all of them is the same:
 * - Calculate the normals at the start, and use them instead of NormalWorld for
 *   CalcPhongShading… and so on.
 * - ApplyBumpBlend takes the phong shading color as a parameter.
 * - Both ApplyBumpBlend and ApplyBumpBlendSpecular no longer take the bump
 *   color as a parameter.
 *
 * I did not keep the original code for all of them.
 */
float4 DiffuseBumpPS_1(BumpVertexShaderOutput input) : COLOR0
{
	float4 diffuseColor = GetDiffuseColor(input.TexCoord);
	diffuseColor *= input.Color;
//	float phongShadingFactor = CalcPhongShadingFactors_1(input.NormalWorld);
//	float4 phongShadingColor1 = CalcPhongShadingColor1(input.NormalWorld, phongShadingFactor);
//	float4 bumpColor;
//	if (EnableBumpMaps) {
//		bumpColor = tex2D(BumpTextureSampler, input.TexCoord);
//	}
//	else {
//		bumpColor = float4(0.5, 0.5, 1, 1);
//	}
//	float3 bumpNormal = CalcBumpNormal(bumpColor, input);
//	float bumpSpecularFactor = CalcBumpSpecularFactors_1(bumpNormal, input, phongShadingFactor);
//	float4 color1 = ApplyBumpBlend(diffuseColor, bumpColor, bumpSpecularFactor) * phongShadingColor1;
//	return color1;

	float4 bumpColor;
	if (EnableBumpMaps) {
		bumpColor = tex2D(BumpTextureSampler, input.TexCoord);
	}
	else {
		bumpColor = float4(0.5, 0.5, 1, 1);
	}
	float3 bumpNormal = CalcBumpNormal(bumpColor, input);
	float phongShadingFactor = CalcPhongShadingFactors_1(bumpNormal);
	float4 phongShadingColor1 = CalcPhongShadingColor1(bumpNormal, phongShadingFactor);
	float bumpSpecularFactor = CalcBumpSpecularFactors_1(bumpNormal, input, phongShadingFactor);
	float4 color1 = ApplyBumpBlend(diffuseColor, bumpSpecularFactor, phongShadingColor1);
	return color1;
}


float4 DiffuseBumpPS_2(BumpVertexShaderOutput input) : COLOR0
{
//	float4 diffuseColor = GetDiffuseColor(input.TexCoord);
//	diffuseColor *= input.Color;
//	float2 phongShadingFactors = CalcPhongShadingFactors_2(input.NormalWorld);
//	float4 phongShadingColor1 = CalcPhongShadingColor1(input.NormalWorld, phongShadingFactors[0]);
//	float4 phongShadingColor2 = CalcPhongShadingColor2(input.NormalWorld, phongShadingFactors[1]);
//	float4 bumpColor;
//	if (EnableBumpMaps) {
//		bumpColor = tex2D(BumpTextureSampler, input.TexCoord);
//	}
//	else {
//		bumpColor = float4(0.5, 0.5, 1, 1);
//	}
//	float3 bumpNormal = CalcBumpNormal(bumpColor, input);
//	float2 bumpSpecularFactors = CalcBumpSpecularFactors_2(bumpNormal, input, phongShadingFactors);
//	float4 color1 = ApplyBumpBlend(diffuseColor, bumpColor, bumpSpecularFactors[0]) * phongShadingColor1;
//	float4 color2 = ApplyBumpBlend(diffuseColor, bumpColor, bumpSpecularFactors[1]) * phongShadingColor2;
//	return BlendColorLayers_2(color1, color2);

	float4 diffuseColor = GetDiffuseColor(input.TexCoord);
	diffuseColor *= input.Color;
	float4 bumpColor;
	if (EnableBumpMaps) {
		bumpColor = tex2D(BumpTextureSampler, input.TexCoord);
	}
	else {
		bumpColor = float4(0.5, 0.5, 1, 1);
	}
	float3 bumpNormal = CalcBumpNormal(bumpColor, input);
	float2 phongShadingFactors = CalcPhongShadingFactors_2(bumpNormal);
	float4 phongShadingColor1 = CalcPhongShadingColor1(bumpNormal, phongShadingFactors[0]);
	float4 phongShadingColor2 = CalcPhongShadingColor2(bumpNormal, phongShadingFactors[1]);
	float2 bumpSpecularFactors = CalcBumpSpecularFactors_2(bumpNormal, input, phongShadingFactors);
	float4 color1 = ApplyBumpBlend(diffuseColor, bumpSpecularFactors[0], phongShadingColor1);
	float4 color2 = ApplyBumpBlend(diffuseColor, bumpSpecularFactors[1], phongShadingColor2);
	return BlendColorLayers_2(color1, color2);

}


float4 DiffuseBumpPS_3(BumpVertexShaderOutput input) : COLOR0
{
//	float4 diffuseColor = GetDiffuseColor(input.TexCoord);
//	diffuseColor *= input.Color;
//	float3 phongShadingFactors = CalcPhongShadingFactors_3(input.NormalWorld);
//	float4 phongShadingColor1 = CalcPhongShadingColor1(input.NormalWorld, phongShadingFactors[0]);
//	float4 phongShadingColor2 = CalcPhongShadingColor2(input.NormalWorld, phongShadingFactors[1]);
//	float4 phongShadingColor3 = CalcPhongShadingColor3(input.NormalWorld, phongShadingFactors[2]);
//	float4 bumpColor;
//	if (EnableBumpMaps) {
//		bumpColor = tex2D(BumpTextureSampler, input.TexCoord);
//	}
//	else {
//		bumpColor = float4(0.5, 0.5, 1, 1);
//	}
//	float3 bumpNormal = CalcBumpNormal(bumpColor, input);
//	float3 bumpSpecularFactors = CalcBumpSpecularFactors_3(bumpNormal, input, phongShadingFactors);
//	float4 color1 = ApplyBumpBlend(diffuseColor, bumpColor, bumpSpecularFactors[0]) * phongShadingColor1;
//	float4 color2 = ApplyBumpBlend(diffuseColor, bumpColor, bumpSpecularFactors[1]) * phongShadingColor2;
//	float4 color3 = ApplyBumpBlend(diffuseColor, bumpColor, bumpSpecularFactors[2]) * phongShadingColor3;
//	return BlendColorLayers_3(color1, color2, color3);
	
	float4 bumpColor;
	if (EnableBumpMaps) {
		bumpColor = tex2D(BumpTextureSampler, input.TexCoord);
	}
	else {
		bumpColor = float4(0.5, 0.5, 1, 1);
	}
	float3 bumpNormal = CalcBumpNormal(bumpColor, input);
	float4 diffuseColor = GetDiffuseColor(input.TexCoord);
	diffuseColor *= input.Color;
	float3 phongShadingFactors = CalcPhongShadingFactors_3(bumpNormal);
	float4 phongShadingColor1 = CalcPhongShadingColor1(bumpNormal, phongShadingFactors[0]);
	float4 phongShadingColor2 = CalcPhongShadingColor2(bumpNormal, phongShadingFactors[1]);
	float4 phongShadingColor3 = CalcPhongShadingColor3(bumpNormal, phongShadingFactors[2]);
	float3 bumpSpecularFactors = CalcBumpSpecularFactors_3(bumpNormal, input, phongShadingFactors);
	float4 color1 = ApplyBumpBlend(diffuseColor, bumpSpecularFactors[0], phongShadingColor1);
	float4 color2 = ApplyBumpBlend(diffuseColor, bumpSpecularFactors[1], phongShadingColor2);
	float4 color3 = ApplyBumpBlend(diffuseColor, bumpSpecularFactors[2], phongShadingColor3);
	return BlendColorLayers_3(color1, color2, color3);
}


float4 DiffuseLightmapBumpPS_1(BumpVertexShaderOutput input) : COLOR0
{
//	float4 diffuseColor = GetDiffuseColor(input.TexCoord);
//	diffuseColor *= input.Color;
//	float phongShadingFactor = CalcPhongShadingFactors_1(input.NormalWorld);
//	float4 phongShadingColor1 = CalcPhongShadingColor1(input.NormalWorld, phongShadingFactor);
//	float4 bumpColor;
//	if (EnableBumpMaps) {
//		bumpColor = tex2D(BumpTextureSampler, input.TexCoord);
//	}
//	else {
//		bumpColor = float4(0.5, 0.5, 1, 1);
//	}
//	float3 bumpNormal = CalcBumpNormal(bumpColor, input);
//	float bumpSpecularFactor = CalcBumpSpecularFactors_1(bumpNormal, input, phongShadingFactor);
//	float4 lightmapColor = tex2D(LightmapTextureSampler, input.TexCoord);
//	float4 color1 = ApplyBumpBlend(diffuseColor, bumpColor, bumpSpecularFactor) * phongShadingColor1 * lightmapColor;
//	return color1;
	
	float4 bumpColor;
	if (EnableBumpMaps) {
		bumpColor = tex2D(BumpTextureSampler, input.TexCoord);
	}
	else {
		bumpColor = float4(0.5, 0.5, 1, 1);
	}
	float3 bumpNormal = CalcBumpNormal(bumpColor, input);
	float4 diffuseColor = GetDiffuseColor(input.TexCoord);
	diffuseColor *= input.Color;
	float phongShadingFactor = CalcPhongShadingFactors_1(bumpNormal);
	float4 phongShadingColor1 = CalcPhongShadingColor1(bumpNormal, phongShadingFactor);
	float bumpSpecularFactor = CalcBumpSpecularFactors_1(bumpNormal, input, phongShadingFactor);
	float4 lightmapColor = tex2D(LightmapTextureSampler, input.TexCoord);
	float4 color1 = ApplyBumpBlend(diffuseColor, bumpSpecularFactor, phongShadingColor1) * lightmapColor;
	return color1;
}


float4 DiffuseLightmapBumpPS_2(BumpVertexShaderOutput input) : COLOR0
{
	float4 diffuseColor = GetDiffuseColor(input.TexCoord);
	diffuseColor *= input.Color;
	float4 bumpColor;
	if (EnableBumpMaps) {
		bumpColor = tex2D(BumpTextureSampler, input.TexCoord);
	}
	else {
		bumpColor = float4(0.5, 0.5, 1, 1);
	}
	float3 bumpNormal = CalcBumpNormal(bumpColor, input);
	float2 phongShadingFactors = CalcPhongShadingFactors_2(bumpNormal);
	float4 phongShadingColor1 = CalcPhongShadingColor1(bumpNormal, phongShadingFactors[0]);
	float4 phongShadingColor2 = CalcPhongShadingColor2(bumpNormal, phongShadingFactors[1]);
	float2 bumpSpecularFactors = CalcBumpSpecularFactors_2(bumpNormal, input, phongShadingFactors);
	float4 lightmapColor = tex2D(LightmapTextureSampler, input.TexCoord);
	float4 color1 = ApplyBumpBlend(diffuseColor, bumpSpecularFactors[0], phongShadingColor1) * lightmapColor;
	float4 color2 = ApplyBumpBlend(diffuseColor, bumpSpecularFactors[1], phongShadingColor2) * lightmapColor;
	return BlendColorLayers_2(color1, color2);
}


float4 DiffuseLightmapBumpPS_3(BumpVertexShaderOutput input) : COLOR0
{
	float4 bumpColor;
	if (EnableBumpMaps) {
		bumpColor = tex2D(BumpTextureSampler, input.TexCoord);
	}
	else {
		bumpColor = float4(0.5, 0.5, 1, 1);
	}
	float3 bumpNormal = CalcBumpNormal(bumpColor, input);
	float4 diffuseColor = GetDiffuseColor(input.TexCoord);
	diffuseColor *= input.Color;
	float3 phongShadingFactors = CalcPhongShadingFactors_3(bumpNormal);
	float4 phongShadingColor1 = CalcPhongShadingColor1(bumpNormal, phongShadingFactors[0]);
	float4 phongShadingColor2 = CalcPhongShadingColor2(bumpNormal, phongShadingFactors[1]);
	float4 phongShadingColor3 = CalcPhongShadingColor3(bumpNormal, phongShadingFactors[2]);
	float3 bumpSpecularFactors = CalcBumpSpecularFactors_3(bumpNormal, input, phongShadingFactors);
	float4 lightmapColor = tex2D(LightmapTextureSampler, input.TexCoord);
	float4 color1 = ApplyBumpBlend(diffuseColor, bumpSpecularFactors[0], phongShadingColor1) * lightmapColor;
	float4 color2 = ApplyBumpBlend(diffuseColor, bumpSpecularFactors[1], phongShadingColor2) * lightmapColor;
	float4 color3 = ApplyBumpBlend(diffuseColor, bumpSpecularFactors[2], phongShadingColor3) * lightmapColor;
	return BlendColorLayers_3(color1, color2, color3);
}


float4 DiffuseLightmapBump3PS_1(BumpVertexShaderOutput input) : COLOR0
{
	float4 diffuseColor = GetDiffuseColor(input.TexCoord);
	diffuseColor *= input.Color;
	float4 bumpColor = CombinedBumpColor(input);
	float3 bumpNormal = CalcBumpNormal(bumpColor, input);
	
	float phongShadingFactor = CalcPhongShadingFactors_1(bumpNormal);
	float4 phongShadingColor1 = CalcPhongShadingColor1(bumpNormal, phongShadingFactor);
	float bumpSpecularFactor = CalcBumpSpecularFactors_1(bumpNormal, input, phongShadingFactor);
	float4 lightmapColor = tex2D(LightmapTextureSampler, input.TexCoord);
	float4 color1 = ApplyBumpBlend(diffuseColor, bumpSpecularFactor, phongShadingColor1) * lightmapColor;
	return color1;
}


float4 DiffuseLightmapBump3PS_2_HQ(BumpVertexShaderOutput input) : COLOR0
{
	float4 diffuseColor = GetDiffuseColor(input.TexCoord);
	diffuseColor *= input.Color;
	float4 bumpColor = CombinedBumpColor(input);
	float3 bumpNormal = CalcBumpNormal(bumpColor, input);
	
	float2 phongShadingFactors = CalcPhongShadingFactors_2(bumpNormal);
	float4 phongShadingColor1 = CalcPhongShadingColor1(bumpNormal, phongShadingFactors[0]);
	float4 phongShadingColor2 = CalcPhongShadingColor2(bumpNormal, phongShadingFactors[1]);
	float2 bumpSpecularFactors = CalcBumpSpecularFactors_2(bumpNormal, input, phongShadingFactors);
	float4 lightmapColor = tex2D(LightmapTextureSampler, input.TexCoord);
	float4 color1 = ApplyBumpBlend(diffuseColor, bumpSpecularFactors[0], phongShadingColor1) * lightmapColor;
	float4 color2 = ApplyBumpBlend(diffuseColor, bumpSpecularFactors[1], phongShadingColor2) * lightmapColor;
	return BlendColorLayers_2(color1, color2);
}


float4 DiffuseLightmapBump3PS_2_LQ(BumpVertexShaderOutput input) : COLOR0
{
	float4 diffuseColor = GetDiffuseColor(input.TexCoord);
	diffuseColor *= input.Color;
	float4 bumpColor = CombinedBumpColor(input);
	float3 bumpNormal = CalcBumpNormal(bumpColor, input);

	float2 phongShadingFactors = CalcPhongShadingFactors_2(bumpNormal);
	float4 phongShadingColor1 = CalcPhongShadingColor1(bumpNormal, phongShadingFactors[0]);
	float4 phongShadingColor2 = CalcPhongShadingColor2(bumpNormal, phongShadingFactors[1]);
	float2 bumpSpecularFactors = CalcBumpSpecularFactors_2(bumpNormal, input, phongShadingFactors);
	float4 lightmapColor = tex2D(LightmapTextureSampler, input.TexCoord);
	float4 color1 = ApplyBumpBlend(diffuseColor, bumpSpecularFactors[0], phongShadingColor1) * lightmapColor;
	float4 color2 = ApplyBumpBlend(diffuseColor, bumpSpecularFactors[1], phongShadingColor2) * lightmapColor;
	return BlendColorLayers_2(color1, color2);
}


float4 DiffuseLightmapBump3PS_3(BumpVertexShaderOutput input) : COLOR0
{
	float4 diffuseColor = GetDiffuseColor(input.TexCoord);
	diffuseColor *= input.Color;
	float4 bumpColor = CombinedBumpColor(input);
	float3 bumpNormal = CalcBumpNormal(bumpColor, input);

	float3 phongShadingFactors = CalcPhongShadingFactors_3(bumpNormal);
	float4 phongShadingColor1 = CalcPhongShadingColor1(bumpNormal, phongShadingFactors[0]);
	float4 phongShadingColor2 = CalcPhongShadingColor2(bumpNormal, phongShadingFactors[1]);
	float4 phongShadingColor3 = CalcPhongShadingColor3(bumpNormal, phongShadingFactors[2]);
	float3 bumpSpecularFactors = CalcBumpSpecularFactors_3(bumpNormal, input, phongShadingFactors);
	float4 lightmapColor = tex2D(LightmapTextureSampler, input.TexCoord);
	float4 color1 = ApplyBumpBlend(diffuseColor, bumpSpecularFactors[0], phongShadingColor1) * lightmapColor;
	float4 color2 = ApplyBumpBlend(diffuseColor, bumpSpecularFactors[1], phongShadingColor2) * lightmapColor;
	float4 color3 = ApplyBumpBlend(diffuseColor, bumpSpecularFactors[2], phongShadingColor3) * lightmapColor;
	return BlendColorLayers_3(color1, color2, color3);
}


float4 DiffuseLightmapBumpSpecularPS_1(BumpVertexShaderOutput input) : COLOR0
{
	float4 diffuseColor = GetDiffuseColor(input.TexCoord);
	diffuseColor *= input.Color;

	// Fix issue reported by o0Crofty0o - this shader should not use CombinedBumpColor.
	float4 bumpColor;
	if (EnableBumpMaps) {
		bumpColor = tex2D(BumpTextureSampler, input.TexCoord);
	}
	else {
		bumpColor = float4(0.5, 0.5, 1, 1);
	}
	float3 bumpNormal = CalcBumpNormal(bumpColor, input);

	float phongShadingFactor = CalcPhongShadingFactors_1(bumpNormal);
	float4 phongShadingColor1 = CalcPhongShadingColor1(bumpNormal, phongShadingFactor);
	float bumpSpecularFactor = CalcBumpSpecularFactors_1(bumpNormal, input, phongShadingFactor);
	float4 lightmapColor = tex2D(LightmapTextureSampler, input.TexCoord);
	float4 specularColor = tex2D(SpecularTextureSampler, input.TexCoord);
	float3 bumpSpecularColor1 = bumpSpecularFactor * specularColor.rgb * Light1Intensity;
	float4 color1 = ApplyBumpBlendSpecular(diffuseColor, float4(bumpSpecularColor1,0), phongShadingColor1) * lightmapColor;
	return color1;
}


float4 DiffuseLightmapBumpSpecularPS_2(BumpVertexShaderOutput input) : COLOR0
{
	float4 diffuseColor = GetDiffuseColor(input.TexCoord);
	diffuseColor *= input.Color;

	// Fix issue reported by o0Crofty0o - this shader should not use CombinedBumpColor.
	float4 bumpColor;
	if (EnableBumpMaps) {
		bumpColor = tex2D(BumpTextureSampler, input.TexCoord);
	}
	else {
		bumpColor = float4(0.5, 0.5, 1, 1);
	}
	float3 bumpNormal = CalcBumpNormal(bumpColor, input);

	float2 phongShadingFactors = CalcPhongShadingFactors_2(bumpNormal);
	float4 phongShadingColor1 = CalcPhongShadingColor1(bumpNormal, phongShadingFactors[0]);
	float4 phongShadingColor2 = CalcPhongShadingColor2(bumpNormal, phongShadingFactors[1]);
	float2 bumpSpecularFactors = CalcBumpSpecularFactors_2(bumpNormal, input, phongShadingFactors);
	float4 lightmapColor = tex2D(LightmapTextureSampler, input.TexCoord);
	float4 specularColor = tex2D(SpecularTextureSampler, input.TexCoord);
	float3 bumpSpecularColor1 = bumpSpecularFactors[0] * specularColor.rgb * Light1Intensity;
	float3 bumpSpecularColor2 = bumpSpecularFactors[1] * specularColor.rgb * Light2Intensity;
	float4 color1 = ApplyBumpBlendSpecular(diffuseColor, bumpSpecularColor1, phongShadingColor1) * lightmapColor;
	float4 color2 = ApplyBumpBlendSpecular(diffuseColor, bumpSpecularColor2, phongShadingColor2) * lightmapColor;
	return BlendColorLayers_2(color1, color2);
}


float4 DiffuseLightmapBumpSpecularPS_3(BumpVertexShaderOutput input) : COLOR0
{
	float4 diffuseColor = GetDiffuseColor(input.TexCoord);
	diffuseColor *= input.Color;

	// Fix issue reported by o0Crofty0o - this shader should not use CombinedBumpColor.
	float4 bumpColor;
	if (EnableBumpMaps) {
		bumpColor = tex2D(BumpTextureSampler, input.TexCoord);
	}
	else {
		bumpColor = float4(0.5, 0.5, 1, 1);
	}
	float3 bumpNormal = CalcBumpNormal(bumpColor, input);
	
	float3 phongShadingFactors = CalcPhongShadingFactors_3(bumpNormal);
	float4 phongShadingColor1 = CalcPhongShadingColor1(bumpNormal, phongShadingFactors[0]);
	float4 phongShadingColor2 = CalcPhongShadingColor2(bumpNormal, phongShadingFactors[1]);
	float4 phongShadingColor3 = CalcPhongShadingColor3(bumpNormal, phongShadingFactors[2]);
	float3 bumpSpecularFactors = CalcBumpSpecularFactors_3(bumpNormal, input, phongShadingFactors);
	float4 lightmapColor = tex2D(LightmapTextureSampler, input.TexCoord);
	float4 specularColor = tex2D(SpecularTextureSampler, input.TexCoord);
	float3 bumpSpecularColor1 = bumpSpecularFactors[0] * specularColor.rgb * Light1Intensity;
	float3 bumpSpecularColor2 = bumpSpecularFactors[1] * specularColor.rgb * Light2Intensity;
	float3 bumpSpecularColor3 = bumpSpecularFactors[2] * specularColor.rgb * Light3Intensity;
	float4 color1 = ApplyBumpBlendSpecular(diffuseColor, bumpSpecularColor1, phongShadingColor1) * lightmapColor;
	float4 color2 = ApplyBumpBlendSpecular(diffuseColor, bumpSpecularColor2, phongShadingColor2) * lightmapColor;
	float4 color3 = ApplyBumpBlendSpecular(diffuseColor, bumpSpecularColor3, phongShadingColor3) * lightmapColor;
	return BlendColorLayers_3(color1, color2, color3);
}


float4 DiffuseLightmapBump3SpecularPS_1(BumpVertexShaderOutput input) : COLOR0
{
	float4 diffuseColor = GetDiffuseColor(input.TexCoord);
	diffuseColor *= input.Color;
	float4 bumpColor = CombinedBumpColor(input);
	float3 bumpNormal = CalcBumpNormal(bumpColor, input);
	
	float phongShadingFactor = CalcPhongShadingFactors_1(bumpNormal);
	float4 phongShadingColor1 = CalcPhongShadingColor1(bumpNormal, phongShadingFactor);
	// float4 bumpColor = CombinedBumpColor(input);
	// float3 bumpNormal = CalcBumpNormal(bumpColor, input);
	float bumpSpecularFactor = CalcBumpSpecularFactors_1(bumpNormal, input, phongShadingFactor);
	float4 lightmapColor = tex2D(LightmapTextureSampler, input.TexCoord);
	float4 specularColor = tex2D(SpecularTextureSampler, input.TexCoord);
	float3 bumpSpecularColor1 = bumpSpecularFactor * specularColor.rgb * Light1Intensity;
	float4 color1 = ApplyBumpBlendSpecular(diffuseColor, bumpSpecularColor1, phongShadingColor1) * lightmapColor;
	return color1;
}


float4 DiffuseLightmapBump3SpecularPS_2(BumpVertexShaderOutput input) : COLOR0
{
	float4 diffuseColor = GetDiffuseColor(input.TexCoord);
	diffuseColor *= input.Color;
	float4 bumpColor = CombinedBumpColor(input);
	float3 bumpNormal = CalcBumpNormal(bumpColor, input);
	
	float2 phongShadingFactors = CalcPhongShadingFactors_2(bumpNormal);
	float4 phongShadingColor1 = CalcPhongShadingColor1(bumpNormal, phongShadingFactors[0]);
	float4 phongShadingColor2 = CalcPhongShadingColor2(bumpNormal, phongShadingFactors[1]);
	float2 bumpSpecularFactors = CalcBumpSpecularFactors_2(bumpNormal, input, phongShadingFactors);
	float4 lightmapColor = tex2D(LightmapTextureSampler, input.TexCoord);
	float4 specularColor = tex2D(SpecularTextureSampler, input.TexCoord);
	float3 bumpSpecularColor1 = bumpSpecularFactors[0] * specularColor.rgb * Light1Intensity;
	float3 bumpSpecularColor2 = bumpSpecularFactors[1] * specularColor.rgb * Light2Intensity;
	float4 color1 = ApplyBumpBlendSpecular(diffuseColor, bumpSpecularColor1, phongShadingColor1) * lightmapColor;
	float4 color2 = ApplyBumpBlendSpecular(diffuseColor, bumpSpecularColor2, phongShadingColor2) * lightmapColor;
	return BlendColorLayers_2(color1, color2);
}


float4 DiffuseLightmapBump3SpecularPS_3(BumpVertexShaderOutput input) : COLOR0
{
	float4 diffuseColor = GetDiffuseColor(input.TexCoord);
	diffuseColor *= input.Color;
	float4 bumpColor = CombinedBumpColor(input);
	float3 bumpNormal = CalcBumpNormal(bumpColor, input);
	
	float3 phongShadingFactors = CalcPhongShadingFactors_3(bumpNormal);
	float4 phongShadingColor1 = CalcPhongShadingColor1(bumpNormal, phongShadingFactors[0]);
	float4 phongShadingColor2 = CalcPhongShadingColor2(bumpNormal, phongShadingFactors[1]);
	float4 phongShadingColor3 = CalcPhongShadingColor3(bumpNormal, phongShadingFactors[2]);
	float3 bumpSpecularFactors = CalcBumpSpecularFactors_3(bumpNormal, input, phongShadingFactors);
	float4 lightmapColor = tex2D(LightmapTextureSampler, input.TexCoord);
	float4 specularColor = tex2D(SpecularTextureSampler, input.TexCoord);
	float3 bumpSpecularColor1 = bumpSpecularFactors[0] * specularColor.rgb * Light1Intensity;
	float3 bumpSpecularColor2 = bumpSpecularFactors[1] * specularColor.rgb * Light2Intensity;
	float3 bumpSpecularColor3 = bumpSpecularFactors[2] * specularColor.rgb * Light3Intensity;
	float4 color1 = ApplyBumpBlendSpecular(diffuseColor, bumpSpecularColor1, phongShadingColor1) * lightmapColor;
	float4 color2 = ApplyBumpBlendSpecular(diffuseColor, bumpSpecularColor2, phongShadingColor2) * lightmapColor;
	float4 color3 = ApplyBumpBlendSpecular(diffuseColor, bumpSpecularColor3, phongShadingColor3) * lightmapColor;
	return BlendColorLayers_3(color1, color2, color3);
}

/*******************************************************************************
 * Metallic shaders.
 *
 * For the most part, see above. But I also added a new feature: Lighting is now
 * bump-mapped here, too. If you're wondering why it wasn't before, well, so was
 * I, but I'm not going to use per-vertex normals if I have a bump map anyway.
 * Doing that gives me no performance or other benefit whatsoever.
 *
 * I've also chagned to using reflect() here, like in the specular shaders.
 */
float4 MetallicPS_1(BumpVertexShaderOutput input) : COLOR0
{
	float4 bumpColor = tex2D(BumpTextureSampler, input.TexCoord);
	float3 bumpNormal = CalcBumpNormal(bumpColor, input);
	
	float phongShadingFactor = CalcPhongShadingFactors_1(bumpNormal);
	float4 phongShadingColor1 = CalcPhongShadingColor1(bumpNormal, phongShadingFactor);
	
	float4 diffuseColor = GetDiffuseColor(input.TexCoord);
	diffuseColor *= input.Color * phongShadingColor1;

	//float3 cameraDir = normalize(input.PositionWorld - CameraPos);
	float3 cameraDir = normalize(CameraPos - input.PositionWorld);
	//float3 reflectionDir = normalize(dot(bumpNormal, cameraDir) * bumpNormal * 2 - cameraDir);
	float3 reflectionDir = reflect(cameraDir, bumpNormal);

	float2 environmentTexCoord = CalculateEnvironmentTexCoord(reflectionDir);
	float4 environmentColor = tex2D(EnvironmentTextureSampler, environmentTexCoord);
	
	return float4(lerp(diffuseColor.rgb, environmentColor.rgb, ReflectionAmount), diffuseColor.a);
}


float4 MetallicPS_2(BumpVertexShaderOutput input) : COLOR0
{
	float4 bumpColor = tex2D(BumpTextureSampler, input.TexCoord);
	float3 bumpNormal = CalcBumpNormal(bumpColor, input);
	
	float2 phongShadingFactors = CalcPhongShadingFactors_2(bumpNormal);
	float4 phongShadingColor1 = CalcPhongShadingColor1(bumpNormal, phongShadingFactors[0]);
	float4 phongShadingColor2 = CalcPhongShadingColor2(bumpNormal, phongShadingFactors[1]);
	
	float4 diffuseColor = GetDiffuseColor(input.TexCoord);
	diffuseColor *= input.Color * BlendColorLayers_2(phongShadingColor1, phongShadingColor2);

	//float3 cameraDir = normalize(input.PositionWorld - CameraPos);
	float3 cameraDir = normalize(CameraPos - input.PositionWorld);
	//float3 reflectionDir = normalize(dot(bumpNormal, cameraDir) * bumpNormal * 2 - cameraDir);
	float3 reflectionDir = reflect(cameraDir, bumpNormal);

	float2 environmentTexCoord = CalculateEnvironmentTexCoord(reflectionDir);
	float4 environmentColor = tex2D(EnvironmentTextureSampler, environmentTexCoord);
	
	return float4(lerp(diffuseColor.rgb, environmentColor.rgb, ReflectionAmount), diffuseColor.a);
}


float4 MetallicPS_3(BumpVertexShaderOutput input) : COLOR0
{
	float4 bumpColor = tex2D(BumpTextureSampler, input.TexCoord);
	float3 bumpNormal = CalcBumpNormal(bumpColor, input);
	
	float3 phongShadingFactors = CalcPhongShadingFactors_3(bumpNormal);
	float4 phongShadingColor1 = CalcPhongShadingColor1(bumpNormal, phongShadingFactors[0]);
	float4 phongShadingColor2 = CalcPhongShadingColor2(bumpNormal, phongShadingFactors[1]);
	float4 phongShadingColor3 = CalcPhongShadingColor3(bumpNormal, phongShadingFactors[2]);
	
	float4 diffuseColor = GetDiffuseColor(input.TexCoord);
	diffuseColor *= input.Color * BlendColorLayers_3(phongShadingColor1, phongShadingColor2, phongShadingColor3);

	//float3 cameraDir = normalize(input.PositionWorld - CameraPos);
	float3 cameraDir = normalize(CameraPos - input.PositionWorld);
	//float3 reflectionDir = normalize(dot(bumpNormal, cameraDir) * bumpNormal * 2 - cameraDir);
	float3 reflectionDir = reflect(cameraDir, bumpNormal);

	float2 environmentTexCoord = CalculateEnvironmentTexCoord(reflectionDir);
	float4 environmentColor = tex2D(EnvironmentTextureSampler, environmentTexCoord);
	
	return float4(lerp(diffuseColor.rgb, environmentColor.rgb, ReflectionAmount), diffuseColor.a);
}


float4 MetallicBump3PS_1_LQ(BumpVertexShaderOutput input) : COLOR0
{
	float4 bumpColor = CombinedBumpColor(input);
	float3 bumpNormal = CalcBumpNormal(bumpColor, input);
	
	float4 diffuseColor = GetDiffuseColor(input.TexCoord);
	diffuseColor *= input.Color;
	
	float phongShadingFactor = CalcPhongShadingFactors_1(bumpNormal);
	float4 phongShadingColor1 = CalcPhongShadingColor1(bumpNormal, phongShadingFactor);

	float bumpSpecularFactor = CalcBumpSpecularFactors_1(bumpNormal, input, phongShadingFactor);
	float4 color1 = ApplyBumpBlend(diffuseColor, bumpSpecularFactor, phongShadingColor1);
	float4 color = color1;

	//float3 cameraDir = normalize(input.PositionWorld - CameraPos);
	float3 cameraDir = normalize(CameraPos - input.PositionWorld);
	//float3 reflectionDir = normalize(dot(bumpNormal, cameraDir) * bumpNormal * 2 - cameraDir);
	float3 reflectionDir = reflect(cameraDir, bumpNormal);

	float2 environmentTexCoord = CalculateEnvironmentTexCoord(reflectionDir);
	float4 environmentColor = tex2D(EnvironmentTextureSampler, environmentTexCoord);
	
	return float4(lerp(color.rgb, environmentColor.rgb, ReflectionAmount), color.a);
}


float4 MetallicBump3PS_1_HQ(BumpVertexShaderOutput input) : COLOR0
{
	float4 bumpColor = CombinedBumpColor(input);
	float3 bumpNormal = CalcBumpNormal(bumpColor, input);
	
	float4 diffuseColor = GetDiffuseColor(input.TexCoord);
	diffuseColor *= input.Color;
	
	float phongShadingFactor = CalcPhongShadingFactors_1(bumpNormal);
	float4 phongShadingColor1 = CalcPhongShadingColor1(bumpNormal, phongShadingFactor);

	float bumpSpecularFactor = CalcBumpSpecularFactors_1(bumpNormal, input, phongShadingFactor);
	float4 color1 = ApplyBumpBlend(diffuseColor, bumpSpecularFactor, phongShadingColor1);
	float4 color = color1;

	//float3 cameraDir = normalize(input.PositionWorld - CameraPos);
	float3 cameraDir = normalize(CameraPos - input.PositionWorld);
	//float3 reflectionDir = normalize(dot(bumpNormal, cameraDir) * bumpNormal * 2 - cameraDir);
	float3 reflectionDir = reflect(cameraDir, bumpNormal);

	float2 environmentTexCoord = CalculateEnvironmentTexCoord(reflectionDir);
	float4 environmentColor = tex2D(EnvironmentTextureSampler, environmentTexCoord);
	
	return float4(lerp(color.rgb, environmentColor.rgb, ReflectionAmount), color.a);
}


float4 MetallicBump3PS_2(BumpVertexShaderOutput input) : COLOR0
{
	float4 bumpColor = CombinedBumpColor(input);
	float3 bumpNormal = CalcBumpNormal(bumpColor, input);
	
	float4 diffuseColor = GetDiffuseColor(input.TexCoord);
	diffuseColor *= input.Color;
	
	float2 phongShadingFactors = CalcPhongShadingFactors_2(bumpNormal);
	float4 phongShadingColor1 = CalcPhongShadingColor1(bumpNormal, phongShadingFactors[0]);
	float4 phongShadingColor2 = CalcPhongShadingColor2(bumpNormal, phongShadingFactors[1]);
	
	float2 bumpSpecularFactors = CalcBumpSpecularFactors_2(bumpNormal, input, phongShadingFactors);
	float4 color1 = ApplyBumpBlend(diffuseColor, bumpSpecularFactors[0], phongShadingColor1);
	float4 color2 = ApplyBumpBlend(diffuseColor, bumpSpecularFactors[1], phongShadingColor2);
	float4 color = BlendColorLayers_2(color1, color2);

	//float3 cameraDir = normalize(input.PositionWorld - CameraPos);
	float3 cameraDir = normalize(CameraPos - input.PositionWorld);
	//float3 reflectionDir = normalize(dot(bumpNormal, cameraDir) * bumpNormal * 2 - cameraDir);
	float3 reflectionDir = reflect(cameraDir, bumpNormal);

	float2 environmentTexCoord = CalculateEnvironmentTexCoord(reflectionDir);
	float4 environmentColor = tex2D(EnvironmentTextureSampler, environmentTexCoord);
	
	return float4(lerp(color.rgb, environmentColor.rgb, ReflectionAmount), color.a);
}


float4 MetallicBump3PS_3(BumpVertexShaderOutput input) : COLOR0
{
	float4 bumpColor = CombinedBumpColor(input);
	float3 bumpNormal = CalcBumpNormal(bumpColor, input);
	
	float4 diffuseColor = GetDiffuseColor(input.TexCoord);
	diffuseColor *= input.Color;
	
	float3 phongShadingFactors = CalcPhongShadingFactors_3(bumpNormal);
	float4 phongShadingColor1 = CalcPhongShadingColor1(bumpNormal, phongShadingFactors[0]);
	float4 phongShadingColor2 = CalcPhongShadingColor2(bumpNormal, phongShadingFactors[1]);
	float4 phongShadingColor3 = CalcPhongShadingColor3(bumpNormal, phongShadingFactors[2]);

	float3 bumpSpecularFactors = CalcBumpSpecularFactors_3(bumpNormal, input, phongShadingFactors);
	float4 color1 = ApplyBumpBlend(diffuseColor, bumpSpecularFactors[0], phongShadingColor1);
	float4 color2 = ApplyBumpBlend(diffuseColor, bumpSpecularFactors[1], phongShadingColor2);
	float4 color3 = ApplyBumpBlend(diffuseColor, bumpSpecularFactors[2], phongShadingColor3);
	float4 color = BlendColorLayers_3(color1, color2, color3);

	//float3 cameraDir = normalize(input.PositionWorld - CameraPos);
	float3 cameraDir = normalize(CameraPos - input.PositionWorld);
	//float3 reflectionDir = normalize(dot(bumpNormal, cameraDir) * bumpNormal * 2 - cameraDir);
	float3 reflectionDir = reflect(cameraDir, bumpNormal);

	float2 environmentTexCoord = CalculateEnvironmentTexCoord(reflectionDir);
	float4 environmentColor = tex2D(EnvironmentTextureSampler, environmentTexCoord);
	
	return float4(lerp(color.rgb, environmentColor.rgb, ReflectionAmount), color.a);
}


float4 ShadelessPS(BasicVertexShaderOutput input) : COLOR0
{
	return GetDiffuseColorShadeless(input.TexCoord);
}


float4 ThorGlow1PS(BasicVertexShaderOutput input) : COLOR0
{
	return GetDiffuseColor(input.TexCoord) * float4(0.25, 0.5, 1.0, 1.0);
}


float4 ThorGlow2PS(BasicVertexShaderOutput input) : COLOR0
{
	float4 color = GetDiffuseColor(input.TexCoord);
	color.r = 0.25;
	color.g = 0.5;
	color.b = 1.0;
	return color;
}


technique Diffuse_1
{
    pass Pass1
    {
        VertexShader = compile vs_1_1 BasicVS();
        PixelShader = compile ps_2_0 DiffusePS_1();
    }
}


technique Diffuse_2
{
    pass Pass1
    {
        VertexShader = compile vs_1_1 BasicVS();
        PixelShader = compile ps_2_0 DiffusePS_2();
    }
}


technique Diffuse_3
{
    pass Pass1
    {
        VertexShader = compile vs_1_1 BasicVS();
        PixelShader = compile ps_2_0 DiffusePS_3();
    }
}


technique DiffuseLightmap_1
{
    pass Pass1
    {
        VertexShader = compile vs_1_1 BasicVS();
        PixelShader = compile ps_2_0 DiffuseLightmapPS_1();
    }
}


technique DiffuseLightmap_2
{
    pass Pass1
    {
        VertexShader = compile vs_1_1 BasicVS();
        PixelShader = compile ps_2_0 DiffuseLightmapPS_2();
    }
}


technique DiffuseLightmap_3
{
    pass Pass1
    {
        VertexShader = compile vs_1_1 BasicVS();
        PixelShader = compile ps_2_0 DiffuseLightmapPS_3();
    }
}


technique DiffuseBump_1
{
    pass Pass1
    {
        VertexShader = compile vs_2_0 BumpVS();
        PixelShader = compile ps_2_0 DiffuseBumpPS_1();
    }
}


technique DiffuseBump_2
{
    pass Pass1
    {
        VertexShader = compile vs_2_0 BumpVS();
        PixelShader = compile ps_2_0 DiffuseBumpPS_2();
    }
}


technique DiffuseBump_3
{
    pass Pass1
    {
        VertexShader = compile vs_3_0 BumpVS();
        PixelShader = compile ps_3_0 DiffuseBumpPS_3();
    }
}


technique DiffuseLightmapBump_1
{
    pass Pass1
    {
        VertexShader = compile vs_2_0 BumpVS();
        PixelShader = compile ps_2_0 DiffuseLightmapBumpPS_1();
    }
}


technique DiffuseLightmapBump_2
{
    pass Pass1
    {
        VertexShader = compile vs_2_0 BumpVS();
        PixelShader = compile ps_2_0 DiffuseLightmapBumpPS_2();
    }
}


technique DiffuseLightmapBump_3
{
    pass Pass1
    {
        VertexShader = compile vs_3_0 BumpVS();
        PixelShader = compile ps_3_0 DiffuseLightmapBumpPS_3();
    }
}


technique DiffuseLightmapBump3_1
{
    pass Pass1
    {
        VertexShader = compile vs_2_0 BumpVS();
        PixelShader = compile ps_2_0 DiffuseLightmapBump3PS_1();
    }
}


technique DiffuseLightmapBump3_2_HQ
{
    pass Pass1
    {
        VertexShader = compile vs_2_0 BumpVS();
        PixelShader = compile ps_3_0 DiffuseLightmapBump3PS_2_HQ();
    }
}


technique DiffuseLightmapBump3_2_LQ
{
    pass Pass1
    {
        VertexShader = compile vs_2_0 BumpVS();
        PixelShader = compile ps_2_0 DiffuseLightmapBump3PS_2_LQ();
    }
}


technique DiffuseLightmapBump3_3
{
    pass Pass1
    {
        VertexShader = compile vs_3_0 BumpVS();
        PixelShader = compile ps_3_0 DiffuseLightmapBump3PS_3();
    }
}


technique DiffuseLightmapBumpSpecular_1
{
    pass Pass1
    {
        VertexShader = compile vs_2_0 BumpVS();
        PixelShader = compile ps_2_0 DiffuseLightmapBumpSpecularPS_1();
    }
}


technique DiffuseLightmapBumpSpecular_2
{
    pass Pass1
    {
        VertexShader = compile vs_2_0 BumpVS();
        PixelShader = compile ps_2_0 DiffuseLightmapBumpSpecularPS_2();
    }
}


technique DiffuseLightmapBumpSpecular_3
{
    pass Pass1
    {
        VertexShader = compile vs_3_0 BumpVS();
        PixelShader = compile ps_3_0 DiffuseLightmapBumpSpecularPS_3();
    }
}


technique DiffuseLightmapBump3Specular_1
{
    pass Pass1
    {
        VertexShader = compile vs_2_0 BumpVS();
        PixelShader = compile ps_2_0 DiffuseLightmapBump3SpecularPS_1();
    }
}


technique DiffuseLightmapBump3Specular_2
{
    pass Pass1
    {
        VertexShader = compile vs_2_0 BumpVS();
        PixelShader = compile ps_3_0 DiffuseLightmapBump3SpecularPS_2();
    }
}


technique DiffuseLightmapBump3Specular_3
{
    pass Pass1
    {
        VertexShader = compile vs_3_0 BumpVS();
        PixelShader = compile ps_3_0 DiffuseLightmapBump3SpecularPS_3();
    }
}


technique Metallic_1
{
    pass Pass1
    {
        VertexShader = compile vs_2_0 BumpVS();
        PixelShader = compile ps_2_0 MetallicPS_1();
    }
}


technique Metallic_2
{
    pass Pass1
    {
        VertexShader = compile vs_2_0 BumpVS();
        PixelShader = compile ps_2_0 MetallicPS_2();
    }
}


technique Metallic_3
{
    pass Pass1
    {
        VertexShader = compile vs_2_0 BumpVS();
        PixelShader = compile ps_2_0 MetallicPS_3();
    }
}


technique Metallic_3_V3
{
    pass Pass1
    {
        VertexShader = compile vs_3_0 BumpVS();
        PixelShader = compile ps_3_0 MetallicPS_3();
    }
}


technique MetallicBump3_1_LQ
{
    pass Pass1
    {
        VertexShader = compile vs_2_0 BumpVS();
        PixelShader = compile ps_2_0 MetallicBump3PS_1_LQ();
    }
}


technique MetallicBump3_1_HQ
{
    pass Pass1
    {
        VertexShader = compile vs_2_0 BumpVS();
        PixelShader = compile ps_3_0 MetallicBump3PS_1_HQ();
    }
}


technique MetallicBump3_2
{
    pass Pass1
    {
        VertexShader = compile vs_2_0 BumpVS();
        PixelShader = compile ps_3_0 MetallicBump3PS_2();
    }
}


technique MetallicBump3_3
{
    pass Pass1
    {
        VertexShader = compile vs_2_0 BumpVS();
        PixelShader = compile ps_3_0 MetallicBump3PS_3();
    }
}


technique Shadeless
{
    pass Pass1
    {
        VertexShader = compile vs_1_1 BasicVS();
        PixelShader = compile ps_1_1 ShadelessPS();
    }
}


technique ThorGlow1
{
    pass Pass1
    {
        VertexShader = compile vs_1_1 BasicVS();
        PixelShader = compile ps_1_1 ThorGlow1PS();
    }
}


technique ThorGlow2
{
    pass Pass1
    {
        VertexShader = compile vs_1_1 BasicVS();
        PixelShader = compile ps_1_1 ThorGlow2PS();
    }
}
