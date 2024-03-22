using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class ScrollInteractable : MonoBehaviour
{
    private bool inRange;

    private void Update()
    {
        if (Input.GetKeyDown("e"))
        {
            if (inRange == true)
            {
                Singleton.Instance.ReceiveScroll();
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
