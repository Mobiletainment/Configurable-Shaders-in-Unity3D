using UnityEngine;
using System.Collections;
 
public class MyParticleEmitter : MonoBehaviour {
	private Transform _transform;
 
	public bool emit = true;
	public MyParticleSettings particleSettings = new MyParticleSettings();
 
	public int particleAmount = 200;
	public float emissionArea = 1;
	public GameObject particleObject;
 
	void Start()
	{
		_transform = transform;
 
		if ( particleObject == null ) {
			Debug.LogError("You must assign a GameObject as Particle");
			return;
		}
 
		StartCoroutine(Emit());
	}
 
	IEnumerator Emit() 
	{
		float timeStep = (particleSettings.lifeMin / particleSettings.lifeMax + particleSettings.lifeMin) / particleAmount;
 
		while (true){
			if ( emit ) {
				Quaternion myRotation = Quaternion.identity;
				GameObject newParticle = Instantiate(particleObject, _transform.position + Random.onUnitSphere * emissionArea, myRotation) as GameObject;
				newParticle.renderer.material.SetFloat("_BirthTime", Time.time);
 				newParticle.AddComponent<MyParticleController>().InitParticleSettings(particleSettings, _transform);
				
				yield return new WaitForSeconds( timeStep );
			} else yield return null;
		}
	}
}
 
[System.Serializable]
public class MyParticleSettings {
	public float lifeMin = 2;
	public float lifeMax = 2;
	public Vector3 localVelocity;
	public Vector3 rndVelocity;
	public float particleMinSize = 1;
	public float particleMaxSize = 1;
	public float angularVelocity;
}