//When using Vertex and Fragment Shaders instead of Surface shaders, we are responsible for:
//    Converting the vertex from model space to projection space
//    Creating texture coordinates from model uvs if needed
//    Calculating all of the lighting

//Unity built-in uniforms: http://docs.unity3d.com/Documentation/Components/SL-BuiltinValues.html

Shader "Custom/HeightMapShader" {
   Properties {
   	  _MainTex ("Base (RGB)", 2D) = "white" {} // By default we use the built-in texture "white"  

      _BumpMap ("Normal Map", 2D) = "bump" {}
      _Color ("Diffuse Material Color", Color) = (1,1,1,1) 
      _SpecularColor ("Specular Material Color", Color) = (1,1,1,1) 
      _Glossiness ("Shininess", Float) = 0.7
      
      _SpecularIntensity("Specular Light Intensity", Range(0.0, 1.0)) = 1.0
	  _DiffIntensity("Diffuse Light Intensity", Range(0.0, 1.0)) = 1.0
		_AmbientIntensity("Ambient Light Intensity", Range(0.0, 1.0)) = 1.0
		_SelfShadowingIntensity("Self Shadowing Light Intensity", Range(0.0, 1.0)) = 1.0
		_Attenuation("Attenuation Point Light", Range(0.0, 10.0)) = 1.0
		_UseBlinnInsteadPhong("Use Blinn instead Phong Shading", float) = 0.0

		//Height Map
		_HeightMap ("Heightmap (R)", 2D) = "grey" {}
		_HeightmapStrength ("Heightmap Strength", Float) = 1.0
		_HeightmapDimX ("Heightmap Width", Float) = 2048
		_HeightmapDimY ("Heightmap Height", Float) = 2048
		
		_DisplacementSteps("Displacement Steps", Range(0.0, 1.0)) = 1.0
   }
   SubShader {
      Pass {      
         Tags { "LightMode" = "ForwardBase" } // make sure that all uniforms are correctly set
            // pass for ambient light and first light source
 
         CGPROGRAM
 	     #pragma target 3.0
         #pragma vertex vert  
         #pragma fragment frag  
 
         // User-specified properties
         uniform sampler2D _MainTex;    
         uniform float4 _MainTex_ST; // tiling and offset parameters of property  
         uniform sampler2D _BumpMap;    
         uniform float4 _BumpMap_ST;
         uniform float4 _Color; 
         uniform float4 _SpecularColor; 
         uniform float _Glossiness;

 		#include "UnityCG.cginc"
         //uniform float4 unity_Scale; // w = 1/scale; see _World2Object
         // uniform float3 _WorldSpaceCameraPos;
         // uniform float4x4 _Object2World; // model matrix
         // uniform float4x4 _World2Object; // inverse model matrix 
            // (all but the bottom-right element have to be scaled 
            // with unity_Scale.w if scaling is important) 
         //uniform float4 _WorldSpaceLightPos0; 
            // position or direction of light source
         uniform float4 _LightColor0; 
            // color of light source (from "Lighting.cginc")
 
         struct vertexInput
         {
            float4 vertex : POSITION; // position in object coordinates (local or model cordinates)
            float3 normal : NORMAL; // surface normal vector (in object coordinates)
            float4 tangent : TANGENT; // vector orthogonal to the surface normal, only the first three components of tangent represent the tangent direction. The scaling and the fourth component are set in a specific way, which is mainly useful for parallax mapping 
            float4 texcoord : TEXCOORD0; // texture UV between 0 and 1
            float4 texcoord1 : TEXCOORD1; // texture UV between 0 and 1
            fixed4 color : COLOR; // color
         };
         
         struct vertexOutput
         {
            float4 pos : SV_POSITION;
            float4 posWorld : TEXCOORD0;
               // position of the vertex (and fragment) in world space 
            float4 tex : TEXCOORD1;
            float3 tangentWorld : TEXCOORD2;  
            float3 normalWorld : TEXCOORD3;
            float3 binormalWorld : TEXCOORD4;
         };
 
         vertexOutput vert(vertexInput input) 
         {
            vertexOutput output; 
            float4x4 modelMatrix = _Object2World;
            float4x4 modelMatrixInverse = _World2Object; 
               // unity_Scale.w is unnecessary 
 
            output.tangentWorld = normalize(float3(
               mul(modelMatrix, float4(float3(input.tangent), 0.0))));
            output.normalWorld = normalize(
               mul(float4(input.normal, 0.0), modelMatrixInverse));
            output.binormalWorld = normalize(
               cross(output.normalWorld, output.tangentWorld) 
               * input.tangent.w); // tangent.w is specific to Unity
 
            output.posWorld = mul(modelMatrix, input.vertex);
            output.tex = input.texcoord;
            output.pos = mul(UNITY_MATRIX_MVP, input.vertex);
            return output;
         }
 
         float4 frag(vertexOutput input) : COLOR
         {
            // in principle we have to normalize tangentWorld,
            // binormalWorld, and normalWorld again; however, the 
            // potential problems are small since we use this 
            // matrix only to compute "normalDirection", 
            // which we normalize anyways
 
            float4 encodedNormal = tex2D(_BumpMap, 
               _BumpMap_ST.xy * input.tex.xy + _BumpMap_ST.zw);
            float3 localCoords = 
                float3(2.0 * encodedNormal.ag - float2(1.0), 0.0);
            localCoords.z = sqrt(1.0 - dot(localCoords, localCoords));
               // approximation without sqrt:  localCoords.z = 
               // 1.0 - 0.5 * dot(localCoords, localCoords);
 
            float3x3 local2WorldTranspose = float3x3(
               input.tangentWorld, 
               input.binormalWorld, 
               input.normalWorld);
            float3 normalDirection = 
               normalize(mul(localCoords, local2WorldTranspose));
 
            float3 viewDirection = normalize(
               _WorldSpaceCameraPos - float3(input.posWorld));
            float3 lightDirection;
            float attenuation;
 
            if (0.0 == _WorldSpaceLightPos0.w) // directional light?
            {
               attenuation = 1.0; // no attenuation
               lightDirection = 
                  normalize(float3(_WorldSpaceLightPos0));
            } 
            else // point or spot light
            {
               float3 vertexToLightSource = 
                  float3(_WorldSpaceLightPos0 - input.posWorld);
               float distance = length(vertexToLightSource);
               attenuation = 1.0 / distance; // linear attenuation 
               lightDirection = normalize(vertexToLightSource);
            }
 
            float3 ambientLighting = 
               float3(UNITY_LIGHTMODEL_AMBIENT) * float3(_Color);
 
            float3 diffuseReflection = 
               attenuation * float3(_LightColor0) * float3(_Color)
               * max(0.0, dot(normalDirection, lightDirection));
 
            float3 specularReflection;
            if (dot(normalDirection, lightDirection) < 0.0) 
               // light source on the wrong side?
            {
               specularReflection = float3(0.0, 0.0, 0.0); 
                  // no specular reflection
            }
            else // light source on the right side
            {
               specularReflection = attenuation * float3(_LightColor0) 
                  * float3(_SpecularColor) * pow(max(0.0, dot(
                  reflect(-lightDirection, normalDirection), 
                  viewDirection)), _Glossiness);
            }
 
            return float4(ambientLighting + diffuseReflection 
               + specularReflection, 1.0);
         }
 
         ENDCG
      }
 
      Pass {      
         Tags { "LightMode" = "ForwardAdd" } 
            // pass for additional light sources
         Blend One One // additive blending 
 
         CGPROGRAM
 		 #pragma target 3.0
         #pragma vertex vert  
         #pragma fragment frag  
 
         // User-specified properties
         uniform sampler2D _BumpMap;    
         uniform float4 _BumpMap_ST;
         uniform float4 _Color; 
         uniform float4 _SpecularColor; 
         uniform float _Glossiness;
 
         #include "UnityCG.cginc"
         uniform float4 _LightColor0; 
            // color of light source (from "Lighting.cginc")
 
         struct vertexInput {
            float4 vertex : POSITION;
            float4 texcoord : TEXCOORD0;
            float3 normal : NORMAL;
            float4 tangent : TANGENT;
         };
         struct vertexOutput {
            float4 pos : SV_POSITION;
            float4 posWorld : TEXCOORD0;
               // position of the vertex (and fragment) in world space 
            float4 tex : TEXCOORD1;
            float3 tangentWorld : TEXCOORD2;  
            float3 normalWorld : TEXCOORD3;
            float3 binormalWorld : TEXCOORD4;
         };
 
         vertexOutput vert(vertexInput input) 
         {
            vertexOutput output;
 
            float4x4 modelMatrix = _Object2World;
            float4x4 modelMatrixInverse = _World2Object; 
               // unity_Scale.w is unnecessary
 
            output.tangentWorld = normalize(float3(
               mul(modelMatrix, float4(float3(input.tangent), 0.0))));
            output.normalWorld = normalize(
               mul(float4(input.normal, 0.0), modelMatrixInverse));
            output.binormalWorld = normalize(
               cross(output.normalWorld, output.tangentWorld) 
               * input.tangent.w); // tangent.w is specific to Unity
 
            output.posWorld = mul(modelMatrix, input.vertex);
            output.tex = input.texcoord;
            output.pos = mul(UNITY_MATRIX_MVP, input.vertex);
            return output;
         }
 
         float4 frag(vertexOutput input) : COLOR
         {
            // in principle we have to normalize tangentWorld,
            // binormalWorld, and normalWorld again; however, the  
            // potential problems are small since we use this 
            // matrix only to compute "normalDirection", 
            // which we normalize anyways
 
            float4 encodedNormal = tex2D(_BumpMap, 
               _BumpMap_ST.xy * input.tex.xy + _BumpMap_ST.zw);
            float3 localCoords = 
                float3(2.0 * encodedNormal.ag - float2(1.0), 0.0);
            localCoords.z = sqrt(1.0 - dot(localCoords, localCoords));
               // approximation without sqrt:  localCoords.z = 
               // 1.0 - 0.5 * dot(localCoords, localCoords);
 
            float3x3 local2WorldTranspose = float3x3(
               input.tangentWorld,
               input.binormalWorld, 
               input.normalWorld);
            float3 normalDirection = 
               normalize(mul(localCoords, local2WorldTranspose));
 
            float3 viewDirection = normalize(
               _WorldSpaceCameraPos - float3(input.posWorld));
            float3 lightDirection;
            float attenuation;
 
            if (0.0 == _WorldSpaceLightPos0.w) // directional light?
            {
               attenuation = 1.0; // no attenuation
               lightDirection = 
                  normalize(float3(_WorldSpaceLightPos0));
            } 
            else // point or spot light
            {
               float3 vertexToLightSource = 
                  float3(_WorldSpaceLightPos0 - input.posWorld);
               float distance = length(vertexToLightSource);
               attenuation = 1.0 / distance; // linear attenuation 
               lightDirection = normalize(vertexToLightSource);
            }
 
            float3 diffuseReflection = 
               attenuation * float3(_LightColor0) * float3(_Color)
               * max(0.0, dot(normalDirection, lightDirection));
 
            float3 specularReflection;
            if (dot(normalDirection, lightDirection) < 0.0) 
               // light source on the wrong side?
            {
               specularReflection = float3(0.0, 0.0, 0.0); 
                  // no specular reflection
            }
            else // light source on the right side
            {
               specularReflection = attenuation * float3(_LightColor0) 
                  * float3(_SpecularColor) * pow(max(0.0, dot(
                  reflect(-lightDirection, normalDirection), 
                  viewDirection)), _Glossiness);
            }
 
            return float4(diffuseReflection + specularReflection, 1.0);
         }
 
         ENDCG
      }
 
   }
}