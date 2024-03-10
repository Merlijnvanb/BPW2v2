using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.Rendering;

[ExecuteInEditMode]
public class ProceduralGrassRenderer : MonoBehaviour {
    [System.Serializable]
    public class GrassSettings {
        public int maxSegments = 3;
        public float maxBendAngle = 0;
        public float bladeCurvature = 1;
        public float bladeHeight = 1;
        public float bladeHeightVariance = 0.1f;
        public float bladeWidth = 1;
        public float bladeWidthVariance = 0.1f;
        public Texture2D windNoiseTexture = null;
        public float windTextureScale = 1;
        public float windPeriod = 1;
        public float windScale = 1;
        public float windAmplitude = 0;
        public float windDirectionAngle = 0;
    }

    [SerializeField] private Mesh sourceMesh = default;
    [SerializeField] private ComputeShader grassComputeShader = default;
    [SerializeField] private Material material = default;

    [SerializeField] private GrassSettings grassSettings = default;

    [System.Runtime.InteropServices.StructLayout(System.Runtime.InteropServices.LayoutKind.Sequential)]
    private struct SourceVertex {
        public Vector3 position;
    }

    private bool initialized;
    private ComputeBuffer sourceVertBuffer;
    private ComputeBuffer sourceTriBuffer;
    private ComputeBuffer drawBuffer;
    private ComputeBuffer argsBuffer;
    private int idGrassKernel;
    private int dispatchSize;
    private Bounds localBounds;

    private const int SOURCE_VERT_STRIDE = sizeof(float) * 3;
    private const int SOURCE_TRI_STRIDE = sizeof(int);
    private const int DRAW_STRIDE = sizeof(float) * (3 + (3 + 1) * 3);
    private const int INDIRECT_ARGS_STRIDE = sizeof(int) * 4;

    private int[] argsBufferReset = new int[] { 0, 1, 0, 0 };

    private void OnEnable() {
        Debug.Assert(grassComputeShader != null, "The grass compute shader is null", gameObject);
        Debug.Assert(material != null, "The material is null", gameObject);

        if(initialized) {
            OnDisable();
        }
        initialized = true;

        Vector3[] positions = sourceMesh.vertices;
        int[] tris = sourceMesh.triangles;

        SourceVertex[] vertices = new SourceVertex[positions.Length];
        for(int i = 0; i < vertices.Length; i++) {
            vertices[i] = new SourceVertex() {
                position = positions[i],
            };
        }
        int numSourceTriangles = tris.Length / 3;
        int maxBladeSegments = Mathf.Max(1, grassSettings.maxSegments);
        int maxBladeTriangles = (maxBladeSegments - 1) * 2 + 1;

        sourceVertBuffer = new ComputeBuffer(vertices.Length, SOURCE_VERT_STRIDE, ComputeBufferType.Structured, ComputeBufferMode.Immutable);
        sourceVertBuffer.SetData(vertices);
        sourceTriBuffer = new ComputeBuffer(tris.Length, SOURCE_TRI_STRIDE, ComputeBufferType.Structured, ComputeBufferMode.Immutable);
        sourceTriBuffer.SetData(tris);
        drawBuffer = new ComputeBuffer(numSourceTriangles * maxBladeTriangles, DRAW_STRIDE, ComputeBufferType.Append);
        drawBuffer.SetCounterValue(0);
        argsBuffer = new ComputeBuffer(1, INDIRECT_ARGS_STRIDE, ComputeBufferType.IndirectArguments);

        idGrassKernel = grassComputeShader.FindKernel("Main");

        grassComputeShader.SetBuffer(idGrassKernel, "_SourceVertices", sourceVertBuffer);
        grassComputeShader.SetBuffer(idGrassKernel, "_SourceTriangles", sourceTriBuffer);
        grassComputeShader.SetBuffer(idGrassKernel, "_DrawTriangles", drawBuffer);
        grassComputeShader.SetBuffer(idGrassKernel, "_IndirectArgsBuffer", argsBuffer);
        grassComputeShader.SetInt("_NumSourceTriangles", numSourceTriangles);
        grassComputeShader.SetInt("_MaxBladeSegments", maxBladeSegments);
        grassComputeShader.SetFloat("_MaxBendAngle", grassSettings.maxBendAngle);
        grassComputeShader.SetFloat("_BladeCurvature", grassSettings.bladeCurvature);
        grassComputeShader.SetFloat("_BladeHeight", grassSettings.bladeHeight);
        grassComputeShader.SetFloat("_BladeHeightVariance", grassSettings.bladeHeightVariance);
        grassComputeShader.SetFloat("_BladeWidth", grassSettings.bladeWidth);
        grassComputeShader.SetFloat("_BladeWidthVariance", grassSettings.bladeWidthVariance);
        grassComputeShader.SetTexture(idGrassKernel, "_WindNoiseTexture", grassSettings.windNoiseTexture);
        grassComputeShader.SetFloat("_WindTexMult", grassSettings.windTextureScale);
        grassComputeShader.SetFloat("_WindTimeMult", grassSettings.windPeriod);
        grassComputeShader.SetFloat("_WindPosMult", grassSettings.windScale);
        grassComputeShader.SetFloat("_WindAmplitude", grassSettings.windAmplitude);
        grassComputeShader.SetFloat("_WindDirectionAngle", grassSettings.windDirectionAngle);

        material.SetBuffer("_DrawTriangles", drawBuffer);

        grassComputeShader.GetKernelThreadGroupSizes(idGrassKernel, out uint threadGroupSize, out _, out _);
        dispatchSize = Mathf.CeilToInt((float)numSourceTriangles / threadGroupSize);

        localBounds = sourceMesh.bounds;
        localBounds.Expand(Mathf.Max(grassSettings.bladeHeight + grassSettings.bladeHeightVariance, 
            grassSettings.bladeWidth + grassSettings.bladeWidthVariance));
    }

