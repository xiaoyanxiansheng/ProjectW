using UnityEngine;

namespace ProjectW.Rendering
{
    /// <summary>
    /// 悬停/选中变暗（不换材质、不实例化材质）
    /// - 使用 MaterialPropertyBlock 修改颜色
    /// - 默认尝试写入 _BaseColor（URP）与 _Color（旧Shader）
    /// </summary>
    public sealed class HoverDarkenByPropertyBlock : MonoBehaviour
    {
        [Header("Target Renderers")]
        [SerializeField] private bool _includeChildren = true;

        [Header("Darken")]
        [Tooltip("悬停时颜色乘以该系数（<1 变暗）")]
        [Range(0.05f, 1f)]
        [SerializeField] private float _darkenMultiplier = 0.7f;

        private static readonly int BaseColorId = Shader.PropertyToID("_BaseColor");
        private static readonly int ColorId = Shader.PropertyToID("_Color");

        private Renderer[] _renderers;
        private Color[] _baseColors;
        private MaterialPropertyBlock _block;
        private bool _isHovered;
        private Coroutine _flashRoutine;
        private Color? _flashColor;

        private void Awake()
        {
            CacheRenderersAndBaseColors();
            Apply(false, force: true);
        }

        private void OnDisable()
        {
            // 退出/禁用时确保还原
            Apply(false, force: true);
        }

        public void SetDarkenMultiplier(float multiplier)
        {
            _darkenMultiplier = Mathf.Clamp(multiplier, 0.05f, 1f);
            if (_isHovered)
            {
                Apply(true, force: true);
            }
        }

        public void SetHovered(bool hovered)
        {
            if (_isHovered == hovered) return;
            _isHovered = hovered;
            Apply(_isHovered, force: false);
        }

        public void Flash(Color color, float duration)
        {
            duration = Mathf.Max(0.05f, duration);
            if (_flashRoutine != null)
            {
                StopCoroutine(_flashRoutine);
                _flashRoutine = null;
            }
            _flashRoutine = StartCoroutine(FlashRoutine(color, duration));
        }

        private void CacheRenderersAndBaseColors()
        {
            _renderers = _includeChildren
                ? GetComponentsInChildren<Renderer>(includeInactive: true)
                : GetComponents<Renderer>();

            // 过滤：忽略被标记为“不参与变暗/闪色”的Renderer（例如血条）
            if (_renderers != null && _renderers.Length > 0)
            {
                var tmp = new System.Collections.Generic.List<Renderer>(_renderers.Length);
                for (var i = 0; i < _renderers.Length; i++)
                {
                    var r = _renderers[i];
                    if (r == null) continue;
                    // 如果Renderer所在层级任意父节点带 IgnoreHoverDarken，则跳过
                    if (r.GetComponentInParent<IgnoreHoverDarken>() != null) continue;
                    tmp.Add(r);
                }
                _renderers = tmp.ToArray();
            }

            _baseColors = new Color[_renderers.Length];
            for (var i = 0; i < _renderers.Length; i++)
            {
                var r = _renderers[i];
                if (r == null)
                {
                    _baseColors[i] = Color.white;
                    continue;
                }

                // 用 sharedMaterial 读取原始颜色（不触发材质实例化）
                var mat = r.sharedMaterial;
                if (mat == null)
                {
                    _baseColors[i] = Color.white;
                    continue;
                }

                if (mat.HasProperty(BaseColorId))
                {
                    _baseColors[i] = mat.GetColor(BaseColorId);
                }
                else if (mat.HasProperty(ColorId))
                {
                    _baseColors[i] = mat.GetColor(ColorId);
                }
                else
                {
                    _baseColors[i] = Color.white;
                }
            }

            _block = new MaterialPropertyBlock();
        }

        private void Apply(bool hovered, bool force)
        {
            if (_renderers == null || _baseColors == null || _block == null)
            {
                CacheRenderersAndBaseColors();
            }

            for (var i = 0; i < _renderers.Length; i++)
            {
                var r = _renderers[i];
                if (r == null) continue;

                var c = _baseColors[i];
                if (hovered)
                {
                    c = new Color(c.r * _darkenMultiplier, c.g * _darkenMultiplier, c.b * _darkenMultiplier, c.a);
                }

                if (_flashColor.HasValue)
                {
                    var fc = _flashColor.Value;
                    c = new Color(fc.r, fc.g, fc.b, c.a);
                }

                _block.Clear();
                _block.SetColor(BaseColorId, c);
                _block.SetColor(ColorId, c);
                r.SetPropertyBlock(_block);
            }
        }

        private System.Collections.IEnumerator FlashRoutine(Color color, float duration)
        {
            _flashColor = color;
            Apply(_isHovered, force: true);

            yield return new WaitForSeconds(duration);

            _flashColor = null;
            _flashRoutine = null;
            Apply(_isHovered, force: true);
        }
    }
}

