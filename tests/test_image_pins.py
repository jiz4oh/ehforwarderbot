from pathlib import Path


DOCKERFILE = (Path(__file__).parents[1] / "Dockerfile").read_text(encoding="utf-8")


def test_image_pins_login_recovery_revisions_and_preserves_http_hook():
    assert "efb-telegram-master.git@64cbe34c373a86985318ef8a6c9831feea067425" in DOCKERFILE
    assert "python-comwechatrobot-http.git@687e2374dab5aa04c136c173d511ac8a8c89dbb5" in DOCKERFILE
    assert "efb-wechat-comwechat-slave.git@0fb6199ae06812ec703e7dcbb4802fc30bbf0660" in DOCKERFILE
    assert 'ENV EFB_IMAGE_REVISION "64cbe34-0fb6199-http687e237-' in DOCKERFILE
    assert "bridge-13d443a-watchdog-edde14a" in DOCKERFILE
    assert 'ENV EFB_TELEGRAM_MASTER_REVISION "64cbe34c373a86985318ef8a6c9831feea067425"' in DOCKERFILE
    assert 'ENV EFB_COMWECHAT_SLAVE_REVISION "0fb6199ae06812ec703e7dcbb4802fc30bbf0660"' in DOCKERFILE
