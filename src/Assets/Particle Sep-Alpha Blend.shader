Shader "Particles/Alpha Blended (sep tex)" {
Properties {
	_TintColor ("Tint Color", Color) = (0.5,0.5,0.5,0.5)
	_MainTex ("Particle Texture", 2D) = "white"
	_AlphaTex ("Trans. (Alpha)", 2D) = "white" {}
}

SubShader {
	Tags { "Queue" = "Transparent" }
	Cull Off
	Lighting Off
	ZWrite Off
	AlphaTest Greater .01
	Blend SrcAlpha OneMinusSrcAlpha
	ColorMask RGB
	BindChannels {
		Bind "Color", color
		Bind "Vertex", vertex
		Bind "TexCoord", texcoord
	}
	Pass {
		SetTexture [_MainTex] {
			Combine texture * primary DOUBLE, texture * primary 
		}
		SetTexture [_AlphaTex] {
			combine previous * texture
		}
	}
}
}
