//When using Vertex and Fragment Shaders instead of Surface shaders, we are responsible for: 
//    Converting the vertex from model space to projection space
//    Creating texture coordinates from model uvs if needed
//    Calculating all of the lighting
//    Applying the lighting colour to the texture colour to get a final pixel colour


Shader "Custom/VertexFragPass2" {
    Properties {
        _MainTex ("Base (RGB)", 2D) = "white" {}
        _Bump ("Bump", 2D) = "bump" {}
        _SpecularColor("Specular Color", Color) = (0.5, 0.25, 0.25, 1.0)
		_Glossiness("Gloss", Range(1.0, 512.0)) = 80.0
    }
    SubShader {
        Tags { "RenderType"="Opaque" }
        LOD 400
 
        Pass {
 			Tags { "LightMode"="ForwardBase" }
            Cull Back
            Lighting On
 
            CGPROGRAM
// Upgrade NOTE: excluded shader from DX11 and Xbox360; has structs without semantics (struct v2f members lightDirection)
#pragma exclude_renderers d3d11 xbox360
            #pragma vertex vert
            #pragma fragment frag
 
            #include "UnityCG.cginc"
            uniform float4 _LightColor0; //Define the current light's colour variable
 
            sampler2D _MainTex;
            sampler2D _Bump;
            float4 _MainTex_ST; //to use the TRANSFORM_TEX macro we have to define it with _ST appended
            float4 _Bump_ST;
            fixed4 _SpecularColor;
			half _Glossiness;
 
            struct a2v //input to our vertex program
            {
                float4 vertex : POSITION;
                float3 normal : NORMAL;
                float4 texcoord : TEXCOORD0;
                float4 tangent : TANGENT; //used to convert light directions to tangent space
 
            };
 
            struct v2f
            {
                float4 pos : POSITION;
                float2 uv : TEXCOORD0;
                float2 uv2 : TEXCOORD1; //texture coordinate of the bump map
                float3 lightDirection; // will be the interpolated light direction vector
 
            };
 
            v2f vert (a2v v) //to work with the pre-defined macros, the input structure must be called v and it must contain a normal called normal and a tangent called tangent.
            {
                v2f o;
                TANGENT_SPACE_ROTATION; //convert object space coordinates to tangent space
 
                o.lightDirection = mul(rotation, ObjSpaceLightDir(v.vertex));
                o.pos = mul( UNITY_MATRIX_MVP, v.vertex); //converting to projection space by a predefined matrix (from UnityCg.cginc
                o.uv = TRANSFORM_TEX (v.texcoord, _MainTex); 
                o.uv2 = TRANSFORM_TEX (v.texcoord, _Bump);
                return o;
            }
 
            float4 frag(v2f i) : COLOR //calculate the color of the interpolated input structure
            {
                float4 c = tex2D (_MainTex, i.uv); 
                float3 n =  UnpackNormal(tex2D (_Bump, i.uv2)); //unpack the normal from it's encoded format in the texture map and use that
 				
                float3 lightColor = UNITY_LIGHTMODEL_AMBIENT.xyz; //base color of the ambient light
 
                float lengthSq = dot(i.lightDirection, i.lightDirection); //how far away our real light is; If this is a directional light then the vector is already normalized so the distance will be 1 (no affect)
                float atten = 1.0 / (1.0 + lengthSq);
                //Angle to the light
                float diff = saturate (dot (n, normalize(i.lightDirection)));  
                lightColor += _LightColor0.rgb * (diff * atten); //add light's color with dependency on the attenuation  and intensity
                c.rgb = lightColor * c.rgb * 2; 
                return c;
 
            }
 
            ENDCG
        }
 
 		Pass {
            Cull Back
            Lighting On
            Tags { "LightMode"="ForwardAdd" }
 			Blend One One
 
            CGPROGRAM
// Upgrade NOTE: excluded shader from DX11 and Xbox360; has structs without semantics (struct v2f members lightDirection)
#pragma exclude_renderers d3d11 xbox360
            #pragma vertex vert
            #pragma fragment frag
 
            #include "UnityCG.cginc"
            uniform float4 _LightColor0; //Define the current light's colour variable
            uniform float4 _SpecularColor; //Define the current light's colour variable
 
            sampler2D _MainTex;
            sampler2D _Bump;
            float4 _MainTex_ST; //to use the TRANSFORM_TEX macro we have to define it with _ST appended
            float4 _Bump_ST;
            
			half _Glossiness;
 
            struct a2v //input to our vertex program
            {
                float4 vertex : POSITION;
                float3 normal : NORMAL;
                float4 texcoord : TEXCOORD0;
                float4 tangent : TANGENT; //used to convert light directions to tangent space
 
            };
 
            struct v2f
            {
                float4 pos : POSITION;
                float2 uv : TEXCOORD0;
                float2 uv2 : TEXCOORD1; //texture coordinate of the bump map
                float3 lightDirection; // will be the interpolated light direction vector
 
            };
 
            v2f vert (a2v v) //to work with the pre-defined macros, the input structure must be called v and it must contain a normal called normal and a tangent called tangent.
            {
                v2f o;
                TANGENT_SPACE_ROTATION; //convert object space coordinates to tangent space
 
                o.lightDirection = mul(rotation, ObjSpaceLightDir(v.vertex));
                o.pos = mul( UNITY_MATRIX_MVP, v.vertex); //converting to projection space by a predefined matrix (from UnityCg.cginc
                o.uv = TRANSFORM_TEX (v.texcoord, _MainTex); 
                o.uv2 = TRANSFORM_TEX (v.texcoord, _Bump);
                return o;
            }
 
            float4 frag(v2f i) : COLOR //calculate the color of the interpolated input structure
            {
                float4 c = tex2D (_MainTex, i.uv); 
                float3 n =  UnpackNormal(tex2D (_Bump, i.uv2)); //unpack the normal from it's encoded format in the texture map and use that
 
                float3 lightColor = float3(0.0f, 0.0f, 0.0f);
 
                float lengthSq = dot(i.lightDirection, i.lightDirection); //how far away our real light is; If this is a directional light then the vector is already normalized so the distance will be 1 (no affect)
                float atten = 1.0 / (1.0 + lengthSq);
                //Angle to the light
                float diff = saturate (dot (n, normalize(i.lightDirection)));  
                lightColor += _SpecularColor.rgb * (diff * atten) * _SpecularColor.a; //add light's color with dependency on the attenuation  and intensity
                c.rgb = lightColor * c.rgb * 2; 
                return c;
 
            }
 
            ENDCG
        }
 
    }
    FallBack "Diffuse"
}