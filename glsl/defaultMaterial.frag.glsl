#include "include/common.glsl"
#include "include/lightmap.glsl"
#include "include/uniforms.glsl"
#if defined(NUM_DLIGHTS)
#include "include/dlights.glsl"
#endif
#ifdef APPLY_FOG
#include "include/fog.glsl"
#endif
#ifdef APPLY_GREYSCALE
#include "include/greyscale.glsl"
#endif

#include "include/varying_material.glsl"

#ifdef NUM_LIGHTMAPS
uniform vec4 u_DeluxemapOffset[(NUM_LIGHTMAPS + 3) / 4]; // s-offset for v_LightmapTexCoord
uniform LightmapSampler u_LightmapTexture0;
#if NUM_LIGHTMAPS >= 2
uniform LightmapSampler u_LightmapTexture1;
#if NUM_LIGHTMAPS >= 3
uniform LightmapSampler u_LightmapTexture2;
#if NUM_LIGHTMAPS >= 4
uniform LightmapSampler u_LightmapTexture3;
#endif // NUM_LIGHTMAPS >= 4
#endif // NUM_LIGHTMAPS >= 3
#endif // NUM_LIGHTMAPS >= 2
#endif // NUM_LIGHTMAPS

uniform sampler2D u_BaseTexture;
uniform sampler2D u_NormalmapTexture;
uniform sampler2D u_GlossTexture;
#ifdef APPLY_DECAL
uniform sampler2D u_DecalTexture;
#endif

#ifdef APPLY_ENTITY_DECAL
uniform sampler2D u_EntityDecalTexture;
#endif

#if defined(APPLY_OFFSETMAPPING) || defined(APPLY_RELIEFMAPPING)
uniform float u_OffsetMappingScale;
#endif

#ifdef APPLY_DRAWFLAT
uniform myhalf3 u_WallColor;
uniform myhalf3 u_FloorColor;
#endif

uniform myhalf2 u_GlossFactors; // gloss scaling and exponent factors

#if defined(APPLY_OFFSETMAPPING) || defined(APPLY_RELIEFMAPPING)
// The following reliefmapping and offsetmapping routine was taken from DarkPlaces
// The credit goes to LordHavoc (as always)
vec2 OffsetMapping(vec2 TexCoord)
{
#ifdef APPLY_RELIEFMAPPING
	// 14 sample relief mapping: linear search and then binary search
	// this basically steps forward a small amount repeatedly until it finds
	// itself inside solid, then jitters forward and back using decreasing
	// amounts to find the impact
	//vec3 OffsetVector = vec3(v_EyeVector.xy * ((1.0 / v_EyeVector.z) * u_OffsetMappingScale) * vec2(-1, 1), -1);
	//vec3 OffsetVector = vec3(normalize(v_EyeVector.xy) * u_OffsetMappingScale * vec2(-1, 1), -1);
	vec3 OffsetVector = vec3(normalize(v_EyeVector).xy * u_OffsetMappingScale * vec2(-1, 1), -1);
	vec3 RT = vec3(TexCoord, 1);
	OffsetVector *= 0.1;
	RT += OffsetVector *  step(qf_texture(u_NormalmapTexture, RT.xy).a, RT.z);
	RT += OffsetVector *  step(qf_texture(u_NormalmapTexture, RT.xy).a, RT.z);
	RT += OffsetVector *  step(qf_texture(u_NormalmapTexture, RT.xy).a, RT.z);
	RT += OffsetVector *  step(qf_texture(u_NormalmapTexture, RT.xy).a, RT.z);
	RT += OffsetVector *  step(qf_texture(u_NormalmapTexture, RT.xy).a, RT.z);
	RT += OffsetVector *  step(qf_texture(u_NormalmapTexture, RT.xy).a, RT.z);
	RT += OffsetVector *  step(qf_texture(u_NormalmapTexture, RT.xy).a, RT.z);
	RT += OffsetVector *  step(qf_texture(u_NormalmapTexture, RT.xy).a, RT.z);
	RT += OffsetVector *  step(qf_texture(u_NormalmapTexture, RT.xy).a, RT.z);
	RT += OffsetVector * (step(qf_texture(u_NormalmapTexture, RT.xy).a, RT.z)          - 0.5);
	RT += OffsetVector * (step(qf_texture(u_NormalmapTexture, RT.xy).a, RT.z) * 0.5    - 0.25);
	RT += OffsetVector * (step(qf_texture(u_NormalmapTexture, RT.xy).a, RT.z) * 0.25   - 0.125);
	RT += OffsetVector * (step(qf_texture(u_NormalmapTexture, RT.xy).a, RT.z) * 0.125  - 0.0625);
	RT += OffsetVector * (step(qf_texture(u_NormalmapTexture, RT.xy).a, RT.z) * 0.0625 - 0.03125);
	return RT.xy;
#else
	// 2 sample offset mapping (only 2 samples because of ATI Radeon 9500-9800/X300 limits)
	// this basically moves forward the full distance, and then backs up based
	// on height of samples
	//vec2 OffsetVector = vec2(v_EyeVector.xy * ((1.0 / v_EyeVector.z) * u_OffsetMappingScale) * vec2(-1, 1));
	//vec2 OffsetVector = vec2(normalize(v_EyeVector.xy) * u_OffsetMappingScale * vec2(-1, 1));
	vec2 OffsetVector = vec2(normalize(v_EyeVector).xy * u_OffsetMappingScale * vec2(-1, 1));
	TexCoord += OffsetVector;
	OffsetVector *= 0.5;
	TexCoord -= OffsetVector * qf_texture(u_NormalmapTexture, TexCoord).a;
	TexCoord -= OffsetVector * qf_texture(u_NormalmapTexture, TexCoord).a;
	return TexCoord;
#endif // APPLY_RELIEFMAPPING
}
#endif // defined(APPLY_OFFSETMAPPING) || defined(APPLY_RELIEFMAPPING)

