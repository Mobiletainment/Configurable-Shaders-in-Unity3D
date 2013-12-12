using UnityEngine;
using System.Collections;
 
public class OldMyParticleEmitter : MonoBehaviour {
	private Transform _transform;
 /*
	public bool emit = true;
	public OldMyParticleSettings particleSettings = new OldMyParticleSettings();
 
	public int particleAmmount = 10;
	public float emissionArea = 5;
	public GameObject particleObject;
 
	void Start() {
		_transform = transform;
 
		if ( particleObject == null ) {
			Debug.LogError("You must assign a GameObject as Particle");
			return;
		}
 
		StartCoroutine( Emit() );
	}
 
	IEnumerator Emit() {
		float timeStep = (particleSettings.lifeMin / particleSettings.lifeMax + particleSettings.lifeMin) / particleAmmount;
 
		while (true){
			if ( emit ) {
				Quaternion myRotation;
				myRotation = (particleSettings.billboard) ? Quaternion.LookRotation(Camera.main.transform.position, Camera.main.transform.up) : Quaternion.identity;
				(Instantiate(particleObject,_transform.position + Random.onUnitSphere * emissionArea, myRotation) as GameObject)
				.AddComponent<MyParticleController>().InitParticleSettings(particleSettings, _transform);
 
				yield return new WaitForSeconds( timeStep );
			} else yield return null;
		}
	}
	*/
}
 
[System.Serializable]
public class OldMyParticleSettings
{
	public float lifeMin = 2;
	public float lifeMax = 2;
	public Vector3 localVelocity;
	public Vector3 rndVelocity;
	public float particleMinSize = 1;
	public float particleMaxSize = 1;
	public bool animateColor = false;
	public Color[] animationColor = new Color[5];
	public bool billboard = true;
	public float angularVelocity;
}