using ProjectW.Rendering;
using UnityEngine;

namespace ProjectW.SkillTest
{
    /// <summary>
    /// 极简世界空间血条（无UI依赖）
    /// - SpriteRenderer 背景 + 填充
    /// - 始终面向相机
    /// </summary>
    public sealed class WorldHealthBar : MonoBehaviour
    {
        [Header("Size")]
        [SerializeField] private float _width = 1.4f;
        [SerializeField] private float _height = 0.18f;
        [SerializeField] private float _yOffset = 0.2f;

        [Header("Colors")]
        [SerializeField] private Color _bgColor = new(0f, 0f, 0f, 0.55f);
        [SerializeField] private Color _hpColor = new(0.15f, 0.95f, 0.2f, 0.95f);

        private Transform _target;
        private SpriteRenderer _bg;
        private SpriteRenderer _fill;
        private static Sprite _whiteSprite;
        private Renderer[] _targetRenderers;

        public void BindTarget(Transform target)
        {
            _target = target;
            CacheTargetRenderers();
        }

        public void SetVisible(bool visible)
        {
            if (_bg != null) _bg.enabled = visible;
            if (_fill != null) _fill.enabled = visible;
        }

        public void SetValue(int hp, int maxHp)
        {
            maxHp = Mathf.Max(1, maxHp);
            var ratio = Mathf.Clamp01(hp / (float)maxHp);
            ApplyRatio(ratio);
        }

        private void Awake()
        {
            EnsureRenderers();
            ApplyRatio(1f);
        }

        private void CacheTargetRenderers()
        {
            if (_target == null)
            {
                _targetRenderers = null;
                return;
            }

            // IMPORTANT: exclude any Renderer that belongs to a WorldHealthBar (including ourselves),
            // otherwise bounds will include the bar and create a feedback loop (bar keeps drifting upward).
            var all = _target.GetComponentsInChildren<Renderer>(includeInactive: true);
            if (all == null || all.Length == 0)
            {
                _targetRenderers = null;
                return;
            }

            // filter in-place
            var tmp = new System.Collections.Generic.List<Renderer>(all.Length);
            for (var i = 0; i < all.Length; i++)
            {
                var r = all[i];
                if (r == null) continue;
                // skip renderers under any WorldHealthBar
                if (r.GetComponentInParent<WorldHealthBar>() != null) continue;
                tmp.Add(r);
            }

            _targetRenderers = tmp.Count > 0 ? tmp.ToArray() : null;
        }

        private void EnsureRenderers()
        {
            // 标记：血条不应被 HoverDarkenByPropertyBlock 变暗/闪色影响
            if (GetComponent<IgnoreHoverDarken>() == null)
            {
                gameObject.AddComponent<IgnoreHoverDarken>();
            }

            if (_whiteSprite == null)
            {
                var tex = new Texture2D(1, 1, TextureFormat.RGBA32, mipChain: false);
                tex.SetPixel(0, 0, Color.white);
                tex.Apply(updateMipmaps: false, makeNoLongerReadable: true);
                _whiteSprite = Sprite.Create(tex, new Rect(0, 0, 1, 1), new Vector2(0.5f, 0.5f), pixelsPerUnit: 1f);
            }

            if (_bg == null)
            {
                var bgGo = new GameObject("BG");
                bgGo.transform.SetParent(transform, worldPositionStays: false);
                _bg = bgGo.AddComponent<SpriteRenderer>();
                _bg.sprite = _whiteSprite;
                _bg.color = _bgColor;
                _bg.sortingOrder = 5000;
            }

            if (_fill == null)
            {
                var fillGo = new GameObject("Fill");
                fillGo.transform.SetParent(transform, worldPositionStays: false);
                _fill = fillGo.AddComponent<SpriteRenderer>();
                _fill.sprite = _whiteSprite;
                _fill.color = _hpColor;
                _fill.sortingOrder = 5001;
            }

            // 初始布局
            _bg.transform.localPosition = Vector3.zero;
            _bg.transform.localScale = new Vector3(_width, _height, 1f);

            _fill.transform.localPosition = new Vector3(-_width * 0.5f, 0f, 0f);
            _fill.transform.localScale = new Vector3(_width, _height, 1f);
        }

        private void ApplyRatio(float ratio01)
        {
            EnsureRenderers();

            // 背景固定宽度
            _bg.transform.localScale = new Vector3(_width, _height, 1f);

            // 填充从左到右
            var w = _width * Mathf.Clamp01(ratio01);
            _fill.transform.localScale = new Vector3(w, _height, 1f);
            _fill.transform.localPosition = new Vector3(-_width * 0.5f + w * 0.5f, 0f, 0f);

            // 低血量变红（简易）
            if (ratio01 < 0.3f) _fill.color = new Color(1f, 0.2f, 0.2f, _hpColor.a);
            else _fill.color = _hpColor;
        }

        private void LateUpdate()
        {
            if (_target == null) return;
            if (_targetRenderers == null || _targetRenderers.Length == 0)
            {
                // target may have been reconfigured (renderers added/removed)
                CacheTargetRenderers();
            }

            // 跟随到“头顶”
            var head = GetHeadPositionFromCachedRenderers(_target, _targetRenderers);
            transform.position = head + Vector3.up * _yOffset;

            // 面向相机
            var cam = Camera.main;
            if (cam != null)
            {
                var dir = transform.position - cam.transform.position;
                if (dir.sqrMagnitude > 1e-6f)
                {
                    transform.rotation = Quaternion.LookRotation(dir);
                }
            }

        }

        private static Vector3 GetHeadPositionFromCachedRenderers(Transform t, Renderer[] cached)
        {
            var rs = cached;
            if (rs != null && rs.Length > 0)
            {
                var has = false;
                var b = new Bounds(t.position, Vector3.zero);
                foreach (var r in rs)
                {
                    if (r == null || !r.enabled) continue;
                    if (!has) { b = r.bounds; has = true; }
                    else b.Encapsulate(r.bounds);
                }
                if (has) return b.center + Vector3.up * b.extents.y;
            }
            return t.position + Vector3.up * 1.8f;
        }
    }
}

