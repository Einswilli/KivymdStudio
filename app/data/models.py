from __future__ import annotations

from pathlib import Path

from ryx import (
    Model,
    CharField,
    TextField,
    BooleanField,
    IntField,
    DateTimeField,
    ForeignKey,
    JSONField,
)


class Project(Model):
    name = CharField(max_length=255)
    path = CharField(max_length=1024, unique=True)
    template = CharField(max_length=50, default="Empty")
    color = CharField(max_length=24, null=True)
    avatar = CharField(max_length=8, null=True)
    opened_at = DateTimeField(auto_now_add=True)
    is_active = BooleanField(default=True)

    class Meta:
        ordering = ["-opened_at"]


class FileHistory(Model):
    path = CharField(max_length=1024)
    display_name = CharField(max_length=255)
    language = CharField(max_length=20, default="text")
    opened_at = DateTimeField(auto_now_add=True)
    project = ForeignKey(Project, null=True, on_delete="SET NULL", related_name="files")

    class Meta:
        ordering = ["-opened_at"]


class EditorSession(Model):
    project = ForeignKey(Project, null=True, on_delete="CASCADE", related_name="sessions")
    workspace_path = CharField(max_length=1024, null=True)
    open_files = JSONField(null=True)
    active_file = CharField(max_length=1024, null=True)
    cursor_positions = JSONField(null=True)
    saved_at = DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ["-saved_at"]


class UserSnippet(Model):
    name = CharField(max_length=100)
    prefix = CharField(max_length=50)
    body = TextField()
    language = CharField(max_length=20, default="python")
    scope = CharField(max_length=50, null=True)

    class Meta:
        ordering = ["name"]


class AICache(Model):
    prompt_hash = CharField(max_length=64, unique=True)
    response = TextField()
    provider = CharField(max_length=50)
    model = CharField(max_length=100)
    created_at = DateTimeField(auto_now_add=True)
    hit_count = IntField(default=1)

    class Meta:
        ordering = ["-created_at"]


class UserSettings(Model):
    key = CharField(max_length=255, unique=True)
    value = JSONField()
    updated_at = DateTimeField(auto_now_add=True)


class PluginInfo(Model):
    name = CharField(max_length=100, unique=True)
    version = CharField(max_length=20)
    author = CharField(max_length=100)
    description = TextField(null=True)
    manifest = JSONField()
    enabled = BooleanField(default=True)
    installed_at = DateTimeField(auto_now_add=True)
    installed_from = CharField(max_length=1024, null=True)
    manifest_hash = CharField(max_length=64, null=True)
    trusted = BooleanField(default=False)

    class Meta:
        ordering = ["name"]


class ToolInstallAudit(Model):
    provider_id = CharField(max_length=160)
    plugin_name = CharField(max_length=160, null=True)
    command = TextField()
    status = CharField(max_length=24)
    message = TextField(null=True)
    stdout = TextField(null=True)
    stderr = TextField(null=True)
    created_at = DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ["-created_at"]


ALL_MODELS = [
    Project,
    FileHistory,
    EditorSession,
    UserSnippet,
    AICache,
    UserSettings,
    PluginInfo,
    ToolInstallAudit,
]

MIGRATIONS_DIR = Path(__file__).with_name("migrations")


async def init_database(url: str | None = None) -> None:
    from app.core.settings import DATABASE_URL
    import ryx

    db_url = url or DATABASE_URL

    if not ryx.is_connected():
        await ryx.setup(db_url)

    await make_migrations()
    await migrate()


async def make_migrations() -> None:
    try:
        from ryx.migrations.autodetect import Autodetector

        detector = Autodetector(
            models=ALL_MODELS,
            migrations_dir=str(MIGRATIONS_DIR),
            app_label="ember",
        )
        operations = detector.detect()
        if operations:
            path = detector.write_migration(operations)
            print(f"[Ember] Created Ryx migration: {path.name}")
    except Exception as e:
        print(f"[Ember] Ryx makemigrations skipped: {e}")


async def migrate() -> None:
    try:
        from ryx.migrations.runner import MigrationRunner

        runner = MigrationRunner(
            ALL_MODELS,
            migrations_dir=str(MIGRATIONS_DIR),
            no_interactive=True,
        )
        await runner.migrate()
    except Exception as e:
        print(f"[Ember] Ryx migrate skipped: {e}")
