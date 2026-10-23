#!/usr/bin/env python3
"""本地自检：把「不需要 Mac 就能查的部分」全查一遍。

用法（在工程根目录或任意位置）：
    python Scripts/verify_local.py

它不能替代 CI 编译 —— 只能提前抓住配置错误、版本漂移、SHA 没固定这类问题，
这类错误在 CI 上往往要等 8 分钟才报出来，而且报错位置很绕。
"""
import glob
import os
import re
import shutil
import subprocess
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
PASS, FAIL, WARN, INFO = [], [], [], []


def ok(msg):
    PASS.append(msg)


def bad(msg):
    FAIL.append(msg)


def warn(msg):
    WARN.append(msg)


def info(msg):
    INFO.append(msg)


def load_yaml(path):
    try:
        import yaml
    except ImportError:
        return None, "未安装 PyYAML，跳过解析（pip install pyyaml）"
    try:
        with open(path, encoding="utf-8") as f:
            return yaml.safe_load(f), None
    except Exception as exc:  # noqa: BLE001
        return None, str(exc)


def check_required_files():
    required = [
        "project.yml",
        ".ios-ci.yml",
        ".gitignore",
        ".github/workflows/build-test.yml",
        ".github/workflows/build-unsigned-ipa.yml",
        ".github/workflows/live-preview.yml",
        "Core/Package.swift",
        "Core/Sources/Core/CalculatorEngine.swift",
        "App/MyApp.swift",
        "App/ContentView.swift",
    ]
    missing = [p for p in required if not os.path.exists(os.path.join(ROOT, p))]
    if missing:
        for p in missing:
            bad("缺少文件: " + p)
    else:
        ok("骨架文件齐全（%d 个）" % len(required))


def check_project_yml():
    path = os.path.join(ROOT, "project.yml")
    if not os.path.exists(path):
        return
    data, err = load_yaml(path)
    if err:
        warn("project.yml 未解析: " + err)
        return

    name = data.get("name")
    if name:
        ok("工程名: %s" % name)
    else:
        bad("project.yml 里没有 name")

    target = (data.get("options") or {}).get("deploymentTarget") or {}
    ios = str(target.get("iOS", ""))
    if ios == "15.0":
        ok("部署目标 iOS 15.0（正好是 Xcode 26 的下限）")
    elif ios:
        warn("部署目标是 iOS %s，不是 15.0 —— 你的真机 iOS 15 会装不上" % ios)
    else:
        bad("project.yml 里没写 options.deploymentTarget.iOS")

    targets = data.get("targets") or {}
    schemes = data.get("schemes") or {}
    if name and name not in schemes:
        warn("schemes 里没有 %s，CI 选 scheme 会失败" % name)
    else:
        ok("scheme 已定义: %s" % name)
    if name not in targets:
        warn("targets 里没有同名的 %s" % name)


def check_ios_ci():
    path = os.path.join(ROOT, ".ios-ci.yml")
    if not os.path.exists(path):
        return
    data, err = load_yaml(path)
    if err:
        warn(".ios-ci.yml 未解析: " + err)
        return
    for key in ("project", "scheme", "bundle_id"):
        if not data.get(key):
            bad(".ios-ci.yml 必填项缺失: %s" % key)
    if data.get("scheme"):
        ok(".ios-ci.yml scheme = %s" % data["scheme"])

    gen = str(data.get("generate_command", ""))
    if "xcodegen" in gen:
        ok("CI 会现生成工程（generate_command: xcodegen generate）")
    else:
        warn("generate_command 不是 xcodegen，无 Mac 时工程文件将无人维护")

    tool = data.get("toolchain") or {}
    if tool.get("xcode") and tool.get("ios"):
        ok("工具链已固定: Xcode %s / iOS %s" % (tool.get("xcode"), tool.get("ios")))
    else:
        warn("toolchain 没固定，快照参考图会跨版本漂移")

    if data.get("testflight"):
        warn("这工程不该启用 TestFlight（TrollStore 路线不需要），可删掉 testflight 段")


def check_workflows():
    wf_dir = os.path.join(ROOT, ".github/workflows")
    if not os.path.isdir(wf_dir):
        bad("没有 .github/workflows 目录")
        return

    pin = re.compile(r"uses:\s*wenjinliuu/ios-ci-workflows/[^\s@]+@([A-Za-z0-9._\-]+)")
    sha = re.compile(r"^[0-9a-f]{40}$")
    for name in sorted(os.listdir(wf_dir)):
        if not name.endswith((".yml", ".yaml")):
            continue
        with open(os.path.join(wf_dir, name), encoding="utf-8") as f:
            text = f.read()
        _, err = load_yaml(os.path.join(wf_dir, name))
        if err and "PyYAML" not in err:
            bad("%s 语法错误: %s" % (name, err))
            continue
        for ref in pin.findall(text):
            if sha.match(ref):
                ok("%s 固定到 SHA %s…" % (name, ref[:8]))
            else:
                bad("%s 引用的是 @%s —— 必须写死 40 位提交 SHA" % (name, ref))
        if "AGENT_PREVIEW_PASSWORD" in text and "secrets." not in text:
            warn("%s 用了预览密码但没从 secrets 取" % name)


