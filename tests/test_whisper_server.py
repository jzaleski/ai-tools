import io
import json
import os
import sys
import tempfile
import unittest
from unittest.mock import MagicMock, patch

# Ensure repository root is in sys.path
repo_root = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
if repo_root not in sys.path:
    sys.path.insert(0, repo_root)

import lib.whisper_server as ws


class TestWhisperServerArgs(unittest.TestCase):
    def test_parse_args_defaults(self):
        with patch.object(sys, "argv", ["whisper_server.py"]):
            with patch.dict(os.environ, {}, clear=True):
                args = ws.parse_args()
                self.assertEqual(args.host, "127.0.0.1")
                self.assertEqual(args.port, 8765)
                self.assertEqual(args.model, "turbo")

    def test_parse_args_env_overrides(self):
        env = {
            "WHISPER_HOST": "0.0.0.0",
            "WHISPER_PORT": "8766",
            "WHISPER_MODEL": "base",
            "WHISPER_DEVICE": "cpu",
        }
        with patch.object(sys, "argv", ["whisper_server.py"]):
            with patch.dict(os.environ, env, clear=True):
                args = ws.parse_args()
                self.assertEqual(args.host, "0.0.0.0")
                self.assertEqual(args.port, 8766)
                self.assertEqual(args.model, "base")
                self.assertEqual(args.device, "cpu")

    def test_parse_args_cli_overrides(self):
        cli = [
            "whisper_server.py",
            "--host",
            "10.0.0.1",
            "--port",
            "8770",
            "--model",
            "small",
            "--device",
            "cuda:1",
        ]
        with patch.object(sys, "argv", cli):
            args = ws.parse_args()
            self.assertEqual(args.host, "10.0.0.1")
            self.assertEqual(args.port, 8770)
            self.assertEqual(args.model, "small")
            self.assertEqual(args.device, "cuda:1")

    def test_parse_args_general_env_fallback(self):
        env = {
            "HOST": "0.0.0.0",
            "PORT": "9000",
        }
        with patch.object(sys, "argv", ["whisper_server.py"]):
            with patch.dict(os.environ, env, clear=True):
                args = ws.parse_args()
                self.assertEqual(args.host, "0.0.0.0")
                self.assertEqual(args.port, 9000)

    def test_parse_args_whisper_env_precedence_over_general(self):
        env = {
            "HOST": "1.1.1.1",
            "PORT": "8000",
            "WHISPER_HOST": "2.2.2.2",
            "WHISPER_PORT": "8888",
        }
        with patch.object(sys, "argv", ["whisper_server.py"]):
            with patch.dict(os.environ, env, clear=True):
                args = ws.parse_args()
                self.assertEqual(args.host, "2.2.2.2")
                self.assertEqual(args.port, 8888)

    def test_parse_args_short_flags(self):
        cli = [
            "whisper_server.py",
            "-H",
            "192.168.1.100",
            "-p",
            "8999",
            "-m",
            "medium",
            "-d",
            "cpu",
        ]
        with patch.object(sys, "argv", cli):
            with patch.dict(os.environ, {}, clear=True):
                args = ws.parse_args()
                self.assertEqual(args.host, "192.168.1.100")
                self.assertEqual(args.port, 8999)
                self.assertEqual(args.model, "medium")
                self.assertEqual(args.device, "cpu")


class TestGetDefaultDevice(unittest.TestCase):
    def test_cuda_available_returns_cuda(self):
        with patch.dict(os.environ, {}, clear=True):
            with patch.object(ws.torch.cuda, "is_available", return_value=True):
                self.assertEqual(ws.get_default_device(), "cuda")

    def test_mps_available_returns_mps_when_cuda_unavailable(self):
        with patch.dict(os.environ, {}, clear=True):
            with patch.object(ws.torch.cuda, "is_available", return_value=False):
                with patch.object(
                    ws.torch.backends.mps, "is_available", return_value=True
                ):
                    self.assertEqual(ws.get_default_device(), "mps")

    def test_cpu_fallback_when_neither_cuda_nor_mps(self):
        with patch.dict(os.environ, {}, clear=True):
            with patch.object(ws.torch.cuda, "is_available", return_value=False):
                with patch.object(
                    ws.torch.backends.mps, "is_available", return_value=False
                ):
                    self.assertEqual(ws.get_default_device(), "cpu")

    def test_env_var_overrides_detection(self):
        with patch.dict(os.environ, {"WHISPER_DEVICE": "cpu"}, clear=True):
            with patch.object(ws.torch.cuda, "is_available", return_value=True):
                self.assertEqual(ws.get_default_device(), "cpu")

        with patch.dict(os.environ, {"WHISPER_DEVICE": "mps"}, clear=True):
            with patch.object(ws.torch.cuda, "is_available", return_value=True):
                self.assertEqual(ws.get_default_device(), "mps")


