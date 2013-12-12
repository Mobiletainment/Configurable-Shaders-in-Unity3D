//When using Vertex and Fragment Shaders instead of Surface shaders, we are responsible for:
//    Converting the vertex from model space to projection space
//    Creating texture coordinates from model uvs if needed
//    Calculating all of the lighting

Shader "Custom/VertexFragBumpDisplacement" {
    Properties {
        _MainTex ("Base (RGB)", 2D) = "white" {}
        _Bump ("Bump", 2D) = "bump" {}
        _SpecularColor("Specular Color", Color) = (1.0, 1.0, 1.0, 1.0)
		_Glossiness("Glossiness", Range(1.0, 10.0)) = 4.0
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
        Tags { "RenderType"="Opaque" }
        LOD 400

        Pass {
 			Tags { "LightMode"="ForwardBase" }
            Cull Back
            Lighting On

            CGPROGRAM
// Upgrade NOTE: excluded shader from DX11 and Xbox360; has structs without semantics (struct v2f members lightDir)
#pragma exclude_renderers d3d11 xbox360
		#pragma target 3.0
            #pragma vertex vert
            #pragma fragment frag

            #include "UnityCG.cginc"
            uniform float4 _LightColor0; //Define the current light's colour variable
            uniform float4 _SpecularColor;
            float _Glossiness;
 			float _DiffIntensity;
 			float _AmbientIntensity;
 			float _SpecularIntensity;
 			float _SelfShadowingIntensity;
 			float _Attenuation;
 			float _UseBlinnInsteadPhong;
            sampler2D _MainTex;
            sampler2D _Bump;
            sampler2D _HeightMap;
            float4 _MainTex_ST; //to use the TRANSFORM_TEX macro we have to define it with _ST appended
            float4 _Bump_ST;
			float4 _HeightMapST;
			float _HeightmapStrength, _HeightmapDimX, _HeightmapDimY;

			float _DisplacementSteps;

            struct a2v //input to our vertex program
            {
                float4 vertex : POSITION;
                float4 texcoord : TEXCOORD0;
                float3 normal : NORMAL;
                float3 tangent : TANGENT; //used to convert light directions to tangent space
		    };

            struct v2f
            {
                float4 pos : POSITION;
                float2 uv : TEXCOORD0;
                float2 uv2 : TEXCOORD1; //texture coordinate of the bump map (packed normal vector)
                float3 lightDir; // will be the interpolated light direction vector
 				float4 posWorld;
 				
 				float3 normal;
 				float3 tangent;
    			float3 viewDirection;
				float3 tangentEyeVector;
            };

            v2f vert (a2v v) //to work with the pre-defined macros, the input structure must be called v and it must contain a normal called normal and a tangent called tangent.
            {
                v2f o;
                //TANGENT_SPACE_ROTATION; //convert object space coordinates to tangent space

                o.lightDir = mul(rotation, ObjSpaceLightDir(v.vertex));
                o.pos = mul( UNITY_MATRIX_MVP, v.vertex); //converting to projection space by a predefined matrix (from UnityCg.cginc
                o.uv = TRANSFORM_TEX (v.texcoord, _MainTex);
                o.uv2 = TRANSFORM_TEX (v.texcoord, _Bump);
                //o.uv2 = (v.normal + 1) * 0.5; //pack normal
                
                o.tangent = normalize(v.tangent);
                float3 binormal = normalize(cross(v.normal, v.tangent));
                float3x3 TBN = float3x3(v.tangent, binormal, v.normal);
				o.tangentEyeVector = mul(TBN, o.lightDir);
				//o.normal = mul((float3x3)_Object2World, v.normal);
				//o.normal = normalize(mul(float4(v.normal, 0.0), _Object2World));
                o.normal = normalize(v.normal);
                o.posWorld = mul(_Object2World, v.vertex);
                return o;
            }

            float4 frag(v2f i) : COLOR //the actual color calculation
            {
            	float3 lightDir = normalize(i.lightDir);
                float3 viewDir = normalize(_WorldSpaceCameraPos.xyz - i.posWorld.xyz);
				float3 normal = UnpackNormal(tex2D (_Bump, i.uv2)); //unpack the normal (*2 -1) from it's encoded format in the texture map
				float4 c; 				

				//Height Mapping:
				//given a normal, the height map is sampled in 5 places: the current pixel and the 4-connected pixels surrounding it.
				//these values form an "offset vector" that is added to the normal,


				float  h     = 1.0; //height currently checked
				float2 dUV   = -( ( i.tangentEyeVector.xy / (float)_DisplacementSteps) / 15.0f); //displacement depth, amount uv coords changed per loop iteration
				float  prev_hit = 0; //stores if we already had a hit or not
				float  hit_h = 0; //height we hit the surface
				float  diff  = 1.0f / (float)_DisplacementSteps; //amount substracted from height per step
				float2 uv    = i.uv; //uv coords for each step
				int    hit_step = 0; //the step we hit surface

				for (int i = 0; i < _DisplacementSteps; ++i) 
				{
					h  -= diff;
					uv += dUV;
					float h_tex = tex2D(_HeightMap, uv).x;
					float is_first_hit = saturate((h_tex - h - prev_hit)*4999999); // equivalent to: if ( (h_tex < h) && !prev_hit )
					hit_h    += is_first_hit * h; 
					hit_step += is_first_hit * i;
					prev_hit += is_first_hit;
				}
			
				// change UV coords according to our hit
				c = tex2D (_MainTex, uv + dUV * (hit_step+1)); //color of the pixel as specified in the texture
            
				
			

				float3 ambient = UNITY_LIGHTMODEL_AMBIENT.xyz * _AmbientIntensity; //base color of the ambient light

               	//Point Light Attenuation
				//Get the direction of the light source related to the normal of character
				float lengthSq = dot(lightDir, lightDir) * _Attenuation; //how far away our real light is; If this is a directional light then the vector is already normalized so the distance will be 1 (no affect)
               // float atten = (1.0 / (1.0 + lengthSq)); //attenuation (Abschwächung) of the light -> quadratische abhnahme

                //Diffuse
                //Angle to the light
                float nDotL = saturate (dot (normal, lightDir));
                float3 diffuse = (_LightColor0.rgb * nDotL) * _DiffIntensity; //add light's color with dependency on the attenuation  and intensity

             //   float3 specular; //not yet assigned, because we can switch between Phong and Blinn Model

            //Blinn-Phong shading model, uses half vector
                //float3 halfVec = (i.LightDir + viewDir) / length(i.LightDir + viewDir);
               	//specular = pow(saturate(dot(n, halfVec)), _Glossiness); //float3(0.0, 1.0, 0.0);
             // float3 specular = pow(saturate(dot(normal, (lightDir + viewDir) / length(lightDir+viewDir))), _Glossiness) * _SpecularIntensity; //float3(0.0, 1.0, 0.0);

			//Phong shading model, uses reflection vector
				//float3 reflectionVec = normalize(2 * nDotL * n - i.lightDir);  //   reflect(i.lightDir, n); //R = 2 * (N.L) * N - L
				//specular = pow(saturate(dot(reflectionVec, viewDir)), _Glossiness) * _SpecularIntensity;
				//else specular = pow(saturate(dot(reflect(i.lightDir, n), viewDir)), _Glossiness) * _SpecularIntensity;
              //  else specular = pow(saturate(dot(normalize(2 * nDotL * normal - lightDir), viewDir)), _Glossiness) * _SpecularIntensity;

                // compute self-shadowing term
				//float shadow = saturate(4* nDotL) * _SelfShadowingIntensity;


                float3 lightColor = ambient + (diffuse ); // * atten; //add light's color with dependency on the attenuation  and intensity
                c.rgb = c.rgb * (lightColor * 2);
                return c;

            }

            ENDCG
        }

    }
    FallBack "Diffuse"
}