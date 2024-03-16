using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class Singleton : MonoBehaviour 
{
    public static Singleton Instance { get; private set; }

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

public bool HasGottenScroll() {
    return gottenScroll;
}

public void ReceiveScroll() {
    gottenScroll = true;
}

public int GetActivatedEvents() {
    return eventsActivated;
}

public void IncreaseEvents() {
    eventsActivated++;
}
}
