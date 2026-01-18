using UnityEngine;

namespace ProjectW.SkillTest
{
    /// <summary>
    /// PlayMode下定位Missing Script来源（一次性打印）。
    /// 仅用于测试环境排查，后续可删除。
    /// </summary>
    public sealed class MissingScriptRuntimeReporter : MonoBehaviour
    {
        [SerializeField] private bool _runOnce = true;

        private bool _done;

        private void Update()
        {
            if (_done) return;
            if (_runOnce) _done = true;

            var gos = FindObjectsByType<GameObject>(FindObjectsInactive.Include, FindObjectsSortMode.None);
            var missingCount = 0;

            foreach (var go in gos)
            {
                if (go == null) continue;
                var monos = go.GetComponents<MonoBehaviour>();
                for (var i = 0; i < monos.Length; i++)
                {
                    if (monos[i] == null)
                    {
                        missingCount++;
                        Debug.LogError($"[MissingScriptRuntimeReporter] MissingScript on GO: {GetPath(go.transform)}", go);
                    }
                }
            }

            if (missingCount == 0)
            {
                Debug.Log("[MissingScriptRuntimeReporter] No missing scripts found in PlayMode objects.");
            }
        }

        private static string GetPath(Transform t)
        {
            if (t == null) return "<null>";
            var path = t.name;
            while (t.parent != null)
            {
                t = t.parent;
                path = $"{t.name}/{path}";
            }
            return path;
        }
    }
}

