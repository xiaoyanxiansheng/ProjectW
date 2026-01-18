using UnityEngine;

namespace ProjectW.SkillTest
{
    /// <summary>
    /// 俯视跟随相机（Dota2风格）
    /// </summary>
    public sealed class TopDownCameraFollow : MonoBehaviour
    {
        [SerializeField] private Transform _target;
        [SerializeField] private float _height = 18f;
        [SerializeField] private float _distance = 12f;
        [SerializeField] private float _yaw = 45f;
        [SerializeField] private float _pitch = 55f;
        [SerializeField] private float _followSpeed = 8f;
        [SerializeField] private float _rotationSpeed = 8f;

        private Vector3 _velocity;

        private void LateUpdate()
        {
            if (_target == null)
            {
                var player = GameObject.Find("Player");
                if (player != null) _target = player.transform;
            }

            if (_target == null) return;

            var offset = Quaternion.Euler(0f, _yaw, 0f) * new Vector3(0f, _height, -_distance);
            var desiredPos = _target.position + offset;

            var smoothTime = _followSpeed <= 0f ? 0f : 1f / _followSpeed;
            transform.position = smoothTime <= 0f
                ? desiredPos
                : Vector3.SmoothDamp(transform.position, desiredPos, ref _velocity, smoothTime);

            var desiredRot = Quaternion.Euler(_pitch, _yaw, 0f);
            var t = 1f - Mathf.Exp(-_rotationSpeed * Time.deltaTime);
            transform.rotation = Quaternion.Slerp(transform.rotation, desiredRot, t);
        }
    }
}

