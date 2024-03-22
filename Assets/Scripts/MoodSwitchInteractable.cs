using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class MoodSwitchInteractable : MonoBehaviour
{
    private bool inRange;
    private bool activated;

    private void Update()
    {
        if (Input.GetKeyDown("e"))
        {
            if (inRange == true && activated != true && Singleton.Instance.GetActivatedEvents() == 3)
            {
                activated = true;
                Singleton.Instance.MoodSwitch();
            }
        }
    }

    private void OnTriggerEnter(Collider other)
    {
        if (other.CompareTag("Player"))
        {
            inRange = true;
        }
    }

    private void OnTriggerExit(Collider other)
    {
        if (other.CompareTag("Player"))
        {
            inRange = false;
        }
    }
}
