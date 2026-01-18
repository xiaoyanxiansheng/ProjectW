using UnityEngine;

namespace ProjectW.SkillTest
{
    /// <summary>
    /// 简易世界空间飘字（测试用）
    /// - 不依赖TMP，使用TextMesh
    /// - 上飘 + 渐隐
    /// </summary>
    public sealed class FloatingText : MonoBehaviour
    {
        [SerializeField] private float _lifeTime = 0.5f;
        [SerializeField] private float _riseSpeed = 1.2f;

        private TextMesh _text;
        private float _t;
        private Color _startColor;

        public static FloatingText Create(string content, Vector3 worldPos, Color color, float lifeTime = 0.5f)
        {
            var go = new GameObject("FloatingText");
            go.transform.position = worldPos;

            var tm = go.AddComponent<TextMesh>();
            tm.text = content;
            tm.fontSize = 48;
            // 放大 5 倍（原值 0.08f）
            tm.characterSize = 0.08f * 5f;
            tm.anchor = TextAnchor.MiddleCenter;
            tm.alignment = TextAlignment.Center;
            tm.color = color;

            // 让文字尽量在渲染队列前面（简单处理）
            var mr = go.GetComponent<MeshRenderer>();
            if (mr != null)
            {
                mr.shadowCastingMode = UnityEngine.Rendering.ShadowCastingMode.Off;
                mr.receiveShadows = false;
            }

            var ft = go.AddComponent<FloatingText>();
            ft._text = tm;
            ft._lifeTime = Mathf.Max(0.05f, lifeTime);
            ft._startColor = color;

            return ft;
        }

        private void Update()
        {
            _t += Time.deltaTime;

            // 朝向相机（避免难读）
            var cam = Camera.main;
            if (cam != null)
            {
                var dir = transform.position - cam.transform.position;
                if (dir.sqrMagnitude > 1e-6f)
                {
                    transform.rotation = Quaternion.LookRotation(dir);
                }
            }

            // 上飘
            transform.position += Vector3.up * (_riseSpeed * Time.deltaTime);

            // 渐隐
            if (_text != null)
            {
                var a = 1f - Mathf.Clamp01(_t / _lifeTime);
                var c = _startColor;
                c.a *= a;
                _text.color = c;
            }

            if (_t >= _lifeTime)
            {
                Destroy(gameObject);
            }
        }
    }
}

