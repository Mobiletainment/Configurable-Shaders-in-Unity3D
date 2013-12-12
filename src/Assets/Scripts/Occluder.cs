using UnityEngine;
using System.Collections;

public class Occluder : MonoBehaviour 
{
	// Use this for initialization
	void Start ()
	{
		
	}
	
	// Update is called once per frame
	void Update ()
	{
		renderer.sharedMaterial.SetVector("_SpherePosition", transform.position);
		renderer.sharedMaterial.SetFloat("_SphereRadius", transform.localScale.x * 0.5f);
	}
}
