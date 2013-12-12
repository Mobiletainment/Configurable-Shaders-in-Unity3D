//When using Vertex and Fragment Shaders instead of Surface shaders, we are responsible for: 
//    Converting the vertex from model space to projection space
//    Creating texture coordinates from model texs if needed
//    Calculating all of the lighting

Shader "Custom/DisplacementSoftShadowShader" {
    Properties {
        _MainTex ("Base (RGB)", 2D) = "white" {}
        _BumpMap ("Bump", 2D) = "bump" {}
        _HeightMap ("Heightmap (in A)", 2D) = "black" {}
        
        _Color ("Overall Diffuse Color Filter", Color) = (1,1,1,1)
        _SpecColor("Specular Color", Color) = (1.0, 1.0, 1.0, 1.0)
		_Shininess("Shininess", Range(1.0, 50.0)) = 10.0
		_SpecularIntensity("Specular Light Intensity", Range(0.0, 1.0)) = 1.0
		_DiffIntensity("Diffuse Light Intensity", Range(0.0, 1.0)) = 1.0
		_AmbientIntensity("Ambient Light Intensity", Range(0.0, 1.0)) = 1.0
		_SelfShadowingIntensity("Self Shadowing Light Intensity", Range(0.0, 1.0)) = 1.0
		_Attenuation("Attenuation Point Light", Range(0.01, 1.0)) = 0.01
		_UseBlinnInsteadPhong("Use Blinn instead Phong Shading", float) = 0.0
		_DisplacementSteps("Displacement Steps", Range(1, 16)) = 16
		_RefinementSteps("Refinement Steps", Range(1, 10)) = 8
		_DisplacementStrength("Displacement Strength", Range(1, 50)) = 4
		_ShadowColor("Shadow Color", Color) = (0, 0, 0, 1)
		_k("ESM Parameter k Scale", Range(0.0, 100.0)) = 30.0
    }
    SubShader {
    
      Pass {
        
		Tags { "LightMode"="ForwardBase" } // pass for ambient light and first light source
		Cull Off
		CGPROGRAM
		// Upgrade NOTE: excluded shader from DX11 and Xbox360; has structs without semantics (struct vertexOutput members lightDir,posWorld)
		#pragma exclude_renderers d3d11 xbox360
		
		#pragma target 3.0
		//without #pragma glsl OpenGL complains because of using for loops. 3.0 target is for D3D9. Since OpenGL doesn't have "shader model" concept, for that we kind of approximate it by increasing the instruction limits etc.
		#pragma glsl
		#pragma vertex vert
		#pragma fragment frag
		
		//#include "UnityCG.cginc"
		uniform float4 _LightColor0; //Define the current light's colour variable
		uniform float4 _Color; 
		uniform float4 _SpecColor;
		uniform float _Shininess;
		uniform float _DiffIntensity;
		uniform float _AmbientIntensity;
		uniform float _SpecularIntensity;
		uniform float _SelfShadowingIntensity;
		uniform float _Attenuation;
		uniform float _UseBlinnInsteadPhong;
		uniform sampler2D _MainTex;
		uniform float4 _MainTex_ST; //to use the TRANSFORM_TEX macro we have to define it with _ST appended
		
		uniform sampler2D _BumpMap;
		uniform float4 _BumpMap_ST;
		
		uniform sampler2D _HeightMap; 
        uniform float4 _HeightMap_ST;
        
        uniform float _DisplacementSteps;
        uniform float _RefinementSteps;
        uniform float _DisplacementStrength;
		
		struct vertexInput //input to our vertex program
		{
		    float4 vertex : POSITION;
		    float3 normal : NORMAL;
		    float4 tangent : TANGENT; //used to convert light directions to tangent space
		    float4 texcoord : TEXCOORD0;
		};
		
		struct vertexOutput
		{
		    float4 pos : SV_POSITION;
		    float4 posWorld : TEXCOORD0;
		    float2 tex : TEXCOORD1;
		    float3 tangentWorld : TEXCOORD2;  
			float3 normalWorld : TEXCOORD3;
			float3 binormalWorld : TEXCOORD4;
			float3 viewDirWorld : TEXCOORD5; 
     };
		
		vertexOutput vert (vertexInput input) //to work with the pre-defined macros, the input structure must be called v and it must contain a normal called normal and a tangent called tangent.
		{
		    vertexOutput output;
		    
		    float4x4 modelMatrix = _Object2World;
			float4x4 modelMatrixInverse = _World2Object; // multiplication with unity_Scale.w is unnecessary, because we normalize transformed vectors
		    
		    output.posWorld = mul(modelMatrix, input.vertex);
		    output.pos = mul(UNITY_MATRIX_MVP, input.vertex); //converting to projection space by a predefined matrix (from UnityCg.cginc
		    
		    
		    output.tangentWorld = normalize(float3(mul(modelMatrix, float4(float3(input.tangent), 0.0))));
            output.normalWorld = normalize(mul(float4(input.normal, 0.0), modelMatrixInverse));
            output.binormalWorld = normalize(cross(output.normalWorld, output.tangentWorld) * input.tangent.w); // tangent.w is specific to Unity
		    
		    output.tex = input.texcoord;
		    
            output.viewDirWorld = normalize(_WorldSpaceCameraPos - float3(output.posWorld)); //View Direction in World Space
		    
		    //For displacement mapping:  
		    //float3x3 TBN = float3x3(output.tangentWorld, output.binormalWorld, output.normalWorld);
			//output.eyeVector = mul(TBN, output.viewDirWorld);
		   
		    return output;
		}
		
		float4 frag(vertexOutput input) : COLOR //the actual color calculation
		{
			float3x3 local2WorldTranspose = float3x3(normalize(input.tangentWorld), normalize(input.binormalWorld), normalize(input.normalWorld));
				
			float3 eyeVector = mul(local2WorldTranspose, input.viewDirWorld); 
			//float3 eyeVector = input.eyeVector;
		
			//Displacement Mapping Algorithm: March along the eye ray const-xx steps until we hit the virtual [sunken] surface.
			//For each pixel
			//	1. Start with the original UV coordinates.
			//	2. Run the displacement algorithm; you end up with modified UV coordinates (UV’).
			//	3. Use UV’ for the final color / bump texture lookups for this projection.
			
			float step = 1.0f / _DisplacementSteps; // the distance of the path we walk with every iteration
			float2 dd_texels_max = -eyeVector.xy * _DisplacementStrength; //influence the displacement mapping by a strength factor
			float2 dUV_max = 1.0/1024.0 * dd_texels_max;
			float2 dUV = dUV_max / _DisplacementSteps; // the delta UV step which the texture lookup is adjusted to in each iteration
			
			float prev_hit = 0; //is used to determine if the previous iteration led to a hit
			float h = 1.0; // the current height used in the iteration
			float hit_h = 0; // the final height at which we hit the surface
			
			float2 uv = input.tex.xy; //these are the uv coords we're adaptively modifying 
		
			for (int i = 0; i < _DisplacementSteps; ++i) // determine the inter-texel occlusion silhouette
			{
				h  -= step; // walk 1 step along the path
				uv += dUV;  // adjust the UV coordinate by the delta UV
				float h_tex = tex2D(_HeightMap, _HeightMap_ST.xy * uv + _HeightMap_ST.zw).r; // sample height map at current UV coordinate
				
				//determine if this step is the first hit:
				float is_first_hit = saturate((h_tex - h - prev_hit)*4999999); // to avoid an if statement, this term is used instead of: "if ((h_tex < h) && !prev_hit)"
				hit_h += is_first_hit * h; // in case of a hit, remember the height
				prev_hit += is_first_hit; 	  // in case of a hit, prev_hit will be incremented, which means that it's not zero anymore (which compares to false) and the above expression will always lead to is_first_hit == false
			}
			
			//move to the step BEFORE the hit and start refinement with smaller steps from there
			h = hit_h + step; // start 1 step before the first hit
			uv = input.tex + dUV_max * (1-h); // adjust UV coordinate according to the position 1 step before the 'big' hit
			
			// start refinement with smaller steps			
			dUV = dUV / _RefinementSteps; // further refine the delta UV step which the texture lookup is adjusted to in each iteration
			step = step / _RefinementSteps; // further refine the distance of the path we walk with every iteration by the number of RefinementSteps
			
			//set back all variables used in the iteration
			prev_hit = 0;
			hit_h = 0;
			

			for(int j = 0; j < _RefinementSteps; ++j) //determine the more accurate intersection point to get the refined UV coordinate
			{
				h  -= step; // walk 1 step along the path
				uv += dUV;  // adjust the UV coordinate by the delta UV
				float h_tex = tex2D(_HeightMap, _HeightMap_ST.xy * uv + _HeightMap_ST.zw).r; // sample height map at current UV coordinate
				
				//determine if this step is the first hit:
				float is_first_hit = saturate((h_tex - h - prev_hit)*4999999); // to avoid an if statement, this term is used instead of: "if ((h_tex < h) && !prev_hit)"
				hit_h += is_first_hit * h; // in case of a hit, save the height
				prev_hit += is_first_hit;     // in case of a hit, prev_hit will be incremented, which means that it's not zero anymore (which compares to false) and the above expression will always lead to is_first_hit == false
			}
			
			// assuming the two points in the second iteration only covered one texel, we can now interpolate between the heights at those two points and get the EXACT intersection point. 
			float h1 = hit_h - step;
			float h2 = hit_h;
			
			float v1 = tex2D(_HeightMap, _HeightMap_ST.xy * (input.tex.xy + dUV_max * (1-h1)) + _HeightMap_ST.zw).r; //sample height value at h1
			float v2 = tex2D(_HeightMap, _HeightMap_ST.xy * (input.tex.xy + dUV_max * (1-h2)) + _HeightMap_ST.zw).r; //sample height value at h2
			 
			float t_interp = saturate((v1-h1)/(h2+v1-h1-v2) - 1);
			hit_h = (h1 + t_interp*(h2-h1)); //the final, interpolated height value
			
			input.tex.xy = input.tex.xy + dUV_max* (1 - hit_h); // sample the final UV coordinate according with the location of the final hit from the displacement calculation
			
			//we now have the displaced texel coordinate and can use it for further operations
			
			float4 textureColor = tex2D(_MainTex, _MainTex_ST.xy * input.tex.xy + _MainTex_ST.zw);  // color of the pixel as specified in the texture
			float4 encodedNormal = tex2D(_BumpMap, _BumpMap_ST.xy * input.tex.xy + _BumpMap_ST.zw); // sample the normal from the bump map 
			float3 localCoords = float3(2.0 * encodedNormal.ag - float2(1.0), 0.0); //Unity uses a local surface coordinate systems for each point of the surface to specify normal vectors in the normal map
			localCoords.z = sqrt(1.0 - dot(localCoords, localCoords)); // approximation without sqrt: localCoords.z = 1.0 - 0.5 * dot(localCoords, localCoords);
			
			//normal vector N is transformed with the transpose of the inverse model matrix from object space to world space (because it is orthogonal to a surface
			float3 normalDirection = normalize(mul(localCoords, local2WorldTranspose)); //our final normal vector
			
			float3 viewDirection = normalize(_WorldSpaceCameraPos - float3(input.posWorld));
			
			float attenuation;
			float3 lightDirection;
			
			if (0.0 == _WorldSpaceLightPos0.w) // directional light?
			{
				attenuation = 1.0; // no attenuation
				lightDirection = normalize(float3(_WorldSpaceLightPos0));
			} 
			else // point or spot light
			{
			   float3 vertexToLightSource = float3(_WorldSpaceLightPos0 - input.posWorld);
			   float distance = length(vertexToLightSource);
			   attenuation = 1.0 / (distance * _Attenuation); // linear attenuation 
			   lightDirection = normalize(vertexToLightSource);
			}
			
			float nDotL = dot(normalDirection, lightDirection);
			
			float3 ambientLighting = float3(textureColor) * float3(UNITY_LIGHTMODEL_AMBIENT) * float3(_Color) * _AmbientIntensity; //base color of the ambient light;
			
			float3 diffuseReflection = float3(textureColor) * attenuation * float3(_LightColor0) * float3(_Color) * max(0.0, nDotL) * _DiffIntensity;
			
			float3 specularReflection;
			
			float3 specularReflectionBase = attenuation * float3(_LightColor0) * float3(_SpecColor) * (1.0 - textureColor.a) * _SpecularIntensity;
			   
		    if (_UseBlinnInsteadPhong >= 1.0)
		    {
		   		//Blinn-Phong shading model, uses half vector
		   		float3 halfVec = (lightDirection + viewDirection) / length(lightDirection + viewDirection);
		   		specularReflection = specularReflectionBase * pow(saturate(dot(normalDirection, halfVec)), _Shininess);
		    }
		    else
		    {
		   		//Phong shading model, uses reflection vector
		   		//float3 reflectionVec = normalize(2 * nDotL * n - i.lightDir);
		   		specularReflection = specularReflectionBase * pow(max(0.0, dot(reflect(-lightDirection, normalDirection), viewDirection)), _Shininess);
		    }	
		
			// compute self-shadowing term
			float selfShadowing = saturate(4* nDotL) * _SelfShadowingIntensity;
			
			return float4(ambientLighting + selfShadowing *  (diffuseReflection + specularReflection), 1.0);
		}
		
		ENDCG
	}
 
      Pass {    
		Tags { "LightMode" = "ForwardAdd" } // pass for additional light sources
		Blend One One // additive blending 
		
		CGPROGRAM
		#pragma target 3.0
		//without #pragma glsl OpenGL complains because of using for loops. 3.0 target is for D3D9. Since OpenGL doesn't have "shader model" concept, for that we kind of approximate it by increasing the instruction limits etc.
		#pragma glsl
		#pragma vertex vert
		#pragma fragment frag
		
		//#include "UnityCG.cginc"
		uniform float4 _LightColor0; //Define the current light's colour variable
		uniform float4 _Color; 
		uniform float4 _SpecColor;
		uniform float _Shininess;
		uniform float _DiffIntensity;
		uniform float _AmbientIntensity;
		uniform float _SpecularIntensity;
		uniform float _SelfShadowingIntensity;
		uniform float _Attenuation;
		uniform float _UseBlinnInsteadPhong;
		uniform sampler2D _MainTex;
		uniform float4 _MainTex_ST; //to use the TRANSFORM_TEX macro we have to define it with _ST appended
		
		uniform sampler2D _BumpMap;
		uniform float4 _BumpMap_ST;
		
		uniform sampler2D _HeightMap; 
        uniform float4 _HeightMap_ST;
        uniform float _MaxTexCoordOffset;
        
        uniform float _DisplacementSteps;
        uniform float _RefinementSteps;
        uniform float _DisplacementStrength;
		
		struct vertexInput //input to our vertex program
		{
		    float4 vertex : POSITION;
		    float3 normal : NORMAL;
		    float4 tangent : TANGENT; //used to convert light directions to tangent space
		    float4 texcoord : TEXCOORD0;
		};
		
		struct vertexOutput
		{
		    float4 pos : SV_POSITION;
		    float4 posWorld : TEXCOORD0;
		    float2 tex : TEXCOORD1;
		    float3 tangentWorld : TEXCOORD2;  
			float3 normalWorld : TEXCOORD3;
			float3 binormalWorld : TEXCOORD4;
			float3 viewDirWorld : TEXCOORD5; 
   	};
		
		vertexOutput vert (vertexInput input) //to work with the pre-defined macros, the input structure must be called v and it must contain a normal called normal and a tangent called tangent.
		{
		    vertexOutput output;
		    
		    float4x4 modelMatrix = _Object2World;
			float4x4 modelMatrixInverse = _World2Object; // multiplication with unity_Scale.w is unnecessary, because we normalize transformed vectors
		    
		    output.posWorld = mul(modelMatrix, input.vertex);
		    output.pos = mul(UNITY_MATRIX_MVP, input.vertex); //converting to projection space by a predefined matrix (from UnityCg.cginc
		    
		    
		    output.tangentWorld = normalize(float3(mul(modelMatrix, float4(float3(input.tangent), 0.0))));
            output.normalWorld = normalize(mul(float4(input.normal, 0.0), modelMatrixInverse));
            output.binormalWorld = normalize(cross(output.normalWorld, output.tangentWorld) * input.tangent.w); // tangent.w is specific to Unity
		    
		    output.tex = input.texcoord;
		    
            output.viewDirWorld = normalize(_WorldSpaceCameraPos - float3(output.posWorld)); //View Direction in World Space
		    
		    //For displacement mapping:  
		    //float3x3 TBN = float3x3(output.tangentWorld, output.binormalWorld, output.normalWorld);
			//output.eyeVector = mul(TBN, output.viewDirWorld);
		   
		    return output;
		}
		
		float4 frag(vertexOutput input) : COLOR //the actual color calculation
		{
			float3x3 local2WorldTranspose = float3x3(normalize(input.tangentWorld), normalize(input.binormalWorld), normalize(input.normalWorld));
				
			float3 eyeVector = mul(local2WorldTranspose, input.viewDirWorld); 
			//float3 eyeVector = input.eyeVector;
			
			//Displacement Mapping Algorithm: March along the eye ray const-xx steps until we hit the virtual [sunken] surface.
			//For each pixel
			//	1. Start with the original UV coordinates.
			//	2. Run the displacement algorithm; you end up with modified UV coordinates (UV’).
			//	3. Use UV’ for the final color / bump texture lookups for this projection.
			
			float step = 1.0f / _DisplacementSteps; // the distance of the path we walk with every iteration
			float2 dd_texels_max = -eyeVector.xy * _DisplacementStrength; //influence the displacement mapping by a strength factor
			float2 dUV_max = 1.0/1024.0 * dd_texels_max;
			float2 dUV = dUV_max / _DisplacementSteps; // the delta UV step which the texture lookup is adjusted to in each iteration
			
			float prev_hit = 0; //is used to determine if the previous iteration led to a hit
			float h = 1.0; // the current height used in the iteration
			float hit_h = 0; // the final height at which we hit the surface
			
			float2 uv = input.tex.xy; //these are the uv coords we're adaptively modifying 
		
			for (int i = 0; i < _DisplacementSteps; ++i) // determine the inter-texel occlusion silhouette
			{
				h  -= step; // walk 1 step along the path
				uv += dUV;  // adjust the UV coordinate by the delta UV
				float h_tex = tex2D(_HeightMap, _HeightMap_ST.xy * uv + _HeightMap_ST.zw).r; // sample height map at current UV coordinate
				
				//determine if this step is the first hit:
				float is_first_hit = saturate((h_tex - h - prev_hit)*4999999); // to avoid an if statement, this term is used instead of: "if ((h_tex < h) && !prev_hit)"
				hit_h += is_first_hit * h; // in case of a hit, remember the height
				prev_hit += is_first_hit; 	  // in case of a hit, prev_hit will be incremented, which means that it's not zero anymore (which compares to false) and the above expression will always lead to is_first_hit == false
			}
			
			//move to the step BEFORE the hit and start refinement with smaller steps from there
			h = hit_h + step; // start 1 step before the first hit
			uv = input.tex + dUV_max * (1-h); // adjust UV coordinate according to the position 1 step before the 'big' hit
			
			// start refinement with smaller steps			
			dUV = dUV / _RefinementSteps; // further refine the delta UV step which the texture lookup is adjusted to in each iteration
			step = step / _RefinementSteps; // further refine the distance of the path we walk with every iteration by the number of RefinementSteps
			
			//set back all variables used in the iteration
			prev_hit = 0;
			hit_h = 0;
			

			for(int j = 0; j < _RefinementSteps; ++j) //determine the more accurate intersection point to get the refined UV coordinate
			{
				h  -= step; // walk 1 step along the path
				uv += dUV;  // adjust the UV coordinate by the delta UV
				float h_tex = tex2D(_HeightMap, _HeightMap_ST.xy * uv + _HeightMap_ST.zw).r; // sample height map at current UV coordinate
				
				//determine if this step is the first hit:
				float is_first_hit = saturate((h_tex - h - prev_hit)*4999999); // to avoid an if statement, this term is used instead of: "if ((h_tex < h) && !prev_hit)"
				hit_h += is_first_hit * h; // in case of a hit, save the height
				prev_hit += is_first_hit;     // in case of a hit, prev_hit will be incremented, which means that it's not zero anymore (which compares to false) and the above expression will always lead to is_first_hit == false
			}
			
			// assuming the two points in the second iteration only covered one texel, we can now interpolate between the heights at those two points and get the EXACT intersection point. 
			float h1 = hit_h - step;
			float h2 = hit_h;
			
			float v1 = tex2D(_HeightMap, _HeightMap_ST.xy * (input.tex.xy + dUV_max * (1-h1)) + _HeightMap_ST.zw).r; //sample height value at h1
			float v2 = tex2D(_HeightMap, _HeightMap_ST.xy * (input.tex.xy + dUV_max * (1-h2)) + _HeightMap_ST.zw).r; //sample height value at h2
			 
			float t_interp = saturate((v1-h1)/(h2+v1-h1-v2) - 1);
			hit_h = (h1 + t_interp*(h2-h1)); //the final, interpolated height value
			
			input.tex.xy = input.tex.xy + dUV_max* (1 - hit_h); // sample the final UV coordinate according with the location of the final hit from the displacement calculation
			
			//we now have the displaced texel coordinate and can use it for further operations
			
			float4 textureColor = tex2D(_MainTex, _MainTex_ST.xy * input.tex.xy + _MainTex_ST.zw);  // color of the pixel as specified in the texture
			float4 encodedNormal = tex2D(_BumpMap, _BumpMap_ST.xy * input.tex.xy + _BumpMap_ST.zw); // sample the normal from the bump map 
			float3 localCoords = float3(2.0 * encodedNormal.ag - float2(1.0), 0.0);
			localCoords.z = sqrt(1.0 - dot(localCoords, localCoords)); // approximation without sqrt: localCoords.z = 1.0 - 0.5 * dot(localCoords, localCoords);
			
			float3 normalDirection = normalize(mul(localCoords, local2WorldTranspose)); //our final normal vector in world space
			
			float3 viewDirection = normalize(_WorldSpaceCameraPos - float3(input.posWorld));
			
			float attenuation;
			float3 lightDirection;
			
			if (0.0 == _WorldSpaceLightPos0.w) // directional light?
			{
				attenuation = 1.0; // no attenuation
				lightDirection = normalize(float3(_WorldSpaceLightPos0));
			} 
			else // point or spot light
			{
			   float3 vertexToLightSource = float3(_WorldSpaceLightPos0 - input.posWorld);
			   float distance = length(vertexToLightSource);
			   attenuation = 1.0 / (distance * _Attenuation); // linear attenuation 
			   lightDirection = normalize(vertexToLightSource);
			}
			
			float nDotL = dot(normalDirection, lightDirection);
			
			float3 ambientLighting = float3(textureColor) * float3(UNITY_LIGHTMODEL_AMBIENT) * float3(_Color) * _AmbientIntensity; //base color of the ambient light;
			
			float3 diffuseReflection = float3(textureColor) * attenuation * float3(_LightColor0) * float3(_Color) * max(0.0, nDotL) * _DiffIntensity;
			
			float3 specularReflection;
			
			float3 specularReflectionBase = attenuation * float3(_LightColor0) * float3(_SpecColor) * (1.0 - textureColor.a) * _SpecularIntensity;
			   
		    if (_UseBlinnInsteadPhong >= 1.0)
		    {
		   		//Blinn-Phong shading model, uses half vector
		   		float3 halfVec = (lightDirection + viewDirection) / length(lightDirection + viewDirection);
		   		specularReflection = specularReflectionBase * pow(saturate(dot(normalDirection, halfVec)), _Shininess);
		    }
		    else
		    {
		   		//Phong shading model, uses reflection vector
		   		//float3 reflectionVec = normalize(2 * nDotL * n - i.lightDir);
		   		specularReflection = specularReflectionBase * pow(max(0.0, dot(reflect(-lightDirection, normalDirection), viewDirection)), _Shininess);
		    }	
			
			
			// compute self-shadowing term
			float selfShadowing = saturate(4* nDotL) * _SelfShadowingIntensity;
			
			return float4(ambientLighting + selfShadowing *  (diffuseReflection + specularReflection), 1.0);
		}
		
		ENDCG
	}
	
	Pass {   
         Tags { "LightMode" = "ForwardBase" } // rendering of projected shadow
         Offset -1.0, -2.0 // make sure shadow polygons are on top of shadow receiver
 		 Cull Off
 		 Blend OneMinusDstColor One // Soft Additive Blending
 
         CGPROGRAM
        
 		 #pragma target 3.0
         #pragma vertex vert 
         #pragma fragment frag
 
         // User-specified uniforms
         uniform float4 _ShadowColor;
         uniform float _k;
         uniform float4x4 _World2Receiver; // transformation from world coordinates to the coordinate system of the plane, the worldToLocalMatrix of the plane
            
        struct vertexOutput
		{
			float4 pos : SV_POSITION;
		    float d : TEXCOORD0;
		    float z : TEXCOORD1;
		    float4 lightDirection : TEXCOORD2;
   		};
 
         vertexOutput vert(float4 vertexPos : POSITION)
         {
            float4x4 modelMatrix = _Object2World;
            float4x4 modelMatrixInverse = _World2Object * unity_Scale.w; //Multiplication with unity_Scale.w to get correct matrix
            modelMatrixInverse[3][3] = 1.0; //after multiplication, the matrix is good except for the last element, which we manually set to 1
            float4x4 viewMatrix = mul(UNITY_MATRIX_MV, modelMatrixInverse);
 
            float4 lightDirection;

			// point or spot light?
			// Info: LightMode = ForwardBase is executed with the directional light
			//		 LightMode = ForwardAdd  is executed with point light
            if (_WorldSpaceLightPos0.w != 0.0) 
            {
               //Point Light
               lightDirection = normalize(mul(modelMatrix, vertexPos - _WorldSpaceLightPos0));
            } 
            else 
            {
               // directional light
               lightDirection = -normalize(_WorldSpaceLightPos0); //invert the direction to get the direction from vertex to light
            }
 
            float4 vertexInWorldSpace = mul(modelMatrix, vertexPos);
            
            
            //we improve the performance by building a matrix just from the second row (index 1) of the ground plane, because the y coordinate of a matrix-vector product is just the dot product of the second row
            float4 world2ReceiverRow1 = 
               	float4(_World2Receiver[0][1], _World2Receiver[1][1], 
               		   _World2Receiver[2][1], _World2Receiver[3][1]);
            
            // = (_World2Receiver * vertexInWorldSpace).y 
            float distanceOfVertex = dot(world2ReceiverRow1, vertexInWorldSpace); // = height over plane 
               
            // = (_World2Receiver * lightDirection).y
            float lengthOfLightDirectionInY = dot(world2ReceiverRow1, lightDirection); // = length in y direction
            
            //In order to move the point P to the plane, we add a scaled version of L. The scaling factor turns out to be the distance of P to the plane 
            //divided by the length of L in the direction of the normal vector of the plane
                
                
            //only move vertex into the light's direction if it is above the ground plane, otherwise it would result in wrong visibility 
            if (distanceOfVertex > 0.0 && lengthOfLightDirectionInY < 0.0)
            {
               lightDirection = lightDirection * (distanceOfVertex / (-lengthOfLightDirectionInY));
            }
            else
            {
               lightDirection = float4(0.0, 0.0, 0.0, 0.0); // don't move vertex when below plane                
            }
            
            vertexOutput output;
            output.d = -lengthOfLightDirectionInY; //Distance of Light for ESM
            output.z = -lengthOfLightDirectionInY - distanceOfVertex; //Distance of Vertex for ESM
 			output.lightDirection = lightDirection;
 			//UNITY_MATRIX_P = Current projection matrix
 			output.pos = mul(UNITY_MATRIX_P, mul(viewMatrix, vertexInWorldSpace + lightDirection)); //Position of Vertex moved into the light's direction and mapped to Plane (on y=0)
            return output;
         }
 
         float4 frag(vertexOutput input) : COLOR 
         {
         	float4 shadow = _ShadowColor;
         	float4 groundPlaneNormal = float4(0.0, 1.0, 0.0, 0.0); //normal of ground plane
         	float nDotL = dot(groundPlaneNormal, input.lightDirection); //reflect the light on the ground plane accordingly
         	
         	float esmIntensity = exp(_k * input.z) * exp(-_k * input.d); //ESM Soft Shadowing
         	
         	float lightIntensity = nDotL * esmIntensity; //the final light intensity
         	return shadow * lightIntensity;
            
            //return float4(color.r, color.g, color.b, 1.0);
         }
 
         ENDCG 
      }
  }
   // The definition of a fallback shader is commented out during development:
   // Fallback "Specular"
}
		