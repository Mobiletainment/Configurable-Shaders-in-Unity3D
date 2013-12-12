Shader "Custom/MyShader" {
	Properties {
		_MainTex ("Base (RGB)", 2D) = "white" {}
		_BumpMap ("Bumpmap", 2D) = "bump" {}
		_BumpMapEnabled("Bumpmapping Enabled", float) = 1.0
		_AmbientColor ("Ambient Color", Color) = (0.1, 0.1, 0.1, 1.0)
		_SpecularColor("Specular Color", Color) = (0.12, 0.31, 0.47, 1.0)
		_Glossiness("Gloss", Range(1.0, 512.0)) = 80.0
	}
	SubShader {
		Tags { "RenderType"="Opaque" }
		LOD 400
		
		CGPROGRAM
		//#pragma surface surf Lambert

		// Custom lighting function that uses a texture ramp based on angle between light direction and normal
		// Will map to LightingRampSpecular, Unity needs to Lighting prefix
		#pragma surface surf RampSpecular

		sampler2D _MainTex;
		sampler2D _BumpMap;
		
		//fixed = low precision (11 bits, the range of -2.0 to +2.0 and 1/256th precision)
		//half  = medium precision (16 bits, the range of -60000 to +60000 and 3.3 decimal digits of precision)
		fixed4 _AmbientColor; 
		fixed4 _SpecularColor;
		half _Glossiness;
		half _BumpMapEnabled;

		struct Input {
			float2 uv_MainTex;
			float2 uv_BumpMap;
		};

		void surf (Input IN, inout SurfaceOutput o)
		{
			//half4 c = tex2D (_MainTex, IN.uv_MainTex);
			fixed4 c = tex2D (_MainTex, IN.uv_MainTex);
			o.Albedo = c.rgb;
			o.Alpha = c.a;
			
			if (_BumpMapEnabled == 1.0f)
				o.Normal = UnpackNormal(tex2D(_BumpMap, IN.uv_BumpMap));
		}
		
		inline fixed4 LightingRampSpecular (SurfaceOutput s, fixed3 lightDir, fixed3 viewDir, fixed attenuation)
		{
			//Ambient Light
			fixed3 ambient = s.Albedo * _AmbientColor.rgb * _AmbientColor.a; //alpha crucial for enabling/disabling
			
			//Diffuse
			//Get the direction of the light source related to the normal of character
			fixed NdotL = saturate(dot(s.Normal, lightDir));
			fixed3 diffuse = s.Albedo * _LightColor0.rgb * NdotL;
			
			//Specular - Gloss
			fixed3 h = normalize (lightDir + viewDir); // Get the normalized vector of the lighting direction and view direction
			float nh = saturate(dot (s.Normal, h)); //Make sure that the return number isn't lower than 0 or greater than 1
            float specPower = pow (nh, _Glossiness);
            fixed3 specular = _LightColor0.rgb * specPower * _SpecularColor.rgb * _SpecularColor.a; //disabling Specular by setting alpha to 0
            
            //Result
           fixed4 c;
           c.rgb = (ambient + diffuse + specular) * (attenuation * 2); //multiply the lighting attenuation value doubled, to get the smooth specular effect 
           c.a = s.Alpha + (_LightColor0.a * _SpecularColor.a * specPower * attenuation);
           
           return c;
		}
		
		ENDCG
	} 
	FallBack "Diffuse"
}
