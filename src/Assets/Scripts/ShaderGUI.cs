using UnityEngine;
using System.Collections;
using System.Collections.Generic;

public class ShaderGUI : MonoBehaviour
{
	public float shininess = 10.0f;
	public float specular = 1.0f;
	//public Color specularColor = new Color(0.12f, 0.31f, 0.47f, 1.0f);
	public Color specularColor = new Color(0.0f, 1.0f, 1.0f, 1.0f);
	public float diffuse = 1.0f;
	public float ambient = 1.0f;
	public float selfShadowing = 1.0f;
	public float attenuation = 0.2f;
	public int displacementSteps = 10;
	public int refinementSteps = 10;
	public int displacementStrength = 10;
	

	string[] specularModelStrings = {"Phong", "Blinn"};
	int specularModelInt = 0;
	
	string [] bumpMappingStrings = {"Bump Mapping", "No Bump"};
	int bumpMappingInt = 0;
	
	string [] displacementMappingStrings = {"Displacement", "No Disp."};
	int displacementMappingInt = 0;
	
	string[] shadowsStrings = {"Soft Shadows", "No Shadow"};
	int shadows = 0;
	
	Shader customShader;
	Shader customShaderWithoutBump;
	Shader customShaderBumpDisplacement;
	Shader customShaderBumpDisplacementSoftShadow;
	
	Material materialDefault;
	Material materialBump;
	Material materialDisplacement;
	Material materialDisplacementSoftShadow;
	
	
	List<GameObject> gameObjects; //this is where all game objects are held

	void InitializeValues ()
	{
		UpdateShaderFloatToObjects("_SpecularIntensity", specular);
		UpdateShaderFloatToObjects("_Shininess", shininess); //apply new glossiness
		UpdateShaderFloatToObjects("_AmbientIntensity", ambient);
		UpdateShaderFloatToObjects("_DiffIntensity", diffuse);
		UpdateShaderFloatToObjects("_SelfShadowingIntensity", selfShadowing);
		UpdateShaderFloatToObjects("_Attenuation", attenuation);
		UpdateShaderFloatToObjects("_UseBlinnInsteadPhong", (float)specularModelInt);
		UpdateShaderFloatToObjects("_DisplacementSteps", (float) displacementSteps);
		UpdateShaderFloatToObjects("_RefinementSteps", (float) refinementSteps);
		UpdateShaderFloatToObjects("_DisplacementStrength", (float) displacementStrength);
	}

	void InitializeRenderer (Material material)
	{
		Debug.Log("Initializing with: " + material.name);
		gameObjects.Clear();
		GameObject[] objects = FindObjectsOfType(typeof(GameObject)) as GameObject[];
		foreach( GameObject go in objects )
		{
			if (go.tag == "Model" && go.renderer != null && go.renderer.material != null)
			{
				go.renderer.material = material;
				gameObjects.Add(go);
			}
		}
		
		Debug.Log(gameObjects.Count);
		InitializeValues ();
	}
	
	void Start ()
	{	
		materialDefault = Resources.Load("Materials/default", typeof(Material)) as Material;
		materialBump = Resources.Load("Materials/bump", typeof(Material)) as Material;
		materialDisplacement = Resources.Load("Materials/displacement", typeof(Material)) as Material;
		materialDisplacementSoftShadow = Resources.Load("Materials/softshadow", typeof(Material)) as Material;
		
		Debug.Log(materialDisplacementSoftShadow);
		
		
		if (gameObjects == null) //only setup objects if they're not already set up!
		{
			gameObjects = new List<GameObject>();
			InitializeRenderer (materialDisplacementSoftShadow);
		}
	}
	
	void OnGUI ()
	{
		GUI.Window (0, new Rect(20, 10, 200, 490), OptionsWindow, "Shader Properties");
	}	
	
