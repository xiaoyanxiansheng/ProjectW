using System.Collections.Generic;
using UnityEditor;
using UnityEditor.SceneManagement;
using UnityEngine;
using UnityEngine.SceneManagement;

namespace ProjectW.EditorTools
{
    /// <summary>
    /// 查找并（可选）移除场景里的Missing Script组件。
    /// 目的：避免控制台出现“The referenced script (Unknown) on this Behaviour is missing!”影响测试。
    /// </summary>
    public static class MissingScriptUtility
    {
        [MenuItem("Tools/ProjectW/Find Missing Scripts (Active Scene)")]
        public static void FindMissingScriptsInActiveScene()
        {
            var scene = SceneManager.GetActiveScene();
            if (!scene.IsValid() || !scene.isLoaded)
            {
                Debug.LogWarning("[MissingScriptUtility] Active scene not loaded.");
                return;
            }

            var roots = scene.GetRootGameObjects();
            var missingCount = 0;
            var goCount = 0;

            foreach (var root in roots)
            {
                if (root == null) continue;
                goCount += FindMissingScriptsRecursive(root.transform, ref missingCount);
            }

            Debug.Log($"[MissingScriptUtility] ActiveScene='{scene.path}' scanned. GameObjects={goCount}, MissingScripts={missingCount}");
        }

        [MenuItem("Tools/ProjectW/Find Missing Scripts (All Loaded Objects)")]
        public static void FindMissingScriptsInAllLoadedObjects()
        {
            var all = Resources.FindObjectsOfTypeAll<GameObject>();
            var missingCount = 0;
            var logged = 0;

            foreach (var go in all)
            {
                if (go == null) continue;

                var monos = go.GetComponents<MonoBehaviour>();
                for (var i = 0; i < monos.Length; i++)
                {
                    if (monos[i] == null)
                    {
                        missingCount++;
                        if (logged < 30)
                        {
                            var isAsset = EditorUtility.IsPersistent(go);
                            Debug.LogWarning($"[MissingScriptUtility] MissingScript: {GetPath(go.transform)} (persistentAsset={isAsset})", go);
                            logged++;
                        }
                    }
                }
            }

            Debug.Log($"[MissingScriptUtility] AllLoadedObjects scanned. MissingScripts={missingCount}, Logged={logged}");
        }

        [MenuItem("Tools/ProjectW/Remove Missing Scripts (Active Scene)")]
        public static void RemoveMissingScriptsInActiveScene()
        {
            var scene = SceneManager.GetActiveScene();
            if (!scene.IsValid() || !scene.isLoaded)
            {
                Debug.LogWarning("[MissingScriptUtility] Active scene not loaded.");
                return;
            }

            var roots = scene.GetRootGameObjects();
            var removed = 0;

            foreach (var root in roots)
            {
                if (root == null) continue;
                removed += RemoveMissingScriptsRecursive(root.transform);
            }

            if (removed > 0)
            {
                EditorSceneManager.MarkSceneDirty(scene);
            }

            Debug.Log($"[MissingScriptUtility] ActiveScene='{scene.path}' removed MissingScripts={removed}");
        }

        private static int FindMissingScriptsRecursive(Transform t, ref int missingCount)
        {
            var goCount = 1;
            var go = t.gameObject;

            // Missing脚本会表现为 GetComponents<MonoBehaviour>() 返回 null 项
            var monos = go.GetComponents<MonoBehaviour>();
            for (var i = 0; i < monos.Length; i++)
            {
                if (monos[i] == null)
                {
                    missingCount++;
                    Debug.LogWarning($"[MissingScriptUtility] MissingScript: {GetPath(t)}", go);
                }
            }

            for (var i = 0; i < t.childCount; i++)
            {
                goCount += FindMissingScriptsRecursive(t.GetChild(i), ref missingCount);
            }

            return goCount;
        }

        private static int RemoveMissingScriptsRecursive(Transform t)
        {
            var go = t.gameObject;
            var removed = GameObjectUtility.RemoveMonoBehavioursWithMissingScript(go);

            for (var i = 0; i < t.childCount; i++)
            {
                removed += RemoveMissingScriptsRecursive(t.GetChild(i));
            }

            return removed;
        }

        private static string GetPath(Transform t)
        {
            var stack = new Stack<string>();
            while (t != null)
            {
                stack.Push(t.name);
                t = t.parent;
            }
            return string.Join("/", stack);
        }
    }
}

