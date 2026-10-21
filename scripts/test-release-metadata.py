import base64
import hashlib
import importlib.util
from pathlib import Path
import tempfile
import unittest
import xml.etree.ElementTree as xml


class ReleaseMetadataTests(unittest.TestCase):
    def setUp(self):
        spec = importlib.util.spec_from_file_location(
            "releaseMetadata", Path(__file__).with_name("release-metadata.py")
        )
        self.metadata = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(self.metadata)
        self.signature = base64.b64encode(bytes(64)).decode()

    def testPublicReleaseMetadata(self):
        with tempfile.TemporaryDirectory() as directory:
            archive = Path(directory) / "Neat-0.1.0.zip"
            archive.write_bytes(b"signed archive")
            self.metadata.generateMetadata(archive, "0.1.0", "116", self.signature)
            feed = xml.parse(archive.with_name("appcast.xml"))
            namespace = "{http://www.andymatuschak.org/xml-namespaces/sparkle}"
            enclosure = feed.find("./channel/item/enclosure")
            self.assertEqual(enclosure.get(namespace + "version"), "116")
            self.assertEqual(enclosure.get(namespace + "shortVersionString"), "0.1.0")
            self.assertEqual(enclosure.get(namespace + "edSignature"), self.signature)
            self.assertEqual(enclosure.get("length"), str(archive.stat().st_size))
            self.assertEqual(enclosure.get("url"), "https://github.com/hangs0908/neat/releases/download/v0.1.0/Neat-0.1.0.zip")
            self.assertIsNone(feed.find("./channel/item/" + namespace + "channel"))
            self.assertEqual(feed.findtext("./channel/item/" + namespace + "minimumSystemVersion"), "27.0")
            cask = archive.with_name("neat.rb").read_text()
            self.assertIn(hashlib.sha256(archive.read_bytes()).hexdigest(), cask)
            self.assertIn('depends_on arch: :arm64', cask)
            self.assertIn('depends_on macos: ">= :golden_gate"', cask)
            self.assertIn('auto_updates true', cask)

    def testRejectsInvalidReleaseInputs(self):
        with tempfile.TemporaryDirectory() as directory:
            archive = Path(directory) / "Neat-0.1.0.zip"
            archive.write_bytes(b"signed archive")
            for version, build, signature in [
                ("0.1.0-beta", "116", self.signature),
                ("../0.1.0", "116", self.signature),
                ("0.1.0", "0", self.signature),
                ("0.1.0", "abc", self.signature),
                ("0.1.0", "116", "invalid"),
                ("0.1.0", "116", base64.b64encode(bytes(32)).decode()),
            ]:
                with self.subTest(version=version, build=build, signature=signature):
                    with self.assertRaises(ValueError):
                        self.metadata.generateMetadata(archive, version, build, signature)
            self.assertFalse(archive.with_name("appcast.xml").exists())

    def testPublishedFeedMustMatchTagAndDownload(self):
        with tempfile.TemporaryDirectory() as directory:
            directory = Path(directory)
            archive = directory / "Neat-0.1.0.zip"
            archive.write_bytes(b"signed archive")
            self.metadata.generateMetadata(archive, "0.1.0", "116", self.signature)
            output = directory / "Casks" / "neat.rb"
            self.metadata.generatePublishedCask("v0.1.0", directory, output)
            self.assertEqual(output.read_bytes(), (directory / "neat.rb").read_bytes())
            feed = directory / "appcast.xml"
            feed.write_text(feed.read_text().replace("https://github.com", "https://example.com"))
            with self.assertRaises(ValueError):
                self.metadata.generatePublishedCask("v0.1.0", directory, output)
            with self.assertRaises(ValueError):
                self.metadata.generatePublishedCask("v0.2.0", directory, output)


if __name__ == "__main__":
    unittest.main()