	void OptionsWindow (int windowID)
	{
		//Specular Light Intensity:
		GUI.Label(new Rect(10, 20, 160, 40), string.Format("Specular Intensity: {0:F0}%", specular*100));
		//get current specular light intensity value from slider (0 = off, 1.0 = max)
		float currentSpecular = GUI.HorizontalSlider(new Rect(10, 40, 180, 32), specular, 0.0f, 1.0f);
		
		if (specular != currentSpecular) //only adjust shader's specular light intensity if value has changed
		{
			specular = currentSpecular;
			UpdateShaderFloatToObjects("_SpecularIntensity", specular);
		}
		
		//Shininess of Specular Light:
		GUI.Label(new Rect(10, 50, 160, 40), string.Format("Shininess: {0:F2}", shininess));
		//get current glossiness value from slider
		float currentShininess = (GUI.HorizontalSlider(new Rect(10, 70, 180, 10), shininess, 1.0f, 50.0f));
		
		if (shininess != currentShininess) //only adjust shader if value has changed
		{
			shininess = currentShininess;
			UpdateShaderFloatToObjects("_Shininess", shininess); //apply new glossiness
		}
		
		int newSpecularModelInt = GUI.SelectionGrid(new Rect (10, 90, 180, 40), specularModelInt, specularModelStrings, 2);
		
		if (specularModelInt != newSpecularModelInt)
		{
			specularModelInt = newSpecularModelInt;
			UpdateShaderFloatToObjects("_UseBlinnInsteadPhong", (float)specularModelInt);
		}
		
		
		int newBumpMappingInt = GUI.SelectionGrid(new Rect (10, 140, 180, 40), bumpMappingInt, bumpMappingStrings, 2);
		
		if (bumpMappingInt != newBumpMappingInt)
		{
			bumpMappingInt = newBumpMappingInt;
			
			if (bumpMappingInt == 0)
				InitializeRenderer(materialBump);
			else
				InitializeRenderer(materialDefault);
			
		}
		
	
		
		//Diffuse Light Intensity:
		GUI.Label(new Rect(10, 180, 160, 40), string.Format("Diffuse Intensity: {0:F0}%", diffuse*100));
		//get current specular light intensity value from slider (0 = off, 1.0 = max)
		float currentDiffuse = GUI.HorizontalSlider(new Rect(10, 200, 180, 32), diffuse, 0.0f, 1.0f);
		
		if (diffuse != currentDiffuse) //only adjust shader's specular light intensity if value has changed
		{
			diffuse = currentDiffuse;
			UpdateShaderFloatToObjects("_DiffIntensity", diffuse);
		}
		
		//Ambient Light Intensity:
		GUI.Label(new Rect(10, 210, 160, 40), string.Format("Ambient Intensity: {0:F0}%", ambient*100));
		float currentAmbient = GUI.HorizontalSlider(new Rect(10, 230, 180, 32), ambient, 0.0f, 1.0f);
		
		if (ambient != currentAmbient) //only adjust shader's specular light intensity if value has changed
		{
			ambient = currentAmbient;
			UpdateShaderFloatToObjects("_AmbientIntensity", ambient);
		}
		
		//Self shadowing Intensity:
		GUI.Label(new Rect(10, 240, 160, 40), string.Format("Self-shadowing: {0:F2}%", selfShadowing*100));
		float currentSelfShadowing = GUI.HorizontalSlider(new Rect(10, 260, 180, 32), selfShadowing, 0.0f, 1.0f);
		
		if (selfShadowing != currentSelfShadowing) //only adjust shader's specular light intensity if value has changed
		{
			selfShadowing = currentSelfShadowing;
			UpdateShaderFloatToObjects("_SelfShadowingIntensity", selfShadowing);
		}
		
		//Attenuation:
		GUI.Label(new Rect(10, 270, 160, 40), string.Format("Attenuation: {0:F2}%", attenuation*100));
		//get current specular light intensity value from slider (0 = off, 1.0 = max)
		float currentAttenuation = GUI.HorizontalSlider(new Rect(10, 290, 180, 32), attenuation, 0.01f, 1.0f);
		
		if (attenuation != currentAttenuation) //only adjust shader's specular light intensity if value has changed
		{
			attenuation = currentAttenuation;
			UpdateShaderFloatToObjects("_Attenuation", attenuation);
		}
		
		//Soft shadowing
		int newShadowInt = GUI.SelectionGrid(new Rect (10, 305, 180, 40), shadows, shadowsStrings, 2);
		
		if (shadows != newShadowInt)
		{
			shadows = newShadowInt;
			
			if (shadows == 0)
				InitializeRenderer(materialDisplacementSoftShadow);
			else
			{
				InitializeRenderer(materialDisplacement);
			}
		}
		
		
		int newDisplacementMappingInt = GUI.SelectionGrid(new Rect (10, 350, 180, 40), displacementMappingInt, displacementMappingStrings, 2);
		
		if (displacementMappingInt != newDisplacementMappingInt)
		{
			displacementMappingInt = newDisplacementMappingInt;
			
			if (displacementMappingInt == 0)
				InitializeRenderer(materialDisplacement);
			else
			{
				if (bumpMappingInt == 0)
					InitializeRenderer(materialBump);
				else
					InitializeRenderer(materialDefault);
			}
			
			
		}
		
		GUI.Label(new Rect(10, 390, 160, 40), string.Format("Displacement Steps: {0}", displacementSteps));
	
		int currentDisplacementSteps = (int) GUI.HorizontalSlider(new Rect(10, 410, 180, 10), displacementSteps, 0, 30);
		
		if (currentDisplacementSteps != displacementSteps) //only adjust shader if value has changed
		{
			displacementSteps = currentDisplacementSteps;
			UpdateShaderFloatToObjects("_DisplacementSteps", (float) displacementSteps);
		}
		
		GUI.Label(new Rect(10, 420, 160, 40), string.Format("Refinement Steps: {0}", refinementSteps));
		
		int currentRefinementSteps = (int) GUI.HorizontalSlider(new Rect(10, 440, 180, 10), refinementSteps, 0, 30);
		
		if (currentRefinementSteps != refinementSteps) //only adjust shader if value has changed
		{
			refinementSteps = currentRefinementSteps;
			UpdateShaderFloatToObjects("_RefinementSteps", (float) refinementSteps);
		}
		
		GUI.Label(new Rect(10, 450, 160, 40), string.Format("Displacement Strength: {0}", displacementStrength));
		
		int currentDisplacementStrength = (int) GUI.HorizontalSlider(new Rect(10, 470, 180, 10), displacementStrength, 0, 30);
		
		if (currentDisplacementStrength != displacementStrength) //only adjust shader if value has changed
		{
			displacementStrength = currentDisplacementStrength;
			UpdateShaderFloatToObjects("_DisplacementStrength", (float) displacementStrength);
		}
	}
	
	void UpdateShaderColorToObjects(string property, Color color)
	{
		gameObjects[0].renderer.sharedMaterial.SetColor(property, color); //apply the adjusted color to take effect
		
	}
	
	void UpdateShaderFloatToObjects(string property, float value)
	{
		Debug.Log(property);
		gameObjects[0].renderer.sharedMaterial.SetFloat(property, value); //apply the adjusted color to take effect

	}
}
