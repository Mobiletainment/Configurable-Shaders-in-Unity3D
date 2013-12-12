using UnityEngine;
using System.Collections;
 
public class MyParticleController : MonoBehaviour {
	private Transform _transform;
	private Transform emitter;
 
	private Vector3 particleSize;
	private Vector3 particleDir;
	private float particleLife;
	private Material _material;
 
	private float myAngular;
 
	void Start() 
	{
		_transform.localScale = particleSize;
		_material.SetVector("_Velocity", new Vector4(particleDir.x, particleDir.y, particleDir.z, 0.0f));
		
		Destroy ( _transform.gameObject, particleLife );
	}
 /*
	void Update()
	{
		
		//_transform.Translate( particleDir * Time.deltaTime, emitter );
		//myAngular += angularVelocity * Time.deltaTime;
		//_transform.rotation = Quaternion.identity * Quaternion.Euler(myAngular,0,0);
	}
*/ 
 
	public void InitParticleSettings( MyParticleSettings particleSettings, Transform _emitter ) {
		emitter = _emitter;
		_material = renderer.material;
		_transform = transform;
		particleSize = _transform.localScale;
		float pSize = Random.Range(particleSettings.particleMinSize, particleSettings.particleMaxSize);
		particleSize *= pSize;
 
		Vector3 rndVelocity = particleSettings.rndVelocity;
		Vector3 localVelocity = particleSettings.localVelocity;
 
		particleDir.x = Random.Range(-rndVelocity.x + localVelocity.x, rndVelocity.x + localVelocity.x);
		particleDir.y = Random.Range(-rndVelocity.y + localVelocity.y, rndVelocity.y + localVelocity.y);
		particleDir.z = Random.Range(-rndVelocity.z + localVelocity.z, rndVelocity.z + localVelocity.z);
 
		particleLife = Random.Range(particleSettings.lifeMin, particleSettings.lifeMax);
		gameObject.hideFlags = HideFlags.HideInHierarchy;
 
	}
}