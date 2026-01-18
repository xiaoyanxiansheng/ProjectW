using System;
using ProjectW.LuaBridge;
using ProjectW.Rendering;
using UnityEngine;

namespace ProjectW.SkillTest
{
    /// <summary>
    /// 测试用：伤害/治疗表现
    /// - 头顶飘字（-1 / +1）
    /// - 模型闪色（0.5s）：伤害红色、治疗绿色
    /// 
    /// 由Lua通过 LuaManager 注入的全局函数回调触发。
    /// </summary>
    public sealed class DamageHealVfxService : MonoBehaviour
    {
        private static DamageHealVfxService _instance;

        public static DamageHealVfxService Instance
        {
            get
            {
                if (_instance != null) return _instance;
                var go = new GameObject("DamageHealVfxService");
                DontDestroyOnLoad(go);
                _instance = go.AddComponent<DamageHealVfxService>();
                return _instance;
            }
        }

        /// <summary>
        /// Lua回调入口：显示伤害/治疗表现
        /// </summary>
        /// <param name="targetInsId">目标insId</param>
        /// <param name="delta">-1=伤害，+1=治疗（当前阶段固定值）</param>
        public static void Play(int targetInsId, int delta)
        {
            Instance.PlayInternal(targetInsId, delta);
        }

        private void PlayInternal(int targetInsId, int delta)
        {
            if (targetInsId <= 0) return;

            if (!TryGetTargetTransform(targetInsId, out var t) || t == null) return;

            var isHeal = delta > 0;
            var color = isHeal ? new Color(0.1f, 1f, 0.1f, 1f) : new Color(1f, 0.1f, 0.1f, 1f);
            var text = isHeal ? $"+{Mathf.Abs(delta)}" : $"-{Mathf.Abs(delta)}";

            var headPos = GetHeadPosition(t);
            FloatingText.Create(text, headPos, color, lifeTime: 0.5f);

            var flash = t.GetComponent<HoverDarkenByPropertyBlock>();
            if (flash == null)
            {
                flash = t.gameObject.AddComponent<HoverDarkenByPropertyBlock>();
            }
            flash.Flash(color, 0.5f);
        }

        private static bool TryGetTargetTransform(int insId, out Transform t)
        {
            if (EntityBridge.TryGetTransform(insId, out t)) return true;

            // 兜底：场景搜索（测试环境够用）
            var proxies = FindObjectsByType<EntityProxy>(FindObjectsInactive.Exclude, FindObjectsSortMode.None);
            foreach (var p in proxies)
            {
                if (p != null && p.InsId == insId)
                {
                    t = p.transform;
                    return true;
                }
            }

            t = null;
            return false;
        }

        private static Vector3 GetHeadPosition(Transform t)
        {
            // 优先根据Renderer bounds估算头顶
            var rs = t.GetComponentsInChildren<Renderer>(includeInactive: true);
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
                if (has)
                {
                    return b.center + Vector3.up * (b.extents.y + 0.2f);
                }
            }

            // 兜底：固定高度
            return t.position + Vector3.up * 1.8f;
        }
    }
}