    private void OnDisable() {
        if(initialized) {
            // Release each buffer
            sourceVertBuffer.Release();
            sourceTriBuffer.Release();
            drawBuffer.Release();
            argsBuffer.Release();
        }
        initialized = false;
    }

    // Code by benblo from https://answers.unity.com/questions/361275/cant-convert-bounds-from-world-coordinates-to-loca.html
    public Bounds TransformBounds(Bounds boundsOS) {
        var center = transform.TransformPoint(boundsOS.center);

        // transform the local extents' axes
        var extents = boundsOS.extents;
        var axisX = transform.TransformVector(extents.x, 0, 0);
        var axisY = transform.TransformVector(0, extents.y, 0);
        var axisZ = transform.TransformVector(0, 0, extents.z);

        // sum their absolute value to get the world extents
        extents.x = Mathf.Abs(axisX.x) + Mathf.Abs(axisY.x) + Mathf.Abs(axisZ.x);
        extents.y = Mathf.Abs(axisX.y) + Mathf.Abs(axisY.y) + Mathf.Abs(axisZ.y);
        extents.z = Mathf.Abs(axisX.z) + Mathf.Abs(axisY.z) + Mathf.Abs(axisZ.z);

        return new Bounds { center = center, extents = extents };
    }

    private void LateUpdate() {
        if(Application.isPlaying == false) {
            OnDisable();
            OnEnable();
        }

        drawBuffer.SetCounterValue(0);
        argsBuffer.SetData(argsBufferReset);

        Bounds bounds = TransformBounds(localBounds);

        grassComputeShader.SetVector("_Time", new Vector4(0, Time.timeSinceLevelLoad, 0, 0));
        grassComputeShader.SetMatrix("_LocalToWorld", transform.localToWorldMatrix);

        grassComputeShader.Dispatch(idGrassKernel, dispatchSize, 1, 1);

        Graphics.DrawProceduralIndirect(material, bounds, MeshTopology.Triangles, argsBuffer, 0,
            null, null, ShadowCastingMode.Off, true, gameObject.layer);
    }
}