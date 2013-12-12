//The first pass of the shader renders the shadow-casting object
//the second pass renders the projected shadow

Shader "Custom/Cg planar shadow" {
   Properties {
      _Color ("Object's Color", Color) = (0,1,0,1)
      _ShadowColor ("Shadow's Color", Color) = (0,0,0,1)
   }
   SubShader {
      Pass {      
         Tags { "LightMode" = "ForwardBase" } // rendering of object
 
         CGPROGRAM
 
         #pragma target 3.0
         #pragma vertex vert 
         #pragma fragment frag
         
 
         // User-specified properties
         uniform float4 _Color; 
 
         float4 vert(float4 vertexPos : POSITION) : SV_POSITION 
         {
            return mul(UNITY_MATRIX_MVP, vertexPos);
         }
 
         float4 frag(void) : COLOR
         {
            return _Color; 
         }
 
         ENDCG 
      }
 
      Pass {   
         Tags { "LightMode" = "ForwardBase" } // rendering of projected shadow
         Offset -1.0, -2.0 // make sure shadow polygons are on top of shadow receiver
 
         CGPROGRAM
 
 		 #pragma target 3.0
         #pragma vertex vert 
         #pragma fragment frag
 
         // User-specified uniforms
         uniform float4 _ShadowColor;
         uniform float4x4 _World2Receiver; // transformation from 
            // world coordinates to the coordinate system of the plane
 
         float4 vert(float4 vertexPos : POSITION) : SV_POSITION
         {
            float4x4 modelMatrix = _Object2World;
            float4x4 modelMatrixInverse = 
               _World2Object * unity_Scale.w;
            modelMatrixInverse[3][3] = 1.0; 
            float4x4 viewMatrix = 
               mul(UNITY_MATRIX_MV, modelMatrixInverse);
 
            float4 lightDirection;
            if (0.0 != _WorldSpaceLightPos0.w) 
            {
               // point or spot light
               lightDirection = normalize(
                  mul(modelMatrix, vertexPos - _WorldSpaceLightPos0));
            } 
            else 
            {
               // directional light
               lightDirection = -normalize(_WorldSpaceLightPos0); 
            }
 
            float4 vertexInWorldSpace = mul(modelMatrix, vertexPos);
            float4 world2ReceiverRow1 = 
               float4(_World2Receiver[0][1], _World2Receiver[1][1], 
               _World2Receiver[2][1], _World2Receiver[3][1]);
            float distanceOfVertex = 
               dot(world2ReceiverRow1, vertexInWorldSpace); 
               // = (_World2Receiver * vertexInWorldSpace).y 
               // = height over plane 
            float lengthOfLightDirectionInY = 
               dot(world2ReceiverRow1, lightDirection); 
               // = (_World2Receiver * lightDirection).y 
               // = length in y direction
 
            if (distanceOfVertex > 0.0 && lengthOfLightDirectionInY < 0.0)
            {
               lightDirection = lightDirection 
                  * (distanceOfVertex / (-lengthOfLightDirectionInY));
            }
            else
            {
               lightDirection = float4(0.0, 0.0, 0.0, 0.0); 
                  // don't move vertex
            }
 
            return mul(UNITY_MATRIX_P, mul(viewMatrix, 
               vertexInWorldSpace + lightDirection));
         }
 
         float4 frag(void) : COLOR 
         {
            return _ShadowColor;
         }
 
         ENDCG 
      }
   }
}