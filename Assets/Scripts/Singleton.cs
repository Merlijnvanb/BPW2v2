using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class Singleton : MonoBehaviour
{
    public static Singleton Instance { get; private set; }
    public TimelineManager timeline;

    public ParticleSystem particle1;
    public ParticleSystem particle2;
    public ParticleSystem particle3;

    private bool gottenScroll = false;

    private int eventsActivated = 0;

    private void Awake()
    {
        if (Instance != null && Instance != this)
        {
            Destroy(this);
        }
        else
        {
            Instance = this;
        }
    }

    public bool HasGottenScroll()
    {
        return gottenScroll;
    }

    public void ReceiveScroll()
    {
        gottenScroll = true;
        Debug.Log("Scroll gotten");
        timeline.ScrollGotten();
    }

    public int GetActivatedEvents()
    {
        return eventsActivated;
    }

    public void IncreaseEvents()
    {
        eventsActivated++;
        Debug.Log("Events increased, count is: " + eventsActivated);
        if (eventsActivated == 1) {timeline.Event1();
        particle1.Play();}
        else if (eventsActivated == 2) {timeline.Event2();
        particle2.Play();}
        else if (eventsActivated == 3) {timeline.Event3();
        particle3.Play();}
    }

    public void MoodSwitch()
    {
        Debug.Log("Mood switch activated");
        timeline.End();
    }
}
