using UnityEngine;

namespace ProjectW.SkillTest
{
    /// <summary>
    /// DebugDraw服务：供Lua侧范围显示调用。
    /// 说明：
    /// - 通过 Debug.DrawLine 绘制，支持 duration 与 depthTest。
    /// - 支持Lua技能坐标系或Unity坐标系两种调用。
    /// </summary>
    public static class DebugDrawService
    {
        public static void DrawLineSkillCoord(
            float ox, float oy, float oz,
            float tx, float ty, float tz,
            float r, float g, float b,
            bool depthTest,
            float duration)
        {
            var oSkill = new Vector3(ox, oy, oz);
            var tSkill = new Vector3(tx, ty, tz);
            var oUnity = CoordAdapter.SkillToUnity(oSkill);
            var tUnity = CoordAdapter.SkillToUnity(tSkill);
            var color = CoordAdapter.Color255(r, g, b);

            // Debug.DrawLine 会自行管理 duration；无需每帧重绘
            Debug.DrawLine(oUnity, tUnity, color, Mathf.Max(0f, duration), depthTest);
        }

        public static void DrawLineUnityCoord(
            float ox, float oy, float oz,
            float tx, float ty, float tz,
            float r, float g, float b,
            bool depthTest,
            float duration)
        {
            var oUnity = new Vector3(ox, oy, oz);
            var tUnity = new Vector3(tx, ty, tz);
            var color = CoordAdapter.Color255(r, g, b);
            Debug.DrawLine(oUnity, tUnity, color, Mathf.Max(0f, duration), depthTest);
        }
    }
}