class TestWhisperRequestHandler(unittest.TestCase):
    def test_health_check_payload(self):
        handler = MagicMock(spec=ws.WhisperRequestHandler)
        handler.path = "/health"
        ws.current_model_name = "turbo"
        ws.current_device = "cpu"
        ws.model = MagicMock()

        ws.WhisperRequestHandler.do_GET(handler)
        handler.send_json_response.assert_called_once()
        status_code, data = handler.send_json_response.call_args[0]
        self.assertEqual(status_code, 200)
        self.assertEqual(data["status"], "ok")
        self.assertEqual(data["model"], "turbo")
        self.assertEqual(data["device"], "cpu")
        self.assertIn("cuda_available", data)
        self.assertIn("mps_available", data)

    def test_models_payload(self):
        handler = MagicMock(spec=ws.WhisperRequestHandler)
        handler.path = "/v1/models"
        ws.current_model_name = "turbo"

        ws.WhisperRequestHandler.do_GET(handler)
        handler.send_json_response.assert_called_once()
        status_code, data = handler.send_json_response.call_args[0]
        self.assertEqual(status_code, 200)
        self.assertEqual(data["object"], "list")
        self.assertEqual(len(data["data"]), 1)
        self.assertEqual(data["data"][0]["id"], "turbo")
        self.assertEqual(data["data"][0]["object"], "model")

    def test_unknown_get_endpoint_returns_404(self):
        handler = MagicMock(spec=ws.WhisperRequestHandler)
        handler.path = "/unknown"

        ws.WhisperRequestHandler.do_GET(handler)
        handler.send_json_response.assert_called_once()
        status_code, data = handler.send_json_response.call_args[0]
        self.assertEqual(status_code, 404)
        self.assertIn("error", data)


