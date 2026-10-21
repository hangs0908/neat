import argparse
import base64
import binascii
import hashlib
from pathlib import Path
import re
import xml.etree.ElementTree as xml


def generateMetadata(archive, version, build, signature):
    if not re.fullmatch(r"(0|[1-9]\d*)\.(0|[1-9]\d*)\.(0|[1-9]\d*)", version):
        raise ValueError("공개 버전은 숫자 세 부분이어야 합니다.")
    if not re.fullmatch(r"[1-9]\d*", build):
        raise ValueError("빌드 번호는 양의 정수여야 합니다.")
    try:
        validSignature = len(base64.b64decode(signature, validate=True)) == 64
    except binascii.Error:
        validSignature = False
    if not validSignature:
        raise ValueError("유효한 EdDSA 서명이 필요합니다.")
    if archive.name != f"Neat-{version}.zip" or archive.stat().st_size == 0:
        raise ValueError("버전과 일치하는 비어 있지 않은 앱 ZIP이 필요합니다.")

    downloadUrl = f"https://github.com/hangs0908/neat/releases/download/v{version}/{archive.name}"
    sparkleNamespace = "http://www.andymatuschak.org/xml-namespaces/sparkle"
    xml.register_namespace("sparkle", sparkleNamespace)
    feed = xml.Element("rss", {"version": "2.0"})
    channel = xml.SubElement(feed, "channel")
    xml.SubElement(channel, "title").text = "Neat 업데이트"
    item = xml.SubElement(channel, "item")
    xml.SubElement(item, "title").text = f"Neat {version}"
    xml.SubElement(item, f"{{{sparkleNamespace}}}minimumSystemVersion").text = "27.0"
    xml.SubElement(item, "enclosure", {
        "url": downloadUrl,
        "length": str(archive.stat().st_size),
        "type": "application/octet-stream",
        f"{{{sparkleNamespace}}}version": build,
        f"{{{sparkleNamespace}}}shortVersionString": version,
        f"{{{sparkleNamespace}}}edSignature": signature,
    })
    xml.indent(feed)
    xml.ElementTree(feed).write(archive.with_name("appcast.xml"), encoding="utf-8", xml_declaration=True)
    checksum = hashlib.sha256(archive.read_bytes()).hexdigest()
    archive.with_name("neat.rb").write_text(f'''cask "neat" do
  version "{version}"
  sha256 "{checksum}"

  url "https://github.com/hangs0908/neat/releases/download/v#{{version}}/Neat-#{{version}}.zip"
  name "Neat"
  desc "메뉴 막대 아이콘 정리"
  homepage "https://github.com/hangs0908/neat"

  auto_updates true
  depends_on arch: :arm64
  depends_on macos: ">= :golden_gate"

  app "Neat.app"
end
''', encoding="utf-8")


def generatePublishedCask(tag, directory, output):
    version = tag.removeprefix("v")
    feedPath = directory / "appcast.xml"
    if feedPath.stat().st_size > 1024 * 1024:
        raise ValueError("앱캐스트 크기가 비정상적입니다.")
    enclosure = xml.parse(feedPath).find("./channel/item/enclosure")
    namespace = "{http://www.andymatuschak.org/xml-namespaces/sparkle}"
    expectedUrl = f"https://github.com/hangs0908/neat/releases/download/{tag}/Neat-{version}.zip"
    if enclosure is None or enclosure.get("url") != expectedUrl or enclosure.get(namespace + "shortVersionString") != version:
        raise ValueError("공개 태그와 일치하지 않는 앱캐스트입니다.")
    archive = directory / f"Neat-{version}.zip"
    if enclosure.get("length") != str(archive.stat().st_size):
        raise ValueError("공개 ZIP 크기가 앱캐스트와 다릅니다.")
    generateMetadata(archive, version, enclosure.get(namespace + "version", ""), enclosure.get(namespace + "edSignature", ""))
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_bytes((directory / "neat.rb").read_bytes())


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Neat 배포 메타데이터 생성")
    commands = parser.add_subparsers(dest="command", required=True)
    create = commands.add_parser("create")
    create.add_argument("archive", type=Path)
    create.add_argument("version")
    create.add_argument("build")
    create.add_argument("signature")
    published = commands.add_parser("published")
    published.add_argument("tag")
    published.add_argument("directory", type=Path)
    published.add_argument("output", type=Path)
    arguments = parser.parse_args()
    if arguments.command == "create":
        generateMetadata(arguments.archive, arguments.version, arguments.build, arguments.signature)
    else:
        generatePublishedCask(arguments.tag, arguments.directory, arguments.output)