def check_core_purity():
    """Core 绝不能 import UIKit / SwiftUI，否则 Windows 上编不了。
    只匹配行首真正的 import 语句，注释里提到这些词不算。
    """
    core_dir = os.path.join(ROOT, "Core/Sources/Core")
    if not os.path.isdir(core_dir):
        return
    banned = re.compile(r"^\s*import\s+(UIKit|SwiftUI|AppKit|WatchKit)\b", re.MULTILINE)
    violations = []
    for base, _, files in os.walk(core_dir):
        for f in files:
            if not f.endswith(".swift"):
                continue
            with open(os.path.join(base, f), encoding="utf-8") as fh:
                body = fh.read()
            for hit in banned.findall(body):
                violations.append("%s: import %s" % (f, hit))
    if violations:
        for v in violations:
            bad("Core 层污染（本地将无法编译）: " + v)
    else:
        ok("Core 层干净，未 import UIKit/SwiftUI")


SWIFT_ROOTS = [
    r"D:\Swift",
    os.path.expandvars(r"%LOCALAPPDATA%\Programs\Swift"),
]


def find_swift():
    """优先用 PATH，其次扫已知安装根目录（D:\\Swift 或默认位置）。"""
    exe = shutil.which("swift")
    if exe:
        return exe
    for root in SWIFT_ROOTS:
        hits = glob.glob(os.path.join(root, "Toolchains", "*", "usr", "bin", "swift.exe"))
        if hits:
            return hits[0]
    return None


def sanitize_env():
    """Windows 环境变量名不区分大小写，Swift 读到大小写重复的键会直接崩溃。

    这里做去重：同名（忽略大小写）只保留一份，优先保留全大写形式。
    """
    seen = {}
    dropped = []
    for key in os.environ:
        low = key.lower()
        if low in seen:
            keep = seen[low]
            if key.isupper() and not keep.isupper():
                dropped.append(keep)
                seen[low] = key
            else:
                dropped.append(key)
        else:
            seen[low] = key
    env = {k: v for k, v in os.environ.items() if k not in dropped}
    if dropped:
        info("已清理大小写重复的环境变量: " + ", ".join(sorted(dropped)))
    return env


def swift_env(swift_exe):
    """还原安装器配置的环境：toolchain bin + runtimes bin + SDKROOT。"""
    toolchain_bin = os.path.dirname(os.path.abspath(swift_exe))
    # <root>\Toolchains\<ver>\usr\bin -> 往上四层才是安装根目录
    root = toolchain_bin
    for _ in range(4):
        root = os.path.dirname(root)
    if not os.path.isdir(os.path.join(root, "Platforms")):
        raise RuntimeError("无法从 %s 推出安装根目录" % swift_exe)

    env = sanitize_env()
    paths = [toolchain_bin]
    for r in glob.glob(os.path.join(root, "Runtimes", "*", "usr", "bin")):
        paths.append(r)
    sdks = glob.glob(os.path.join(root, "Platforms", "*", "Windows.platform",
                                  "Developer", "SDKs", "Windows.sdk"))
    if not sdks:
        raise RuntimeError("找不到 Windows.sdk，Swift 安装不完整")
    env["SDKROOT"] = max(sdks)
    env["PATH"] = os.pathsep.join(paths) + os.pathsep + env.get("PATH", "")
    return env


def run_swift_tests():
    swift = find_swift()
    if not swift:
        warn("本机没有 swift，跳过 Core 测试（装 Swift for Windows 后这里能秒级反馈）")
        return
    try:
        env = swift_env(swift)
    except RuntimeError as exc:
        bad("Swift 环境准备失败: %s" % exc)
        return
    ver = subprocess.run([swift, "--version"], env=env,
                         capture_output=True, text=True)
    if ver.returncode == 0:
        info("Swift: " + ver.stdout.strip().splitlines()[0])
    else:
        bad("swift 无法启动: " + (ver.stderr or ver.stdout).strip()[:200])
        return
    core = os.path.join(ROOT, "Core")
    print("\n运行 Core 单元测试…")
    proc = subprocess.run([swift, "test"], cwd=core, env=env)
    if proc.returncode == 0:
        ok("Core 单元测试全部通过")
    else:
        bad("Core 单元测试失败（退出码 %d）" % proc.returncode)


def main():
    os.chdir(ROOT)
    print("检查目录: %s\n" % ROOT)
    check_required_files()
    check_project_yml()
    check_ios_ci()
    check_workflows()
    check_core_purity()
    run_swift_tests()

    print()
    for m in INFO:
        print("  [INFO] " + m)
    for m in PASS:
        print("  [OK]   " + m)
    for m in WARN:
        print("  [WARN] " + m)
    for m in FAIL:
        print("  [FAIL] " + m)

    print("\n本地无法验证、只能交给 CI 的：编译、链接、模拟器运行、界面渲染、真机安装。")
    print("结论: %d 通过 / %d 警告 / %d 失败" % (len(PASS), len(WARN), len(FAIL)))
    return 1 if FAIL else 0


if __name__ == "__main__":
    sys.exit(main())
