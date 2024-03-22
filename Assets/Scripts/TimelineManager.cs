using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.Playables;
using UnityEngine.SceneManagement;
using UnityEngine.UIElements;

public class TimelineManager : MonoBehaviour
{
    public Material skyboxMat;
    public Image image;

    private PlayableDirector director;

    private float MoodswitchTime = 4.211064f;
    private float Event1Time = 7.833333f;
    private float Event2Time = 10.7f;
    private float Event3Time = 13.95f;
    private float EndTime = 34.16667f;

    void Start()
    {
        director = GetComponent<PlayableDirector>();
    }

    public void ScrollGotten() 
    {
        director.Play();
        director.playableGraph.GetRootPlayable(0).SetDuration(MoodswitchTime);
    }

    public void Event1()
    {
        director.Play();
        director.playableGraph.GetRootPlayable(0).SetDuration(Event1Time);
    }

    public void Event2()
    {
        director.Play();
        director.playableGraph.GetRootPlayable(0).SetDuration(Event2Time);
    }

    public void Event3()
    {
        director.Play();
        director.playableGraph.GetRootPlayable(0).SetDuration(Event3Time);
    }

    public void End()
    {
        director.Play();
        director.playableGraph.GetRootPlayable(0).SetDuration(EndTime);
    }

    public void SkyboxChange()
    {
        RenderSettings.skybox = skyboxMat;
    }

    public void EndGame()
    {
        SceneManager.LoadScene("EndScreen");
    }
}
