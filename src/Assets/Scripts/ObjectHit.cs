using UnityEngine;
using System.Collections;

public class ObjectHit : MonoBehaviour 
{
	public GameObject particleEmitter;
	
	// Use this for initialization
	void Start () {
	
	}
	
	// Update is called once per frame
	void Update ()
	{
		if (Input.GetMouseButtonDown(0))
		{
			// Construct a ray from the current mouse coordinates
			// Returns a ray going from camera through a screen point.
			// 
			Ray ray = camera.ScreenPointToRay (Input.mousePosition);
			RaycastHit hit;
			
			if (Physics.Raycast(ray, out hit) && hit.transform.gameObject.tag != "Background")
			{
					// Create a particle if hit
					/*MyParticleEmitter emitter = ScriptableObject.CreateInstance<MyParticleEmitter>();
					
					*/
					/*
					MyParticleEmitter emitter = gameObject.AddComponent<MyParticleEmitter>();
					emitter.particle = particle;
					emitter.newPosition = hit.point;
					emitter.timeLeftOver = 5.0f;
					emitter.timeBetweenParticles = 0.1f;
					
					*/
					
					Debug.Log("Hit at: " + ray);
					Instantiate(particleEmitter, hit.point, transform.rotation);
			}
			else
			{
				Debug.Log("No Hit");
			}
			
			 //Debug.DrawRay (ray.origin, ray.direction * 10, Color.yellow);
		}
	}
	
}