void main()
{
#if defined(APPLY_OFFSETMAPPING) || defined(APPLY_RELIEFMAPPING)
	// apply offsetmapping
	vec2 TexCoordOffset = OffsetMapping(v_TexCoord_FogCoord.st);
#define v_TexCoord TexCoordOffset
#else
#define v_TexCoord v_TexCoord_FogCoord.st
#endif

	myhalf3 surfaceNormal;
	myhalf3 surfaceNormalModelspace;
	myhalf3 diffuseNormalModelspace;
	float diffuseProduct;

#ifdef APPLY_CELSHADING
	float diffuseProductPositive;
	float diffuseProductNegative;
	float hardShadow;
#endif

	myhalf3 weightedDiffuseNormalModelspace;

#if !defined(APPLY_DIRECTIONAL_LIGHT) && !defined(NUM_LIGHTMAPS)
	myhalf4 color = myhalf4 (1.0, 1.0, 1.0, 1.0);
#else
	myhalf4 color = myhalf4 (0.0, 0.0, 0.0, 1.0);
#endif

	myhalf4 decal = myhalf4 (0.0, 0.0, 0.0, 1.0);

	// get the surface normal
	surfaceNormal = normalize(myhalf3(qf_texture (u_NormalmapTexture, v_TexCoord)) - myhalf3 (0.5));
	surfaceNormalModelspace = normalize(v_StrMatrix * surfaceNormal);

#ifdef APPLY_DIRECTIONAL_LIGHT

#ifdef APPLY_DIRECTIONAL_LIGHT_FROM_NORMAL
	diffuseNormalModelspace = v_StrMatrix[2];
#else
	diffuseNormalModelspace = u_LightDir;
#endif // APPLY_DIRECTIONAL_LIGHT_FROM_NORMAL

	weightedDiffuseNormalModelspace = diffuseNormalModelspace;

#ifdef APPLY_CELSHADING
	hardShadow = 0.0;
#ifdef APPLY_HALFLAMBERT
	diffuseProduct = float (dot (surfaceNormalModelspace, diffuseNormalModelspace));
	diffuseProductPositive = float ( clamp(diffuseProduct, 0.0, 1.0) * 0.5 + 0.5 );
	diffuseProductPositive *= diffuseProductPositive;
	diffuseProductNegative = float ( clamp(diffuseProduct, -1.0, 0.0) * 0.5 - 0.5 );
	diffuseProductNegative = diffuseProductNegative * diffuseProductNegative - 0.25;
	diffuseProduct = diffuseProductPositive;
#else
	diffuseProduct = float (dot (surfaceNormalModelspace, diffuseNormalModelspace));
	diffuseProductPositive = max (diffuseProduct, 0.0);
	diffuseProductNegative = (-min (diffuseProduct, 0.0) - 0.3);
#endif // APPLY_HALFLAMBERT

	// smooth the hard shadow edge
	hardShadow += floor(max(diffuseProduct + 0.1, 0.0) * 2.0);
	hardShadow += floor(max(diffuseProduct + 0.055, 0.0) * 2.0);
	hardShadow += floor(diffuseProductPositive * 2.0);

	color.rgb += myhalf(0.6 + hardShadow * 0.09 + diffuseProductPositive * 0.14);

	// backlight
	color.rgb += myhalf (ceil(diffuseProductNegative * 2.0) * 0.085 + diffuseProductNegative * 0.085);
#else

#ifdef APPLY_HALFLAMBERT
	diffuseProduct = float ( clamp(dot (surfaceNormalModelspace, diffuseNormalModelspace), 0.0, 1.0) * 0.5 + 0.5 );
	diffuseProduct *= diffuseProduct;
#else
	diffuseProduct = float (dot (surfaceNormalModelspace, diffuseNormalModelspace));
#endif // APPLY_HALFLAMBERT

#ifdef APPLY_DIRECTIONAL_LIGHT_MIX
	color.rgb += qf_FrontColor.rgb;
#else
	color.rgb += u_LightDiffuse.rgb * myhalf(max (diffuseProduct, 0.0)) + u_LightAmbient;
#endif

#endif // APPLY_CELSHADING

#endif // APPLY_DIRECTIONAL_LIGHT

	// deluxemapping using light vectors in modelspace

#ifdef NUM_LIGHTMAPS
	// get light normal
	diffuseNormalModelspace = normalize(myhalf3 (Lightmap(u_LightmapTexture0, v_LightmapTexCoord01.st+vec2(u_DeluxemapOffset[0].x, 0.0), v_LightmapLayer0123.x)) - myhalf3 (0.5));
	// calculate directional shading
	diffuseProduct = float (dot (surfaceNormalModelspace, diffuseNormalModelspace));

#ifdef APPLY_FBLIGHTMAP
	weightedDiffuseNormalModelspace = diffuseNormalModelspace;
	// apply lightmap color
	color.rgb += myhalf3 (max (diffuseProduct, 0.0) * myhalf3 (Lightmap(u_LightmapTexture0, v_LightmapTexCoord01.st, v_LightmapLayer0123.x)));
#else
#define NORMALIZE_DIFFUSE_NORMAL
	weightedDiffuseNormalModelspace = u_LightstyleColor[0] * diffuseNormalModelspace;
	// apply lightmap color
	color.rgb += u_LightstyleColor[0] * myhalf(max (diffuseProduct, 0.0)) * myhalf3 (Lightmap(u_LightmapTexture0, v_LightmapTexCoord01.st, v_LightmapLayer0123.x));
#endif // APPLY_FBLIGHTMAP

#ifdef APPLY_AMBIENT_COMPENSATION
	// compensate for ambient lighting
	color.rgb += myhalf((1.0 - max (diffuseProduct, 0.0))) * u_LightAmbient;
#endif

#if NUM_LIGHTMAPS >= 2
	diffuseNormalModelspace = normalize(myhalf3 (Lightmap(u_LightmapTexture1, v_LightmapTexCoord01.pq+vec2(u_DeluxemapOffset[0].y,0.0), v_LightmapLayer0123.y)) - myhalf3 (0.5));
	diffuseProduct = float (dot (surfaceNormalModelspace, diffuseNormalModelspace));
	weightedDiffuseNormalModelspace += u_LightstyleColor[1] * diffuseNormalModelspace;
	color.rgb += u_LightstyleColor[1] * myhalf(max (diffuseProduct, 0.0)) * myhalf3 (Lightmap(u_LightmapTexture1, v_LightmapTexCoord01.pq, v_LightmapLayer0123.y));
#if NUM_LIGHTMAPS >= 3
	diffuseNormalModelspace = normalize(myhalf3 (Lightmap(u_LightmapTexture2, v_LightmapTexCoord23.st+vec2(u_DeluxemapOffset[0].z,0.0), v_LightmapLayer0123.z)) - myhalf3 (0.5));
	diffuseProduct = float (dot (surfaceNormalModelspace, diffuseNormalModelspace));
	weightedDiffuseNormalModelspace += u_LightstyleColor[2] * diffuseNormalModelspace;
	color.rgb += u_LightstyleColor[2] * myhalf(max (diffuseProduct, 0.0)) * myhalf3 (Lightmap(u_LightmapTexture2, v_LightmapTexCoord23.st, v_LightmapLayer0123.z));
#if NUM_LIGHTMAPS >= 4
	diffuseNormalModelspace = normalize(myhalf3 (Lightmap(u_LightmapTexture3, v_LightmapTexCoord23.pq+vec2(u_DeluxemapOffset[0].w,0.0), v_LightmapLayer0123.w)) - myhalf3 (0.5));
	diffuseProduct = float (dot (surfaceNormalModelspace, diffuseNormalModelspace));
	weightedDiffuseNormalModelspace += u_LightstyleColor[3] * diffuseNormalModelspace;
	color.rgb += u_LightstyleColor[3] * myhalf(max (diffuseProduct, 0.0)) * myhalf3 (Lightmap(u_LightmapTexture3, v_LightmapTexCoord23.pq, v_LightmapLayer0123.w));
#endif // NUM_LIGHTMAPS >= 4
#endif // NUM_LIGHTMAPS >= 3
#endif // NUM_LIGHTMAPS >= 2
#endif // NUM_LIGHTMAPS

#if defined(NUM_DLIGHTS)
	color.rgb += DynamicLightsSummaryColor(v_Position, surfaceNormalModelspace);
#endif

#ifdef APPLY_SPECULAR

#ifdef NORMALIZE_DIFFUSE_NORMAL
	myhalf3 specularNormal = normalize (myhalf3 (normalize (weightedDiffuseNormalModelspace)) + myhalf3 (normalize (u_EntityDist - v_Position)));
#else
	myhalf3 specularNormal = normalize (weightedDiffuseNormalModelspace + myhalf3 (normalize (u_EntityDist - v_Position)));
#endif

	myhalf specularProduct = myhalf(dot (surfaceNormalModelspace, specularNormal));
	color.rgb += (myhalf3(qf_texture(u_GlossTexture, v_TexCoord)) * u_GlossFactors.x) * pow(myhalf(max(specularProduct, 0.0)), u_GlossFactors.y);
#endif // APPLY_SPECULAR

#if defined(APPLY_BASETEX_ALPHA_ONLY) && !defined(APPLY_DRAWFLAT)
	color = min(color, myhalf4(qf_texture(u_BaseTexture, v_TexCoord).a));
#else
	myhalf4 diffuse;

#ifdef APPLY_DRAWFLAT
	myhalf n = myhalf(step(DRAWFLAT_NORMAL_STEP, abs(v_StrMatrix[2].z)));
	diffuse = myhalf4(mix(u_WallColor, u_FloorColor, n), myhalf(qf_texture(u_BaseTexture, v_TexCoord).a));
#else
	diffuse = myhalf4(qf_texture(u_BaseTexture, v_TexCoord));
#endif

#ifdef APPLY_ENTITY_DECAL

#ifdef APPLY_ENTITY_DECAL_ADD
	decal.rgb = myhalf3(qf_texture(u_EntityDecalTexture, v_TexCoord));
	diffuse.rgb += u_EntityColor.rgb * decal.rgb;
#else
	decal = myhalf4(u_EntityColor.rgb, 1.0) * myhalf4(qf_texture(u_EntityDecalTexture, v_TexCoord));
	diffuse.rgb = mix(diffuse.rgb, decal.rgb, decal.a);
#endif // APPLY_ENTITY_DECAL_ADD

#endif // APPLY_ENTITY_DECAL

	color = color * diffuse;
#endif // defined(APPLY_BASETEX_ALPHA_ONLY) && !defined(APPLY_DRAWFLAT)

#ifdef APPLY_DECAL

#ifdef APPLY_DECAL_ADD
	decal.rgb = myhalf3(qf_FrontColor.rgb) * myhalf3(qf_texture(u_DecalTexture, v_TexCoord));
	color.rgb += decal.rgb;
#else
	decal = myhalf4(qf_FrontColor.rgb, 1.0) * myhalf4(qf_texture(u_DecalTexture, v_TexCoord));
	color.rgb = mix(color.rgb, decal.rgb, decal.a);
#endif // APPLY_DECAL_ADD
	color.a *= myhalf(qf_FrontColor.a);

#else

#if !defined (APPLY_DIRECTIONAL_LIGHT) || !defined(APPLY_DIRECTIONAL_LIGHT_MIX)
	color *= myhalf4(qf_FrontColor);
#else
	color.a *= myhalf(qf_FrontColor.a);
#endif

#endif // APPLY_DECAL

#ifdef QF_ALPHATEST
	QF_ALPHATEST(color.a);
#endif

#ifdef APPLY_GREYSCALE
	color.rgb = Greyscale(color.rgb);
#endif

#if defined(APPLY_FOG) && !defined(APPLY_FOG_COLOR)
	myhalf fogDensity = FogDensity(v_TexCoord_FogCoord.pq);
	color.rgb = mix(color.rgb, u_FogColor, fogDensity);
#endif

#ifdef APPLY_BLEND
	qf_FragColor = vec4(color);
#else
	qf_FragColor = vec4(vec3(color), 1.0);
#endif
}
