using ProjectW.Rendering;
using UnityEngine;

namespace ProjectW.SkillTest
{
    /// <summary>
    /// 挂在实体根节点：显示血条 + 死亡变暗
    /// </summary>
    public sealed class EntityHealthView : MonoBehaviour
    {
        [SerializeField] private int _insId;
        [SerializeField] private bool _hideWhenDead = false;

        private WorldHealthBar _bar;
        private HoverDarkenByPropertyBlock _darken;
        private bool _lastDead;

        public void BindInsId(int insId)
        {
            if (insId <= 0) return;
            _insId = insId;
        }

        private void OnEnable()
        {
            EnsureBar();
        }

        private void EnsureBar()
        {
            if (_bar != null) return;

            var child = transform.Find("WorldHealthBar");
            if (child != null) _bar = child.GetComponent<WorldHealthBar>();

            if (_bar == null)
            {
                var go = new GameObject("WorldHealthBar");
                go.transform.SetParent(transform, worldPositionStays: false);
                _bar = go.AddComponent<WorldHealthBar>();
            }

            _bar.BindTarget(transform);
        }

        private void Update()
        {
            if (_insId <= 0) return;
            EnsureBar();

            if (!EntityHealthService.TryGet(_insId, out var hp, out var maxHp, out var dead))
            {
                // 未收到上报时先按满血
                hp = 100;
                maxHp = 100;
                dead = false;
            }

            if (_bar != null)
            {
                if (_hideWhenDead && dead)
                {
                    _bar.SetVisible(false);
                }
                else
                {
                    _bar.SetVisible(true);
                    _bar.SetValue(hp, maxHp);
                }
            }

            if (dead != _lastDead)
            {
                ApplyDeathVisual(dead);
                _lastDead = dead;
            }
        }

        private void ApplyDeathVisual(bool dead)
        {
            // 复用现有 PropertyBlock 方案，不换材质、不实例化材质
            _darken ??= GetComponent<HoverDarkenByPropertyBlock>() ?? gameObject.AddComponent<HoverDarkenByPropertyBlock>();

            if (dead)
            {
                _darken.SetDarkenMultiplier(0.25f);
                _darken.SetHovered(true);
            }
            else
            {
                _darken.SetHovered(false);
            }
        }
    }
}

