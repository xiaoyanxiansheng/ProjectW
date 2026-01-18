using UnityEngine;

namespace ProjectW.SkillTest
{
    /// <summary>
    /// 坐标系适配（必须统一，避免测试歧义）
    ///
    /// Lua技能坐标系（SkillCoord）：
    /// - 平面：x/y
    /// - 高度：z
    ///
    /// Unity世界坐标（UnityCoord）：
    /// - 平面：x/z
    /// - 高度：y
    ///
    /// 映射：
    /// - Unity = (lua.x, lua.z, lua.y)
    /// - Lua   = (unity.x, unity.z, unity.y)
    /// </summary>
    public static class CoordAdapter
    {
        /// <summary>
        /// Dota2单位到Unity单位的缩放（可根据项目需要调整）
        /// 例如：600 Dota单位 -> 6 Unity单位
        /// </summary>
        public const float DotaUnitScale = 0.0254f;

        public static Vector3 SkillToUnity(Vector3 skill)
        {
            return new Vector3(skill.x * DotaUnitScale, skill.z * DotaUnitScale, skill.y * DotaUnitScale);
        }

        public static Vector3 UnityToSkill(Vector3 unity)
        {
            return new Vector3(unity.x / DotaUnitScale, unity.z / DotaUnitScale, unity.y / DotaUnitScale);
        }

        public static Vector3 SkillToUnityDir(Vector3 skillDir)
        {
            // 方向同映射（高度分量通常为0）
            return new Vector3(skillDir.x, skillDir.z, skillDir.y).normalized;
        }

        public static Vector3 UnityToSkillDir(Vector3 unityDir)
        {
            return new Vector3(unityDir.x, unityDir.z, unityDir.y).normalized;
        }

        public static Color Color255(float r, float g, float b)
        {
            return new Color(Mathf.Clamp01(r / 255f), Mathf.Clamp01(g / 255f), Mathf.Clamp01(b / 255f), 1f);
        }
    }
}

