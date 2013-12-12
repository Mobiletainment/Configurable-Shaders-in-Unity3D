Shader "Custom/Particles" {
	Properties {
		_MainTex ("Base (RGB)", 2D) = "white" {}
		_Duration("Duration", Range(0.01, 10.0)) = 1.00
		_DurationRandomness("Duration Randomness", Range(0.01, 10.0)) = 1.00
		_Gravity("Gravity", Range(0.01, 20.0)) = 15.0
		_CurrentTime("Current Time", Range(0.01, 20.0)) = 15.0
		
		
		_StartVelocity("StartVelocity", Range(0.01, 10.0)) = 10.0
		_EndVelocity("EndVelocity", Range(0.01, 10.0)) = 1.00
		_MinColor("Min Color", Color) = (0,0,0,1)
		_MaxColor("Max Color", Color) = (1,1,1,1)
		
		_RotateSpeedX("Rotation Speed X", Range(0.01, 10.0)) = 1.00
		_RotateSpeedY("Rotation Speed Y", Range(0.01, 10.0)) = 1.00
		
		_StartSizeX("Start Size X", Range(0.01, 10.0)) = 1.00
		_StartSizeY("Start Size Y", Range(0.01, 10.0)) = 1.00
		
		_EndSizeX("End Size X", Range(0.01, 10.0)) = 1.00
		_EndSizeY("End Size Y", Range(0.01, 10.0)) = 1.00
		
		_Random("Randoms", Vector) = (1,1,1,1)
			
	}
	SubShader 
	{
		Pass {
			Tags { "RenderType"="Opaque" }
			LOD 200
			
			CGPROGRAM
			#pragma exclude_renderers d3d11 xbox360
	
			#pragma target 3.0
			#pragma glsl
			#pragma vertex ParticleVertexShader
	        #pragma fragment ParticlePixelShader
	
			uniform sampler2D _MainTex;
	
			// The current time, in seconds.
			uniform float _CurrentTime;
			
			
			// Parameters describing how the particles animate.
			uniform float _Duration;
			uniform float _DurationRandomness;
			uniform float3 _Gravity;
			
			uniform float _StartVelocity;
			uniform float _EndVelocity;
			uniform float4 _MinColor;
			uniform float4 _MaxColor;
			
			uniform float4 _Random;
			
			
			// These float2 parameters describe the min and max of a range.
			// The actual value is chosen differently for each particle,
			// interpolating between x and y by some random amount.
			uniform float _RotateSpeedX;
			uniform float _RotateSpeedY;
			
			uniform float _StartSizeX;
			uniform float _StartSizeY;
			
			uniform float _EndSizeX;
			uniform float _EndSizeY;
			
		
			// Vertex shader input structure describes the start position and
			// velocity of the particle, and the time at which it was created,
			// along with some random values that affect its size and rotation.
			struct VertexShaderInput
			{
			    float4 Position : POSITION;
			    float4 Texcoord : TEXCOORD0;
			    float Time : TEXCOORD1;
			    
			};
	
			// Vertex shader output structure specifies the position and color of the particle.
			struct VertexShaderOutput
			{
			    float4 Position : POSITION;
			    float2 TextureCoordinate : TEXCOORD0;
			    float4 Color : TEXCOORD1;
			};
			
			
			// Vertex shader helper for computing the size of a particle.
			float ComputeParticleSize(float randomValue, float normalizedAge)
			{
			    // Apply a random factor to make each particle a slightly different size.
			    float startSize = lerp(_StartSizeX, _StartSizeY, randomValue);
			    float endSize = lerp(_EndSizeX, _EndSizeY, randomValue);
			    
			    // Compute the actual size based on the age of the particle.
			    float size = lerp(startSize, endSize, normalizedAge);
			    
			    // Project the size into screen coordinates.
			    return size * 100;// mul(UNITY_MATRIX_MVP, size);// size * Projection._m11;
			}
			
			
			// Vertex shader helper for computing the color of a particle.
			float4 ComputeParticleColor(float4 projectedPosition, float randomValue, float normalizedAge)
			{
			    // Apply a random factor to make each particle a slightly different color.
			    float4 color = lerp(_MinColor, _MaxColor, randomValue);
			    
			    // Fade the alpha based on the age of the particle. This curve is hard coded
			    // to make the particle fade in fairly quickly, then fade out more slowly:
			    // plot x*(1-x)*(1-x) for x=0:1 in a graphing program if you want to see what
			    // this looks like. The 6.7 scaling factor normalizes the curve so the alpha
			    // will reach all the way up to fully solid.
			    
			    color.a *= normalizedAge * (1-normalizedAge) * (1-normalizedAge) * 6.7;
			   
			    return color;
			}
			
			
			// Vertex shader helper for computing the rotation of a particle.
			float2x2 ComputeParticleRotation(float randomValue, float age)
			{    
			    // Apply a random factor to make each particle rotate at a different speed.
			    float rotateSpeed = lerp(_RotateSpeedX, _RotateSpeedY, randomValue);
			    
			    float rotation = rotateSpeed * age;
			
			    // Compute a 2x2 rotation matrix.
			    float c = cos(rotation);
			    float s = sin(rotation);
			    
			    return float2x2(c, -s, s, c);
			}
			
			
			// Custom vertex shader animates particles entirely on the GPU.
			VertexShaderOutput ParticleVertexShader(VertexShaderInput input)
			{
			    VertexShaderOutput output;
			    
			    // Compute the age of the particle.
			    float age = _CurrentTime - input.Time;
			    
			    // Apply a random factor to make different particles age at different rates.
			    age *= 1 + _Random.x * _DurationRandomness;
			    
			    // Normalize the age into the range zero to one.
			    float normalizedAge = saturate(age / _Duration);
			
			    // Compute the particle position, size, color, and rotation.
			    float3 position = input.Position.xyz;
			    float3 velocity = _StartVelocity;
			    
			    float startVelocity = length(velocity);
			
			    // Work out how fast the particle should be moving at the end of its life,
			    // by applying a constant scaling factor to its starting velocity.
			    float endVelocity = startVelocity * _EndVelocity;
			    
			    // Our particles have constant acceleration, so given a starting velocity
			    // S and ending velocity E, at time T their velocity should be S + (E-S)*T.
			    // The particle position is the sum of this velocity over the range 0 to T.
			    // To compute the position directly, we must integrate the velocity
			    // equation. Integrating S + (E-S)*T for T produces S*T + (E-S)*T*T/2.
			
			    float velocityIntegral = startVelocity * normalizedAge + (endVelocity - startVelocity) * normalizedAge * normalizedAge / 2;
			     
			    position += normalize(velocity) * velocityIntegral * _Duration;
			    
			    // Apply the gravitational force.
			    //position += _Gravity * age * normalizedAge;
			    
			    // Apply the camera view and projection transforms.
			    
			    float4x4 modelMatrix = _Object2World;
			    //output.Position = mul(UNITY_MATRIX_MVP, float4(position, 1.0));
				output.Position = mul(UNITY_MATRIX_MVP, float4(input.Position.xyz, 1.0));
			
			    float size = ComputeParticleSize(_Random.y, normalizedAge);
			    float2x2 rotation = ComputeParticleRotation(_Random.w, age);
			
			    //output.Position.xy += mul(float2(_CornerX, _CornerY), rotation) * size * 1.0; //ViewportScale;
			    
			    output.Color = ComputeParticleColor(output.Position, _Random.z, normalizedAge);
			    output.TextureCoordinate = input.Texcoord;
			    
			    return output;
			}
			
			
			// Pixel shader for drawing particles.
			float4 ParticlePixelShader(VertexShaderOutput input) : COLOR0
			{
			    return tex2D(_MainTex, float2(input.TextureCoordinate)) * input.Color;
			}
	
	
			ENDCG
	 }
 
	}
	FallBack "Diffuse"
}
