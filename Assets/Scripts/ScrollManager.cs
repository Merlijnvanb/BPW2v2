using System.Collections;
using System.Collections.Generic;
using Unity.VisualScripting;
using UnityEngine;

public class ScrollManager : MonoBehaviour
{
    public Transform playerCam;
    public Transform playerJoint;

    private bool pickedUp;

    private void Update()
    {
        if(Singleton.Instance.HasGottenScroll() && pickedUp == false)
        {
            transform.SetParent(playerJoint);
            transform.localPosition = new Vector3(0, -0.5f, 0.5f);
            transform.localEulerAngles = new Vector3(-20, 0, 0);
            pickedUp = true;
        }
    }
}