class TestWhisperTranscriptionHandling(unittest.TestCase):
    def test_do_post_unknown_endpoint(self):
        handler = MagicMock(spec=ws.WhisperRequestHandler)
        handler.path = "/v1/unknown"

        ws.WhisperRequestHandler.do_POST(handler)
        handler.send_json_response.assert_called_once()
        status_code, data = handler.send_json_response.call_args[0]
        self.assertEqual(status_code, 404)
        self.assertIn("error", data)

    def test_do_post_invalid_content_length(self):
        handler = MagicMock(spec=ws.WhisperRequestHandler)
        handler.path = "/v1/audio/transcriptions"
        handler.headers = {
            "Content-Type": "application/json",
            "Content-Length": "invalid",
        }

        ws.WhisperRequestHandler.do_POST(handler)
        handler.send_json_response.assert_called_once()
        status_code, data = handler.send_json_response.call_args[0]
        self.assertEqual(status_code, 400)
        self.assertIn("error", data)

    def test_do_post_content_length_zero_or_negative(self):
        for cl_val in ["0", "-5"]:
            handler = MagicMock(spec=ws.WhisperRequestHandler)
            handler.path = "/v1/audio/transcriptions"
            handler.headers = {
                "Content-Type": "application/json",
                "Content-Length": cl_val,
            }

            ws.WhisperRequestHandler.do_POST(handler)
            handler.send_json_response.assert_called_once()
            status_code, data = handler.send_json_response.call_args[0]
            self.assertEqual(status_code, 400)
            self.assertIn("error", data)

    def test_do_post_unsupported_content_type(self):
        handler = MagicMock(spec=ws.WhisperRequestHandler)
        handler.path = "/v1/audio/transcriptions"
        handler.headers = {
            "Content-Type": "text/plain",
            "Content-Length": "10",
        }
        handler.rfile = io.BytesIO(b"0123456789")

        ws.WhisperRequestHandler.do_POST(handler)
        handler.send_json_response.assert_called_once()
        status_code, data = handler.send_json_response.call_args[0]
        self.assertEqual(status_code, 400)
        self.assertIn("Unsupported Content-Type", data["error"])

    def test_do_post_no_audio_file_provided(self):
        handler = MagicMock(spec=ws.WhisperRequestHandler)
        handler.path = "/v1/audio/transcriptions"
        body = json.dumps({"foo": "bar"}).encode("utf-8")
        handler.headers = {
            "Content-Type": "application/json",
            "Content-Length": str(len(body)),
        }
        handler.rfile = io.BytesIO(body)

        ws.WhisperRequestHandler.do_POST(handler)
        handler.send_json_response.assert_called_once()
        status_code, data = handler.send_json_response.call_args[0]
        self.assertEqual(status_code, 400)
        self.assertIn("No valid audio file provided", data["error"])

    def test_do_post_temp_files_cleaned_up_on_error(self):
        handler = MagicMock(spec=ws.WhisperRequestHandler)
        handler.path = "/v1/audio/transcriptions"
        boundary = "----WebKitFormBoundaryTest123"
        body = (
            f"--{boundary}\r\n"
            f'Content-Disposition: form-data; name="file"; filename="test.m4a"\r\n'
            f"Content-Type: audio/m4a\r\n\r\n"
            f"dummy audio data\r\n"
            f"--{boundary}--\r\n"
        ).encode("utf-8")
        handler.headers = {
            "Content-Type": f"multipart/form-data; boundary={boundary}",
            "Content-Length": str(len(body)),
        }
        handler.rfile = io.BytesIO(body)

        mock_model = MagicMock()
        mock_model.transcribe.side_effect = RuntimeError("transcription failed")
        ws.model = mock_model

        created_files = []
        original_named_temp_file = ws.tempfile.NamedTemporaryFile

        def tracking_temp_file(*args, **kwargs):
            tmp = original_named_temp_file(*args, **kwargs)
            created_files.append(tmp.name)
            return tmp

        with patch("tempfile.NamedTemporaryFile", side_effect=tracking_temp_file):
            with patch("sys.stderr"):
                ws.WhisperRequestHandler.do_POST(handler)

        self.assertTrue(len(created_files) > 0)
        for created_file in created_files:
            self.assertFalse(
                os.path.exists(created_file),
                f"File {created_file} was not cleaned up",
            )
        status_code, data = handler.send_json_response.call_args[0]
        self.assertEqual(status_code, 500)
        self.assertIn("error", data)

    def test_do_post_audio_load_error_returns_status_400(self):
        handler = MagicMock(spec=ws.WhisperRequestHandler)
        handler.path = "/v1/audio/transcriptions"
        boundary = "----WebKitFormBoundaryAudioLoadErr"
        body = (
            f"--{boundary}\r\n"
            f'Content-Disposition: form-data; name="file"; filename="test.mp4"\r\n'
            f"Content-Type: video/mp4\r\n\r\n"
            f"dummy video data\r\n"
            f"--{boundary}--\r\n"
        ).encode("utf-8")
        handler.headers = {
            "Content-Type": f"multipart/form-data; boundary={boundary}",
            "Content-Length": str(len(body)),
        }
        handler.rfile = io.BytesIO(body)

        mock_model = MagicMock()
        mock_model.transcribe.side_effect = RuntimeError(
            "Failed to load audio: ffmpeg ... Output file does not contain any stream"
        )
        ws.model = mock_model

        with patch("sys.stderr"):
            ws.WhisperRequestHandler.do_POST(handler)

        handler.send_json_response.assert_called_once()
        status_code, data = handler.send_json_response.call_args[0]
        self.assertEqual(status_code, 400)
        self.assertIn("Failed to load audio", data["error"])

    def test_do_post_successful_transcription_logs_elapsed(self):
        handler = MagicMock(spec=ws.WhisperRequestHandler)
        handler.path = "/v1/audio/transcriptions"
        boundary = "----WebKitFormBoundaryTest456"
        body = (
            f"--{boundary}\r\n"
            f'Content-Disposition: form-data; name="file"; filename="test.m4a"\r\n'
            f"Content-Type: audio/m4a\r\n\r\n"
            f"dummy audio data\r\n"
            f"--{boundary}--\r\n"
        ).encode("utf-8")
        handler.headers = {
            "Content-Type": f"multipart/form-data; boundary={boundary}",
            "Content-Length": str(len(body)),
        }
        handler.rfile = io.BytesIO(body)

        mock_model = MagicMock()
        mock_model.transcribe.return_value = {
            "text": "Hello world",
            "language": "en",
            "segments": [
                {
                    "id": 0,
                    "start": 0.0,
                    "end": 1.5,
                    "text": "Hello world",
                    "avg_logprob": -0.2,
                }
            ],
        }
        ws.model = mock_model

        ws.WhisperRequestHandler.do_POST(handler)

        handler.send_json_response.assert_called_once()
        status_code, data = handler.send_json_response.call_args[0]
        self.assertEqual(status_code, 200)
        self.assertEqual(data["text"], "Hello world")
        self.assertEqual(data["language"], "en")
        self.assertEqual(data["duration"], 1.5)
        self.assertEqual(len(data["segments"]), 1)
        handler.log_message.assert_called_once()
        log_fmt = handler.log_message.call_args[0][0]
        self.assertIn("Transcription completed in", log_fmt)

    def test_do_post_cpu_disables_fp16(self):
        handler = MagicMock(spec=ws.WhisperRequestHandler)
        handler.path = "/v1/audio/transcriptions"
        boundary = "----WebKitFormBoundaryCpuTest"
        body = (
            f"--{boundary}\r\n"
            f'Content-Disposition: form-data; name="file"; filename="test.m4a"\r\n'
            f"Content-Type: audio/m4a\r\n\r\n"
            f"dummy audio data\r\n"
            f"--{boundary}--\r\n"
        ).encode("utf-8")
        handler.headers = {
            "Content-Type": f"multipart/form-data; boundary={boundary}",
            "Content-Length": str(len(body)),
        }
        handler.rfile = io.BytesIO(body)

        ws.current_device = "cpu"
        mock_model = MagicMock()
        mock_model.device = ws.torch.device("cpu")
        mock_model.transcribe.return_value = {"text": "cpu test", "segments": []}
        ws.model = mock_model

        ws.WhisperRequestHandler.do_POST(handler)
        self.assertEqual(mock_model.transcribe.call_args[1].get("fp16"), False)

    def test_do_post_non_cpu_keeps_default_fp16(self):
        handler = MagicMock(spec=ws.WhisperRequestHandler)
        handler.path = "/v1/audio/transcriptions"
        boundary = "----WebKitFormBoundaryMpsTest"
        body = (
            f"--{boundary}\r\n"
            f'Content-Disposition: form-data; name="file"; filename="test.m4a"\r\n'
            f"Content-Type: audio/m4a\r\n\r\n"
            f"dummy audio data\r\n"
            f"--{boundary}--\r\n"
        ).encode("utf-8")
        handler.headers = {
            "Content-Type": f"multipart/form-data; boundary={boundary}",
            "Content-Length": str(len(body)),
        }
        handler.rfile = io.BytesIO(body)

        ws.current_device = "mps"
        mock_model = MagicMock()
        mock_model.device = ws.torch.device("mps:0")
        mock_model.transcribe.return_value = {"text": "mps test", "segments": []}
        ws.model = mock_model

        ws.WhisperRequestHandler.do_POST(handler)
        self.assertNotIn("fp16", mock_model.transcribe.call_args[1])

    def test_do_post_json_local_path_transcription(self):
        with tempfile.NamedTemporaryFile(suffix=".m4a", delete=False) as tmp_audio:
            tmp_audio.write(b"dummy local audio")
            local_path = tmp_audio.name

        try:
            handler = MagicMock(spec=ws.WhisperRequestHandler)
            handler.path = "/v1/audio/transcriptions"
            body = json.dumps({"path": local_path, "language": "es"}).encode("utf-8")
            handler.headers = {
                "Content-Type": "application/json",
                "Content-Length": str(len(body)),
            }
            handler.rfile = io.BytesIO(body)

            mock_model = MagicMock()
            mock_model.transcribe.return_value = {
                "text": "Hola mundo",
                "language": "es",
                "segments": [
                    {
                        "id": 0,
                        "start": 0.0,
                        "end": 2.0,
                        "text": "Hola mundo",
                        "avg_logprob": -0.1,
                    }
                ],
            }
            ws.model = mock_model

            ws.WhisperRequestHandler.do_POST(handler)

            handler.send_json_response.assert_called_once()
            status_code, data = handler.send_json_response.call_args[0]
            self.assertEqual(status_code, 200)
            self.assertEqual(data["text"], "Hola mundo")
            self.assertEqual(data["language"], "es")
            self.assertEqual(mock_model.transcribe.call_args[1].get("language"), "es")
            self.assertEqual(
                mock_model.transcribe.call_args[1].get("audio"), local_path
            )
        finally:
            if os.path.exists(local_path):
                os.remove(local_path)


if __name__ == "__main__":
    unittest.main()
