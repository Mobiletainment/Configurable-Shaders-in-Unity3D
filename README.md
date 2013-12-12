On-The-Fly Configurable Shaders in Unity3D
==========================
What is it?
------------
This project demonstrates **on-the-fly configurable shaders** in the free version of Unity3D 4.0, so **no pro license needed**!

All settings can be conveniently adjusted in a GUI **while the game is running**, e.g. turning on displacement mapping and adjusting the step size of the texture sampling.

Shader-Features:
-------------

* **Emit particles** with varying velocities and directions
* Switch on **soft shadows**
* Switch on **bump mapping**
* Switch on **displacement mapping**
 * Configure displacement strength
 * Configure step size for displacement texture sampling
* Choose **reflection model**
  * Enable Phong shading model
  * Enable Blinn shading model 
* Configure **specular light** intensity
* Configure **shininess (glossiness)** for specular lighting
* Configure **light attenuation**
* Configure **self-shadowing** intensity
* Configure **diffuse light** intensity
* Configure **ambient light** intensity (day/night)

All shaders are written in the shader language Cg with vertex- and fragment-shaders. No surface-shaders are used. Computation is performed entirely on the GPU instead of the CPU. The CPU's computing power can therefore be used to perform other computationally intensive work.



![Screenshot](./doc/Screenshot.png?raw=true)

Requirements
------------
* Unity 3D 4.0 or above (http://unity3d.com/)
* Grahpics card with shader model 3.0 or above
* OS: Windows, Mac OS X or a Linux Distribution (Multiplatform-support)

How to run and play?
------------

Open the project in Unity and double-click on the **scene "Shader"**. Hit play. 

| Input | Action  |
| --------------: | :-------|
| W, S, A, D      | Move camera front (W), back (S), left (A) or right (D) |
| Right mouse click & mouse movement  | Change view direction |
| Left mouse click      | Shoot a ray in the view direction. If the ray hits an object, particles are emitted on the position of intersection (runs entirely on GPU) |
| GUI controls adjustment     | Adjusting the values of the GUI controls results in an immediate update of the shader properties. You'll instantly see the new effect or the change in the used shader technique |

Documentation
------------
For a detailed description of the project and the techniques used, please have a look at [this documentation (German)](./doc/Dokumentation.pdf?raw=true).

Where to get help?
------------
* Have a look at the [author's website](http://www.pertiller.net/public-projects)
* Contact the author at david@pertiller.net

License
------------
(The MIT License)

Copyright (c) 2013 [David Pertiller](http://www.pertiller.net)

Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.