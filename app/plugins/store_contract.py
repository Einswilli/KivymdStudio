from __future__ import annotations

from typing import Any

from pydantic import BaseModel, Field


class PluginPublisher(BaseModel):
    id: str = ""
    name: str = "Unknown Publisher"
    verified: bool = False
    website: str = ""


class PluginStoreAsset(BaseModel):
    download_url: str = Field(default="", alias="downloadUrl")
    archive_hash: str = Field(default="", alias="archiveHash")
    archive_hash_algorithm: str = Field(default="sha256", alias="archiveHashAlgorithm")
    signature: str = ""
    signature_algorithm: str = Field(default="", alias="signatureAlgorithm")

    class Config:
        populate_by_name = True


class PluginStoreItem(BaseModel):
    id: str
    display_name: str = Field(default="", alias="displayName")
    version: str = "0.0.0"
    author: str = "unknown"
    description: str = ""
    license: str = ""
    pricing: str = "free"
    verified: bool = False
    publisher: PluginPublisher = Field(default_factory=PluginPublisher)
    manifest: dict[str, Any] = Field(default_factory=dict)
    manifest_hash: str = Field(default="", alias="manifestHash")
    asset: PluginStoreAsset = Field(default_factory=PluginStoreAsset)
    screenshots: list[str] = Field(default_factory=list)
    tags: list[str] = Field(default_factory=list)
    permissions: list[str] = Field(default_factory=list)
    contributions: dict[str, Any] = Field(default_factory=dict)

    class Config:
        populate_by_name = True

    @classmethod
    def from_api(cls, raw: dict[str, Any]) -> "PluginStoreItem":
        manifest = raw.get("manifest") if isinstance(raw.get("manifest"), dict) else {}
        publisher = raw.get("publisher") if isinstance(raw.get("publisher"), dict) else {}
        asset = raw.get("asset") if isinstance(raw.get("asset"), dict) else {}
        if not asset:
            asset = {
                "downloadUrl": raw.get("downloadUrl")
                or raw.get("download_url")
                or raw.get("archiveUrl")
                or raw.get("archive_url")
                or manifest.get("downloadUrl")
                or "",
                "archiveHash": raw.get("archiveHash")
                or raw.get("archive_hash")
                or raw.get("sha256")
                or "",
                "archiveHashAlgorithm": raw.get("archiveHashAlgorithm")
                or raw.get("archive_hash_algorithm")
                or "sha256",
                "signature": raw.get("signature") or "",
                "signatureAlgorithm": raw.get("signatureAlgorithm")
                or raw.get("signature_algorithm")
                or "",
            }
        item_id = str(raw.get("id") or raw.get("name") or manifest.get("name") or "").strip()
        return cls(
            id=item_id,
            displayName=raw.get("displayName")
            or raw.get("display_name")
            or manifest.get("display_name")
            or item_id,
            version=raw.get("version") or manifest.get("version") or "0.0.0",
            author=raw.get("author") or manifest.get("author") or "unknown",
            description=raw.get("description") or manifest.get("description") or "",
            license=raw.get("license") or manifest.get("license") or "",
            pricing=raw.get("pricing") or "free",
            verified=bool(raw.get("verified") or publisher.get("verified") or False),
            publisher=publisher,
            manifest=manifest,
            manifestHash=raw.get("manifestHash") or raw.get("manifest_hash") or "",
            asset=asset,
            screenshots=list(raw.get("screenshots") or []),
            tags=list(raw.get("tags") or raw.get("keywords") or manifest.get("keywords") or []),
            permissions=list(raw.get("permissions") or manifest.get("permissions") or []),
            contributions=raw.get("contributions") or {},
        )

