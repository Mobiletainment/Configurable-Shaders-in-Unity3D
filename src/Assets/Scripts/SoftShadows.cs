using UnityEngine;
using System.Collections;

public class SoftShadows : MonoBehaviour 
{
	public GameObject _ShadowReceiver;
	// Use this for initialization
	void Start ()
	{
	}
	
	// Update is called once per frame
	void Update () 
	{
		//Debug.Log(_ShadowReceiver.renderer.worldToLocalMatrix);
		renderer.sharedMaterial.SetMatrix("_World2Receiver", _ShadowReceiver.renderer.worldToLocalMatrix);
	}
}
