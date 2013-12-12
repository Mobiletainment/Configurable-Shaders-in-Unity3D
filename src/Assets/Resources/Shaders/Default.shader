//When using Vertex and Fragment Shaders instead of Surface shaders, we are responsible for: 
//    Converting the vertex from model space to projection space
//    Creating texture coordinates from model texs if needed
//    Calculating all of the lighting

Shader "Custom/DefaultShader" {
    Properties {
        _MainTex ("Base (RGB)", 2D) = "white" {}
        _Color ("Overall Diffuse Color Filter", Color) = (1,1,1,1)
        _SpecColor("Specular Color", Color) = (1.0, 1.0, 1.0, 1.0)
		_Shininess("Shininess", Range(1.0, 50.0)) = 10.0
		_SpecularIntensity("Specular Light Intensity", Range(0.0, 1.0)) = 1.0
		_DiffIntensity("Diffuse Light Intensity", Range(0.0, 1.0)) = 1.0
		_AmbientIntensity("Ambient Light Intensity", Range(0.0, 1.0)) = 1.0
		_SelfShadowingIntensity("Self Shadowing Light Intensity", Range(0.0, 1.0)) = 1.0
		_Attenuation("Attenuation Point Light", Range(0.01, 1.0)) = 0.01
		_UseBlinnInsteadPhong("Use Blinn instead Phong Shading", float) = 0.0
    }
    SubShader {
    
        Pass {
 			Tags { "LightMode"="ForwardBase" } // pass for ambient light and first light source
            Cull Back
            
            CGPROGRAM
// Upgrade NOTE: excluded shader from DX11 and Xbox360; has structs without semantics (struct vertexOutput members lightDir,posWorld)
#pragma exclude_renderers d3d11 xbox360

			#pragma target 3.0
			#pragma vertex vert
            #pragma fragment frag
 
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
            uniform float4 _MainTex_ST; // provides tiling and offset parameters of property "_MainTex"
            
 			//The naming of variables is adopted to the ones used in the Unity shaders, in order to be compliant if a fallback shader is used 
            struct vertexInput //input to our vertex program
            {
                float4 vertex : POSITION;
                float3 normal : NORMAL;
                float4 texcoord : TEXCOORD0;
                float4 tangent : TANGENT; //used to convert light directions to tangent space
 
            };
 
            struct vertexOutput //the output of our vertex shader calculations, severs as input to our fragment shader
            {
                float4 pos : SV_POSITION;
                float4 posWorld : TEXCOORD0;
                float2 tex : TEXCOORD1;
                float2 tex2 : TEXCOORD2; //texture coordinate of the bump map (packed normal vector)
                float3 normalDir : TEXCOORD3;
                float3 tangentWorld : TEXCOORD4;  
            	float3 normalWorld : TEXCOORD5;
            	float3 binormalWorld : TEXCOORD6;
            };
 
            vertexOutput vert (vertexInput input)
            {
                vertexOutput output;
                
                float4x4 modelMatrix = _Object2World;
            	float4x4 modelMatrixInverse = _World2Object; // multiplication with unity_Scale.w is unnecessary, because we normalize transformed vectors
                
                output.posWorld = mul(modelMatrix, input.vertex);
                output.pos = mul(UNITY_MATRIX_MVP, input.vertex); //converting to projection space by a predefined matrix (from UnityCg.cginc
                
                output.normalDir = normalize(float3(mul(float4(input.normal, 0.0), modelMatrixInverse)));
                
                output.tex = input.texcoord;
                output.tex2 = input.texcoord;
                
                return output;
            }
 
            float4 frag(vertexOutput input) : COLOR //the actual color calculation
            {
            	float3 normalDirection = normalize(input.normalDir);
            	float3 viewDirection = normalize(_WorldSpaceCameraPos - float3(input.posWorld));
	
				float3 lightDirection;
            
            	float4 textureColor = tex2D(_MainTex, float2(input.tex)); //color of the pixel as specified in the texture
				float attenuation;

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
            uniform float4 _MainTex_ST; // provides tiling and offset parameters of property "_MainTex"
            
 			//The naming of variables is adopted to the ones used in the Unity shaders, in order to be compliant if a fallback shader is used 
            struct vertexInput //input to our vertex program
            {
                float4 vertex : POSITION;
                float3 normal : NORMAL;
                float4 texcoord : TEXCOORD0;
                float4 tangent : TANGENT; //used to convert light directions to tangent space
 
            };
 
            struct vertexOutput //the output of our vertex shader calculations, severs as input to our fragment shader
            {
                float4 pos : SV_POSITION;
                float4 posWorld : TEXCOORD0;
                float2 tex : TEXCOORD1;
                float2 tex2 : TEXCOORD2; //texture coordinate of the bump map (packed normal vector)
                float3 normalDir : TEXCOORD3;
                float3 tangentWorld : TEXCOORD4;  
            	float3 normalWorld : TEXCOORD5;
            	float3 binormalWorld : TEXCOORD6;
            };
 
            vertexOutput vert (vertexInput input)
            {
                vertexOutput output;
                
                float4x4 modelMatrix = _Object2World;
            	float4x4 modelMatrixInverse = _World2Object; // multiplication with unity_Scale.w is unnecessary, because we normalize transformed vectors
                
                output.posWorld = mul(modelMatrix, input.vertex);
                output.pos = mul(UNITY_MATRIX_MVP, input.vertex); //converting to projection space by a predefined matrix (from UnityCg.cginc
                
                output.normalDir = normalize(float3(mul(float4(input.normal, 0.0), modelMatrixInverse)));
                
                output.tex = input.texcoord;
                output.tex2 = input.texcoord;
                
                return output;
            }
 
            float4 frag(vertexOutput input) : COLOR //the actual color calculation
            {
            	float3 normalDirection = normalize(input.normalDir);
            	float3 viewDirection = normalize(_WorldSpaceCameraPos - float3(input.posWorld));
	
				float3 lightDirection;
            
            	float4 textureColor = tex2D(_MainTex, float2(input.tex)); //color of the pixel as specified in the texture
				float attenuation;

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
	 
	            float nDotL = saturate(dot(normalDirection, lightDirection));
	 
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
   }
   // The definition of a fallback shader should be commented out 
   // during development:
   // Fallback "Specular"
}