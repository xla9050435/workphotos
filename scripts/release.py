"""一键发布到 GitHub Release（需要用户提供 token）。

用法：
  C:/Users/19629/.workbuddy/binaries/python/envs/default/Scripts/python.exe \
      scripts/release.py <GITHUB_TOKEN> [--skip-build]

步骤（幂等，失败可重跑）：
  1. push main（含所有本地提交）
  2. 按 pubspec.yaml 的 version 打 tag `v1.3.1+22` 并推送
  3. 创建 Release（body 取最近一条 commit 的信息摘要）
  4. 上传 app-release.apk 作为资产
"""
import json
import os
import sys
import urllib.request
from pathlib import Path

REPO = "xla9050435/workphotos"
APK = Path("build/app/outputs/flutter-apk/app-release.apk")
PUBSPEC = Path("pubspec.yaml")


def api(method: str, path: str, token: str, payload: dict | None = None,
        raw: bytes | None = None, content_type: str | None = None) -> tuple[int, dict | bytes]:
    """返回 (status, 响应)。4xx/5xx 由调用方按需处理。"""
    url = path if path.startswith("http") else f"https://api.github.com/repos/{REPO}/{path}"
    data = json.dumps(payload).encode() if payload is not None else raw
    req = urllib.request.Request(url, data=data, method=method)
    req.add_header("Authorization", f"token {token}")
    req.add_header("Accept", "application/vnd.github+json")
    req.add_header("User-Agent", "workphotos-release")
    if content_type:
        req.add_header("Content-Type", content_type)
    try:
        with urllib.request.urlopen(req, timeout=60) as r:
            body = r.read()
            return r.status, json.loads(body) if body.strip().startswith(b"{") else body
    except urllib.error.HTTPError as e:
        return e.code, json.loads(e.read() or b"{}")


def read_version() -> tuple[str, str]:
    for line in PUBSPEC.read_text(encoding="utf-8").splitlines():
        if line.startswith("version:"):
            ver = line.split(":", 1)[1].strip()
            name, _, build = ver.partition("+")
            return name, build or "0"
    raise SystemExit("pubspec.yaml 里没找到 version 行")


def sh(cmd: str) -> int:
    print(f"$ {cmd}")
    return os.system(cmd)


def main() -> None:
    if len(sys.argv) < 2:
        raise SystemExit("用法: release.py <GITHUB_TOKEN> [--skip-build]")
    token = sys.argv[1]
    if len(sys.argv) <= 2 or sys.argv[2] != "--skip-build":
        # 1. 推送 main
        if sh("git push origin main") != 0:
            raise SystemExit("git push 失败，检查网络/凭据")
    ver, build = read_version()
    tag = f"v{ver}+{build}"
    print(f"== 发布 {tag} ==")

    # 2. 推 tag（强制覆盖，允许重发）
    sh(f'git tag -f "{tag}"')
    if sh(f'git push -f origin "{tag}"') != 0:
        raise SystemExit("tag 推送失败")

    # 3. 创建 Release（已存在则跳过）
    status, rel = api("POST", "releases", token, payload={
        "tag_name": tag,
        "name": f"工作照片 v{ver} ({build})",
        "body": f"版本 {tag}\n\n详见对应 commit 的说明。",
        "draft": False,
        "prerelease": False,
    })
    if status == 422:
        print("Release 已存在，复用")
        status, rel = api("GET", f"releases/tags/{tag}", token)
    if status not in (200, 201):
        raise SystemExit(f"创建 Release 失败: {status} {rel}")

    if not isinstance(rel, dict):
        raise SystemExit("响应异常")
    upload_url = rel["upload_url"].split("{")[0]
    print(f"Release id={rel['id']} upload_url 就绪")

    # 4. 上传 APK
    asset_name = f"work_photos_v{ver}+{build}.apk"
    apk_bytes = APK.read_bytes()
    status, _ = api("POST", upload_url + f"?name={asset_name}", token,
                    raw=apk_bytes, content_type="application/vnd.android.package-archive")
    if status != 201:
        raise SystemExit(f"APK 上传失败: {status}")
    print(f"== 完成: {rel.get('html_url')} ==")


if __name__ == "__main__":
    main()
